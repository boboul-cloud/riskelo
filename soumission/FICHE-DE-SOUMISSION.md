# Fiche de soumission — Riskelo 1.0

Tout ce que demande App Store Connect, dans l'ordre où il le demande. Chaque
bloc encadré se colle tel quel. Ce qui reste à décider est marqué **à décider**.

---

## En clair : ce qu'il vous reste à faire

Ce document est une **liste de cases à recopier** dans le site d'Apple. Il n'y
a plus rien à programmer : le jeu est fini, le site est en ligne, les textes
sont écrits. Dans l'ordre :

1. **S'inscrire chez Apple** — 99 $ par an, sur `developer.apple.com`. Rien ne
   part sans cela, et la signature du contrat prend parfois un jour.
2. **Créer la fiche du jeu** sur `appstoreconnect.apple.com`. C'est le moment
   où le nom « Riskelo » est réservé à vous. Les valeurs à saisir sont en
   section 1, les adresses du site en section 2.
3. **Photographier cinq écrans du jeu** — la liste des cinq et la commande qui
   les prend à la bonne taille sont en section 7.
4. **Envoyer l'application** depuis votre Mac — deux commandes et un bouton,
   en section 8.
5. **Recopier les textes** de la section 4 dans les cases du site, répondre
   aux questionnaires avec la section 5, coller les notes de la section 6.
6. **Cliquer « Soumettre »**, et attendre un à deux jours.

Le reste du document est le détail de ces six étapes. Si une phrase vous
arrête, elle appartient sans doute à une étape que vous n'avez pas encore
atteinte — laissez-la.

Deux choses seulement demandent une décision de votre part, et elles sont
rassemblées en section 11 : **le prix**, et **si le Mac part en même temps que
l'iPhone**.

---

## 1. Les identifiants

| Champ | Valeur |
|---|---|
| Nom de l'app | `Riskelo` |
| Identifiant du bundle | `com.oulhen.riskelo` |
| Équipe de développement | `38DQ8FW23J` |
| SKU (interne, invisible du public, jamais réutilisable) | `riskelo-2026` |
| Identifiant Apple de l'app | attribué par App Store Connect à la création |
| Langue principale | Français (France) |
| Version | `1.0` |
| Build | `1` |
| Plateformes | iOS et macOS (une seule cible, deux plateformes dans la fiche) |
| Version minimale | iOS 17.0 · macOS 14.0 |
| Appareils | iPhone et iPad (`TARGETED_DEVICE_FAMILY = 1,2`) et Mac |
| Orientations | portrait et paysage ; portrait inversé en plus sur iPad |
| Catégorie principale | Jeux ▸ **Stratégie** |
| Catégorie secondaire | Jeux ▸ **Culture générale** |
| Classification par âge | **4+** |
| Game Center | non |
| Achats intégrés | aucun |
| Prix | **à décider** — gratuit, ou payant sans achat intégré |
| Territoires | tous |
| Publication | **à décider** — automatique à l'approbation, ou manuelle |

## 2. Les adresses

| Champ App Store Connect | Adresse |
|---|---|
| URL marketing | `https://boboul-cloud.github.io/riskelo/` |
| **URL d'assistance** (obligatoire) | `https://boboul-cloud.github.io/riskelo/assistance.html` |
| **URL de la politique de confidentialité** (obligatoire) | `https://boboul-cloud.github.io/riskelo/confidentialite.html` |
| CLUF personnalisé (facultatif) | `https://boboul-cloud.github.io/riskelo/conditions.html` |
| Dépôt du code et du site | `https://github.com/boboul-cloud/riskelo` |

Les trois premières sont publiques et vérifiées. Si l'une répond autre chose
que 200, la soumission est refusée sans autre examen :

```bash
for p in "" assistance.html confidentialite.html conditions.html; do
  curl -s -o /dev/null -w "$p %{http_code}\n" https://boboul-cloud.github.io/riskelo/$p
done
```

## 3. Les coordonnées pour la revue

| Champ | Valeur |
|---|---|
| Prénom | Robert |
| Nom | Oulhen |
| Téléphone | **à décider** — Apple l'exige, il n'est pas rendu public |
| Adresse électronique | `bob.oulhen@gmail.com` |
| Identifiant de connexion de démonstration | *aucun — l'app n'a pas de compte* |
| Mot de passe de démonstration | *aucun* |
| Compte requis pour utiliser l'app | **Non** |

---

## 4. Les textes à coller

### Nom de l'app — 30 caractères max

```
Riskelo
```

### Sous-titre — 30 caractères max

```
La conquête sans dés
```

Variantes : `Conquête et culture générale` (28) · `Conquérir, en répondant juste` (29)

### Mots-clés — 100 caractères max, virgules sans espace après

```
conquête,stratégie,quiz,culture générale,plateau,territoires,duel,solo,famille,hors ligne
```

89 caractères. Le nom et le sous-titre sont déjà indexés : ne pas y répéter
« Riskelo » ni « conquête ». **Aucune marque de jeu de société** — c'est un
motif de rejet immédiat, et la ressemblance de genre ne donne aucun droit sur
le nom d'autrui.

### Texte promotionnel — 170 caractères max, modifiable sans nouvelle version

```
Mille deux cents questions, trois plateaux, deux modes de duel. Aucune publicité, aucun compte, aucune connexion : tout le jeu est dans l'application.
```

### Description — 4 000 caractères max

```
Riskelo est un jeu de conquête au tour par tour où le lancer de dés est remplacé par une question de culture générale.

L'attaquant choisit le thème et le nombre de questions — ce sont ses dés. Le défenseur répond, dans le temps du sablier. Bonne réponse, et c'est l'attaquant qui laisse un homme ; mauvaise réponse ou temps écoulé, et c'est le défenseur. Une question vaut exactement une paire de dés : elle coûte un homme à l'un des deux camps.

DEUX MANIÈRES DE SE BATTRE

• Classique — l'attaquant pose la question et choisit le terrain ; le défenseur seul répond. La culture est une armure.
• Face à face — les deux joueurs reçoivent la même question. Les deux savent ? Le sablier tranche. Aucun des deux ? La place tient, comme sur une égalité de dés. Et le défenseur peut doubler l'enjeu avant de répondre.

L'USURE DU SIÈGE

Sans hasard, un joueur qui sait ne perdrait jamais sa place. Ce qui remplace la statistique du dé, c'est le temps : quinze secondes à la première question, et le sablier se resserre à chaque question subie par un même territoire dans le même tour. Presser une place finit par payer — mais c'est le souffle du défenseur qui cède, pas le sort.

TROIS PLATEAUX

• L'Anneau — un monde inventé, cinq terres en cercle, 28 territoires. Le plus court.
• Europe — de l'Atlantique à la mer Noire, 38 territoires.
• Monde — les six continents, 42 territoires.

DE DEUX À QUATRE JOUEURS

• Seul contre la machine, dont la culture se règle de 35 à 90 % de bonnes réponses et la manœuvre en trois niveaux — savoir et bien jouer sont deux choses différentes.
• À plusieurs sur un même appareil, qui se passe de main en main.
• À plusieurs appareils, un par joueur : sans compte, sans configuration, sans serveur. Le Bluetooth et le Wi-Fi direct suffisent, et cela fonctionne dans un train.

LES RÈGLES DE LA BOÎTE, EN OPTION

• Cartes de territoire, avec le barème qui monte à chaque échange.
• Guerre totale : tous les territoires, sans exception — une partie de soirée entière.
• Renfort d'érudition : un homme de plus toutes les N bonnes réponses dans un même thème.

MILLE DEUX CENTS QUESTIONS

Six thèmes — Géographie, Histoire, Sciences & Nature, Arts & Lettres, Sports & Loisirs, Écrans & Musique — deux cents questions chacun, trois niveaux de difficulté. Le dosage se choisit à la mise en place : faciles pour jouer avec des enfants, mêlées comme dans une boîte de jeu, corsées pour ceux qui trouvent le reste trop facile. Le tirage ne sort jamais du thème demandé : quand vous choisissez le terrain, il est tenu.

LA PARTIE SE GARDE

Elle se retrouve où vous l'avez laissée. Et la bibliothèque enregistre chaque tour sans qu'on le demande : on peut revenir au moment où tout a basculé et rejouer la suite, sans effacer la partie d'origine.

CE QUE RISKELO NE FAIT PAS

Aucune publicité. Aucun achat intégré. Aucun compte. Aucun traceur, aucune mesure d'audience. Aucune connexion à Internet n'est nécessaire : les mille deux cents questions sont dans l'application, et vos parties ne quittent jamais votre appareil.

iPhone, iPad et Mac — une seule application, en français.
```

### Nouveautés de cette version — 4 000 caractères max

```
Première version de Riskelo.
```

### Droits d'auteur

```
2026 Robert Oulhen
```

---

## 5. Les questionnaires

### Confidentialité de l'app

> **Collectez-vous des données depuis cette app ?** → **Non, nous ne collectons
> aucune donnée de cette app.**

Vérifiable : aucune dépendance externe, aucune requête vers un serveur, aucun
identifiant publicitaire. Les fichiers de partie restent dans le conteneur de
l'app et disparaissent avec elle. Des données écrites localement et jamais
envoyées ne comptent pas comme collectées.

### Les réponses annexes

| Question | Réponse |
|---|---|
| Utilisez-vous l'identifiant publicitaire (IDFA) ? | Non |
| Suivi (App Tracking Transparency) ? | Non |
| Achats intégrés ? | Non |
| Publicité dans l'app ? | Non |
| Contenu de tiers soumis à droits ? | Non — code, questions, plateaux et icône sont l'œuvre de l'éditeur |
| Chiffrement / conformité export | `ITSAppUsesNonExemptEncryption = false`, déjà dans l'Info.plist : plus rien à répondre à chaque envoi |
| Connexion à un compte | Aucune |

### Classification par âge

Répondre **Aucun / Jamais** à toutes les questions : pas de violence figurée
(le jeu est fait d'hexagones et de nombres), pas de contenu sexuel, pas de jeu
d'argent, pas d'alcool ni de tabac, pas de contenu généré par les
utilisateurs, pas d'accès web libre. Résultat attendu : **4+**.

### La seule autorisation demandée

| Autorisation | Quand | Texte affiché |
|---|---|---|
| Réseau local | À la première ouverture de « Jouer à plusieurs appareils » | « Riskelo s'en sert pour trouver l'autre appareil et jouer la partie à deux. » |

Refusée, l'app reste entièrement jouable : seul le jeu à plusieurs appareils
est indisponible. Aucune autre autorisation — ni position, ni photos, ni
contacts, ni micro, ni notifications.

### Le point que personne ne déclare, et qu'il vaut mieux avoir écrit

Le nom de l'appareil (« iPhone de Camille ») est visible des appareils proches
pendant la recherche d'une table : `MultipeerConnectivity` s'en sert comme
étiquette. Ce n'est pas une collecte — rien n'est enregistré ni transmis à
l'éditeur — et c'est dit explicitement à la section 4 de la politique de
confidentialité. Si un relecteur pose la question, la réponse y est déjà.

---

## 6. Notes pour la revue (App Review Information)

```
Bonjour,

Riskelo est un jeu de conquête au tour par tour : l'issue de chaque combat est
décidée par une question de culture générale à choix multiple, au lieu d'un
lancer de dés.

AUCUN COMPTE N'EST NÉCESSAIRE
L'application n'a ni inscription, ni connexion, ni achat intégré, ni publicité.
Tout le contenu est accessible dès le lancement. Il n'y a donc pas
d'identifiants de démonstration à fournir.

POUR ESSAYER EN UNE MINUTE
1. Touchez « Commencer » (les réglages par défaut conviennent).
2. Touchez vos territoires pour poser vos renforts, puis « À l'attaque ».
3. Touchez un de vos territoires d'au moins deux hommes, puis un voisin ennemi.
4. Choisissez un thème et « Lancer l'assaut » : une question apparaît.

Le mode d'emploi complet est dans l'application : bouton « Mode d'emploi » sur
l'écran d'accueil, ou le point d'interrogation de la barre du haut pendant une
partie.

FONCTION QUI DEMANDE DEUX APPAREILS
« Jouer à plusieurs appareils » utilise MultipeerConnectivity (Bluetooth /
Wi-Fi direct) pour relier de deux à quatre appareils proches. Aucun serveur
n'est utilisé et aucune donnée n'est conservée : seuls les coups de la partie
circulent, directement d'un appareil à l'autre.

Cette fonction demande donc deux appareils physiques dans la même pièce, avec
le Wi-Fi allumé des deux côtés, et l'autorisation « réseau local » accordée.
Elle est facultative : refuser cette autorisation laisse le reste du jeu
entièrement fonctionnel (solo contre l'ordinateur, ou à plusieurs joueurs sur
un même appareil).

AUTORISATIONS
Une seule, facultative : le réseau local, pour la fonction ci-dessus. Aucune
autre — ni position, ni photos, ni contacts, ni micro, ni notifications.

CONFIDENTIALITÉ
Aucune donnée n'est collectée ni transmise. L'application n'intègre aucun kit
tiers et n'effectue aucune requête vers un serveur. Elle fonctionne
entièrement hors ligne : les 1 200 questions sont incluses dans le bundle.

CONTENU
Les questions, les plateaux, les dessins et l'icône sont des créations
originales. Riskelo est un jeu indépendant, inspiré du genre des jeux de
conquête territoriale ; il n'utilise aucune marque, aucun visuel et aucun texte
appartenant à un éditeur de jeu de société.

LANGUE
L'application est en français, y compris les questions. C'est sa seule langue.

Merci de votre lecture,
Robert Oulhen — bob.oulhen@gmail.com
```

---

## 7. Les captures d'écran

| Plateforme | Taille exigée | Résolution (portrait) | Appareil |
|---|---|---|---|
| iPhone | 6,9 pouces | 1290 × 2796 ou 1320 × 2868 | iPhone 17 Pro Max |
| iPad | 13 pouces | 2064 × 2752 | iPad Pro 13" (M4) |
| Mac | — | 2880 × 1800 (16:10) | fenêtre de l'app |

Une capture d'iPhone 6,9" suffit pour toutes les autres tailles d'iPhone.
Minimum une par taille, maximum dix ; trois à cinq bien choisies valent mieux
que dix répétitives.

**Les cinq écrans, dans cet ordre** — le premier est celui qu'on voit dans les
résultats de recherche :

1. **Un duel en cours** — la question par-dessus le plateau, le sablier entamé.
2. **Le panneau d'assaut** — les six thèmes, les scores du défenseur, la
   lunette sur son point faible.
3. **Le plateau du Monde** en milieu de partie — deux ou trois camps
   enchevêtrés, un continent tenu.
4. **La feuille du verdict en face à face** — les deux réponses, leurs temps,
   la couronne.
5. **L'écran de mise en place** — tout ce qui se règle, d'un coup d'œil.

```bash
xcrun simctl boot "iPhone 17 Pro Max" && open -a Simulator
# jouer jusqu'à l'écran voulu, puis :
xcrun simctl io booted screenshot ~/Desktop/riskelo-01-duel.png

# sur le Mac, sans l'ombre portée qu'Apple refuse :
screencapture -o -w ~/Desktop/riskelo-mac-01.png
```

Ce qui fait rejeter une capture : une maquette d'appareil dessinée autour de
l'écran, un montage qui ne vient pas de l'app, des barres d'état incohérentes
d'une capture à l'autre (le simulateur affiche 9:41 partout), du texte
promotionnel qui recouvre l'interface.

L'icône de l'App Store est déjà au catalogue en 1024 × 1024 sans canal alpha,
et se refait d'une commande :

```bash
swiftc -O -parse-as-library -o /tmp/icone outils/icone.swift && /tmp/icone
```

---

## 8. Fabriquer et envoyer

```bash
xcodegen generate
xcodebuild -scheme Riskelo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
xcodebuild -scheme Riskelo -destination 'generic/platform=iOS' \
           -archivePath ~/Desktop/Riskelo-ios.xcarchive archive
```

Puis Xcode ▸ Window ▸ Organizer ▸ l'archive ▸ **Distribute App** ▸ *App Store
Connect* ▸ *Upload*. La build apparaît dans App Store Connect au bout de
quelques minutes, le temps du traitement.

Le numéro de build doit **monter à chaque envoi** : un même `1` ne se dépose
pas deux fois. Il se change dans `project.yml`
(`CURRENT_PROJECT_VERSION`), jamais dans Xcode — `xcodegen generate` réécrit
le projet.

---

## 9. Le Mac App Store — c'est posé, il reste à l'essayer

L'application est une cible unique pour iPhone, iPad et Mac ; dans App Store
Connect, cela fait **deux plateformes sous le même enregistrement**, chacune
avec ses captures et son envoi. Les textes peuvent être identiques.

### Ce qui a été fait

Le Mac App Store impose le **bac à sable** : l'application y est enfermée dans
son propre dossier et ne voit rien du reste du Mac. C'est obligatoire, sans
exception — et le projet n'avait pas ce réglage. Il l'a maintenant, dans
`Resources/Riskelo-mac.entitlements`, avec trois clés :

| Clé | Ce qu'elle dit |
|---|---|
| `com.apple.security.app-sandbox` | Enferme l'application. Exigé par le Mac App Store. |
| `com.apple.security.network.client` | La laisse sortir chercher l'autre appareil. |
| `com.apple.security.network.server` | La laisse se faire trouver par lui. |

Les deux dernières comptent autant que la première : **le bac à sable coupe le
réseau avec le reste**, et sans elles le Mac et l'iPhone cesseraient de se voir
sans que rien à l'écran ne dise pourquoi.

Le réglage ne s'applique qu'au Mac — `project.yml` le pose sous
`CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`. Vérifié : la version Mac embarque bien
les trois clés, la version iPhone n'en reçoit aucune, et les deux se
construisent.

### Essayé, et la liaison tient

**28 août 2026 — vérifié sur un vrai Mac et un vrai iPhone : la partie à deux
appareils fonctionne avec le bac à sable actif.** C'était le seul point du
dossier qu'aucune commande ne pouvait établir, et il est levé : la version Mac
peut partir en même temps que celle de l'iPhone.

La marche à suivre reste écrite ici — elle servira à chaque version, parce
qu'une autorisation retirée par inadvertance ne se voit qu'à l'essai :

1. Wi-Fi allumé des deux côtés, les deux machines dans la même pièce.
2. Sur le Mac : ouvrir le projet et lancer le jeu (`⌘R`).
3. Sur l'iPhone : le brancher, le choisir comme destination, lancer (`⌘R`).
4. Sur l'une des deux : **Jouer à plusieurs appareils** ▸ *Ouvrir la table*.
5. Sur l'autre : **Jouer à plusieurs appareils** ▸ *Rejoindre une table*, puis
   toucher le nom qui apparaît.
6. Si le Mac demande l'autorisation d'utiliser le réseau local, **accepter**.
7. Si rien ne vient au bout d'une minute : **inverser les rôles** — que celui
   qui cherchait ouvre la table. C'est le remède habituel, et il ne veut pas
   dire que le bac à sable est en cause.

**Ce qu'on cherche à savoir :** le Mac voit-il encore l'iPhone, et l'iPhone
voit-il encore le Mac ? Au 28 août 2026, oui.

**Rien n'oblige pour autant à soumettre les deux le même jour.** L'iPhone peut
partir seul, et le Mac s'ajouter plus tard sous le même enregistrement — c'est
une question de calendrier, plus d'un obstacle technique.

---

## 10. L'ordre des opérations

- [ ] Adhésion **Apple Developer Program** active (99 $/an)
- [ ] Contrat **Applications gratuites** signé dans App Store Connect ▸
      Contrats, taxes et opérations bancaires — un contrat non signé bloque la
      publication sans rien expliquer
- [ ] Si l'app est payante : contrat payant, coordonnées bancaires et fiscales
- [ ] Identifiant d'app `com.oulhen.riskelo` enregistré sur le portail
- [ ] Enregistrement créé dans App Store Connect (le nom « Riskelo » est
      réservé à ce moment-là)
- [ ] Tests verts, une partie jouée sur chaque machine, une partie à deux
      appareils dans les deux sens
- [ ] Archive envoyée, build traitée et visible dans la fiche
- [ ] Essai TestFlight sur un appareil réel
- [ ] Textes de la section 4 collés
- [ ] Captures déposées (iPhone 6,9" et iPad 13" au minimum)
- [ ] Questionnaires de la section 5 remplis
- [ ] Notes de la section 6 collées
- [ ] Prix et disponibilité choisis
- [ ] Soumis à la revue

Compter de deux à quarante-huit heures. Répondre vite à toute question du
relecteur : un fil qui traîne repart en bas de la file.

---

## 11. Ce qui reste à décider

| Point | Pourquoi c'est à vous |
|---|---|
| Le prix | Gratuit fait des joueurs, payant fait un revenu. Le jeu n'a ni publicité ni achat intégré : c'est l'un ou l'autre. |
| Le numéro de téléphone de la revue | Apple l'exige ; il n'est jamais rendu public. |
| Publication automatique ou manuelle | Manuelle si vous voulez choisir le jour. |
| macOS maintenant ou plus tard | Plus aucun obstacle : le bac à sable est posé et la liaison Mac ↔ iPhone est vérifiée avec. Pure question de calendrier. |
| Le sous-titre | Trois propositions en section 4 ; c'est le seul texte qui se lit avant la description. |
