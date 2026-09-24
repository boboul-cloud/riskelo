//
//  index.js — Riskelo, le serveur des salons
//
//  Ce serveur ne connaît pas Riskelo.
//
//  Il ne sait pas ce qu'est un territoire, ne compte les points de personne,
//  ne voit jamais une question ni une réponse. Il tient des salons désignés
//  par six lettres, et il recopie d'un appareil à l'autre des paquets dont il
//  ignore le contenu. Toute la partie se joue sur les appareils, exactement
//  comme dans la même pièce : c'est la seule raison pour laquelle ce fichier
//  peut tenir en trois cents lignes au lieu de trois mille.
//
//  C'est aussi ce qui le rend anodin en cas de panne. Un serveur qui tiendrait
//  la partie perdrait la partie en tombant. Celui-ci, en tombant, interrompt
//  une liaison — et les appareils la rétablissent d'eux-mêmes, avec l'état que
//  chacun garde de son côté.
//
//  ## Ce qu'il garde, et pendant combien de temps
//
//  Trois valeurs par salon : qui l'a ouvert, quel dialecte on y parle, et si
//  la partie est partie. Plus la liste des identifiants admis, qui sert
//  uniquement à laisser revenir ceux qui y étaient. Une semaine après le
//  départ du dernier, tout est effacé — le code redevient libre.
//
//  Une semaine, parce qu'une partie de Riskelo ne tient pas dans une soirée
//  et que deux personnes ne sont pas libres à la même heure. Ce qui attend
//  pendant ce temps-là, c'est un point de rendez-vous, pas une partie : la
//  partie dort sur les appareils, et celui qui l'a ouverte la redonne à
//  chacun quand tout le monde est revenu.
//
//  Un « identifiant » est un nombre tiré au sort à l'installation du jeu. Il
//  ne désigne personne, et le serveur ne reçoit rien d'autre : **aucun nom de
//  joueur ne lui parvient jamais**, pas même dans l'adresse de connexion, où
//  il finirait dans les journaux. Les prénoms sont à l'intérieur des paquets
//  que ce fichier recopie sans savoir les lire.
//

import { DurableObject } from "cloudflare:workers";

/// L'équipe et le paquet, pour le fichier qu'Apple vient lire afin de savoir
/// que ce site et cette application sont la même maison. Sans lui, un lien
/// ouvre le navigateur au lieu du jeu.
const EQUIPE = "38DQ8FW23J";
const PAQUET = "com.oulhen.riskelo";
/// La fiche de Riskelo sur l'App Store : c'est là que mène la page
/// d'invitation quand on n'a pas encore le jeu. Elle portait un numéro
/// d'exemple tant que la fiche n'existait pas.
const APP_STORE = "https://apps.apple.com/app/riskelo/id6806804539";

/// Le même alphabet que dans l'application — voir `Relais.consonnes`.
/// Consonne, voyelle, consonne, voyelle, consonne, voyelle : un code qui se
/// dicte au téléphone autant qu'il se colle dans WhatsApp.
const CONSONNES = "BCDFGHJKLMNPRSTVZ";
const VOYELLES = "AEIOU";
const LONGUEUR = 6;

/// Quatre joueurs, un appareil chacun. C'est la limite du jeu, pas celle du
/// serveur — mais c'est ici qu'elle se fait respecter.
const MAX_JOUEURS = 4;

/// Combien de temps un salon vide garde sa place.
///
/// Une semaine, et non plus deux minutes. Les deux minutes ne couvraient que
/// la coupure — le tunnel, l'ascenseur, l'appel qu'on prend — et une partie
/// qui s'arrêtait là était une partie perdue : le code mourait avant qu'on
/// ait pu se redonner rendez-vous.
///
/// Or une partie de Riskelo dure plus qu'une soirée, et deux personnes ne
/// sont pas toujours libres la même heure. Le salon garde donc le code au
/// chaud jusqu'au week-end suivant. Il ne garde pas la partie pour autant :
/// elle est sur les appareils, et elle y reste. Ce qui vit ici tient en
/// quelques octets — qui a ouvert, quel dialecte, et la liste de ceux qu'on
/// laisse revenir.
///
/// À ne pas confondre avec les deux minutes de `Relais.dureeDeGrace`, qui
/// sont restées ce qu'elles étaient : elles disent combien de temps
/// l'application rappelle **toute seule** après une coupure. Au-delà, elle
/// rend la main — mais le code, lui, marche encore.
const GRACE_MS = 7 * 24 * 60 * 60 * 1000;

// ---------------------------------------------------------------------------
// Le code
// ---------------------------------------------------------------------------

function tirerUnCode() {
  const octets = new Uint8Array(LONGUEUR);
  crypto.getRandomValues(octets);
  let code = "";
  for (let i = 0; i < LONGUEUR; i++) {
    const alphabet = i % 2 === 0 ? CONSONNES : VOYELLES;
    code += alphabet[octets[i] % alphabet.length];
  }
  return code;
}

/// Le zéro et la lettre O, le un et le I : personne ne les distingue à
/// l'écrit. On les redresse plutôt que de renvoyer « ce code n'existe pas »
/// à quelqu'un qui a tapé exactement ce qu'il voyait.
function normaliser(brut) {
  return (brut || "")
    .toUpperCase()
    .replace(/0/g, "O")
    .replace(/1/g, "I")
    .replace(/[^A-Z]/g, "")
    .slice(0, LONGUEUR);
}

function estUnCode(brut) {
  const code = normaliser(brut);
  if (code.length !== LONGUEUR) return false;
  for (let i = 0; i < LONGUEUR; i++) {
    const alphabet = i % 2 === 0 ? CONSONNES : VOYELLES;
    if (!alphabet.includes(code[i])) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Le salon
// ---------------------------------------------------------------------------

export class Salon extends DurableObject {

  async fetch(request) {
    const url = new URL(request.url);
    const code = normaliser(url.searchParams.get("code"));
    const id = url.searchParams.get("id") || "";
    const dialecte = url.searchParams.get("dialecte") || "";
    const veutHeberger = url.searchParams.get("hote") === "1";

    if (!id) return new Response("sans identité", { status: 400 });

    const hote = await this.ctx.storage.get("hote");
    const dialecteDuSalon = await this.ctx.storage.get("dialecte");
    const commence = (await this.ctx.storage.get("commence")) === true;
    const admis = (await this.ctx.storage.get("admis")) || [];
    const dejaVu = admis.includes(id);

    // Celui qui ouvre : le code doit être libre, ou déjà le sien — il revient
    // chez lui, une semaine après s'il le faut. Sinon 409. Quand il ouvrait
    // une partie neuve, le serveur en tirait simplement un autre et le joueur
    // n'en savait rien ; quand il reprend la sienne, il n'y a pas d'autre
    // code à tirer, et c'est à lui qu'on le dit.
    if (veutHeberger && hote !== undefined && hote !== id) {
      return new Response("code occupé", { status: 409 });
    }

    const [client, serveur] = Object.values(new WebSocketPair());
    // `acceptWebSocket` et non `accept` : le salon peut s'endormir entre deux
    // coups sans que la liaison tombe. Un joueur qui réfléchit quinze
    // secondes ne coûte alors rien du tout.
    this.ctx.acceptWebSocket(serveur);
    // L'identifiant seul. Pas de nom : le serveur n'en reçoit aucun, et
    // c'est délibéré — voir `Relais.composer` du côté de l'application. Les
    // prénoms voyagent dans les paquets, que ce fichier recopie sans savoir
    // les lire.
    serveur.serializeAttachment({ id });

    const refuser = (pourquoi) => {
      serveur.send(JSON.stringify({ t: "refus", pourquoi }));
      serveur.close(1000, pourquoi);
      return new Response(null, { status: 101, webSocket: client });
    };

    if (!veutHeberger) {
      if (hote === undefined) return refuser("inconnu");
      // Deux versions du jeu ne peuvent pas jouer ensemble. Le dire ici, à
      // l'entrée, vaut infiniment mieux que de le découvrir au lancement :
      // là-bas, la panne ressemble à une panne de réseau.
      if (dialecteDuSalon !== undefined && dialecteDuSalon !== dialecte) {
        return refuser("dialecte");
      }
      if (commence && !dejaVu) return refuser("commence");
      const ouverts = this.vivants().length;
      if (!dejaVu && ouverts >= MAX_JOUEURS) return refuser("plein");
    }

    // Le salon naît ici, au premier hôte.
    if (veutHeberger && hote === undefined) {
      await this.ctx.storage.put("hote", id);
      await this.ctx.storage.put("dialecte", dialecte);
      await this.ctx.storage.put("code", code);
    }
    if (!dejaVu) {
      await this.ctx.storage.put("admis", [...admis, id]);
    }

    // Quelqu'un est là : le salon ne s'efface plus.
    await this.ctx.storage.deleteAlarm();

    // Une ancienne liaison du même appareil qui traînerait encore. Elle
    // arrive : on se reconnecte souvent avant que le système n'ait constaté
    // que la précédente était morte.
    for (const autre of this.vivants()) {
      if (autre === serveur) continue;
      const qui = autre.deserializeAttachment();
      if (qui && qui.id === id) autre.close(1000, "remplacé");
    }

    // Son premier mot : le code, et qui est déjà là.
    serveur.send(JSON.stringify({
      t: "salon",
      code: code || (await this.ctx.storage.get("code")) || "",
      hote: veutHeberger ? id : hote,
      gens: this.vivants()
        .filter((ws) => ws !== serveur)
        .map((ws) => ws.deserializeAttachment())
        .filter(Boolean),   // { id } et rien d'autre
    }));

    // Et les autres apprennent son arrivée — ou son retour, ce qui pour eux
    // revient exactement au même : la partie leur sera redemandée.
    this.versLesAutres(serveur, { t: "arrivee", id });

    return new Response(null, { status: 101, webSocket: client });
  }

  // -------------------------------------------------------------------------

  async webSocketMessage(ws, message) {
    if (typeof message !== "string") return;
    const qui = ws.deserializeAttachment();
    if (!qui) return;

    let dit;
    try {
      dit = JSON.parse(message);
    } catch {
      return;
    }

    switch (dit.t) {
      case "vers": {
        // Le seul vrai travail du serveur, et il est aveugle : `d` est une
        // chaîne opaque qu'il recopie sans la lire.
        if (typeof dit.d !== "string") return;
        const paquet = JSON.stringify({ t: "paquet", de: qui.id, d: dit.d });
        for (const autre of this.vivants()) {
          if (autre === ws) continue;
          const lui = autre.deserializeAttachment();
          if (!lui) continue;
          if (dit.a && lui.id !== dit.a) continue;
          if (dit.sauf && lui.id === dit.sauf) continue;
          try {
            autre.send(paquet);
          } catch {
            // Une liaison morte qui n'est pas encore constatée. Le départ
            // sera annoncé par `webSocketClose`.
          }
        }
        return;
      }

      case "ferme": {
        // L'hôte lance la partie : le salon n'accueille plus de nouveaux
        // venus, mais laisse revenir ceux qui y étaient.
        const hote = await this.ctx.storage.get("hote");
        if (qui.id !== hote) return;
        await this.ctx.storage.put("commence", true);
        return;
      }

      default:
        return;
    }
  }

  async webSocketClose(ws, code, reason) {
    await this.partiCelui(ws);
    // Rendre la politesse : sans cela, la moitié de la fermeture reste en
    // suspens et le salon ne s'endort pas.
    try { ws.close(code, reason); } catch { /* déjà close */ }
  }

  async webSocketError(ws) {
    await this.partiCelui(ws);
  }

  async partiCelui(ws) {
    const qui = ws.deserializeAttachment();
    if (qui) this.versLesAutres(ws, { t: "depart", id: qui.id });
    // Le dernier a raccroché : le salon s'efface dans deux minutes, sauf si
    // quelqu'un revient d'ici là.
    //
    // Sauf s'il n'y a jamais eu de salon — un code mal tapé ouvre et referme
    // une liaison sans que rien n'existe derrière. Poser un réveil pour
    // effacer ce qui n'a pas été écrit ne servirait qu'à se faire facturer.
    if (this.vivants().filter((autre) => autre !== ws).length > 0) return;
    if ((await this.ctx.storage.get("hote")) === undefined) return;
    await this.ctx.storage.setAlarm(Date.now() + GRACE_MS);
  }

  async alarm() {
    // Quelqu'un est revenu entre-temps : on ne touche à rien.
    if (this.vivants().length > 0) return;
    await this.ctx.storage.deleteAll();
  }

  // -------------------------------------------------------------------------

  /// Les liaisons réellement ouvertes. `getWebSockets` peut encore rendre
  /// celle qui est en train de se fermer.
  vivants() {
    return this.ctx.getWebSockets().filter((ws) => ws.readyState === 1);
  }

  versLesAutres(sauf, objet) {
    const texte = JSON.stringify(objet);
    for (const ws of this.vivants()) {
      if (ws === sauf) continue;
      try {
        ws.send(texte);
      } catch {
        /* rien à faire : sa fermeture sera annoncée d'elle-même */
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Le serveur devant
// ---------------------------------------------------------------------------

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/salon") return ouvrirUnSalon(request, env, url);

    // Le fichier qu'Apple vient lire pour savoir que ce site et cette
    // application sont la même maison. Il doit être servi à la racine, en
    // JSON, sans redirection : trois conditions, et il suffit qu'une seule
    // manque pour qu'un lien ouvre le navigateur au lieu du jeu.
    if (url.pathname === "/.well-known/apple-app-site-association") {
      return Response.json({
        applinks: {
          details: [{ appIDs: [`${EQUIPE}.${PAQUET}`], components: [{ "/": "/p/*" }] }],
        },
      });
    }

    if (url.pathname.startsWith("/p/")) {
      return pageDInvitation(normaliser(url.pathname.slice(3)));
    }

    if (url.pathname === "/sante") return new Response("ok");

    return pageDInvitation(null);
  },
};

async function ouvrirUnSalon(request, env, url) {
  if (request.headers.get("Upgrade") !== "websocket") {
    return new Response("il faut une liaison WebSocket", { status: 426 });
  }

  const demande = url.searchParams;
  const veutHeberger = demande.get("hote") === "1";

  if (!veutHeberger) {
    const code = normaliser(demande.get("code"));
    if (!estUnCode(code)) {
      // Refuser ici plutôt que d'ouvrir un salon vide pour rien.
      return refusImmediat("inconnu");
    }
    return env.SALONS.getByName(code).fetch(reecrire(request, url, code));
  }

  // Celui qui reprend une partie revient avec le code qu'il avait. On ne lui
  // en tire pas un neuf : ses invités ont l'ancien, et c'est le seul point de
  // rendez-vous qu'ils connaissent. Le salon le reconnaît à son identifiant
  // et le laisse rentrer chez lui — ou rend 409 si le code a été repris par
  // quelqu'un d'autre depuis, ce qui se dit alors au joueur au lieu de le
  // faire atterrir chez un inconnu.
  const voulu = normaliser(demande.get("code"));
  if (voulu) {
    if (!estUnCode(voulu)) return refusImmediat("inconnu");
    const reponse = await env.SALONS.getByName(voulu)
      .fetch(reecrire(request, url, voulu));
    return reponse.status === 409 ? refusImmediat("repris") : reponse;
  }

  // On tire un code, et l'on demande au salon qu'il désigne s'il est libre.
  // Six cent mille codes pour quelques salons ouverts à la fois : une
  // collision est rare, mais elle n'est pas impossible, et un joueur qui
  // tomberait dans la partie d'un inconnu serait une panne inexplicable.
  for (let essai = 0; essai < 6; essai++) {
    const code = tirerUnCode();
    const reponse = await env.SALONS.getByName(code)
      .fetch(reecrire(request, url, code));
    if (reponse.status !== 409) return reponse;
  }
  return new Response("aucun code libre", { status: 503 });
}

/// La même demande, avec le code choisi — le salon le lit dans ses paramètres.
function reecrire(request, url, code) {
  const ou = new URL(url);
  ou.searchParams.set("code", code);
  return new Request(ou, request);
}

/// Un refus qui doit se lire dans le jeu, et non dans un journal.
///
/// On accepte la liaison pour la refuser aussitôt, au lieu de rendre une
/// erreur HTTP. Une liaison WebSocket qui échoue ne dit jamais *pourquoi* du
/// côté de l'appareil : le joueur n'aurait vu que « le serveur ne répond
/// pas », en ayant simplement mal tapé une lettre.
function refusImmediat(pourquoi) {
  const [client, serveur] = Object.values(new WebSocketPair());
  serveur.accept();
  serveur.send(JSON.stringify({ t: "refus", pourquoi }));
  serveur.close(1000, pourquoi);
  return new Response(null, { status: 101, webSocket: client });
}

// ---------------------------------------------------------------------------
// La page qu'on reçoit par WhatsApp
// ---------------------------------------------------------------------------

function pageDInvitation(code) {
  const titre = code ? `Partie de Riskelo — ${code}` : "Riskelo";
  const sousTitre = code
    ? `Quelqu'un vous attend. Le code de la partie est ${code}.`
    : "Un Risk où le lancer de dés est remplacé par une question de culture générale.";

  const html = `<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${echapper(titre)}</title>
<meta property="og:title" content="${echapper(titre)}">
<meta property="og:description" content="${echapper(sousTitre)}">
<meta property="og:type" content="website">
<style>
  :root { color-scheme: dark; }
  body {
    margin: 0; min-height: 100vh; display: grid; place-items: center;
    background: #171f29; color: #edeff2; padding: 24px;
    font: 17px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
  }
  main { max-width: 26rem; text-align: center; }
  h1 { font-size: 1.5rem; margin: 0 0 .5rem; }
  p { color: #949ead; margin: 0 0 1.5rem; }
  .code {
    font: 700 2.1rem/1 ui-monospace, "SF Mono", Menlo, monospace;
    letter-spacing: .35em; text-indent: .35em;
    background: #242b36; border-radius: 14px; padding: 1.1rem 0; margin: 0 0 1.5rem;
    color: #73b3fa;
  }
  a.bouton {
    display: block; text-decoration: none; border-radius: 12px;
    padding: .9rem 1rem; font-weight: 600; margin-bottom: .75rem;
    background: #3d82c7; color: #fff;
  }
  a.discret { background: none; color: #949ead; border: 1px solid #39404b; }
  small { color: #6b7684; display: block; margin-top: 1.5rem; font-size: .8rem; }
</style>
</head>
<body>
<main>
  <h1>${echapper(code ? "Une partie vous attend" : "Riskelo")}</h1>
  <p>${echapper(sousTitre)}</p>
  ${code ? `<div class="code">${echapper(code)}</div>
  <a class="bouton" href="riskelo://p/${echapper(code)}">Ouvrir dans Riskelo</a>
  <a class="discret bouton" href="${APP_STORE}">Je n'ai pas encore le jeu</a>
  <small>Si rien ne s'ouvre, lancez Riskelo, touchez « Jouer au loin »,
  puis « Rejoindre », et tapez le code ci-dessus.</small>`
  : `<a class="bouton" href="${APP_STORE}">Voir Riskelo sur l'App Store</a>`}
</main>
</body>
</html>`;

  return new Response(html, {
    headers: { "content-type": "text/html; charset=utf-8" },
  });
}

function echapper(texte) {
  return String(texte ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[c]);
}
