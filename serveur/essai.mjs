//
//  essai.mjs — le salon, éprouvé de bout en bout
//
//  Deux joueurs, un code, une coupure et un retour. Aucune des vérifications
//  ci-dessous ne se fait à l'œil : un salon qui recopie un paquet à
//  l'envoyeur, un retardataire qu'on laisse entrer dans une partie commencée,
//  un revenant qu'on refuse — tout cela se voit depuis le jeu comme « ça ne
//  marche pas », sans jamais dire où.
//
//  À lancer sur le serveur de développement :
//
//      npm run dev      (dans une fenêtre)
//      npm test         (dans une autre)
//
//  Aucune attente n'est un délai fixe. La première version dormait trois
//  cents millisecondes après chaque envoi, et elle passait — jusqu'à ce que
//  la machine soit occupée ailleurs : onze vérifications sur vingt et une se
//  sont mises à échouer d'un coup, sur un serveur qui n'avait pas changé
//  d'une ligne. Un essai qui dépend de la charge de la machine ne prouve
//  rien, et il accuse l'innocent. On attend donc **ce qu'on attend**, et le
//  délai n'est plus qu'une limite de patience.
//

// Par défaut le serveur de développement ; `RISKELO_SALON` vise ailleurs —
// c'est ainsi qu'on éprouve le serveur **déployé**, et non seulement sa copie
// locale. Un salon d'essai vit deux minutes et s'efface : le faire sur le vrai
// serveur ne coûte rien et ne dérange personne.
//
//     RISKELO_SALON=riskelo-salon.riskelo-salon.workers.dev npm test
const HOTE = process.env.RISKELO_SALON ?? "localhost:8787";
const CHIFFRE = !HOTE.startsWith("localhost") && !HOTE.startsWith("127.0.0.1");
const BASE = `${CHIFFRE ? "wss" : "ws"}://${HOTE}/salon`;
const WEB = `${CHIFFRE ? "https" : "http"}://${HOTE}`;
let rate = 0;

function verifier(quoi, vrai) {
  console.log((vrai ? "  ok   " : "  RATÉ ") + quoi);
  if (!vrai) rate++;
}

/// Attendre qu'une chose devienne vraie, et rendre la main dès qu'elle l'est.
async function jusqua(condition, limite = 4000) {
  const fin = Date.now() + limite;
  while (Date.now() < fin) {
    if (condition()) return true;
    await new Promise((r) => setTimeout(r, 15));
  }
  return false;
}

/// Attendre un message d'une certaine sorte, et le rendre.
async function attendre(ws, quoi, limite = 4000) {
  await jusqua(() => ws.recus.some(quoi), limite);
  return ws.recus.find(quoi);
}

function relier(params) {
  const url = new URL(BASE);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
  const ws = new WebSocket(url);
  ws.recus = [];
  ws.onmessage = (e) => ws.recus.push(JSON.parse(e.data));
  return new Promise((res, rej) => {
    ws.onopen = () => res(ws);
    ws.onerror = () => rej(new Error("liaison refusée"));
  });
}

const b64 = (s) => Buffer.from(s).toString("base64");
const estUnPaquet = (m) => m.t === "paquet";
/// Laisser au serveur le temps de *ne pas* envoyer ce qu'il ne doit pas
/// envoyer. C'est le seul endroit où un délai fixe est la bonne réponse :
/// on vérifie une absence, et une absence n'arrive jamais.
const silence = () => new Promise((r) => setTimeout(r, 250));

// --- 1. L'hôte ouvre -------------------------------------------------------
const hote = await relier({ id: "AAA", dialecte: "7", hote: "1" });
const premier = await attendre(hote, (m) => m.t === "salon");
verifier("l'hôte reçoit son salon", !!premier);
const code = premier?.code;
verifier(`le code a six lettres (${code})`,
  /^[BCDFGHJKLMNPRSTVZ][AEIOU][BCDFGHJKLMNPRSTVZ][AEIOU][BCDFGHJKLMNPRSTVZ][AEIOU]$/.test(code || ""));
verifier("le salon est vide", premier?.gens?.length === 0);

// --- 2. Un code qui n'existe pas -------------------------------------------
const perdu = await relier({ id: "ZZZ", dialecte: "7", code: "BABEBI" });
verifier("un code inconnu est refusé en le disant",
  (await attendre(perdu, (m) => m.t === "refus"))?.pourquoi === "inconnu");

// --- 3. Une autre version du jeu -------------------------------------------
const vieux = await relier({ id: "VVV", dialecte: "3", code });
verifier("une autre version est refusée, et nommée",
  (await attendre(vieux, (m) => m.t === "refus"))?.pourquoi === "dialecte");

// --- 4. L'invité entre -----------------------------------------------------
const invite = await relier({ id: "BBB", dialecte: "7", code });
const vu = await attendre(invite, (m) => m.t === "salon");
verifier("l'invité voit l'hôte déjà là", vu?.gens?.[0]?.id === "AAA");
verifier("l'hôte apprend son arrivée",
  !!(await attendre(hote, (m) => m.t === "arrivee" && m.id === "BBB")));
// Le serveur ne doit jamais rien savoir des joueurs. Un prénom qui
// apparaîtrait ici serait un prénom dans les journaux de Cloudflare.
verifier("et rien de plus que son identifiant",
  Object.keys(hote.recus.find((m) => m.t === "arrivee") || {}).sort().join() === "id,t");

// --- 5. Un coup passe ------------------------------------------------------
hote.recus.length = 0; invite.recus.length = 0;
invite.send(JSON.stringify({ t: "vers", d: b64("un coup") }));
const recu = await attendre(hote, estUnPaquet);
verifier("le coup arrive chez l'hôte", !!recu);
verifier("il arrive intact", Buffer.from(recu?.d || "", "base64").toString() === "un coup");
verifier("il sait de qui il vient", recu?.de === "BBB");
verifier("il ne revient pas à l'envoyeur", !invite.recus.some(estUnPaquet));

// --- 6. Un envoi nominatif -------------------------------------------------
const tiers = await relier({ id: "CCC", dialecte: "7", code });
await attendre(tiers, (m) => m.t === "salon");
hote.recus.length = 0; invite.recus.length = 0; tiers.recus.length = 0;
hote.send(JSON.stringify({ t: "vers", a: "CCC", d: b64("ton rang") }));
await attendre(tiers, estUnPaquet);
await silence();
verifier("« à un seul » ne va qu'à lui",
  tiers.recus.some(estUnPaquet) && !invite.recus.some(estUnPaquet));

hote.recus.length = 0; invite.recus.length = 0; tiers.recus.length = 0;
hote.send(JSON.stringify({ t: "vers", sauf: "CCC", d: b64("relais") }));
await attendre(invite, estUnPaquet);
await silence();
verifier("« à tous sauf un » saute le bon",
  invite.recus.some(estUnPaquet) && !tiers.recus.some(estUnPaquet));

// --- 7. La partie part, un retardataire est refusé --------------------------
hote.send(JSON.stringify({ t: "ferme" }));
// Rien ne revient d'un « ferme » : on attend son effet, qui est le refus
// suivant. Un retardataire admis ici voudrait dire que l'ordre n'a pas porté.
const tard = await relier({ id: "DDD", dialecte: "7", code });
verifier("une partie commencée n'accueille plus",
  (await attendre(tard, (m) => m.t === "refus"))?.pourquoi === "commence");

// --- 8. La coupure, et le retour -------------------------------------------
hote.recus.length = 0;
invite.close();
verifier("l'hôte apprend le départ",
  !!(await attendre(hote, (m) => m.t === "depart" && m.id === "BBB")));

hote.recus.length = 0;
const revenu = await relier({ id: "BBB", dialecte: "7", code });
const reprise = await attendre(revenu, (m) => m.t === "salon");
verifier("celui qui revient est repris malgré la partie commencée", !!reprise);
verifier("il retrouve les autres",
  (reprise?.gens || []).map((g) => g.id).sort().join() === "AAA,CCC");
verifier("l'hôte est prévenu de son retour — c'est ce qui déclenche le renvoi de la partie",
  !!(await attendre(hote, (m) => m.t === "arrivee" && m.id === "BBB")));

// --- 9. La page qu'on reçoit par WhatsApp ----------------------------------
const page = await fetch(`${WEB}/p/${code}`).then((r) => r.text());
verifier("la page d'invitation porte le code", page.includes(code));
verifier("elle sait ouvrir le jeu", page.includes(`riskelo://p/${code}`));
const aasa = await fetch(`${WEB}/.well-known/apple-app-site-association`)
  .then((r) => r.json());
verifier("le fichier d'Apple désigne la bonne application",
  aasa?.applinks?.details?.[0]?.appIDs?.[0] === "38DQ8FW23J.com.oulhen.riskelo");

console.log(rate === 0 ? "\nTout passe." : `\n${rate} essai(s) raté(s).`);
process.exit(rate === 0 ? 0 : 1);
