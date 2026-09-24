# La localisation anglaise — ce qu'il faut faire dans App Store Connect

Riskelo US a été refusée deux fois sous **4.3(a)**, et Apple a nommé le
remède : « consider consolidating these variants into a single app ». L'anglais
est donc devenu une langue de Riskelo, et non une seconde application.

Cette fiche complète `FICHE-DE-SOUMISSION.md` : elle ne couvre que ce que la
localisation ajoute. Le reste — coordonnées, questionnaires, classification —
ne change pas.

## Sur la fiche de l'app

Ajouter la langue **Anglais (États-Unis)**. Le nom reste `Riskelo` dans les
deux langues : c'est le nom de l'app, pas une phrase.

### Les adresses de la fiche anglaise

App Store Connect demande ces adresses **par langue**. Le site en a maintenant
une version anglaise, sous `/en/`, et chaque page renvoie à son équivalent
français par un bouton dans la barre du haut.

| Champ App Store Connect | Adresse |
|---|---|
| URL marketing | `https://boboul-cloud.github.io/riskelo/en/` |
| **URL d'assistance** (obligatoire) | `https://boboul-cloud.github.io/riskelo/en/support.html` |
| **URL de la politique de confidentialité** (obligatoire) | `https://boboul-cloud.github.io/riskelo/en/privacy.html` |
| CLUF personnalisé (facultatif) | `https://boboul-cloud.github.io/riskelo/en/terms.html` |

Les trois premières sont obligatoires et se vérifient avant d'envoyer :

```bash
for p in en/ en/support.html en/privacy.html en/terms.html; do
  curl -s -o /dev/null -w "$p %{http_code}\n" https://boboul-cloud.github.io/riskelo/$p
done
```

Le mode d'emploi du site reste français : sa version anglaise est dans
l'application, au bouton *How to play*, et la fiche anglaise d'assistance y
renvoie plutôt que de promettre une page qui n'existe pas.

### Sous-titre — 30 signes max

```
Conquest and trivia
```

### Mots-clés — 100 signes max

```
quiz,strategy,board,territory,turn-based,offline,online,multiplayer,family,geography,history,dice
```

### Texte promotionnel — 170 signes max

```
2,400 questions, four boards, three ways to fight — dice included. Play alone, around one device, or far apart with a six-letter code. No ads, no account.
```

### Description — 4 000 signes max

**La description à jour est dans [README.md](README.md)**, en français et
en anglais — celle de la 1.5. Rien n'est recopié ici : deux copies d'un
même texte finissent par dire deux choses différentes, et c'est la
mauvaise qu'on colle.

### Nouveautés de cette version

**La note de la version en cours est dans [README.md](README.md)**, en
français et en anglais.

## Les dix-sept articles à créer

Non consommables, partage familial activé, comme les français. Ils portent la
famille `pack.us.` : c'est elle qui les distingue, et un test la vérifie.

Les formulaires se recopient depuis [packs-app-store.md](packs-app-store.md),
un bloc par article, les trente-quatre à la suite. Le tableau ci-dessous en
est le résumé. **Le nom d'affichage s'arrête à 30 signes et la description à
45** : ce tableau a d'abord été écrit pour 55, et ses descriptions ont été
raccourcies pour entrer dans la case.

| Nom de référence | Identifiant de produit | Nom affiché (30) | Description (45) |
|---|---|---|---|
| Rock 70 80 Pack | `com.oulhen.riskelo.pack.us.rock7080` | Rock 70-80 | `Rock of the 1970s and 1980s. 400 questions.` |
| History Grade 6 Pack | `com.oulhen.riskelo.pack.us.history6` | History — Grade 6 | `Ancient Egypt, Greece, Rome. 200 questions.` |
| Geography Grade 6 Pack | `com.oulhen.riskelo.pack.us.geography6` | Geography — Grade 6 | `Map skills, Africa and Asia. 200 questions.` |
| English Grade 6 Pack | `com.oulhen.riskelo.pack.us.english6` | English — Grade 6 | `Grammar, word roots, myths. 200 questions.` |
| Science Grade 6 Pack | `com.oulhen.riskelo.pack.us.science6` | Science — Grade 6 | `Rocks, weather, space. 200 questions.` |
| History Grade 7 Pack | `com.oulhen.riskelo.pack.us.history7` | History — Grade 7 | `Middle Ages to Columbus. 200 questions.` |
| Geography Grade 7 Pack | `com.oulhen.riskelo.pack.us.geography7` | Geography — Grade 7 | `Europe, Americas, Pacific. 200 questions.` |
| English Grade 7 Pack | `com.oulhen.riskelo.pack.us.english7` | English — Grade 7 | `Poetry, fiction, drama. 200 questions.` |
| Science Grade 7 Pack | `com.oulhen.riskelo.pack.us.science7` | Science — Grade 7 | `Cells, plants, animals. 200 questions.` |
| History Grade 8 Pack | `com.oulhen.riskelo.pack.us.history8` | History — Grade 8 | `Colonies to Reconstruction. 200 questions.` |
| Geography Grade 8 Pack | `com.oulhen.riskelo.pack.us.geography8` | Geography — Grade 8 | `States, capitals, cities. 200 questions.` |
| English Grade 8 Pack | `com.oulhen.riskelo.pack.us.english8` | English — Grade 8 | `Literature, Poe to Morrison. 200 questions.` |
| Science Grade 8 Pack | `com.oulhen.riskelo.pack.us.science8` | Science — Grade 8 | `Atoms, forces, energy, waves. 200 questions.` |
| History Grade 9 Pack | `com.oulhen.riskelo.pack.us.history9` | History — Grade 9 | `The modern world since 1750. 200 questions.` |
| Geography Grade 9 Pack | `com.oulhen.riskelo.pack.us.geography9` | Geography — Grade 9 | `Population, cities, trade. 200 questions.` |
| English Grade 9 Pack | `com.oulhen.riskelo.pack.us.english9` | English — Grade 9 | `Shakespeare and the classics. 200 questions.` |
| Science Grade 9 Pack | `com.oulhen.riskelo.pack.us.science9` | Science — Grade 9 | `DNA, genetics, evolution. 200 questions.` |

Les dix-sept articles français ne bougent pas.

## La liaison à deux appareils, revérifiée

Le dialecte réseau est passé de 7 à 8 et trois identifiants de thèmes ont
changé côté anglais : deux appareils qui se seraient crus compatibles auraient
tiré des questions différentes.

**16 septembre 2026 — essayé sur un vrai iPhone et un vrai Mac, dans les deux
modes.** Au loin par le code à six lettres, et en local par Bonjour. L'iPhone
français ouvre, le Mac anglais rejoint, les deux jouent les questions
françaises. C'est la règle : la table joue la langue de celui qui l'ouvre.

## Les captures d'écran

Une série par langue, et c'est le menu de langue en haut de la page de la
version qui décide où elles tombent : sur *Anglais (É.-U.)*, les cases à
images sont celles de la fiche anglaise.

L'anglais a été pris à la main le 17 septembre — l'app se lance en anglais
avec `-AppleLanguages "(en)"`, ce qui évite de changer la langue du
simulateur. `outils/captures.py`, lui, ne sait pas la prendre tout seul : il
clique des boutons qu'il appelle par leur nom, et ces noms sont français.

| Dossier | Taille | Nombre |
|---|---|---|
| `captures/en/iphone-6.9/` | 1320 × 2868 | **0 — manquante, et c'est la seule exigée** |
| `captures/en/iphone-6.5/` | 1242 × 2688 | 8 |
| `captures/en/ipad-13/` | 2064 × 2752 | 4 |

Deux choses vues en rangeant la série anglaise, et qui la regardent :

- **Le salon parle français dans l'app anglaise.** « Ouvrir la table » et
  « Rejoindre une table » sont écrits en clair dans
  `Sources/UI/LobbyView.swift`, lignes 113 et 118, et manquent au catalogue
  `Resources/Localizable.xcstrings` — ce sont les deux seules chaînes de
  l'interface dans ce cas. La capture qui les montre est dans
  `captures/_ecartees/`, et l'écran est celui qu'un relecteur atteint en deux
  touches depuis l'accueil.
- **Les deux séries ne montrent pas les mêmes écrans.** L'anglaise a les
  réglages et pas de plateau vide, la française l'inverse. Rien ne l'interdit ;
  cela se décide.

## Ce qui change dans le binaire

L'App Store porte aujourd'hui la **1.2, build 5**. La 1.3 build 7 n'est jamais
partie : c'est la version en attente, et c'est elle qui emportera la
localisation. Les numéros ne bougent donc pas.

| | |
|---|---|
| Version | **1.3** — inchangée, jamais publiée |
| Build | **7** — le 6 n'est jamais parti, mais il a servi d'essai ici |
| Dialecte réseau | 7 → **8** — une 1.3 ne doit pas jouer avec une 1.4 |
| Questions | 6 000 → **12 000**, deux banques |
| Articles | 17 → **34** |
