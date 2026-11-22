# Soumission à l'App Store — Riskelo 2.0 (build 10)

> **Ce qui est chez Apple**, relu en lecture seule le 22 novembre 2026 : la
> **1.5 (build 9) est en vente**, sur iPhone et iPad. La **2.0 (build 10) est
> soumise** depuis le 22 novembre à 6 h 12, heure de Paris : elle **attend la
> revue**. Il n'y a pas de version Mac sur l'App Store.

## En clair : où en est la 2.0

La 2.0 apporte le plateau en relief, les panneaux translucides, le son qui ne
fige plus l'écran et le mode d'emploi corrigé. Elle est déjà partie :

1. ~~Envoyer le build 10~~ — **fait** le 22 novembre à 6 h 09.
2. ~~Créer la version 2.0 et y choisir le build 10~~ — **fait**.
3. ~~Coller la note de version, en français et en anglais~~ — **fait**. Relue
   chez Apple : elle est mot pour mot celle qui est plus bas.
4. ~~Soumettre à la revue~~ — **fait**.

La description, le texte promotionnel et les mots-clés sont ceux de la 1.5,
repris tels quels : c'était voulu, il n'y avait rien à y changer.

**Reste une chose à décider** : la relecture du 22 novembre a trouvé cinq
cases que la feuille de la 1.5 demandait de remplir et qui ne l'ont jamais
été. La section suivante les donne, et dit comment les corriger.

---

## Les cases oubliées depuis la 1.5

| Case | Ce qu'Apple a | Ce qu'il faudrait |
|---|---|---|
| **Sous-titre** français | vide | `Conquête et culture générale` |
| **Sous-titre** anglais | vide | `Conquest and trivia` |
| **URL d'assistance**, fiche anglaise | la page française | `https://boboul-cloud.github.io/riskelo/en/support.html` |
| **URL marketing**, fiche anglaise | la page française | `https://boboul-cloud.github.io/riskelo/en/` |
| **Politique de confidentialité**, fiche anglaise | la page française | `https://boboul-cloud.github.io/riskelo/en/privacy.html` |
| **Notes pour la revue** | « deux minutes » | « une semaine » — la phrase est plus bas |

Et une sixième que l'outil de lecture ne peut pas voir, parce qu'Apple ne la
montre pas par son interface de programmation : **« Confidentialité de
l'app »** doit dire « Oui : identifiant de l'appareil » (tableau plus bas).
À vérifier à l'œil.

Pourquoi ça compte :

- **Le sous-titre** est lu par la recherche de l'App Store. Les mots-clés de
  la 1.5 ont laissé de côté « conquête » et « culture générale » parce que le
  sous-titre devait les porter : sans lui, ces mots ne sont nulle part, et
  quelqu'un qui cherche « culture générale » ne tombe pas sur Riskelo.
- **Les notes pour la revue** disent au relecteur que le relais garde le
  numéro de l'appareil deux minutes. C'est une semaine depuis la 1.4, et la
  politique de confidentialité le dit. Le relecteur qui compare les deux voit
  une contradiction.
- **La fiche anglaise** envoie un joueur anglais sur des pages en français.

### Deux façons de faire

Tant que la 2.0 attend la revue, Apple **verrouille** ces cases. Seule
« Confidentialité de l'app » se change à tout moment, sans toucher à la
version : celle-là se vérifie tout de suite, quoi qu'on choisisse.

- **A. Maintenant** : retirer la 2.0 de la revue, remplir les cases, la
  soumettre de nouveau. Dix minutes, et la 2.0 repasse en fin de file —
  d'ordinaire un jour ou deux de plus. Le build 10 reste attaché, rien n'est
  à renvoyer.
- **B. À la prochaine version** : laisser la 2.0 suivre son cours, et remplir
  les cases quand une 2.1 sera créée.

### A, pas à pas, dans l'ordre des pages d'App Store Connect

1. **Page de la version 2.0** : en haut, **« Retirer de la vérification »**
   (le libellé peut varier un peu). La version passe à « Rejetée par le
   développeur » : c'est le nom normal de cet état, ce n'est pas un refus
   d'Apple.
2. **Même page, en anglais** (menu de langue en haut à droite) :
   - **URL d'assistance** : `https://boboul-cloud.github.io/riskelo/en/support.html`
   - **URL marketing** : `https://boboul-cloud.github.io/riskelo/en/`
3. **Plus bas, « Informations sur la vérification de l'app » ▸ Notes** :
   remplacer la phrase ci-dessous. Chez Apple, elle est coupée sur deux
   lignes : chercher « deux minutes ».
4. **« Informations sur l'app »**, menu de gauche : le **Sous-titre**, en
   français puis en anglais.
5. **« Confidentialité de l'app »**, menu de gauche : vérifier les réponses du
   tableau plus bas, et, en anglais, l'adresse de la **politique de
   confidentialité** :
   `https://boboul-cloud.github.io/riskelo/en/privacy.html`
6. **Page de la version 2.0** : vérifier que le **build 10** y est toujours,
   puis la soumettre de nouveau (le bouton en haut à droite).

### La phrase à remplacer dans les notes pour la revue

Dans le paragraphe « 2. AU LOIN, AVEC UN CODE », remplacer ces deux lignes :

```
Il connaît un identifiant tiré au sort à l'installation, le garde deux minutes
après la partie pour permettre d'en reprendre une coupée, puis l'efface.
```

par :

```
Il connaît un identifiant tiré au sort à l'installation, le garde une semaine après la dernière séance pour qu'une partie se reprenne un autre soir, puis l'efface.
```

Les notes passent ainsi de 3 971 à 3 983 caractères sur 4 000. Le fichier
[notes-pour-la-revue.md](notes-pour-la-revue.md) porte en plus une phrase sur
la carte du monde, ajoutée après coup : avec elle, on arriverait à 4 131
caractères. Elle reste donc dans le dossier, pas chez Apple.

### Confidentialité de l'app — les réponses

| Écran d'App Store Connect | Réponse |
|---|---|
| Collectez-vous des données depuis cette app ? | **Oui** |
| Types de données | **Identifiants ▸ Identifiant de l'appareil** — rien d'autre |
| À quoi sert-elle ? | **Fonctionnalité de l'app** — rien d'autre |
| Est-elle liée à l'identité de l'utilisateur ? | **Non** |
| Sert-elle au suivi ? | **Non** |

Pourquoi « Oui » : depuis la 1.4, le relais du jeu au loin garde une semaine
le numéro tiré au sort de chaque appareil, pour qu'une partie se reprenne un
autre soir. Apple compte cela comme une donnée collectée. La politique de
confidentialité du site le dit, et la note de la 1.5 l'a annoncé.

---

## La note de version — français

1 169 caractères sur 4 000. C'est celle qui est chez Apple.

```
LE PLATEAU EN RELIEF
• Un bouton « 3D », en haut à droite du plateau, lève la carte en relief : chaque territoire devient une dalle taillée dans son contour, bordée de la couleur de son continent, et un fanion porte le nombre d'hommes.
• Ce qui est en jeu se soulève, et la flèche d'assaut saute en arc d'une terre à l'autre.
• Un doigt promène la table, deux la rapprochent ou la font tourner.
• C'est une option : le bouton « 2D » remet le plateau à plat, et le réglage « Plateau en relief » fait la même chose avant la partie. Le relief demande iOS 18 (macOS 15 sur Mac) ; sur un système plus ancien, rien ne change.

LA CARTE RESTE EN VUE
• Les panneaux du bas — l'assaut, le déplacement, la feuille du duel — sont translucides : on voit la carte au travers, à plat comme en relief.
• Quand un panneau monte, le plateau glisse au lieu de reculer, et garde le rapprochement que vous aviez choisi.

ET AUSSI
• Le son ne fige plus l'écran quand l'appareil tarde à le donner, pendant un appel ou avec un casque sans fil.
• Le mode d'emploi est à jour : il dit exactement ce que garde le relais du jeu au loin, et parle du mode Dés.

iPhone, iPad et Mac, comme toujours.
```

## La note de version — anglais

1 170 caractères sur 4 000. C'est celle qui est chez Apple.

```
THE BOARD IN RELIEF
• A "3D" button, at the top right of the board, raises the map in relief: each territory becomes a tile cut to its outline, edged in its continent's color, and a flag carries its number of men.
• Whatever is in play lifts up, and the assault arrow leaps in an arc from one territory to the next.
• One finger moves the table; two bring it closer or turn it.
• It is optional: the "2D" button lays the board flat again, and the "3D board" setting does the same before the game. Relief needs iOS 18 (macOS 15 on Mac); on an older system, nothing changes.

THE MAP STAYS IN SIGHT
• The panels at the bottom — the assault, the move, the duel sheet — are now translucent: you see the map through them, flat or in relief.
• When a panel comes up, the board slides instead of pulling back, and keeps the zoom you had chosen.

ALSO
• Sound no longer freezes the screen when the device is slow to provide it, during a call or with wireless headphones.
• The user guide is up to date: it says exactly what the relay keeps for games played far away, covers Dice mode, and its links now lead to the English pages of the website.

iPhone, iPad and Mac, as always.
```

Ce que dit la note, et rien d'autre : ce qui a changé depuis la 1.5. Deux
changements n'y sont pas, exprès : une réparation interne du jeu au loin, que
le joueur ne voit pas, et le DMG pour Mac, qui ne passe pas par l'App Store.
Les liens du mode d'emploi ne sont cités qu'en anglais : en français, ils
menaient déjà aux bonnes pages.

Les noms sont ceux que l'application affiche : le bouton « 3D » / « 2D », et
le réglage « Plateau en relief », qui s'appelle « 3D board » en anglais.

---

## Pendant la revue

- [x] Build 10 envoyé
- [x] Version 2.0 créée, build 10 choisi
- [x] Note de version collée, en français et en anglais
- [x] Soumise à la revue, le 22 novembre 2026
- [x] Les essais automatiques : 244, tous verts sur le simulateur iPhone, le
      22 novembre 2026, sur le dernier enregistrement (7f68bad), celui du
      build 10
- [ ] **Une partie en relief sur un vrai iPhone** : glisser, pincer, tourner,
      toucher une terre. La note promet ces gestes, et personne ne les a
      encore faits au doigt — seulement le simulateur et les essais. Si
      quelque chose cloche, la 2.0 peut encore être retirée tant que la revue
      n'a pas commencé.
- [ ] Une partie en relief sur un iPad, et au trackpad du Mac (macOS 15)
- [ ] « Confidentialité de l'app » vérifiée à l'œil
- [ ] Les cases oubliées : façon A ou B, au choix de Robert

## Après l'approbation

- La branche `fusion`, où sont le relief et la 2.0, rejoint `main`, comme la
  1.5 l'avait fait.
- Sur le Mac, reprendre la version App Store à la place de la 1.5.
- Le site ne cite aucun numéro de version : rien n'y est obligatoire. Il
  pourra parler du relief, si Robert le veut.

---

## Ce qui est déjà parti

Les titres viennent des notes réellement publiées, relues chez Apple.

| Version | Créée le | Ce qu'annonçait sa note |
|---|---|---|
| 1.0 | 30 août 2026 | la première version |
| 1.1 | 7 septembre | les conquêtes personnelles, les questions, votre nom et le son, la lisibilité |
| 1.2 | 8 septembre | les conquêtes personnelles décident la partie |
| 1.3 | 17 septembre | le jeu au loin, la table à plusieurs appareils |
| 1.4 (build 8) | 19 septembre | reprendre un autre soir, plusieurs parties à la fois, le français ou l'anglais |
| 1.5 (build 9) | 24 septembre | le Monde réel, les dés — et le défenseur qui choisit un dé ou deux |
| **2.0 (build 10)** | 22 novembre — en attente de revue | le plateau en relief, les panneaux translucides |

La note de la 1.5, et sa feuille complète, restent dans
[FEUILLE-DE-SOUMISSION-1.5.md](FEUILLE-DE-SOUMISSION-1.5.md).

Le build monte à chaque envoi, sans jamais revenir en arrière : le prochain
après le 10 sera le 11. Il ne monte que sur demande de Robert.

---

## Le sous-titre, le texte promotionnel et les mots-clés

Inchangés depuis la 1.5. Le texte promotionnel et les mots-clés sont ceux
qui sont en ligne ; le sous-titre, lui, n'a jamais été posé (voir plus haut).

Sous-titre français — 28 caractères sur 30 :

```
Conquête et culture générale
```

Sous-titre anglais — 19 caractères sur 30 :

```
Conquest and trivia
```

Texte promotionnel français — 167 caractères sur 170 :

```
2 400 questions, quatre plateaux, trois manières de se battre, dés compris. Seul, à plusieurs sur un appareil, ou au loin avec un code. Aucune publicité, aucun compte.
```

Texte promotionnel anglais — 154 caractères sur 170 :

```
2,400 questions, four boards, three ways to fight — dice included. Play alone, around one device, or far apart with a six-letter code. No ads, no account.
```

Mots-clés français — 97 caractères sur 100. « conquête » et « culture
générale » ont laissé leur place à « dés », « géographie », « histoire » et
« questions », parce que le sous-titre devait les porter : il faut donc le
poser pour qu'Apple les lise.

```
stratégie,quiz,dés,plateau,territoires,duel,solo,famille,hors ligne,géographie,histoire,questions
```

Mots-clés anglais — 97 caractères sur 100. « trivia » passe dans le
sous-titre, « dice » entre.

```
quiz,strategy,board,territory,turn-based,offline,online,multiplayer,family,geography,history,dice
```

---

## La description — inchangée depuis la 1.5

C'est celle qui est en ligne : la 2.0 l'a reprise telle quelle, relue chez
Apple le 22 novembre. Elle ne parle pas du relief. En français, elle tient à
20 caractères près : pour y ajouter une ligne, il faudrait en couper une
autre. C'est un choix pour une version suivante, si Robert le veut.

### Français — 3980 caractères sur 4 000

```
Riskelo est un jeu de conquête au tour par tour où le lancer de dés est remplacé par une question de culture générale.

L'attaquant choisit le thème et le nombre de questions — ce sont ses dés. Le défenseur répond, dans le temps du sablier. Bonne réponse, et c'est l'attaquant qui laisse un homme ; mauvaise réponse ou temps écoulé, et c'est le défenseur. Une question vaut exactement une paire de dés : elle coûte un homme à l'un des deux camps.

TROIS MANIÈRES DE SE BATTRE

• Classique — l'attaquant pose la question et choisit le terrain ; le défenseur seul répond. La culture est une armure.
• Face à face — les deux joueurs reçoivent la même question. Les deux savent ? Le sablier tranche. Aucun des deux ? La place tient, comme sur une égalité de dés. Et le défenseur peut doubler l'enjeu avant de répondre.
• Dés — comme dans la boîte : jusqu'à trois dés contre deux, l'égalité au défenseur.

L'USURE DU SIÈGE

Sans hasard, un joueur qui sait ne perdrait jamais sa place. Ce qui remplace le dé, c'est le temps : quinze secondes à la première question, et le sablier se resserre à chaque question subie par un même territoire dans le même tour. Presser une place finit par payer — mais c'est le souffle du défenseur qui cède, pas le sort.

QUATRE PLATEAUX

• L'Anneau — un monde inventé, cinq terres en cercle, 28 territoires.
• Europe — de l'Atlantique à la mer Noire, 38 territoires.
• Monde — les six continents en hexagones, 42 territoires.
• Monde réel — les mêmes 42 territoires sur les vraies côtes, vingt traversées.

DE DEUX À QUATRE JOUEURS

• Seul contre la machine, dont la culture se règle de 35 à 90 % de bonnes réponses et la manœuvre en trois niveaux — savoir et bien jouer sont deux choses différentes.
• À plusieurs sur un même appareil, qui se passe de main en main.
• À plusieurs appareils, un par joueur : dans la même pièce, sans rien à configurer — ou au loin, chacun chez soi, avec un code de six lettres envoyé par message. Sans compte, dans les deux cas.

LES RÈGLES DE LA BOÎTE, EN OPTION

• Cartes de territoire, avec le barème qui monte à chaque échange.
• Guerre totale : tous les territoires, sans exception.
• Conquêtes personnelles : chacun reçoit au départ un objectif que lui seul connaît — deux continents, tant de places tenues, un camp à faire tomber. Le remplir gagne la partie, et le compte des territoires ne dit plus qui va gagner.
• Renfort d'érudition : un homme de plus toutes les N bonnes réponses dans un même thème.

DEUX MILLE QUATRE CENTS QUESTIONS

Six thèmes — Géographie, Histoire, Sciences & Nature, Arts & Lettres, Sports & Loisirs, Écrans & Musique — quatre cents questions chacun, trois niveaux de difficulté. Le dosage se choisit à la mise en place : faciles pour jouer avec des enfants, mêlées comme dans une boîte de jeu, corsées pour ceux qui trouvent le reste trop facile. Et une question ne revient pas : l'appareil fait passer devant celles que vous n'avez jamais vues.

LA PARTIE SE GARDE

Elle se retrouve où vous l'avez laissée. Et la bibliothèque enregistre chaque tour sans qu'on le demande : on peut revenir au moment où tout a basculé et rejouer la suite, sans effacer la partie d'origine.

Une partie au loin tient sur plusieurs soirées, et vous pouvez en avoir plusieurs à la fois — une avec votre sœur, une avec un ami. Il faut seulement être là en même temps.

CE QUE RISKELO NE FAIT PAS

Aucune publicité. Aucun abonnement. Aucun compte. Aucun traceur, aucune mesure d'audience. Les questions sont dans l'application : jouer ne demande aucune connexion. Seule la partie au loin passe par un relais, qui n'apprend rien de vous et ne garde pas la partie.

DIX-SEPT PACKS, EN OPTION

Seize packs scolaires — Histoire, Géographie, Français et SVT, pour les quatre années du collège — et « Rock 70-80 ». Achetés une fois, gardés pour toujours. Le jeu est entier sans eux, et celui qui rejoint une partie joue les packs de l'hôte.

iPhone, iPad et Mac — une seule application, en français et en anglais.
```

### Anglais — 3921 caractères sur 4 000

```
Riskelo is a turn-based conquest game where the roll of the dice is replaced by a trivia question.

The attacker picks the subject and how many questions — those are the dice. The defender answers against the clock. A right answer and it is the attacker who loses a man; a wrong answer, or time running out, and it is the defender. One question is worth exactly one roll: it costs a man to one side or the other.

THREE WAYS TO FIGHT

• Classic — the attacker asks and picks the ground; the defender answers alone. What you know is your armor.
• Showdown — both players get the same question. Both know it? The clock settles it. Neither? The territory holds, the way a tied roll holds it. And the defender can double the stake before answering.
• Dice — just like the box: up to three dice against two, ties to the defender.

THE PRESSURE OF A SIEGE

Without chance, a player who knows would never lose a place. What replaces the dice is time: fifteen seconds on the first question, and the clock tightens with every question the same territory takes in the same turn. Pressing a place eventually pays — but it is the defender's breath that gives out, not their luck.

FOUR BOARDS

• The Ring — an invented world, five lands in a circle, 28 territories.
• Europe — from the Atlantic to the Black Sea, 38 territories.
• World — six continents in hexagons, 42 territories.
• Real World — the same 42 territories on the real coastlines, twenty sea crossings.

TWO TO FOUR PLAYERS

• Alone against the machine, whose knowledge sets anywhere from 35% to 90% correct answers and whose play has three levels — knowing and playing well are two different things.
• Around one device, passed from hand to hand.
• On several devices, one per player: in the same room, with nothing to set up — or far away, each of you at home, with a six-letter code sent by message. No account either way.

THE RULES FROM THE BOX, OPTIONAL

• Territory cards, with the trade-in climbing at every exchange.
• Total war: every territory, no exception.
• Personal conquests: each player is dealt an objective only they can see — two continents, so many places held, one side to bring down. Filling it wins outright, and the territory count no longer tells you who is winning.
• Scholar's reinforcement: one extra man for every few right answers in the same subject.

2,400 QUESTIONS IN THE GAME

Six subjects — Geography, History, Science & Nature, Arts & Literature, Sports & Games, Screen & Music — four hundred questions each, at three levels of difficulty. The mix is set before the game: easy for playing with children, mixed the way a boxed game would be, tough for anyone who finds the rest too easy. And a question does not come back: the device remembers what has already been asked, and puts the ones you have never seen in front.

THE GAME KEEPS

You find it where you left it. And the library records every turn without being asked: you can go back to the moment it all turned and play the rest again, without erasing the original.

A game played far away can span several evenings: the code stays good for a week, and the game starts again on the turn you had reached. You can have several at once — one with your sister, one with a friend — and none of them erases the others. You do have to be there at the same time: a question is answered against the clock.

WHAT RISKELO DOES NOT DO

No ads. No subscription. No account. No tracker, no analytics. The questions are in the app: playing needs no connection at all. Only a game played far away goes through a relay, which learns nothing about you and does not keep the game.

SEVENTEEN PACKS, IF YOU WANT THEM

Sixteen school decks — History, Geography, English and Science, for grades 6 through 9 — and Rock 70-80. Bought once, kept for good. The base game is whole without them, and whoever joins a table plays the host's packs.

iPhone, iPad and Mac — one app, in English and French.
```

---

## Le reste du dossier

Ces fichiers servent à une **première** soumission, ou quand une question de
la fiche change. Pour une mise à jour comme la 2.0, cette page suffit.

| Fichier | Ce qu'il contient |
|---|---|
| [FICHE-DE-SOUMISSION.md](FICHE-DE-SOUMISSION.md) | Tout, dans l'ordre où App Store Connect le demande. Pour la description et la note de version, sa section 4 renvoie ici. |
| [metadonnees.md](metadonnees.md) | Nom, sous-titre, mots-clés, description, catégories, URL |
| [LOCALISATION-EN.md](LOCALISATION-EN.md) | La fiche anglaise : adresses, sous-titre, mots-clés, texte promotionnel |
| [confidentialite-app-store.md](confidentialite-app-store.md) | Les réponses au questionnaire « Confidentialité des données » |
| [captures-decran.md](captures-decran.md) | Les tailles exigées, les écrans à photographier, la marche à suivre |
| [packs-app-store.md](packs-app-store.md) | Les trente-quatre achats intégrés — dix-sept par langue |
| [notes-pour-la-revue.md](notes-pour-la-revue.md) | Ce qu'il faut dire au relecteur d'Apple pour qu'il ne bloque pas |

Les adresses publiques qu'Apple demande sont servies par GitHub Pages, depuis
le dossier `docs/` de ce dépôt :

- Assistance — <https://boboul-cloud.github.io/riskelo/assistance.html>
- Confidentialité — <https://boboul-cloud.github.io/riskelo/confidentialite.html>
- Marketing — <https://boboul-cloud.github.io/riskelo/>

Et leurs versions anglaises, pour la fiche anglaise :

- Support — <https://boboul-cloud.github.io/riskelo/en/support.html>
- Privacy — <https://boboul-cloud.github.io/riskelo/en/privacy.html>
- Marketing — <https://boboul-cloud.github.io/riskelo/en/>

### Le Mac

Riskelo tourne sur Mac, mais n'est pas sur le Mac App Store : aucune version
macOS n'a été créée dans App Store Connect. Le bac à sable qu'il exige est
posé et la liaison Mac ↔ iPhone a été rejouée avec lui — le jour où le Mac
partira, la marche à suivre est à la section 9 de
[FICHE-DE-SOUMISSION.md](FICHE-DE-SOUMISSION.md).
