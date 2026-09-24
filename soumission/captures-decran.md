# Captures d'écran

Apple exige au minimum **une capture par taille d'appareil obligatoire**, et en
accepte jusqu'à dix. Trois à cinq bien choisies valent mieux que dix
répétitives.

## Les tailles obligatoires

| Plateforme | Taille exigée | Résolution (portrait) | Appareil du simulateur |
|---|---|---|---|
| iPhone | 6,9 pouces | 1290 × 2796 ou 1320 × 2868 | iPhone 17 Pro Max |
| iPhone | 6,5 pouces | 1242 × 2688 | iPhone 11 Pro Max |
| iPad | 13 pouces | 2064 × 2752 | iPad Pro 13" (M5) |
| Mac | — | 2880 × 1800 (16:10) | fenêtre de l'app, 1440 × 900 en points |

Une capture d'iPhone 6,9" suffit pour toutes les autres tailles d'iPhone :
Apple les met à l'échelle. Le 6,5" n'est donc pas exigé — il est fourni quand
même, parce qu'il ne coûte qu'un appareil de plus dans la même commande et
qu'un dossier complet ne se refait pas la veille d'un dépôt. Le paysage est accepté, à condition de ne pas
mélanger les orientations dans une même série.

## Où elles sont rangées

Un dossier par langue, puis un par taille : dans App Store Connect, la fiche
française et la fiche anglaise ont chacune ses images, et c'est le menu de
langue en haut de la page de la version qui commande les cases où on les
dépose.

| Dossier | Langue | Taille | Nombre | État |
|---|---|---|---|---|
| `captures/fr/iphone-6.9/` | français | 6,9 pouces | 6 | **périmée** — 30 août, accueil à trois boutons |
| `captures/fr/iphone-6.5/` | français | 6,5 pouces | 6 | 17 septembre |
| `captures/fr/ipad-13/` | français | 13 pouces | 5 | 17 septembre |
| `captures/en/iphone-6.9/` | anglais | 6,9 pouces | — | **manquante** |
| `captures/en/iphone-6.5/` | anglais | 6,5 pouces | 8 | 17 septembre |
| `captures/en/ipad-13/` | anglais | 13 pouces | 4 | 17 septembre |
| `captures/achats/` | les deux | — | 6 | pour les achats intégrés, pas pour la fiche |
| `captures/_ecartees/` | les deux | — | 7 | prises puis mises de côté ; la raison est dans le nom |

> **Il manque la seule taille d'iPhone exigée — 17 septembre 2026.** Les séries
> du jour font 1242 × 2688, c'est-à-dire le 6,5 pouces, qui est facultatif. Le
> 6,9 pouces, lui, est obligatoire : il n'existe qu'en français et il date du
> 30 août, avec un accueil à trois boutons qui n'existe plus. Les deux fiches
> en attendent une neuve.

### Ce que montre chaque série, dans l'ordre

Le numéro est l'ordre de dépôt : la première image est celle qui s'affiche
dans les résultats de recherche.

| | français, iPad 13″ | français, iPhone 6,5″ | anglais, iPad 13″ | anglais, iPhone 6,5″ |
|---|---|---|---|---|
| 01 | duel | duel | assaut | duel |
| 02 | plateau de l'Anneau | assaut | verdict | annonce de l'assaut |
| 03 | plateau du Monde | verdict | jouer au loin | verdict |
| 04 | jouer au loin | pose des renforts | accueil | plateau du Monde |
| 05 | accueil | jouer à plusieurs | | pose des renforts |
| 06 | | jouer au loin | | réglages |
| 07 | | | | jouer à plusieurs |
| 08 | | | | accueil |

Les deux séries ne montrent pas les mêmes écrans : l'anglaise n'a pas de
plateau vide et la française n'a ni réglages ni accueil sur iPhone. Rien ne
l'interdit — Apple demande au moins une image par taille — mais un acheteur
anglais et un acheteur français ne verront pas la même chose.

### Les sept écartées

Elles ne sont pas perdues : elles sont dans `captures/_ecartees/`, sous un nom
qui dit pourquoi.

| Fichier | Pourquoi |
|---|---|
| `fr-montage-deux-telephones.png` | un montage sur fond brun, pas une capture |
| `en-montage-deux-telephones.png` | le même, côté anglais |
| `en-doublon-jouer-a-plusieurs.png` | deux fois le même écran dans la série |
| `fr-verdict-en-anglais-perime.png` | l'Anneau aux noms anglais dans la série française, « Assaillant / Défenseur » d'une version d'avant, et l'heure à 01:22 |
| `fr-assaut-themes-en-anglais.png` | les six thèmes s'affichent en anglais dans l'app française |
| `fr-annonce-question-de-geography.png` | « Question de Geography — facile » |
| `en-ipad-lobby-boutons-en-francais.png` | « Ouvrir la table » et « Rejoindre une table » en français dans l'app anglaise |

Les trois dernières ne sont pas des ratés de prise de vue, mais ce que l'écran
montrait :

- Les deux boutons du salon manquent au catalogue de traduction. Ils sont
  écrits en clair dans `Sources/UI/LobbyView.swift`, lignes 113 et 118, et
  `Resources/Localizable.xcstrings` ne les connaît pas — l'app anglaise les
  affiche donc en français.
- Les thèmes en anglais sous une interface française sont un état que l'app
  permet : la banque de questions se choisit au bouton de langue, en haut de
  la page des packs. Ce n'est pas une panne, mais cela n'a pas sa place dans
  une fiche française — et l'élision (« de Geography ») ne regarde que la
  langue de l'interface, pas celle du thème.

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

Une sixième, prise elle aussi : l'accueil. Elle ne dit pas ce qu'est le jeu —
c'est pourquoi elle vient en dernier — mais elle montre l'icône, et par quoi
l'on commence. C'est aussi celle qui se périme le plus vite : chaque bouton
ajouté à l'accueil la démode, et elle est la seule des six à le faire sans
qu'on y pense.

## Comment les prendre

D'une commande. `outils/captures.py` joue la partie tout seul sur les trois
appareils, prend les six écrans et les range dans `soumission/captures/fr/`,
aux noms et dans l'ordre de cette fiche :

```bash
python3 outils/captures.py
```

Il attend une `Riskelo.app` pour simulateur dans `build/` :

```bash
xcodebuild -project Riskelo.xcodeproj -scheme Riskelo \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
    -derivedDataPath build/dd build
cp -R build/dd/Build/Products/Debug-iphonesimulator/Riskelo.app build/
```

Il règle aussi la barre d'état à 9:41, charge pleine et réseau plein sur les
trois appareils — le simulateur affiche l'heure réelle par défaut, et une
heure qui change d'une capture à l'autre fait rejeter la série.

L'outil ne sait prendre que la série française. Il conduit l'application en
cliquant des boutons qu'il appelle par leur nom — « Jouer à plusieurs »,
« À l'attaque » — et ces noms sont français. Lancer l'app en anglais avec
`-AppleLanguages "(en)"` ne suffit donc pas : il faudrait lui apprendre les
deux jeux de libellés. La série anglaise se prend à la main en attendant.

La série se joue en **face à face** à dessein : en classique, seul le
défenseur répond, et c'est la machine quand c'est nous qui attaquons. La
question ne s'afficherait jamais à l'écran, et la première capture — celle qui
doit dire ce qu'est le jeu — serait impossible à prendre.

À la main, si besoin :

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
