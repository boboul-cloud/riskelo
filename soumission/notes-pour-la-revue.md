# Notes pour la revue (App Review Information)

À coller dans le champ **Notes** de la fiche de version. Le relecteur d'Apple
les lit avant d'ouvrir l'app ; ce qui est expliqué ici ne devient pas un rejet.

---

```
Bonjour,

Riskelo est un jeu de conquête au tour par tour : l'issue de chaque combat est
décidée par une question de culture générale à choix multiple, au lieu d'un
lancer de dés.

AUCUN COMPTE N'EST NÉCESSAIRE
L'application n'a ni inscription, ni connexion, ni publicité. Il n'y a donc pas
d'identifiants de démonstration à fournir.

ACHATS INTÉGRÉS
Dix-sept packs de questions, non consommables, achetés une fois et gardés.
Seize packs scolaires de deux cents questions — Histoire, Géographie, Français
et SVT pour les quatre années du collège — et un pack musical de quatre cents
questions sur les années 1970 et 1980. Le jeu est entier sans eux : les six thèmes de culture générale et
leurs 2 400 questions sont accessibles dès le lancement, sans rien acheter.

Pour les voir : écran d'accueil, bouton « Packs de questions ». La page porte
aussi le bouton « Restaurer mes achats ».

Les fichiers de questions des packs sont inclus dans l'application pour tout le
monde ; ce qui s'achète est le droit de les choisir. C'est ce qui permet à un
joueur qui rejoint une partie de jouer les packs de celui qui l'héberge sans
les avoir achetés — c'est voulu, et non un défaut de contrôle.

POUR ESSAYER EN UNE MINUTE
1. Touchez « Partie rapide » sur l'écran d'accueil.
2. Touchez vos territoires pour poser vos renforts, puis « À l'attaque ».
3. Touchez un de vos territoires d'au moins deux hommes, puis un voisin ennemi.
4. Choisissez un thème et « Lancer l'assaut » : une question apparaît.

Le mode d'emploi complet est dans l'application : bouton « Mode d'emploi » sur
l'écran d'accueil, ou le point d'interrogation de la barre du haut pendant une
partie.

FONCTIONS QUI DEMANDENT DEUX APPAREILS
« Jouer à plusieurs » relie de deux à quatre appareils, un par joueur, et
propose trois chemins. Tous trois sont facultatifs : le jeu est entier sans
eux, seul contre l'ordinateur ou à plusieurs joueurs sur un même appareil.

1. DANS LA MÊME PIÈCE — framework Network d'Apple : Bonjour pour se trouver,
TCP pour se parler. Les appareils passent par le réseau Wi-Fi local, ou
directement de l'un à l'autre lorsqu'il n'y a pas de réseau. Aucun serveur.
Demande deux appareils physiques proches et l'autorisation « réseau local ».

2. AU LOIN, AVEC UN CODE — c'est le chemin le plus simple à essayer, et nous
le signalons parce qu'il lève la difficulté habituelle : les deux appareils
n'ont pas besoin d'être proches, ni sur le même réseau. Une connexion Internet
de chaque côté suffit, et un appareil physique avec un simulateur convient.

  a. Appareil A : accueil ▸ « Jouer à plusieurs » ▸ « Au loin, avec un code »
     ▸ « Ouvrir une partie ». Un code de six lettres s'affiche.
  b. Appareil B : le même chemin, puis « Rejoindre » et ces six lettres.
  c. Appareil A : « Commencer ».

Les coups transitent par un relais que nous hébergeons (Cloudflare Workers).
Ce relais recopie des paquets sans les lire : il ne tient pas la partie, ne
voit aucune question ni aucune réponse, et ne reçoit aucun nom de joueur — pas
même dans l'adresse de connexion. Il connaît un identifiant tiré au sort à
l'installation, qu'il garde deux minutes après la fin pour permettre de
reprendre une partie coupée, puis efface. Aucun journal n'est conservé.

3. PAR GAME CENTER — chemin facultatif, pour les joueurs qui y sont déjà.
Aucune donnée ne nous en revient : Riskelo n'y voit que le pseudonyme Game
Center des joueurs de la partie en cours, et ne le conserve pas.

AUTORISATIONS
Deux, toutes deux facultatives et demandées seulement si le joueur ouvre la
fonction concernée : le réseau local (chemin 1) et Game Center (chemin 3).
Aucune autre — ni position, ni photos, ni contacts, ni micro, ni
notifications.

CONFIDENTIALITÉ
Aucune donnée personnelle n'est collectée. L'application n'intègre aucun kit
tiers — ni régie publicitaire, ni outil d'analyse, ni service
d'authentification. Le jeu fonctionne hors ligne : les questions sont incluses
dans le paquet, et rien ne sort de l'appareil tant que le joueur n'ouvre pas
lui-même « Au loin » ou « Game Center ». Ce qui sort alors est décrit
ci-dessus, et n'est conservé nulle part au-delà de la partie. Les achats
intégrés passent par StoreKit et ne transmettent rien d'autre.

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

## Les trois rejets probables, et la parade

| Motif possible | Pourquoi il peut tomber | Ce qui est déjà en place |
|---|---|---|
| **Ressemblance avec une marque de jeu de société** (règle 5.2.5) | Le genre est proche d'un jeu connu | Aucune marque n'est employée : ni dans le nom, ni dans le sous-titre, ni dans les mots-clés, ni dans la description, ni dans l'app. Les conditions d'utilisation portent une clause d'indépendance explicite. |
| **Fonction non testable par le relecteur** (règle 2.1) | Le jeu à plusieurs demande deux appareils | Les notes l'expliquent, précisent que la fonction est facultative, et **donnent la marche à suivre en trois gestes pour le chemin « au loin »** — celui-ci ne demande ni proximité ni réseau commun, et un appareil avec un simulateur suffit. C'est le risque qui a le plus baissé depuis la 1.2. |
| **Service de tiers non déclaré** (règle 5.1.1) | Les coups du jeu au loin passent par un relais que nous hébergeons | Les notes le nomment, disent ce qu'il reçoit et ce qu'il garde ; la politique de confidentialité en ligne a une section entière dessus. |
| **Politique de confidentialité manquante ou creuse** (règle 5.1.1) | Une URL obligatoire, et souvent bâclée | Page complète et publique, qui décrit jusqu'au nom d'appareil visible en réseau local. |
