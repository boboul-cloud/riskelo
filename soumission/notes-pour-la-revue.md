# Notes pour la revue (App Review Information)

À coller dans le champ **Remarques** de « Informations utiles à la vérification
de l'app ». Le relecteur d'Apple les lit avant d'ouvrir l'app ; ce qui est
expliqué ici ne devient pas un rejet.

**La case accepte 4 000 signes.** Ce texte en fait un peu moins de 3 900 : il a
été resserré le 17 septembre 2026, la version longue n'entrait pas. Ce qui a
été coupé l'est parce que la fiche de confidentialité et la politique en ligne
le disent déjà — pas parce que ça ne comptait plus.

La case **« Connexion requise »**, juste au-dessus, **reste décochée** : le jeu
n'a ni compte ni mot de passe.

---

```
Bonjour,

Riskelo est un jeu de conquête au tour par tour : chaque combat se décide par
une question de culture générale, au lieu d'un lancer de dés.

AUCUN COMPTE N'EST NÉCESSAIRE
Ni inscription, ni connexion, ni publicité. Pas de compte de démonstration.

LANGUES — ET LA RÉPONSE À 4.3(a)
L'application porte le français et l'anglais dans un seul paquet : interface,
mode d'emploi et deux banques de 2 400 questions chacune, écrites dans leur
langue et non traduites. L'interface suit la langue de l'appareil ; la banque
de questions se choisit en plus par le bouton « Français / English » en haut de
la page des packs.

C'est la réponse à l'examen de « Riskelo US », refusée deux fois sous 4.3(a),
où Apple recommandait « consider consolidating these variants into a single
app ». C'est fait : l'enregistrement américain ne sera pas repris.

ACHATS INTÉGRÉS
Trente-quatre packs non consommables, dix-sept par langue : seize packs
scolaires de 200 questions (le collège français, les grades 6 à 9 américains)
et un pack musical de 400 questions. Le jeu est entier sans eux. Accueil ▸
« Packs de questions » ; la page porte aussi « Restaurer mes achats ».

Les fichiers des packs sont inclus dans l'application pour tout le monde ; ce
qui s'achète est le droit de les choisir. C'est ce qui permet à un joueur qui
rejoint une partie de jouer les packs de son hôte sans les avoir achetés —
c'est voulu, et non un défaut de contrôle.

POUR ESSAYER EN UNE MINUTE
1. « Partie rapide » sur l'écran d'accueil.
2. Touchez vos territoires pour poser vos renforts, puis « À l'attaque ».
3. Touchez un territoire à vous d'au moins deux hommes, puis un voisin ennemi.
4. Choisissez un thème et « Lancer l'assaut » : une question apparaît.
Mode d'emploi complet dans l'app.

JOUER À PLUSIEURS — TROIS CHEMINS, TOUS FACULTATIFS
Le jeu est entier sans eux : seul contre l'ordinateur, ou à plusieurs sur un
même appareil.

1. DANS LA MÊME PIÈCE — framework Network d'Apple, Bonjour et TCP, sans
serveur. Demande deux appareils proches et l'autorisation « réseau local ».

2. AU LOIN, AVEC UN CODE — le chemin le plus simple à essayer : les appareils
n'ont besoin ni d'être proches, ni du même réseau, et un appareil physique avec
un simulateur suffit.
  a. Appareil A : accueil ▸ « Jouer à plusieurs » ▸ « Au loin, avec un code »
     ▸ « Ouvrir une partie ». Un code de six lettres s'affiche.
  b. Appareil B : le même chemin, puis « Rejoindre » et ces six lettres.
  c. Appareil A : « Commencer ».
Les coups passent par un relais que nous hébergeons (Cloudflare Workers). Il
recopie des paquets sans les lire : ni question, ni réponse, ni nom de joueur.
Il connaît un identifiant tiré au sort à l'installation, le garde une semaine
après la dernière séance pour qu'une partie se reprenne un autre soir, puis
l'efface.

3. PAR GAME CENTER — facultatif, pour ceux qui y sont déjà. Riskelo n'y voit
que le pseudonyme des joueurs de la partie en cours et ne le conserve pas.
Nous le signalons franchement : « trouver quelqu'un au hasard » demande un
autre joueur connecté au même moment, ce qu'une application qui paraît ne peut
garantir ; seul « inviter un ami » aboutit à coup sûr, à deux comptes Game
Center. Pour éprouver le jeu à plusieurs, préférez le chemin 2.

AUTORISATIONS ET CONFIDENTIALITÉ
Deux autorisations, facultatives, demandées seulement à l'ouverture de la
fonction concernée : réseau local (chemin 1) et Game Center (chemin 3). Aucune
autre. Aucune donnée personnelle collectée, aucun kit tiers — ni publicité, ni
analyse, ni authentification. Le jeu fonctionne hors ligne ; rien ne sort de
l'appareil tant que le joueur n'ouvre pas « Au loin » ou « Game Center ».

CONTENU
Questions, plateaux, dessins et icône sont des créations originales. Riskelo
est un jeu indépendant, inspiré du genre des jeux de conquête territoriale ; il
n'emploie aucune marque, aucun visuel et aucun texte appartenant à un éditeur
de jeu de société. La carte du monde est tracée d'après les côtes réelles —
longitudes et latitudes — et les noms de pays et de continents sont ceux de la
géographie.

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
