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

## Les trois rejets probables, et la parade

| Motif possible | Pourquoi il peut tomber | Ce qui est déjà en place |
|---|---|---|
| **Ressemblance avec une marque de jeu de société** (règle 5.2.5) | Le genre est proche d'un jeu connu | Aucune marque n'est employée : ni dans le nom, ni dans le sous-titre, ni dans les mots-clés, ni dans la description, ni dans l'app. Les conditions d'utilisation portent une clause d'indépendance explicite. |
| **Fonction non testable par le relecteur** (règle 2.1) | Le jeu à plusieurs appareils demande deux appareils | Les notes ci-dessus l'expliquent et précisent que la fonction est facultative. |
| **Politique de confidentialité manquante ou creuse** (règle 5.1.1) | Une URL obligatoire, et souvent bâclée | Page complète et publique, qui décrit jusqu'au nom d'appareil visible en réseau local. |
