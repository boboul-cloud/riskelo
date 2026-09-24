#!/usr/bin/env python3
"""Le monde, dessiné en côtes puis découpé en quarante-deux places.

    python3 outils/carte-du-monde.py

Il écrit `plan.txt`, `places.txt`, `traversees.txt` et deux aperçus PNG dans le
dossier courant. Le plan se recopie ensuite dans `Sources/Engine/PlanDuMonde.swift`,
qui est la seule source que l'application lit — ce script ne tourne pas à
l'exécution et ne sert qu'à refaire le dessin.

Le découpage n'est pas tracé à la main : chaque place reçoit une ou plusieurs
graines en longitude/latitude, et les cellules du continent vont à la graine la
plus proche **en suivant la terre**. Déplacer une graine déplace une frontière ;
c'est tout ce qu'il y a à régler. Le script confronte ensuite les voisinages
obtenus à ceux du jeu de conquête classique, et dit ce qui manque — c'est de là
que sort la liste des traversées.


On part de contours en longitude/latitude — la géographie, qui est un fait —
et l'on rastérise sur une grille. Chaque cellule de terre revient ensuite à la
place la plus proche à l'intérieur de son continent : les frontières intérieures
sortent donc du dessin, et les côtes restent celles du monde.
"""
import math, json, sys
from collections import deque
from PIL import Image, ImageDraw

W, H = 120, 68
LAT_N, LAT_S = 83.0, -56.0

def px(lon, lat):
    x = (lon + 180.0) / 360.0 * W
    y = (LAT_N - lat) / (LAT_N - LAT_S) * H
    return (x, y)

# ---------------------------------------------------------------- les côtes

CONTINENTS = {
 "N": ("Amérique du Nord", 5, [
   # Continent nord-américain, Alaska à Panama, plus l'archipel arctique simplifié.
   [(-168,65),(-166,71),(-156,71),(-140,70),(-128,70),(-115,69),(-100,69),(-90,70),
    (-82,74),(-70,77),(-62,73),(-64,66),(-78,63),(-78,57),(-64,60),(-56,52),(-60,47),
    (-66,45),(-70,42),(-74,39),(-76,35),(-81,26),(-80,25),(-84,30),(-89,29),(-94,29),
    (-97,26),(-97,21),(-95,16),(-92,15),(-87,13),(-83,9),(-78,8),(-79,15),(-88,20),
    (-97,17),(-105,20),(-110,24),(-114,32),(-120,34),(-124,40),(-124,48),(-131,53),
    (-138,58),(-150,59),(-160,55),(-165,60)],
   # Terre-Neuve et le Labrador tiennent déjà ; l'Alaska occidentale.
 ]),
 "G": ("Groenland", 0, [   # rattaché à l'Amérique du Nord, dessiné à part
   [(-45,83),(-25,82),(-20,76),(-22,70),(-40,60),(-50,60),(-55,67),(-58,74),(-55,80)],
 ]),
 "S": ("Amérique du Sud", 2, [
   [(-77,8),(-72,12),(-62,11),(-52,5),(-44,-1),(-35,-6),(-39,-14),(-48,-25),(-53,-33),
    (-58,-38),(-62,-41),(-65,-48),(-69,-53),(-75,-53),(-73,-45),(-71,-33),(-70,-18),
    (-76,-6),(-81,-4),(-80,1),(-77,5)],
 ]),
 "E": ("Europe", 5, [
   # Europe continentale, de l'Ibérie à l'Oural.
   [(-9,36),(-9,43),(-2,43),(-2,48),(2,51),(5,53),(8,54),(11,55),(14,54),(19,54),
    (21,56),(25,57),(28,59),(31,60),(33,66),(38,66),(44,67),(52,68),(60,68),(64,66),
    (62,60),(58,54),(52,50),(48,46),(42,45),(38,45),(33,45),(29,46),(28,41),(24,41),
    (20,40),(23,37),(19,40),(14,40),(12,45),(8,44),(3,43),(-2,37),(-6,36)],
   # Scandinavie.
   [(5,58),(4,62),(11,65),(15,69),(21,71),(28,70),(31,66),(25,64),(22,60),(18,59),
    (12,56),(9,57),(7,58)],
   # Grande-Bretagne et Irlande, d'un seul tenant : deux îles de six
   # cellules ne porteraient ni nom ni garnison.
   [(-10,50),(-11,55),(-8,59),(-2,59),(0,55),(1,51),(-5,49)],
   # Islande.
   [(-22,67),(-10,67),(-10,63),(-21,63)],
 ]),
 "F": ("Afrique", 3, [
   [(-17,15),(-17,21),(-12,28),(-5,32),(0,36),(10,37),(20,32),(25,32),(32,31),(35,24),
    (39,18),(43,12),(51,12),(51,11),(44,2),(41,-3),(40,-12),(35,-21),(33,-27),(27,-34),
    (18,-35),(12,-18),(9,-2),(2,4),(-4,5),(-10,4),(-14,9)],
   # Madagascar.
   [(43,-11),(51,-15),(50,-26),(43,-23)],
 ]),
 "A": ("Asie", 7, [
   # Le bloc eurasiatique à l'est de l'Oural, jusqu'au Pacifique et à l'Inde.
   [(60,68),(72,73),(85,76),(100,77),(112,75),(125,73),(140,73),(155,71),(168,69),
    (178,67),(172,60),(162,58),(156,52),(150,46),(143,44),(135,44),(130,38),(122,38),
    (120,32),(115,23),(107,18),(103,10),(100,6),(97,10),(94,16),(92,21),(88,22),
    (80,15),(77,8),(73,17),(68,23),(62,25),(57,25),(50,29),(50,34),(46,42),(41,44),(36,42),
    (34,36),(35,31),(39,24),(44,13),(48,13),(52,19),(57,24),(60,25),(62,38),(56,44),(50,45),
    (52,51),(58,53),(62,60),(60,66)],
   # Japon.
   [(129,31),(136,34),(143,41),(147,46),(151,45),(145,38),(141,32),(133,28)],
   # Sri Lanka rattachée à l'Inde : négligeable à cette échelle.
 ]),
 "O": ("Océanie", 2, [
   # Australie.
   [(113,-22),(114,-34),(118,-35),(129,-32),(137,-35),(141,-38),(147,-39),(153,-28),
    (148,-20),(145,-15),(136,-12),(130,-11),(125,-14),(117,-20)],
   # Nouvelle-Guinée.
   [(129,2),(142,0),(154,-5),(150,-11),(136,-10),(130,-5)],
   # Indonésie : Sumatra, Java, Bornéo, Célèbes — élargies et rapprochées,
   # faute de quoi l'archipel ne ferait pas une place tenable.
   [(93,8),(101,3),(108,-8),(101,-10),(92,1)],
   [(103,-9),(117,-10),(117,-14),(103,-12)],
   [(108,-4),(116,-5),(121,-2),(118,5),(109,3)],
   [(123,-5),(124,2),(129,2),(127,-6)],
 ]),
}

# Les détroits, élargis.
#
# À cette taille, une cellule vaut trois degrés de longitude : Gibraltar,
# la Manche, le détroit de Béring et celui de Mozambique n'existeraient
# simplement pas, et l'Afrique tiendrait à l'Europe par la terre. On les
# creuse donc à la main, comme le fait toute carte de jeu.
MERS = [
  # Méditerranée : elle sépare l'Europe de l'Afrique, et c'est tout le sens
  # des traversées du Risk — l'Afrique du Nord ne se prend que par la mer.
  [(-8,34),(-8,37.5),(12,39),(20,38),(28,38),(36,33),(36,30),(20,32),(0,34)],
  # La Manche et la mer d'Irlande : les îles Britanniques sont des îles.
  [(-11,49.5),(-11,51),(-4,52),(0,52.5),(2,51.5),(1,50),(-4,49.5)],
  # Détroit de Davis et mer du Groenland : le Groenland est une île.
  [(-75,58),(-75,80),(-60,82),(-56,74),(-58,66),(-68,60)],
  # Mer du Japon.
  [(127,32),(127,44),(134,49),(140,48),(139,42),(134,33)],
  # Canal du Mozambique.
  [(38,-10),(38,-27),(44,-27),(44,-10)],
  # Mer de Tasman et détroit de Torrès : la Nouvelle-Guinée reste une île.
  [(128,-8),(128,-11.5),(155,-11.5),(155,-8)],
  # Mer de Chine méridionale : l'Indonésie ne tient pas au continent.
  [(94,7.5),(94,9),(120,9),(120,7.5)],
]

# ------------------------------------------------------- rastérisation

def raster(polys):
    img = Image.new("1", (W, H), 0)
    d = ImageDraw.Draw(img)
    for p in polys:
        d.polygon([px(lon, lat) for lon, lat in p], fill=1)
    return {(x, y) for y in range(H) for x in range(W) if img.getpixel((x, y))}

terre = {}
for k, (nom, bonus, polys) in CONTINENTS.items():
    terre[k] = raster(polys)
mer = raster(MERS)

# Le Groenland appartient à l'Amérique du Nord mais se dessine à part.
terre["N"] |= terre.pop("G")
CONTINENTS.pop("G")

# Aucune cellule ne doit appartenir à deux continents.
for k in terre: terre[k] -= mer

ordre = ["N", "S", "E", "F", "A", "O"]
vus = {}
for k in ordre:
    for c in sorted(terre[k]):
        if c in vus: terre[k].discard(c)
        else: vus[c] = k

print("cellules par continent :", {k: len(v) for k, v in terre.items()},
      "total", sum(len(v) for v in terre.values()), file=sys.stderr)

# ------------------------------------------------------------ l'aperçu

COUL = {"N":(214,108,88), "S":(226,176,84), "E":(120,150,214),
        "F":(150,196,120), "A":(190,130,200), "O":(226,140,180)}
img = Image.new("RGB", (W*8, H*8), (24,40,58))
d = ImageDraw.Draw(img)
for k, cs in terre.items():
    for (x, y) in cs:
        d.rectangle([x*8, y*8, x*8+7, y*8+7], fill=COUL[k])
img.save("continents.png")
print("aperçu écrit", file=sys.stderr)

# ------------------------------------------------------- les quarante-deux

PLACES = [
 # (continent, nom, [graines en longitude/latitude])
 # Plusieurs graines pour une même place quand sa forme le demande : c'est
 # ainsi qu'on lui fait suivre une côte ou franchir une chaîne, sans avoir à
 # tracer la frontière soi-même.
 ("N","Alaska",[(-152,64),(-160,68)]),
 ("N","Territoires du Nord-Ouest",[(-112,66),(-95,68),(-85,72)]),
 ("N","Groenland",[(-42,72),(-35,78)]),
 ("N","Alberta",[(-115,54),(-108,58)]),
 ("N","Ontario",[(-90,52),(-82,58),(-75,62)]),
 ("N","Québec",[(-70,50),(-62,55)]),
 ("N","Ouest des États-Unis",[(-112,40),(-105,45)]),
 ("N","Est des États-Unis",[(-85,38),(-78,42)]),
 ("N","Amérique centrale",[(-98,20),(-85,14)]),
 ("S","Venezuela",[(-67,6),(-75,4)]),
 ("S","Pérou",[(-73,-12),(-65,-18)]),
 ("S","Brésil",[(-50,-10),(-40,-8),(-55,-22)]),
 ("S","Argentine",[(-65,-35),(-70,-45)]),
 ("E","Islande",[(-16,65)]),
 ("E","Scandinavie",[(16,63),(10,60),(25,68)]),
 ("E","Grande-Bretagne",[(-3,53)]),
 ("E","Europe du Nord",[(12,51),(20,53)]),
 ("E","Ukraine",[(38,56),(50,60),(58,64),(30,52),(44,45)]),
 ("E","Europe de l'Ouest",[(0,45),(-5,40),(3,48)]),
 ("E","Europe du Sud",[(14,43),(22,43),(24,38)]),
 ("F","Afrique du Nord",[(2,25),(-8,25),(12,20),(20,28)]),
 ("F","Égypte",[(30,27),(26,22)]),
 ("F","Congo",[(20,0),(12,-6),(25,-10)]),
 ("F","Afrique de l'Est",[(38,4),(30,10),(38,-10)]),
 ("F","Afrique du Sud",[(24,-26),(31,-24)]),
 ("F","Madagascar",[(46,-19)]),
 ("A","Sibérie",[(88,62),(80,55),(95,70),(88,48)]),
 ("A","Iakoutie",[(128,66),(115,70),(140,68)]),
 ("A","Kamtchatka",[(162,60),(150,58),(140,55)]),
 ("A","Oural",[(66,60),(70,50),(76,46)]),
 ("A","Irkoutsk",[(106,55),(118,55),(128,52)]),
 ("A","Mongolie",[(105,46),(115,45)]),
 ("A","Japon",[(138,37)]),
 ("A","Afghanistan",[(64,36),(58,41),(70,40),(62,33)]),
 ("A","Chine",[(105,33),(88,40),(95,28),(118,28)]),
 ("A","Moyen-Orient",[(44,30),(46,40),(52,25),(56,31)]),
 ("A","Inde",[(78,22),(72,26)]),
 ("A","Siam",[(101,14),(96,20)]),
 ("O","Indonésie",[(110,-2),(100,0)]),
 ("O","Nouvelle-Guinée",[(142,-6)]),
 ("O","Australie occidentale",[(122,-26),(128,-18)]),
 ("O","Australie orientale",[(146,-28),(140,-20)]),
]

def cellule(lon, lat):
    x, y = px(lon, lat)
    return (int(x), int(y))

# Chaque place reçoit la cellule de terre la plus proche de sa graine.
graine = {}
place = {}
file = deque()
for i, (k, nom, points) in enumerate(PLACES):
    for lon, lat in points:
        cx, cy = px(lon, lat)
        best = min(terre[k], key=lambda c: (c[0]+0.5-cx)**2 + (c[1]+0.5-cy)**2)
        graine.setdefault(i, best)
        if best in place:
            print("graine en double :", nom, "et", PLACES[place[best]][1], file=sys.stderr)
            continue
        place[best] = i; file.append(best)
while file:
    x, y = file.popleft()
    i = place[(x, y)]
    k = PLACES[i][0]
    for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
        n = (x+dx, y+dy)
        if n in place or n not in terre[k]: continue
        place[n] = i; file.append(n)

# Les cellules qu'aucune graine n'atteint (une île sans graine) : à la plus
# proche à vol d'oiseau, dans le même continent.
orphelines = []
for k, cs in terre.items():
    for c in cs:
        if c not in place:
            orphelines.append((k, c))
for k, c in orphelines:
    i = min((i for i, p in enumerate(PLACES) if p[0] == k),
            key=lambda i: (graine[i][0]-c[0])**2 + (graine[i][1]-c[1])**2)
    place[c] = i
if orphelines:
    print(len(orphelines), "cellules orphelines rattachées à vue", file=sys.stderr)

# Les mers intérieures : une poche d'eau cernée par la terre. La mer de Java
# en est une, et elle laisse un trou dans l'Indonésie. À cette taille elle ne
# dit rien que la côte ne dise déjà.
dehors = set()
pile = [(x, y) for x in range(W) for y in (0, H-1) if (x, y) not in place]
pile += [(x, y) for y in range(H) for x in (0, W-1) if (x, y) not in place]
dehors.update(pile)
while pile:
    x, y = pile.pop()
    for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
        n = (x+dx, y+dy)
        if 0 <= n[0] < W and 0 <= n[1] < H and n not in place and n not in dehors:
            dehors.add(n); pile.append(n)
reste = {(x, y) for x in range(W) for y in range(H)
         if (x, y) not in place and (x, y) not in dehors}
comblees = 0
while reste:
    depart = reste.pop()
    poche, pile = {depart}, [depart]
    while pile:
        x, y = pile.pop()
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            n = (x+dx, y+dy)
            if n in reste:
                reste.discard(n); poche.add(n); pile.append(n)
    # Seules les petites : la mer du Nord est une mer, pas un trou de dessin,
    # et la combler collerait la Grande-Bretagne au continent.
    if len(poche) > 3: continue
    for c in poche:
        autour = [place[(c[0]+dx, c[1]+dy)] for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))
                  if (c[0]+dx, c[1]+dy) in place]
        if autour: place[c] = max(set(autour), key=autour.count); comblees += 1
if comblees: print(comblees, "cases d'eau cernées comblées", file=sys.stderr)

# Les miettes : un îlot de deux cases détaché de sa place par un détroit
# élargi. Il se rend au voisin qui le touche le plus — une place dont le
# dessin se disperse ne se lit plus.
def morceaux(cs):
    reste, out = set(cs), []
    while reste:
        d = reste.pop(); m, pile = {d}, [d]
        while pile:
            x, y = pile.pop()
            for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                n = (x+dx, y+dy)
                if n in reste: reste.discard(n); m.add(n); pile.append(n)
        out.append(m)
    return sorted(out, key=len, reverse=True)

miettes = 0
for i in range(len(PLACES)):
    ms = morceaux([c for c, j in place.items() if j == i])
    if len(ms) < 2: continue
    for m in ms[1:]:
        if len(m) > 4 or len(m) * 4 >= len(ms[0]): continue
        for c in m:
            autour = [place[(c[0]+dx, c[1]+dy)] for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))
                      if (c[0]+dx, c[1]+dy) in place and place[(c[0]+dx, c[1]+dy)] != i]
            if autour: place[c] = max(set(autour), key=autour.count); miettes += 1
if miettes: print(miettes, "miettes rendues au voisin", file=sys.stderr)

compte = {}
for c, i in place.items(): compte[i] = compte.get(i, 0) + 1
print("plus petite place :", min(compte.items(), key=lambda t: t[1]),
      PLACES[min(compte, key=lambda i: compte[i])][1], file=sys.stderr)

# ------------------------------------------------------ voisinages déduits

voisins = {i: set() for i in range(len(PLACES))}
for (x, y), i in place.items():
    for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
        j = place.get((x+dx, y+dy))
        if j is not None and j != i:
            voisins[i].add(j); voisins[j].add(i)

# ------------------------------------------------------------- l'aperçu

import colorsys
def teinte(i):
    k = PLACES[i][0]
    base = {"N":0.03,"S":0.11,"E":0.58,"F":0.29,"A":0.78,"O":0.90}[k]
    n = sum(1 for p in PLACES if p[0] == k)
    r = [j for j, p in enumerate(PLACES) if p[0] == k].index(i)
    l = 0.42 + 0.30 * (r / max(1, n - 1))
    return tuple(int(255*v) for v in colorsys.hls_to_rgb(base, l, 0.55))

Z = 9
img = Image.new("RGB", (W*Z, H*Z), (24,40,58))
d = ImageDraw.Draw(img)
for (x, y), i in place.items():
    d.rectangle([x*Z, y*Z, x*Z+Z-1, y*Z+Z-1], fill=teinte(i))
for i, (k, nom, points) in enumerate(PLACES):
    cs = [c for c, j in place.items() if j == i]
    mx = sum(c[0] for c in cs)/len(cs); my = sum(c[1] for c in cs)/len(cs)
    d.text((mx*Z, my*Z), nom[:14], fill=(255,255,255))
img.save("places.png")
print("aperçu des places écrit", file=sys.stderr)

# ------------------------------------------- confrontation avec le Risk

from importlib import import_module
ATTENDU = import_module("carte_du_monde_voisinages").PAIRES
nom = {i: p[1] for i, p in enumerate(PLACES)}
obtenu = set()
for i, ns in voisins.items():
    for j in ns: obtenu.add(tuple(sorted((nom[i], nom[j]))))

print("\n— voisinages de terre trouvés :", len(obtenu))
manque = sorted(ATTENDU - obtenu)
trop = sorted(obtenu - ATTENDU)
print("\n— attendus et absents (à déclarer en traversée, ou à corriger) :", len(manque))
for a, b in manque: print("   ", a, "–", b)
print("\n— trouvés mais absents du Risk :", len(trop))
for a, b in trop: print("   ", a, "–", b)

# ---------------------------------------------------- le plan, en toutes lettres

SYMBOLES = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnop"
assert len(SYMBOLES) >= len(PLACES)

xs = [c[0] for c in place]; ys = [c[1] for c in place]
x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
# Une case de marge tout autour : au bord exact, le trait de côte serait rogné.
x0 -= 1; x1 += 1; y0 -= 1; y1 += 1
lignes = []
for y in range(y0, y1 + 1):
    lignes.append("".join(SYMBOLES[place[(x, y)]] if (x, y) in place else "."
                          for x in range(x0, x1 + 1)))
print("\n— plan :", len(lignes), "lignes de", len(lignes[0]), file=sys.stderr)

TRAVERSEES = [p for p in sorted(ATTENDU - obtenu)
              if p != ("Kamtchatka", "Mongolie")]

with open("plan.txt", "w") as f:
    for l in lignes: f.write('        "%s",\n' % l)
with open("places.txt", "w") as f:
    for i, (k, nom, pts) in enumerate(PLACES):
        f.write('        .init("%s", "%s", "%s"),\n' % (SYMBOLES[i], k, nom))
with open("traversees.txt", "w") as f:
    for a, b in TRAVERSEES:
        f.write('        ("%s", "%s"),\n' % (a, b))
print("— traversées :", len(TRAVERSEES), file=sys.stderr)
