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

### Sous-titre — 30 signes max

```
The conquest game without dice
```

### Mots-clés — 100 signes max

```
trivia,quiz,strategy,board,territory,turn-based,offline,multiplayer,family,geography,history,solo
```

### Texte promotionnel — 170 signes max

```
2,400 questions in the game, three boards, two ways to duel. No ads, no account, no connection needed — the whole thing runs on the device, even on a plane.
```

### Description — 4 000 signes max

```
Riskelo is a turn-based conquest game where the roll of the dice is replaced by a trivia question.

The attacker picks the subject and how many questions — those are the dice. The defender answers against the clock. A right answer and it is the attacker who loses a man; a wrong answer, or time running out, and it is the defender. One question is worth exactly one roll: it costs a man to one side or the other.

TWO WAYS TO FIGHT

• Classic — the attacker asks and picks the ground; the defender answers alone. What you know is your armor.
• Showdown — both players get the same question. Both know it? The clock settles it. Neither? The territory holds, the way a tied roll holds it. And the defender can double the stake before answering.

THE PRESSURE OF A SIEGE

Without chance, a player who knows would never lose a place. What replaces the statistics of the dice is time: fifteen seconds on the first question, and the clock tightens with every question the same territory takes in the same turn. Pressing a place eventually pays — but it is the defender's breath that gives out, not their luck.

THREE BOARDS

• The Ring — an invented world, five lands in a circle, 28 territories. The short game.
• Europe — from the Atlantic to the Black Sea, 38 territories.
• World — six continents, 42 territories.

TWO TO FOUR PLAYERS

• Alone against the machine, whose knowledge sets anywhere from 35% to 90% correct answers and whose play has three levels — knowing and playing well are two different things.
• Around one device, passed from hand to hand.
• On several devices, one per player: no account, no setup, no server. The local Wi-Fi does it, or a direct link between the devices when there is no network — it works on a train.

Everyone can enter a name: a side reads "Blue · Marie", and the name travels from device to device.

THE RULES FROM THE BOX, OPTIONAL

• Territory cards, with the trade-in climbing at every exchange.
• Total war: every territory, no exception — a whole evening in one game.
• Personal conquests: each player is dealt an objective only they can see — two continents, so many places held, one side to bring down. Filling it wins outright, and the territory count no longer tells you who is winning.
• Scholar's reinforcement: one extra man for every few right answers in the same subject.

2,400 QUESTIONS IN THE GAME

Six subjects — Geography, History, Science & Nature, Arts & Literature, Sports & Games, Screen & Music — four hundred questions each, at three levels of difficulty. The mix is set before the game: easy for playing with children, mixed the way a boxed game would be, tough for anyone who finds the rest too easy. The draw never leaves the subject asked for: when you choose the ground, it is held. A seventh choice leaves the subject to chance, for anyone who would rather not pick. And a question does not come back: the device remembers what has already been asked, and puts the ones you have never seen in front.

QUESTION PACKS, IF YOU WANT THEM

Seventeen optional packs add 3,600 more questions. Sixteen school decks — History, Geography, English and Science, for grades 6 through 9, two hundred questions each — and Rock 70-80, four hundred questions on the music of the 1970s and 1980s. The base game is whole without them. And at a table of several devices, everyone plays the host's packs, bought or not.

THE GAME KEEPS

You find it where you left it. And the library records every turn without being asked: you can go back to the moment it all turned and play the rest again, without erasing the original.

WHAT RISKELO DOES NOT DO

No ads. No account. No tracker, no analytics. No internet connection is needed: the questions are in the app, and your games never leave your device.

iPhone, iPad and Mac — one app, in English and French.
```

> La dernière ligne a changé depuis la fiche américaine : elle annonçait
> « one app, in English ». L'application porte maintenant les deux langues, et
> une description qui l'ignore serait fausse le jour où un lecteur anglais
> bascule son appareil en français.

### Nouveautés de cette version

```
Riskelo now speaks English. The interface, the manual and six thousand new
questions — written for an American reader, not translated — come with it, and
the app follows your device's language.

Sixteen new school packs cover the American curriculum from grade 6 to grade 9:
History, Geography, English and Science. The French packs are unchanged.
```

## Les dix-sept articles à créer

Non consommables, partage familial activé, comme les français. Ils portent la
famille `pack.us.` : c'est elle qui les distingue, et un test la vérifie.

| Nom de référence | Identifiant de produit | Nom affiché (35) | Description (55) |
|---|---|---|---|
| Rock 70 80 Pack | `com.oulhen.riskelo.pack.us.rock7080` | Rock 70-80 | `Bands and voices of the 1970s and 80s. 400 questions.` |
| History Grade 6 Pack | `com.oulhen.riskelo.pack.us.history6` | History — Grade 6 | `Mesopotamia, Egypt, Greece and Rome. 200 questions.` |
| Geography Grade 6 Pack | `com.oulhen.riskelo.pack.us.geography6` | Geography — Grade 6 | `Map skills, landforms, Africa, Asia. 200 questions.` |
| English Grade 6 Pack | `com.oulhen.riskelo.pack.us.english6` | English — Grade 6 | `Grammar, punctuation, roots and myths. 200 questions.` |
| Science Grade 6 Pack | `com.oulhen.riskelo.pack.us.science6` | Science — Grade 6 | `Earth science: rocks, weather, space. 200 questions.` |
| History Grade 7 Pack | `com.oulhen.riskelo.pack.us.history7` | History — Grade 7 | `The medieval and early modern world. 200 questions.` |
| Geography Grade 7 Pack | `com.oulhen.riskelo.pack.us.geography7` | Geography — Grade 7 | `Europe, the Americas, the Pacific. 200 questions.` |
| English Grade 7 Pack | `com.oulhen.riskelo.pack.us.english7` | English — Grade 7 | `Poetry, fiction, drama and novels. 200 questions.` |
| Science Grade 7 Pack | `com.oulhen.riskelo.pack.us.science7` | Science — Grade 7 | `Life science: cells, plants, animals. 200 questions.` |
| History Grade 8 Pack | `com.oulhen.riskelo.pack.us.history8` | History — Grade 8 | `Colonial America to Reconstruction. 200 questions.` |
| Geography Grade 8 Pack | `com.oulhen.riskelo.pack.us.geography8` | Geography — Grade 8 | `The fifty states and their geography. 200 questions.` |
| English Grade 8 Pack | `com.oulhen.riskelo.pack.us.english8` | English — Grade 8 | `American literature, Poe to Morrison. 200 questions.` |
| Science Grade 8 Pack | `com.oulhen.riskelo.pack.us.science8` | Science — Grade 8 | `Atoms, reactions, forces and waves. 200 questions.` |
| History Grade 9 Pack | `com.oulhen.riskelo.pack.us.history9` | History — Grade 9 | `The modern world, 1750 to today. 200 questions.` |
| Geography Grade 9 Pack | `com.oulhen.riskelo.pack.us.geography9` | Geography — Grade 9 | `Population, cities and world trade. 200 questions.` |
| English Grade 9 Pack | `com.oulhen.riskelo.pack.us.english9` | English — Grade 9 | `Shakespeare and world literature. 200 questions.` |
| Science Grade 9 Pack | `com.oulhen.riskelo.pack.us.science9` | Science — Grade 9 | `Biology: DNA, genetics and evolution. 200 questions.` |

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

Une série par langue. Celles de l'anglais restent à prendre — l'app se lance
en anglais avec `-AppleLanguages "(en)"`, ce qui évite de changer la langue du
simulateur.

## Ce qui change dans le binaire

L'App Store porte aujourd'hui la **1.2, build 5**. La 1.3 build 6 n'est jamais
partie : c'est la version en attente, et c'est elle qui emportera la
localisation. Les numéros ne bougent donc pas.

| | |
|---|---|
| Version | **1.3** — inchangée, jamais publiée |
| Build | **6** — inchangé |
| Dialecte réseau | 7 → **8** — une 1.3 ne doit pas jouer avec une 1.4 |
| Questions | 6 000 → **12 000**, deux banques |
| Articles | 17 → **34** |
