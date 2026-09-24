# Soumission à l'App Store — Riskelo 1.5 (build 9)

> **Ce qui est chez Apple**, relu en lecture seule le 24 septembre 2026 : la
> **1.4 (build 8) est en vente**, sur iPhone et iPad. Les **34 packs sont
> approuvés**. Il n'y a pas de version Mac sur l'App Store.

## En clair : la mise à jour 1.5

L'application, ses packs, ses questionnaires et ses captures sont déjà chez
Apple, et ils y restent. Tout se remplit à la main : la fenêtre d'AgentDouble
ne propose que les apps pas encore en vente. Chaque texte est plus bas, avec
son nombre de caractères, prêt à copier.

1. ~~Envoyer le build 9~~ — **fait**.
2. **Créer la version 1.5** : le « + » à côté de « App iOS », puis « 1.5 ».
   Dans la section « Build » de la nouvelle page, choisir le **build 9**.
3. **Sur la page de la version 1.5, en français** — le menu de langue est en
   haut à droite de la page. Remplacer quatre cases :
   - **Texte promotionnel** ;
   - **Description** — le texte en entier, à la place de l'ancien ;
   - **Mots-clés** ;
   - **Nouveautés de cette version** — la note de version.
4. **Même page, en anglais** : les mêmes quatre cases, avec les textes
   anglais, et en plus deux adresses, qui pointaient vers les pages
   françaises :
   - **URL d'assistance** : `https://boboul-cloud.github.io/riskelo/en/support.html`
   - **URL marketing** : `https://boboul-cloud.github.io/riskelo/en/`
5. **Plus bas sur la même page, « Informations sur la vérification de
   l'app » ▸ Notes** : les notes de la 1.4 y sont reprises d'office. Une
   seule phrase est devenue fausse ; la remplacer (elle est juste en
   dessous).
6. **« Informations sur l'app »**, dans le menu de gauche : le
   **Sous-titre**, en français puis en anglais.
7. **« Confidentialité de l'app »**, dans le menu de gauche :
   - passer la réponse à **« Oui »**, avec les quatre réponses du tableau
     plus bas ;
   - en anglais, l'adresse de la **politique de confidentialité** :
     `https://boboul-cloud.github.io/riskelo/en/privacy.html`
8. **Relire la page de la version 1.5**, dans les deux langues, puis
   **soumettre à la revue**.

### La phrase à remplacer dans les notes pour la revue

Dans le paragraphe « 2. AU LOIN, AVEC UN CODE », remplacer :

```
Il connaît un identifiant tiré au sort à l'installation, le garde deux minutes après la partie pour permettre d'en reprendre une coupée, puis l'efface.
```

par :

```
Il connaît un identifiant tiré au sort à l'installation, le garde une semaine après la dernière séance pour qu'une partie se reprenne un autre soir, puis l'efface.
```

Ce qui change par rapport à la 1.4, en plus des textes :

- **La fiche anglaise renvoie enfin vers les pages anglaises du site**
  (assistance, confidentialité, site). Elle renvoyait vers les pages
  françaises.
- **La déclaration de confidentialité** passe de « Aucune donnée collectée »
  à « Oui : un identifiant d'appareil ». Depuis la 1.4, le relais du jeu au
  loin garde une semaine, au lieu de deux minutes, le numéro tiré au sort de
  chaque appareil, pour qu'une partie se reprenne un autre soir. Apple
  compte cela comme une donnée collectée. La politique de confidentialité du
  site le dit, et la note de version l'annonce, comme la politique le
  promet.
- Les packs, déjà approuvés, n'ont pas à être joints de nouveau, et la
  classification par âge ne change pas.

### Confidentialité de l'app — les réponses

| Écran d'App Store Connect | Réponse |
|---|---|
| Collectez-vous des données depuis cette app ? | **Oui** |
| Types de données | **Identifiants ▸ Identifiant de l'appareil** — rien d'autre |
| À quoi sert-elle ? | **Fonctionnalité de l'app** — rien d'autre |
| Est-elle liée à l'identité de l'utilisateur ? | **Non** |
| Sert-elle au suivi ? | **Non** |

### Les adresses de la fiche anglaise

| Champ | Adresse |
|---|---|
| URL d'assistance | `https://boboul-cloud.github.io/riskelo/en/support.html` |
| URL marketing | `https://boboul-cloud.github.io/riskelo/en/` |
| Politique de confidentialité | `https://boboul-cloud.github.io/riskelo/en/privacy.html` |

La fiche française garde les siennes.

---

## Le sous-titre, le texte promotionnel et les mots-clés

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
générale » sont maintenant dans le sous-titre, qu'Apple indexe déjà : ils
laissent leur place à « dés », « géographie », « histoire » et « questions ».

```
stratégie,quiz,dés,plateau,territoires,duel,solo,famille,hors ligne,géographie,histoire,questions
```

Mots-clés anglais — 97 caractères sur 100. « trivia » passe dans le
sous-titre, « dice » entre.

```
quiz,strategy,board,territory,turn-based,offline,online,multiplayer,family,geography,history,dice
```

---

## La note de version — français

1545 caractères sur 4 000.

```
LE MONDE RÉEL
• Un quatrième plateau : le monde tel qu'il est, dessiné d'après les vraies côtes. Les quarante-deux territoires et les six continents du Monde, mais vingt traversées par la mer au lieu de trois — le Kamtchatka retrouve sa distance, et l'on n'y joue plus pareil.
• Le Monde en hexagones reste : ce sont deux parties différentes, et l'on choisit à la mise en place.
• La carte se promène et se rapproche sous le doigt. Les noms paraissent à mesure qu'on rapproche, sans jamais se chevaucher ; le nombre d'hommes, lui, se lit toujours.

LES DÉS, COMME DANS LA BOÎTE
• Pour ceux qui préfèrent le jeu de plateau : un troisième mode, sans question. L'assaillant lance jusqu'à trois dés, le défenseur un ou deux, à son choix ; les plus forts se comparent paire par paire, et l'égalité va au défenseur. Un même lancer peut coûter un homme à chacun.
• Deux dés font plus mal à l'assaillant, mais peuvent coûter deux hommes d'un coup ; un seul n'en coûte jamais plus d'un. Le choix se fait à chaque assaut, contre un ami comme contre la machine.
• Il se choisit à la mise en place, à côté du Classique et du Face à face, et se joue aussi à plusieurs appareils : les deux écrans voient tomber les mêmes dés.

LA CONFIDENTIALITÉ, DITE EXACTEMENT
• Pour qu'une partie au loin se reprenne un autre soir, le relais garde une semaine un numéro tiré au sort à l'installation. Il ne désigne personne, et aucun nom ne lui parvient. La fiche de l'App Store et la politique de confidentialité le disent désormais.

iPhone, iPad et Mac, comme toujours.
```

## La note de version — anglais

1334 caractères sur 4 000.

```
THE REAL WORLD
• A fourth board: the world as it is, drawn from the real coastlines. The World's forty-two territories and six continents, but twenty sea crossings instead of three — Kamchatka is far away again, and it no longer plays the same.
• The hexagon World stays: they are two different games, and you choose when you set up.
• Drag and pinch the map. Names appear as you zoom in and never overlap; the number of men in each territory always shows.

DICE, JUST LIKE THE BOX
• For those who prefer the board game: a third mode, with no questions. The attacker rolls up to three dice, the defender one or two, as they choose; the highest are compared pair by pair, and ties go to the defender. A single roll can cost each side a man.
• Two dice hurt the attacker more, but can cost two men at once; one never costs more than one. The choice comes with every assault, against a friend or against the machine.
• Choose it when you set up, alongside Classic and Showdown. It plays across devices too: both screens see the same dice fall.

PRIVACY, STATED EXACTLY
• So that a game far away can pick up again another evening, the relay keeps a number drawn at random at installation for a week. It designates nobody, and no name ever reaches it. The App Store page and the privacy policy now say so.

iPhone, iPad and Mac, as always.
```

Ce que dit la note, et rien d'autre : ce qui a changé depuis la 1.4. Les
noms des modes et des plateaux sont ceux que l'application affiche dans
chaque langue — « Face à face » est « Showdown » en anglais.

---

## La description à jour

Quatre retouches à la description de la 1.4, rien d'autre :

- « Deux manières de se battre » devient **trois**, avec une ligne pour les
  **Dés** ;
- « Trois plateaux » devient **quatre**, avec une ligne pour le **Monde
  réel** — et le Monde est dit « en hexagones », pour qu'on les distingue ;
- pour tenir sous les 4 000 caractères, deux phrases se resserrent : le
  paragraphe sur la partie au loin (la note de la 1.4 l'a déjà dit en
  détail) et celle sur les questions qui ne reviennent pas.

Chaque texte se colle **en entier**, à la place de l'ancien.

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

La version anglaise tenait sans rien couper : seules les deux lignes neuves
et les deux titres changent.

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

## Avant d'envoyer

- [x] Les essais automatiques : 233, tous verts sur le simulateur iPhone, le
      24 septembre 2026 — après le choix du défenseur aux dés, et le plateau
      qui attend la fin des dés pour montrer la prise
- [ ] Une partie sur le **Monde réel** et une **aux dés**, sur un vrai iPhone —
      en se faisant attaquer, pour voir le choix « un dé ou deux »
- [ ] Une partie **aux dés à deux appareils** : la note annonce que les deux
      écrans voient tomber les mêmes dés, et le choix du défenseur voyage d'un
      téléphone à l'autre. Des essais automatiques le vérifient, mais personne
      ne l'a encore joué sur deux vrais téléphones.
- [x] Build 9 envoyé
- [ ] Version 1.5 créée dans App Store Connect
- [ ] Textes collés, en français puis en anglais : texte promotionnel,
      description, mots-clés, note de version — et les deux adresses anglaises
- [ ] La phrase des notes pour la revue remplacée
- [ ] Sous-titre remplacé, dans les deux langues
- [ ] « Confidentialité de l'app » passée à « Oui »
- [ ] Page de la version 1.5 relue, en français et en anglais — le build 9
      y est bien choisi
- [ ] Soumis à la revue

## À côté de la mise à jour

- [x] La **page d'invitation** du jeu au loin — celle qu'on reçoit par
      message — mène maintenant à la vraie fiche de l'App Store,
      <https://apps.apple.com/app/riskelo/id6806804539>, au lieu d'une adresse
      d'exemple. Serveur redéployé le 24 septembre 2026 (version `3987b40d`),
      et son essai de bout en bout passe contre le serveur réel. Cela ne
      dépendait pas de la 1.5 et n'attend aucune revue d'Apple.

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
| **1.5 (build 9)** | build envoyé le 24 septembre | le Monde réel, les dés — et le défenseur qui choisit un dé ou deux |

Les notes de la 1.3 et de la 1.4 reprenaient à leur suite les sections des
versions d'avant. Celle de la 1.5 ne dit que ce qui est neuf ; pour garder
l'habitude, il suffit de coller sous elle la note de la 1.4, sans sa
dernière ligne « iPhone, iPad et Mac » — les deux tiennent ensemble sous les
4 000 caractères, dans chaque langue.

Le build monte à chaque envoi, et App Store Connect refuse deux fois le même
numéro : le prochain après le 9 sera le 10.

## Le reste du dossier

Ces fichiers servent à une **première** soumission, ou quand une question de
la fiche change. Pour une mise à jour comme la 1.5, cette page suffit.

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
