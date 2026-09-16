#!/usr/bin/env python3
"""
asc-achats.py — Riskelo, outil hors application

Crée les trente-quatre achats intégrés dans App Store Connect par l'API
officielle, plutôt qu'à la main dans trente-quatre formulaires.

Ce qu'il fait, pour chaque pack déclaré dans Resources/Questions/*.txt :

  1. crée l'article (non consommable, partage familial activé) ;
  2. ajoute sa localisation — française pour les packs français, anglaise
     pour les anglais ;
  3. téléverse sa capture de vérification.

Deux séries dans une seule app depuis la fusion : dix-sept packs français sous
« com.oulhen.riskelo.pack.… » et dix-sept anglais sous « …pack.us.… ». La
langue de chaque article est celle de son fichier de questions ; elle décide de
la fiche à déposer, de la note pour la revue et de la capture.

Ce qu'il ne fait pas, volontairement : le prix. Il n'est pas décidé, et le
poser par l'API demande de choisir un « price point » par territoire — une
mécanique à part, qui mérite d'être vue avant d'être subie. Trente-quatre prix
se posent vite dans l'interface une fois le reste en place.

Il ne fait rien sans --apply. Par défaut il liste ce qu'il ferait, sans réseau
et sans clé : de quoi relire les trente-quatre lignes avant d'ouvrir un compte.

    python3 outils/asc-achats.py                 # à blanc, hors ligne
    python3 outils/asc-achats.py --check         # à blanc, en comparant à Apple
    python3 outils/asc-achats.py --apply         # pour de vrai

Pour --check et --apply, il lui faut outils/asc-config.json, qui n'est pas
versionné :

    {
      "issuer_id": "...",            Utilisateurs et accès ▸ Intégrations
      "key_id":    "...",            l'identifiant de la clé
      "key_file":  "AuthKey_XXX.p8", le fichier téléchargé, gardé hors dépôt
      "app_id":    "..."             l'identifiant Apple de l'app, sur sa fiche
    }

La clé privée ouvre le compte développeur en écriture : elle ne se met pas dans
le dépôt, et .gitignore l'en empêche.
"""

import base64, glob, hashlib, json, os, re, subprocess, sys, time, urllib.error, urllib.request

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://api.appstoreconnect.apple.com"
FICHE = "soumission/packs-app-store.md"
LOCALES = {"fr": "fr-FR", "en": "en-US"}


# --- Le jeton -------------------------------------------------------------
#
# ES256 sans bibliothèque : openssl signe, et l'on convertit sa signature DER
# en la paire R||S de 64 octets que veut JWT. C'est la seule partie du script
# qui ne soit pas de la plomberie HTTP.

def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_en_rs(der: bytes) -> bytes:
    if der[0] != 0x30:
        raise ValueError("signature DER attendue")
    i = 2 if der[1] < 0x80 else 3 + (der[1] & 0x7F) - 1
    out = b""
    for _ in range(2):
        if der[i] != 0x02:
            raise ValueError("entier DER attendu")
        n = der[i + 1]
        v = der[i + 2 : i + 2 + n].lstrip(b"\x00")
        out += v.rjust(32, b"\x00")
        i += 2 + n
    return out


def jeton(cfg) -> str:
    tete = {"alg": "ES256", "kid": cfg["key_id"], "typ": "JWT"}
    corps = {"iss": cfg["issuer_id"], "iat": int(time.time()),
             "exp": int(time.time()) + 15 * 60, "aud": "appstoreconnect-v1"}
    signe = b64(json.dumps(tete).encode()) + "." + b64(json.dumps(corps).encode())
    p = subprocess.run(["openssl", "dgst", "-sha256", "-sign", cfg["_key_path"]],
                       input=signe.encode(), capture_output=True)
    if p.returncode:
        raise SystemExit("openssl : " + p.stderr.decode())
    return signe + "." + b64(der_en_rs(p.stdout))


# --- L'API ----------------------------------------------------------------

def appel(cfg, methode, chemin, corps=None, brut=None, type_contenu=None, doux=False):
    """Un appel. « doux » rend None sur une erreur d'Apple au lieu de s'arrêter :
    c'est pour les questions dont la réponse est facultative."""
    url = chemin if chemin.startswith("http") else API + chemin
    donnees = brut if brut is not None else (json.dumps(corps).encode() if corps else None)
    r = urllib.request.Request(url, data=donnees, method=methode)
    r.add_header("Authorization", "Bearer " + jeton(cfg))
    if brut is None and corps:
        r.add_header("Content-Type", "application/json")
    if type_contenu:
        r.add_header("Content-Type", type_contenu)
    try:
        with urllib.request.urlopen(r) as rep:
            t = rep.read()
            return json.loads(t) if t and rep.headers.get_content_type() == "application/json" else None
    except urllib.error.HTTPError as e:
        if doux:
            return None
        detail = e.read().decode()
        try:
            for err in json.loads(detail).get("errors", []):
                detail = "%s — %s" % (err.get("title", ""), err.get("detail", ""))
        except Exception:
            pass
        raise SystemExit("%s %s\n  %s %s\n  %s" % (e.code, e.reason, methode, chemin, detail))


# --- Ce qu'il y a à créer -------------------------------------------------

def packs():
    """Les packs, lus dans les fichiers de questions — la seule source des
    identifiants. Un identifiant mal recopié ne se rattrape pas ; celui-ci
    n'est jamais recopié."""
    out = []
    for chemin in sorted(glob.glob(os.path.join(RACINE, "Resources/Questions/*.txt"))):
        tete, n = {}, 0
        for ligne in open(chemin, encoding="utf-8"):
            l = ligne.strip()
            if l.startswith("!"):
                k, _, v = l[1:].partition("|")
                tete[k.strip()] = v.strip()
            elif l and not l.startswith("#"):
                n += 1
        pid = tete.get("produit") or tete.get("product")
        if pid:
            out.append({"id": pid,
                        "affiche": tete.get("nom") or tete.get("name"),
                        "rang": int(tete.get("rang") or tete.get("rank")),
                        "langue": "en" if tete.get("lang") == "en" else "fr",
                        "questions": n})
    out.sort(key=lambda p: (p["langue"] != "fr", p["rang"]))
    return out


def fiche():
    """Nom de référence, nom d'affichage, description et capture : ils sont
    dans la page des packs, qui est le document où on les a comptés."""
    s = open(os.path.join(RACINE, FICHE), encoding="utf-8").read()
    blocs = re.findall(
        r"Nom de référence\s+(.+)\n"
        r"Identifiant produit\s+(\S+)\n"
        r"Nom d'affichage\s+(.+)\n"
        r"Description\s+(.+)\n"
        r"Capture\s+(\S+)\n", s)
    return {pid: {"reference": ref.strip(), "affiche": aff.strip(),
                  "description": desc.strip(), "capture": cap.strip()}
            for ref, pid, aff, desc, cap in blocs}


def notes():
    """Les deux notes pour la revue, dans la même page. Elles ne diffèrent que
    par le bouton que le relecteur doit presser."""
    s = open(os.path.join(RACINE, FICHE), encoding="utf-8").read()
    out = {}
    for langue, amorce in (("fr", "Pour les dix-sept français :"),
                           ("en", "Pour les dix-sept anglais :")):
        m = re.search(re.escape(amorce) + r"\s*```\n(.+?)\n```", s, re.S)
        if m:
            out[langue] = " ".join(m.group(1).split())
    return out


# --- Le prix ---------------------------------------------------------------
#
# Il ne se pose pas comme le reste. Apple ne prend pas un montant : il prend un
# « point de prix », choisi dans une grille, pour un territoire de référence —
# et calcule lui-même les autres pays. La France est la référence ici, puisque
# c'est la langue principale de l'app.

TERRITOIRE = "FRA"


def point_de_prix(cfg, iap_id, montant):
    """Le point de la grille qui vaut ce montant, ou rien."""
    url = ("/v2/inAppPurchases/%s/pricePoints?filter[territory]=%s&limit=200"
           % (iap_id, TERRITOIRE))
    while url:
        rep = appel(cfg, "GET", url)
        for d in rep["data"]:
            if d["attributes"].get("customerPrice") == montant:
                return d["id"]
        url = rep.get("links", {}).get("next")
    return None


def prix_pose(cfg, iap_id):
    """Y a-t-il déjà un prix ? Un article sans prix reste incomplet chez Apple."""
    rep = appel(cfg, "GET", "/v2/inAppPurchases/%s/iapPriceSchedule" % iap_id, doux=True)
    return bool((rep or {}).get("data"))


def poser_le_prix(cfg, iap_id, point):
    appel(cfg, "POST", "/v1/inAppPurchasePriceSchedules", {
        "data": {
            "type": "inAppPurchasePriceSchedules",
            "relationships": {
                "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                "baseTerritory": {"data": {"type": "territories", "id": TERRITOIRE}},
                "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${prix}"}]}}},
        "included": [{
            "type": "inAppPurchasePrices",
            "id": "${prix}",
            "attributes": {"startDate": None, "endDate": None},
            "relationships": {"inAppPurchasePricePoint": {
                "data": {"type": "inAppPurchasePricePoints", "id": point}}}}]})


def les_prix(cfg, liste, deja, montant, applique):
    """Le même palier pour les trente-quatre."""
    montant = montant.replace(",", ".").replace("€", "").strip()
    print("Prix demandé : %s € en France — Apple en déduit les autres pays.\n" % montant)
    a_poser = []
    for p in liste:
        iap = deja.get(p["id"])
        if not iap:
            print("  %-40s pas encore créé" % p["id"]); continue
        if prix_pose(cfg, iap):
            print("  %-40s prix déjà posé" % p["id"]); continue
        point = point_de_prix(cfg, iap, montant)
        if not point:
            raise SystemExit("Aucun point de prix à %s € pour %s : la grille d'Apple "
                             "ne le propose pas." % (montant, p["id"]))
        a_poser.append((p, iap, point))
        print("  %-40s à poser" % p["id"])

    if not a_poser:
        print("\nRien à faire : les prix sont posés.")
        return
    if not applique:
        print("\nÀ blanc. %d prix seraient posés. « --apply » pour écrire." % len(a_poser))
        return
    if "--oui" not in sys.argv:
        try:
            reponse = input("\n%d prix à %s €. Taper oui pour écrire : " % (len(a_poser), montant))
        except EOFError:
            reponse = ""
        if reponse.strip().lower() not in ("oui", "o", "yes"):
            raise SystemExit("Rien n'a été envoyé.")
    for p, iap, point in a_poser:
        poser_le_prix(cfg, iap, point)
        print("  %-40s %s € posé" % (p["id"], montant))


def existants(cfg):
    out, url = {}, "/v1/apps/%s/inAppPurchasesV2?limit=200" % cfg["app_id"]
    while url:
        rep = appel(cfg, "GET", url)
        for d in rep["data"]:
            out[d["attributes"]["productId"]] = d["id"]
        url = rep.get("links", {}).get("next")
    return out


def deja_fait(cfg, iap_id):
    """Ce qui est déjà posé sur un article existant : les langues de fiche, et
    si la capture est là. Un article créé puis abandonné en chemin se termine
    au lieu de rester à moitié fait."""
    loc = appel(cfg, "GET", "/v2/inAppPurchases/%s/inAppPurchaseLocalizations" % iap_id, doux=True)
    langues = {d["attributes"]["locale"] for d in (loc or {}).get("data", [])}
    cap = appel(cfg, "GET", "/v2/inAppPurchases/%s/appStoreReviewScreenshot" % iap_id, doux=True)
    return langues, bool((cap or {}).get("data"))


# --- Les trois gestes -----------------------------------------------------

def cree(cfg, pack, ref, note):
    rep = appel(cfg, "POST", "/v2/inAppPurchases", {"data": {
        "type": "inAppPurchases",
        "attributes": {"name": ref["reference"], "productId": pack["id"],
                       "inAppPurchaseType": "NON_CONSUMABLE", "familySharable": True,
                       "reviewNote": note},
        "relationships": {"app": {"data": {"type": "apps", "id": cfg["app_id"]}}}}})
    return rep["data"]["id"]


def localise(cfg, iap_id, pack, ref):
    appel(cfg, "POST", "/v1/inAppPurchaseLocalizations", {"data": {
        "type": "inAppPurchaseLocalizations",
        "attributes": {"name": ref["affiche"], "locale": LOCALES[pack["langue"]],
                       "description": ref["description"]},
        "relationships": {"inAppPurchaseV2": {
            "data": {"type": "inAppPurchases", "id": iap_id}}}}})


def capture(cfg, iap_id, chemin):
    octets = open(chemin, "rb").read()
    rep = appel(cfg, "POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots",
        "attributes": {"fileName": os.path.basename(chemin), "fileSize": len(octets)},
        "relationships": {"inAppPurchaseV2": {
            "data": {"type": "inAppPurchases", "id": iap_id}}}}})
    sid = rep["data"]["id"]
    for op in rep["data"]["attributes"]["uploadOperations"]:
        part = octets[op["offset"]: op["offset"] + op["length"]]
        r = urllib.request.Request(op["url"], data=part, method=op["method"])
        for h in op["requestHeaders"]:
            r.add_header(h["name"], h["value"])
        urllib.request.urlopen(r).read()
    appel(cfg, "PATCH", "/v1/inAppPurchaseAppStoreReviewScreenshots/" + sid, {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots", "id": sid,
        "attributes": {"uploaded": True,
                       "sourceFileChecksum": hashlib.md5(octets).hexdigest()}}})


# --- Ce qui doit être vrai avant d'écrire ---------------------------------

def controles(liste, refs, mots, captures_requises):
    """Rend la liste des empêchements, en clair. Mieux vaut trente-quatre
    lignes de reproches qu'un article à moitié créé."""
    maux = []
    for p in liste:
        r = refs.get(p["id"])
        if not r:
            maux.append("absent de la page des packs : " + p["id"])
            continue
        if r["affiche"] != p["affiche"]:
            maux.append("nom d'affichage divergent pour %s : « %s » dans la page, "
                        "« %s » dans le fichier de questions"
                        % (p["id"], r["affiche"], p["affiche"]))
        if len(r["description"]) > 45:
            maux.append("description de %d signes pour %s : la case en tient 45"
                        % (len(r["description"]), p["id"]))
        if len(r["affiche"]) > 30:
            maux.append("nom d'affichage de %d signes pour %s : la case en tient 30"
                        % (len(r["affiche"]), p["id"]))
    for langue in sorted({p["langue"] for p in liste}):
        if langue not in mots:
            maux.append("note pour la revue introuvable dans la page des packs (%s)" % langue)
    if captures_requises:
        manquantes = sorted({refs[p["id"]]["capture"] for p in liste if p["id"] in refs
                             if not os.path.exists(os.path.join(RACINE, refs[p["id"]]["capture"]))})
        for c in manquantes:
            maux.append("capture à prendre : " + c)
    return maux


# --- Le déroulé -----------------------------------------------------------

def config():
    conf = os.path.join(RACINE, "outils/asc-config.json")
    if not os.path.exists(conf):
        raise SystemExit("Il manque outils/asc-config.json — voir l'en-tête de ce fichier.")
    cfg = json.load(open(conf))
    cfg["_key_path"] = cfg["key_file"] if os.path.isabs(cfg["key_file"]) \
        else os.path.join(RACINE, "outils", cfg["key_file"])
    if not os.path.exists(cfg["_key_path"]):
        raise SystemExit("Clé introuvable : " + cfg["_key_path"])
    return cfg


def etat_dans_la_fiche(cfg, liste, deja):
    """Coche, dans la page des packs, ce qui est réellement chez Apple.

    La page est la liste de contrôle : elle ment dès qu'elle retarde sur les
    articles. Trois cases sur quatre se lisent chez Apple — la quatrième, le
    prix, ne se pose pas par l'API et reste à la main.
    """
    s = open(os.path.join(RACINE, FICHE), encoding="utf-8").read()
    etats = {}
    for p in liste:
        if p["id"] not in deja:
            continue
        langues, capture = deja_fait(cfg, deja[p["id"]])
        etats[p["id"]] = (True, LOCALES[p["langue"]] in langues, capture)

    def coche(oui):
        return "[x]" if oui else "[ ]"

    out, faits = [], 0
    blocs = s.split("\n## ")
    for i, bloc in enumerate(blocs):
        m = re.search(r"Identifiant produit   (\S+)", bloc)
        if m and m.group(1) in etats:
            cree_, loc, cap = etats[m.group(1)]
            bloc = re.sub(r"- \[.\] créé  - \[.\] localisé  - \[.\] capture",
                          "- %s créé  - %s localisé  - %s capture"
                          % (coche(cree_), coche(loc), coche(cap)), bloc)
            faits += 1
        out.append(bloc)
    open(os.path.join(RACINE, FICHE), "w", encoding="utf-8").write("\n## ".join(out))
    print("\n%d blocs cochés dans la fiche." % faits)


def main():
    applique = "--apply" in sys.argv
    compare = applique or "--check" in sys.argv or "--prix" in sys.argv

    liste, refs, mots = packs(), fiche(), notes()
    maux = controles(liste, refs, mots, captures_requises=applique)
    if maux:
        print("Rien n'a été envoyé. Ce qui s'y oppose :\n")
        for m in maux:
            print("  · " + m)
        sys.exit(1)

    cfg = config() if compare else None
    deja = existants(cfg) if compare else {}

    if "--prix" in sys.argv:
        montant = sys.argv[sys.argv.index("--prix") + 1]
        les_prix(cfg, liste, deja, montant, applique)
        return

    if applique:
        a_creer = [p for p in liste if p["id"] not in deja]
        if not a_creer:
            print("Les %d articles sont déjà chez Apple : rien à créer." % len(liste))
        else:
            print("%d articles vont être créés dans App Store Connect.\n"
                  "Un identifiant créé ne se supprime jamais et ne se réutilise pas.\n"
                  % len(a_creer))
            for p in a_creer[:3]:
                print("  · " + p["id"])
            if len(a_creer) > 3:
                print("  · … et %d autres" % (len(a_creer) - 3))
            if "--oui" not in sys.argv:
                # Le mot se tape : cette commande est la seule du dépôt qui
                # écrive quelque chose d'irréversible chez Apple.
                try:
                    reponse = input("\nTaper oui pour écrire : ")
                except EOFError:
                    reponse = ""
                # Les majuscules ne sont pas la garantie : le mot l'est. Un
                # « oui » refusé pour une touche Majuscule est un garde-fou qui
                # se trompe de danger.
                if reponse.strip().lower() not in ("oui", "o", "yes"):
                    raise SystemExit("Rien n'a été envoyé.")
    fr = sum(1 for p in liste if p["langue"] == "fr")
    print("%d packs déclarés — %d français, %d anglais%s\n"
          % (len(liste), fr, len(liste) - fr,
             " · %d déjà dans App Store Connect" % len(deja) if compare else ""))

    langue_en_cours = None
    for i, p in enumerate(liste, 1):
        if p["langue"] != langue_en_cours:
            langue_en_cours = p["langue"]
            print("  — les %s —" % ("dix-sept français" if langue_en_cours == "fr"
                                    else "dix-sept anglais"))
        ref = refs[p["id"]]
        iap = deja.get(p["id"])
        if not applique:
            etat = "déjà là" if iap else ("à créer" if compare else "à créer (hors ligne)")
            print("%2d/%d  %-22s %-40s %s" % (i, len(liste), ref["affiche"], p["id"], etat))
            continue

        if not iap:
            iap = cree(cfg, p, ref, mots[p["langue"]])
            langues, a_sa_capture = set(), False
            print("%2d/%d  %-22s %-40s créé" % (i, len(liste), ref["affiche"], p["id"]))
        else:
            langues, a_sa_capture = deja_fait(cfg, iap)
            print("%2d/%d  %-22s %-40s déjà là" % (i, len(liste), ref["affiche"], p["id"]))
        gestes = []
        if LOCALES[p["langue"]] not in langues:
            localise(cfg, iap, p, ref)
            gestes.append("localisé en " + LOCALES[p["langue"]])
        if not a_sa_capture:
            capture(cfg, iap, os.path.join(RACINE, ref["capture"]))
            gestes.append("capture déposée")
        if gestes:
            print("       → " + ", ".join(gestes))

    if compare and "--fiche" in sys.argv:
        etat_dans_la_fiche(cfg, liste, existants(cfg))

    if not applique:
        print("\nÀ blanc. Rien n'a été envoyé.")
        if not compare:
            print("« --check » compare à ce qui existe déjà chez Apple, « --apply » écrit.")
        else:
            print("Relancer avec --apply pour écrire.")
        print("Le prix reste à poser dans l'interface : il n'est pas décidé.")


if __name__ == "__main__":
    main()
