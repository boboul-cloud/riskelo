# Captures d'écran

Apple exige au minimum **une capture par taille d'appareil obligatoire**, et en
accepte jusqu'à dix. Trois à cinq bien choisies valent mieux que dix
répétitives.

## Les tailles obligatoires

| Plateforme | Taille exigée | Résolution (portrait) | Appareil du simulateur |
|---|---|---|---|
| iPhone | 6,9 pouces | 1290 × 2796 ou 1320 × 2868 | iPhone 17 Pro Max |
| iPad | 13 pouces | 2064 × 2752 | iPad Pro 13" (M4) |
| Mac | — | 2880 × 1800 (16:10) | fenêtre de l'app, 1440 × 900 en points |

Une capture d'iPhone 6,9" suffit pour toutes les autres tailles d'iPhone :
Apple les met à l'échelle. Le paysage est accepté, à condition de ne pas
mélanger les orientations dans une même série.

## Les cinq écrans à photographier

Dans cet ordre — le premier est celui que l'on voit dans les résultats de
recherche, et c'est lui qui doit dire ce qu'est le jeu :

1. **Un duel en cours** — la question par-dessus le plateau, le sablier
   entamé, les propositions visibles. C'est la promesse du jeu en une image.
2. **Le panneau d'assaut** — les six thèmes avec les scores du défenseur et la
   lunette sur son point faible. Cela montre que le choix du terrain est un
   vrai coup.
3. **Le plateau du Monde**, bien rempli, en milieu de partie — deux ou trois
   camps enchevêtrés, un continent tenu avec son bonus affiché.
4. **La feuille du verdict en face à face** — les deux réponses côte à côte
   avec leurs temps et la couronne. C'est le mode qui distingue le jeu.
5. **L'écran de mise en place** — il montre d'un coup d'œil tout ce qui se
   règle.

Une sixième, facultative : la bibliothèque des parties, si l'on veut insister
sur le fait qu'on peut revenir en arrière.

## Comment les prendre

Sur le simulateur, la capture sort exactement à la bonne résolution :

```bash
xcrun simctl list devices          # trouver l'appareil
xcrun simctl boot "iPhone 17 Pro Max"
open -a Simulator
# jouer jusqu'à l'écran voulu, puis :
xcrun simctl io booted screenshot ~/Desktop/riskelo-01-duel.png
```

Sur le Mac, `⌘⇧4` puis la barre d'espace photographie la fenêtre seule — mais
elle ajoute une ombre portée qu'Apple refuse. Pour l'éviter :

```bash
screencapture -o -w ~/Desktop/riskelo-mac-01.png
```

## Ce qui fait rejeter une capture

- Une maquette d'appareil dessinée autour de l'écran, ou un fond ajouté qui
  déborde du cadre.
- Un écran qui ne vient pas de l'application (page web, montage).
- Une barre d'état montrant une heure et une charge incohérentes d'une capture
  à l'autre — le simulateur affiche 9:41 partout, ce qui est la convention.
- Du texte promotionnel qui recouvre l'interface au point qu'on ne la voit
  plus.

## L'icône de l'App Store

Elle est déjà dans le catalogue (`icone-ios-1024.png`, 1024 × 1024, sans canal
alpha ni coins arrondis) et se refait d'une commande :

```bash
swiftc -O -parse-as-library -o /tmp/icone outils/icone.swift && /tmp/icone
```
