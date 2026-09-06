#!/usr/bin/env python3
"""
captures.py — Riskelo, outil hors application

Les captures de l'App Store, prises sans y toucher, sur les trois tailles
qu'Apple demande.

Elles étaient prises à la main : jouer jusqu'à l'écran voulu, appeler
`simctl io screenshot`, recommencer sur l'appareil suivant. Dix-huit fois.
La deuxième série ne ressemblait jamais à la première, et une capture qui
montre autre chose que ce qu'elle annonce ne se voit qu'à la relecture.

Deux repérages, parce qu'il en faut deux. L'arbre d'accessibilité pour ce qui
porte un nom — boutons, segments, champs. Et la couleur pour le plateau, dont
les cases n'en portent aucun : on cherche la teinte d'un territoire à soi,
puis le liseré rouge d'une case visée.

Trois pièges, tous payés une fois :

  · Un Picker segmenté n'est pas un « radio group » mais un « tab group »,
    ses segments portent une description et non un titre, et l'appui
    d'accessibilité ne les change pas. Il faut leur demander leur place et
    cliquer dedans.
  · Le point le plus « intérieur » d'une plage de couleur se cherche en pas
    d'échantillonnage, non en pixels : sinon aucun voisin ne tombe sur la
    grille, le compte vaut zéro partout, et l'on clique sur le premier point
    venu — la lisière d'un hexagone, où l'appui se perd.
  · Une case coupée par le bord de l'écran n'est touchable que sur sa part
    visible. D'où la marge d'un dixième de chaque côté.

    python3 outils/captures.py

Elles sortent dans soumission/captures/, aux noms et dans l'ordre de la fiche.
"""


import subprocess, time, os, shutil
from PIL import Image

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = os.path.join(RACINE, "soumission", "captures", "_brut")
os.makedirs(S, exist_ok=True)

CHERCHE_SEGMENT = """set trouve to missing value
repeat with t in (tab groups of CIBLE)
    repeat with b in (radio buttons of t)
        if (description of b) is "TITRE" then set trouve to b
    end repeat
end repeat
if trouve is missing value then return "absent"
return (position of trouve) & (size of trouve)"""

class Appareil:
    def __init__(self, uuid, fenetre, profondeur):
        self.uuid, self.fenetre, self.profondeur = uuid, fenetre, profondeur
        self.grp = "".join(["group 1 of "] * profondeur) + 'window "%s"' % fenetre

    def osa(self, corps):
        script = 'tell application "System Events" to tell process "Simulator"\n%s\nend tell' % corps
        r = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
        return (r.stdout or r.stderr).strip()

    def devant(self):
        subprocess.run(["osascript", "-e", 'tell application "Simulator" to activate'],
                       capture_output=True)
        self.osa('perform action "AXRaise" of window "%s"' % self.fenetre)
        time.sleep(0.4)

    def _cible(self, defile):
        return ("group 1 of scroll area 1 of " + self.grp) if defile else self.grp

    def boutons(self, defile=False):
        b = self.osa("return description of (buttons of %s)" % self._cible(defile))
        return [x.strip() for x in b.split(",")]

    def presser(self, nom, defile=False):
        return self.osa('click (first button of %s whose description is "%s")'
                        % (self._cible(defile), nom))

    def cocher(self, titre, defile=False):
        """Un segment de Picker, désigné par son libellé.

        Un Picker segmenté n'est pas un « radio group » mais un « tab group »,
        ses segments portent une description et non un titre, et l'appui
        d'accessibilité ne les change pas : on leur demande donc leur place à
        l'écran, et on clique dedans. La boucle est explicite parce qu'un
        filtre « whose » rend une liste trouée qu'on ne peut pas interroger.
        """
        corps = CHERCHE_SEGMENT.replace("CIBLE", self._cible(defile)).replace("TITRE", titre)
        v = self.osa(corps)
        try:
            x, y, w, h = [int(n) for n in v.split(", ")]
        except ValueError:
            return "segment introuvable : " + v[:70]
        self.devant()
        return self.osa("click at {%d, %d}" % (x + w // 2, y + h // 2))

    def ecrire(self, texte, defile=True):
        return self.osa('set value of text field 1 of %s to "%s"' % (self._cible(defile), texte))

    def cadre(self):
        v = self.osa('return (position of window "%s") & (size of window "%s")'
                     % (self.fenetre, self.fenetre))
        return [int(n) for n in v.split(", ")]

    def photo(self, nom=None):
        chemin = "%s/%s" % (S, nom or "_tmp.png")
        subprocess.run(["xcrun", "simctl", "io", self.uuid, "screenshot", chemin],
                       capture_output=True)
        return Image.open(chemin).convert("RGB")

    def cliquer_image(self, px, py, img):
        """Un point de la capture, cliqué sur l'écran du Mac.

        La fenêtre repasse devant à chaque fois : plusieurs simulateurs sont
        ouverts, ils se recouvrent, et un clic en coordonnées d'écran tombe
        sur celle du dessus, non sur celle qu'on vise.
        """
        self.devant()
        x, y, w, h = self.cadre()
        iw, ih = img.size
        haut = w * ih / iw               # l'écran de l'appareil, dans la fenêtre
        barre = h - haut                 # ce que prend la barre de titre
        self.osa("click at {%d, %d}" % (x + px / iw * w, y + barre + py / ih * haut))


def amas(img, cible, zone, tol=26, pas=6, portee=7):
    """Le point le plus intérieur d'une plage de couleur, dans `zone`.

    Non pas le centre de gravité d'un amas — il tombait entre deux hexagones,
    sur la lisière, et l'appui se perdait — mais le point qui a le plus de
    voisins de sa couleur autour de lui.

    `portee` se compte en pas, non en pixels : les décalages doivent tomber
    sur la grille d'échantillonnage, sinon aucun voisin n'est jamais trouvé et
    tous les points se valent.
    """
    x0, y0, x1, y1 = zone
    px = img.load()
    def proche(x, y):
        r, g, b = px[x, y]
        return (abs(r - cible[0]) < tol and abs(g - cible[1]) < tol
                and abs(b - cible[2]) < tol)
    points = [(x, y) for y in range(y0, y1, pas) for x in range(x0, x1, pas) if proche(x, y)]
    if not points:
        return None
    dedans = set(points)
    ecarts = [d * pas for d in range(-portee, portee + 1)]
    def voisins(p):
        return sum(1 for dx in ecarts for dy in ecarts if (p[0] + dx, p[1] + dy) in dedans)
    return max(points, key=voisins)


def anneau(img, cible, zone, tol=30, pas=4):
    """Le centre d'un liseré, et non un point dessus.

    Une case visée porte un contour rouge vif. Chercher le point « le plus
    intérieur » tomberait sur le trait lui-même ; ce qu'on veut est le milieu
    de ce qu'il entoure. On prend donc la moyenne du plus gros groupe de
    pixels du liseré — pour un anneau, c'est son centre.
    """
    x0, y0, x1, y1 = zone
    px = img.load()
    points = []
    for y in range(y0, y1, pas):
        for x in range(x0, x1, pas):
            r, g, b = px[x, y]
            if (abs(r - cible[0]) < tol and abs(g - cible[1]) < tol
                    and abs(b - cible[2]) < tol):
                points.append((x, y))
    if not points:
        return None
    # Regroupement grossier : deux pixels du même liseré sont à moins d'une
    # case l'un de l'autre.
    groupes, reste = [], set(points)
    while reste:
        germe = reste.pop()
        groupe, file = [germe], [germe]
        while file:
            x, y = file.pop()
            for p in [q for q in list(reste)
                      if abs(q[0] - x) <= 4 * pas and abs(q[1] - y) <= 4 * pas]:
                reste.discard(p); groupe.append(p); file.append(p)
        groupes.append(groupe)
    plus_gros = max(groupes, key=len)
    return (sum(p[0] for p in plus_gros) // len(plus_gros),
            sum(p[1] for p in plus_gros) // len(plus_gros))


# ————————————————————————————————————————————————————————————————————————
# La série

BLEU  = (51, 102, 155)     # une case à moi, jouable : le camp à 72 % sur la mer
ROUGE = (104, 53, 50)      # une case d'en face
VISEE = (208, 85, 74)      # le liseré d'une case qu'on peut attaquer
LOUPE = "arrow.up.left.and.down.right.magnifyingglass"
CHROME = {"Au déplacement", "À l'attaque", "Fin du tour", "Retour", "Signet",
          "Continuer", "person.text.rectangle", "list.bullet.rectangle",
          "questionmark.circle", LOUPE, "Fermer", "Je suis prêt",
          "Lancer l'assaut", "Doubler la mise"}

APPAREILS = [
    ("iphone-6.9", "iPhone 17 Pro Max", "iPhone 17 Pro Max – iOS 26.5", 6, (1320, 2868)),
    ("iphone-6.5", "iPhone 11 Pro Max", "iPhone 11 Pro Max – iOS 26.5", 6, (1242, 2688)),
    ("ipad-13",    "iPad Pro 13-inch (M5)", "iPad Pro 13-inch (M5) – iOS 26.5", 7, (2064, 2752)),
]

# L'ordre de la fiche : la première capture est celle qu'on voit dans les
# résultats de recherche, et c'est elle qui doit dire ce qu'est le jeu.
ORDRE = [("duel", "01-duel"), ("assaut", "02-assaut"), ("plateau", "03-plateau"),
         ("verdict", "04-verdict"), ("reglages", "05-reglages"), ("accueil", "06-accueil")]


def serie(a, dossier):
    """Six écrans, sur un appareil."""
    def photo(nom):
        img = a.photo("%s-%s.png" % (dossier, nom))
        print("    %s %s" % (nom, img.size), flush=True)
        return img

    subprocess.run(["xcrun", "simctl", "terminate", a.uuid, "com.oulhen.riskelo"],
                   capture_output=True)
    time.sleep(1)
    subprocess.run(["xcrun", "simctl", "launch", a.uuid, "com.oulhen.riskelo"],
                   capture_output=True)
    time.sleep(4.5); a.devant(); time.sleep(2)      # l'ouverture se joue
    photo("accueil")

    a.presser("Réglages de la partie", defile=True); time.sleep(2)
    photo("reglages")

    # Face à face : les deux joueurs reçoivent la question, donc l'attaquant la
    # voit aussi. En classique, seul le défenseur répond — et c'est la machine
    # quand c'est nous qui attaquons : la question ne s'afficherait jamais.
    for segment in ("Face à face", "Monde", "4"):
        a.cocher(segment, defile=True); time.sleep(0.9)
    a.presser("Commencer", defile=True); time.sleep(5)
    a.presser(LOUPE); time.sleep(1.5)               # le plateau entier, non rogné
    img = photo("plateau")

    # Une marge d'un dixième : une case coupée par le bord n'est touchable que
    # sur sa part visible.
    marge = img.size[0] // 10
    zone = (marge, int(img.size[1] * 0.26), img.size[0] - marge, int(img.size[1] * 0.70))

    for _ in range(6):                              # poser les renforts
        img = a.photo()
        mien = amas(img, BLEU, zone)
        if not mien:
            print("    ! aucune case à moi", flush=True); return
        for _ in range(6):
            a.cliquer_image(mien[0], mien[1], img); time.sleep(0.35)
        if "Au déplacement" in a.boutons():          # les renforts sont posés
            break
        a.presser("À l'attaque"); time.sleep(3)
        if "Au déplacement" in a.boutons():
            break

    img = a.photo()
    mien = amas(img, BLEU, zone)
    a.cliquer_image(mien[0], mien[1], img); time.sleep(1.5)
    img = a.photo()
    cible = anneau(img, VISEE, zone)                # une case vraiment attaquable
    if not cible:
        print("    ! aucune case visée", flush=True); return
    a.cliquer_image(cible[0], cible[1], img); time.sleep(2)
    if "Lancer l'assaut" not in a.boutons():
        print("    ! le panneau ne s'est pas ouvert", flush=True); return
    photo("assaut")

    a.presser("Lancer l'assaut"); time.sleep(4.5)
    for _ in range(4):
        if "Je suis prêt" in a.boutons():
            a.presser("Je suis prêt"); time.sleep(1.5); break
        time.sleep(1.5)
    photo("duel")

    propositions = [b for b in a.boutons() if b and b not in CHROME]
    if not propositions:
        print("    ! pas de question à l'écran", flush=True); return
    a.presser(propositions[0])
    time.sleep(1.1)                                 # le verdict ne reste qu'un instant
    photo("verdict")


def main():
    for dossier, appareil, fenetre, profondeur, taille in APPAREILS:
        print("== %s (%s) ==" % (dossier, appareil), flush=True)
        uuid = subprocess.run(["xcrun", "simctl", "list", "devices"],
                              capture_output=True, text=True).stdout
        ligne = [l for l in uuid.splitlines() if l.strip().startswith(appareil + " (")]
        if not ligne:
            print("    ! appareil absent — xcrun simctl create", flush=True); continue
        uuid = ligne[0].split("(")[1].split(")")[0]
        subprocess.run(["xcrun", "simctl", "boot", uuid], capture_output=True)
        subprocess.run(["xcrun", "simctl", "install", uuid,
                        os.path.join(RACINE, "build", "Riskelo.app")], capture_output=True)
        # La barre d'état aux conventions d'Apple : une heure qui change d'une
        # capture à l'autre fait rejeter la série.
        subprocess.run(["xcrun", "simctl", "status_bar", uuid, "override",
                        "--time", "9:41", "--batteryState", "charged",
                        "--batteryLevel", "100", "--wifiBars", "3",
                        "--cellularBars", "4"], capture_output=True)
        serie(Appareil(uuid, fenetre, profondeur), dossier)

        sortie = os.path.join(RACINE, "soumission", "captures", dossier)
        os.makedirs(sortie, exist_ok=True)
        for brut, propre in ORDRE:
            src = os.path.join(S, "%s-%s.png" % (dossier, brut))
            if os.path.exists(src):
                shutil.copy(src, os.path.join(sortie, propre + ".png"))
        # Contrôle : Apple refuse une taille qui n'est pas celle annoncée.
        for f in sorted(os.listdir(sortie)):
            im = Image.open(os.path.join(sortie, f))
            marque = "ok" if im.size == taille else "TAILLE INATTENDUE %s" % (im.size,)
            print("    %s %s" % (f, marque), flush=True)


if __name__ == "__main__":
    main()
