#!/usr/bin/env python3
"""
captures-achats.py — Riskelo, outil hors application

Les captures de vérification des achats intégrés : celles qu'Apple exige, une
par article, et qui doivent montrer l'article au relecteur.

Trente-quatre packs ne tiennent pas sur un écran. Cet outil ouvre la page des
Packs, descend par pas qu'il choisit lui-même, photographie, et **vérifie après
chaque photo quelles lignes y sont entières**. Il continue tant qu'un pack n'a
pas été vu, puis il écrit dans la fiche, pour chacun des trente-quatre, la
photo qui le montre.

C'est la réponse au piège payé une fois côté américain : deux captures espacées
d'un écran plein laissent une charnière où un pack n'apparaît nulle part. Ici
la charnière ne peut pas exister — un pack qui n'aurait été vu entier sur
aucune photo déclenche une photo de plus, centrée sur lui.

    python3 outils/captures-achats.py           # photographie et dit ce qu'il voit
    python3 outils/captures-achats.py --fiche   # et réécrit les lignes « Capture »

**L'app doit être lancée depuis Xcode** (⌘R), non par `simctl`. Xcode est le
seul à attacher `Resources/Riskelo.storekit` : sans lui, la boutique ne répond
pas et les dix-sept packs affichent « indisponible » au lieu de leur prix. Une
capture de vérification qui dit « indisponible » est exactement ce que le
relecteur ne doit pas voir. L'outil s'en assure avant de commencer.

Deux tailles sortent de chaque photo : la taille de l'appareil, dans `_brut/`,
et 1242 × 2688 — celle qu'App Store Connect accepte — à côté de la fiche.
"""

import json, os, re, shutil, subprocess, sys, time
from PIL import Image

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SORTIE = os.path.join(RACINE, "soumission", "captures", "achats")
BRUT = os.path.join(SORTIE, "_brut")
FICHE = os.path.join(RACINE, "soumission", "packs-app-store.md")
APP = "com.oulhen.riskelo"
TAILLE_APPLE = (1242, 2688)
MARGE = 4          # points : une ligne qui affleure le bord n'est pas « entière »
MAX_PHOTOS = 8     # garde-fou : la page ne fait pas trois écrans


# --- L'appareil et son arbre ----------------------------------------------

class Ecran:
    """Le simulateur où tourne l'app, et ce qu'on peut lui demander."""

    def __init__(self, uuid, fenetre, profondeur=6):
        self.uuid, self.fenetre, self.profondeur = uuid, fenetre, profondeur
        self.grp = "".join(["group 1 of "] * profondeur) + 'window "%s"' % fenetre
        self.zone = "scroll area 1 of " + self.grp
        self.dedans = "group 1 of " + self.zone

    def osa(self, corps):
        script = ('tell application "System Events" to tell process "Simulator"\n%s\nend tell'
                  % corps)
        r = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
        return (r.stdout or r.stderr).strip()

    def devant(self):
        subprocess.run(["osascript", "-e", 'tell application "Simulator" to activate'],
                       capture_output=True)
        self.osa('perform action "AXRaise" of window "%s"' % self.fenetre)
        time.sleep(0.4)

    def liste(self, quoi, propriete):
        """Une propriété de tous les éléments d'un genre, en une seule demande :
        trente-quatre allers-retours par photo seraient trop lents."""
        v = self.osa("return %s of (%s of %s)" % (propriete, quoi, self.dedans))
        return [x.strip() for x in v.split(", ")] if v else []

    def textes(self):
        """Chaque texte de la page : ce qu'il dit, où il est, sa taille.

        Tout en un seul appel, et surtout **pas** en demandant les descriptions
        d'un côté et les positions de l'autre : une description contient des
        virgules — « Les groupes, les voix et les rôles » — et les deux listes
        ne se recollent plus. D'où les deux séparateurs, qui ne peuvent pas
        apparaître dans un libellé.
        """
        corps = ('set AppleScript\'s text item delimiters to "\\t"\n'
                 'set d to (description of (static texts of %s)) as text\n'
                 'set p to (position of (static texts of %s)) as text\n'
                 'set t to (size of (static texts of %s)) as text\n'
                 'return d & "\\n" & p & "\\n" & t'
                 % (self.dedans, self.dedans, self.dedans))
        # Trois demandes en gros, et non trois par élément : demander élément
        # par élément coûtait cinquante secondes par photo, contre une demie.
        parties = self.osa(corps).split("\n")
        if len(parties) != 3:
            return []
        textes = parties[0].split("\t")
        try:
            p = [int(x) for x in parties[1].split("\t")]
            t = [int(x) for x in parties[2].split("\t")]
        except ValueError:
            return []
        if not (len(textes) == len(p) // 2 == len(t) // 2):
            return []
        return [{"texte": textes[i], "y": p[2 * i + 1], "h": t[2 * i + 1]}
                for i in range(len(textes))]

    def ancres(self):
        """Les hauteurs des boutons de prix — un par ligne, dans l'ordre de la
        page. C'est la lecture bon marché : elle sert à savoir si la page a
        bougé, ce qui ne demande pas de savoir ce qu'elle dit."""
        v = self.osa("return position of (buttons of %s)" % self.dedans)
        try:
            n = [int(x) for x in v.split(", ")]
        except ValueError:
            return []
        return n[1::2]

    def cadre_zone(self):
        v = self.osa("return (position of %s) & (size of %s)" % (self.zone, self.zone))
        return [int(x) for x in v.split(", ")]

    def presser(self, description):
        return self.osa('click (first button of %s whose description is "%s")'
                        % (self.dedans, description))

    def segment(self, titre):
        """Un segment de Picker. Il n'est pas « pressable » : on lui demande sa
        place et on clique dedans — le piège est noté dans captures.py."""
        corps = ('set t to (first radio button of tab group 1 of %s whose description is "%s")\n'
                 'return (position of t) & (size of t)' % (self.dedans, titre))
        v = self.osa(corps)
        try:
            x, y, w, h = [int(n) for n in v.split(", ")]
        except ValueError:
            return "segment introuvable : " + v[:80]
        self.devant()
        return self.osa("click at {%d, %d}" % (x + w // 2, y + h // 2))

    def defiler_vers(self, description):
        return self.osa('perform action "AXScrollToVisible" of '
                        '(first static text of %s whose description is "%s")'
                        % (self.dedans, description))

    def remonter(self):
        for _ in range(8):
            self.osa('perform action "AXScrollUpByPage" of ' + self.zone)
        time.sleep(0.6)

    def photo(self, chemin):
        subprocess.run(["xcrun", "simctl", "io", self.uuid, "screenshot", chemin],
                       capture_output=True)
        return Image.open(chemin)


# --- Ce qu'il y a à montrer ------------------------------------------------

def packs():
    """Les packs, lus dans les fichiers de questions — la même source que
    l'outil qui les crée chez Apple."""
    import glob
    out = []
    for chemin in sorted(glob.glob(os.path.join(RACINE, "Resources/Questions/*.txt"))):
        tete = {}
        for ligne in open(chemin, encoding="utf-8"):
            l = ligne.strip()
            if l.startswith("!"):
                k, _, v = l[1:].partition("|")
                tete[k.strip()] = v.strip()
        pid = tete.get("produit") or tete.get("product")
        if pid:
            out.append({"id": pid, "nom": tete.get("nom") or tete.get("name"),
                        "rang": int(tete.get("rang") or tete.get("rank")),
                        "langue": "en" if tete.get("lang") == "en" else "fr"})
    out.sort(key=lambda p: p["rang"])
    return out


def lignes_visibles(e, noms):
    """Où est chaque pack à l'écran, et lesquels y tiennent en entier.

    Une ligne est « entière » quand son titre et son compte de questions sont
    tous deux dans la zone qui défile. C'est le critère du relecteur : il doit
    voir le pack, pas le deviner.
    """
    textes = e.textes()
    zx, zy, zw, zh = e.cadre_zone()
    haut, bas = zy + MARGE, zy + zh - MARGE

    out = {}
    for i, t in enumerate(textes):
        if t["texte"] not in noms:
            continue
        # Le titre, puis le détail, puis « N questions » : la ligne va de l'un
        # à l'autre.
        fin = i
        while fin < len(textes) - 1 and not re.match(r"^\d+ questions$", textes[fin]["texte"]):
            fin += 1
            if fin - i > 3:
                break
        y1 = t["y"]
        y2 = textes[fin]["y"] + textes[fin]["h"]
        if y1 >= haut and y2 <= bas:
            out[t["texte"]] = (y1 + y2) // 2
    return out, (zy, zy + zh)


# --- Une langue ------------------------------------------------------------

def serie(e, langue, noms):
    """Photographie la page jusqu'à ce que les dix-sept aient été vus entiers.

    Rend la liste des photos et, pour chaque pack, celle qui le montre le mieux
    — la plus centrée, puisque c'est celle qu'on regarde sans chercher.
    """
    # Remonter d'abord : le bouton de langue est en haut de la page, et un clic
    # sur sa place alors que la page est restée en bas tombe à côté. La seconde
    # série s'y était perdue.
    e.remonter()
    e.segment("Français" if langue == "fr" else "English")
    time.sleep(1.5)
    e.remonter()

    photos, place = [], {}          # place : nom -> (photo, écart au centre)
    reste = set(noms)
    while reste and len(photos) < MAX_PHOTOS:
        nom_fichier = "%s-%d" % (langue, len(photos) + 1)
        chemin = os.path.join(BRUT, nom_fichier + ".png")
        e.photo(chemin)
        vues, (zh1, zh2) = lignes_visibles(e, noms)
        if not vues and not photos:
            raise SystemExit("Aucune ligne lue : l'écran des Packs n'est pas ouvert ?")
        centre = (zh1 + zh2) / 2
        for nom, y in vues.items():
            ecart = abs(y - centre)
            if nom not in place or ecart < place[nom][1]:
                place[nom] = (nom_fichier, ecart)
        photos.append(nom_fichier)
        print("    %s : %d lignes entières" % (nom_fichier, len(vues)), flush=True)
        reste -= set(vues)
        if not reste:
            break

        # Le pas : viser six lignes plus bas que la dernière vue entière, pour
        # que la suivante arrive en haut de l'écran et non au bord.
        derniere = max((noms.index(n) for n in vues), default=-1)
        cible = noms[min(derniere + 6, len(noms) - 1)]
        avant = e.ancres()
        e.defiler_vers(cible)
        time.sleep(0.9)
        if e.ancres() == avant:            # la page ne bouge plus : on est en bas
            break

    # Une charnière ne peut pas subsister : ce qui n'a été vu entier nulle part
    # reçoit sa propre photo, centrée sur lui.
    rattrapages = 0
    while reste and rattrapages < 3:
        nom = sorted(reste, key=noms.index)[0]
        e.defiler_vers(nom)
        time.sleep(0.9)
        nom_fichier = "%s-%d" % (langue, len(photos) + 1)
        e.photo(os.path.join(BRUT, nom_fichier + ".png"))
        vues, (zh1, zh2) = lignes_visibles(e, noms)
        if nom not in vues:                # le pas n'a rien rattrapé : inutile d'insister
            os.remove(os.path.join(BRUT, nom_fichier + ".png"))
            break
        centre = (zh1 + zh2) / 2
        for n, y in vues.items():
            ecart = abs(y - centre)
            if n not in place or ecart < place[n][1]:
                place[n] = (nom_fichier, ecart)
        photos.append(nom_fichier)
        reste -= set(vues)
        rattrapages += 1
        print("    %s : rattrapage pour « %s »" % (nom_fichier, nom), flush=True)

    manquants = [n for n in noms if n not in place]
    return photos, {n: place[n][0] for n in place}, manquants


# --- La taille qu'Apple prend ---------------------------------------------

def a_la_taille_apple(source, destination):
    """1242 × 2688. On recadre d'abord au bon rapport, puis on réduit : une
    image simplement étirée arriverait légèrement écrasée."""
    im = Image.open(source).convert("RGB")
    l, h = im.size
    rapport = TAILLE_APPLE[0] / TAILLE_APPLE[1]
    h_voulue = round(l / rapport)
    if h_voulue <= h:                       # on rogne en bas, là où il n'y a rien
        im = im.crop((0, 0, l, h_voulue))
    else:
        l_voulue = round(h * rapport)
        marge = (l - l_voulue) // 2
        im = im.crop((marge, 0, marge + l_voulue, h))
    im.resize(TAILLE_APPLE, Image.LANCZOS).save(destination)


# --- La fiche --------------------------------------------------------------

def ecrire_la_fiche(attribution, tous):
    """Chaque bloc de la page des packs reçoit la photo qui le montre.

    Le bloc est reconnu par son identifiant de produit, non par son nom
    affiché : « Rock 70-80 » s'écrit pareil dans les deux langues, et c'est
    justement le pack qui se ferait donner la photo de l'autre série.
    """
    s = open(FICHE, encoding="utf-8").read()
    langue_de = {p["id"]: p["langue"] for p in tous}
    nom_de = {p["id"]: p["nom"] for p in tous}
    faits = [0]

    def remplace(m):
        pid = m.group(2).strip()
        cle = (langue_de.get(pid), nom_de.get(pid))
        if cle not in attribution:
            return m.group(0)
        faits[0] += 1
        return "%ssoumission/captures/achats/%s.png" % (m.group(1), attribution[cle])

    s = re.sub(r"(Identifiant produit   (\S+)\n"
               r"Nom d'affichage       .+\n"
               r"Description           .+\n"
               r"Capture               )\S+", remplace, s)
    open(FICHE, "w", encoding="utf-8").write(s)
    print("    %d blocs mis à jour" % faits[0])


# --- Le déroulé ------------------------------------------------------------

def appareil():
    """Le simulateur où l'app tourne, et le nom de sa fenêtre."""
    devices = json.loads(subprocess.run(["xcrun", "simctl", "list", "devices", "-j"],
                                        capture_output=True, text=True).stdout)["devices"]
    for runtime, liste in devices.items():
        for d in liste:
            if d.get("state") != "Booted":
                continue
            tourne = subprocess.run(["xcrun", "simctl", "spawn", d["udid"], "launchctl", "list"],
                                    capture_output=True, text=True).stdout
            if APP in tourne:
                version = runtime.split(".")[-1].replace("iOS-", "").replace("-", ".")
                return d["udid"], "%s – iOS %s" % (d["name"], version)
    raise SystemExit(
        "Riskelo ne tourne sur aucun simulateur.\n"
        "Lance-le depuis Xcode (⌘R) : lui seul attache Resources/Riskelo.storekit,\n"
        "sans quoi les packs afficheront « indisponible » au lieu de leur prix.")


def main():
    os.makedirs(BRUT, exist_ok=True)
    uuid, fenetre = appareil()
    print("Appareil : %s\n" % fenetre)
    e = Ecran(uuid, fenetre)
    e.devant()

    # La barre d'état aux conventions d'Apple, comme pour les captures de la
    # fiche : une heure qui change d'une image à l'autre se remarque.
    subprocess.run(["xcrun", "simctl", "status_bar", uuid, "override", "--time", "9:41",
                    "--batteryState", "charged", "--batteryLevel", "100",
                    "--wifiBars", "3", "--cellularBars", "4"], capture_output=True)

    # Ouvrir la page des Packs si l'on n'y est pas déjà.
    if "Français" not in e.osa("return description of (radio buttons of tab group 1 of %s)"
                               % e.dedans):
        # Le bouton de l'accueil porte le nom de la langue en cours : l'app
        # garde celle du dernier passage, et l'outil ne sait pas laquelle.
        for libelle in ("Packs de questions", "Question packs"):
            e.presser(libelle)
            time.sleep(2.5)
            if "Français" in e.osa("return description of (radio buttons of tab group 1 of %s)"
                                   % e.dedans):
                break

    prix = [b for b in e.liste("buttons", "description") if "€" in b or "$" in b]
    if not prix:
        raise SystemExit(
            "Aucun prix à l'écran : la boutique n'a pas répondu.\n"
            "Relance l'app depuis Xcode (⌘R) — lui seul attache le fichier des prix.")
    print("Boutique ouverte : %d prix affichés\n" % len(prix))

    tous, attribution = packs(), {}
    photos = []
    for langue in ("fr", "en"):
        noms = [p["nom"] for p in tous if p["langue"] == langue]
        print("  — les %d %s —" % (len(noms), "français" if langue == "fr" else "anglais"),
              flush=True)
        prises, place, manquants = serie(e, langue, noms)
        if manquants:
            raise SystemExit("Jamais vus entiers : " + ", ".join(manquants))
        # La clé porte la langue : « Rock 70-80 » existe dans les deux séries.
        attribution.update({(langue, n): photo for n, photo in place.items()})
        photos += prises

    # Les deux tailles : celle de l'appareil dans _brut/, celle d'Apple à côté
    # de la fiche.
    print("\n  — les fichiers —")
    for nom in photos:
        source = os.path.join(BRUT, nom + ".png")
        cible = os.path.join(SORTIE, nom + ".png")
        a_la_taille_apple(source, cible)
        print("    %-8s %s → %s" % (nom, Image.open(source).size, Image.open(cible).size))

    print("\n  — ce que montre chaque photo —")
    rang_de = {(p["langue"], p["nom"]): p["rang"] for p in tous}
    for nom in photos:
        dedans = sorted([cle for cle, c in attribution.items() if c == nom],
                        key=lambda cle: rang_de[cle])
        print("    %-8s %s" % (nom, ", ".join(n for _, n in dedans)))

    if "--fiche" in sys.argv:
        ecrire_la_fiche(attribution, tous)
        print("\nLes lignes « Capture » de la fiche suivent ces photos.")
    else:
        print("\nLa fiche n'a pas été touchée. « --fiche » y écrit ces attributions.")


if __name__ == "__main__":
    main()
