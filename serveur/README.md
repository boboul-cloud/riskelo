# Le serveur des salons

C'est le point de rendez-vous des parties au loin. Il ne connaît pas Riskelo :
il tient des salons désignés par six lettres et recopie d'un appareil à
l'autre des paquets qu'il ne sait pas lire.

**Tant qu'il n'est pas déployé, « Jouer au loin » ne marche pas.** Les deux
autres façons de jouer à plusieurs — la même pièce et Game Center — ne
dépendent de lui en rien.

---

## Le mettre en service, une fois

### 1. Un compte Cloudflare

Gratuit, à [dash.cloudflare.com](https://dash.cloudflare.com). Aucune carte
bancaire n'est demandée pour le forfait gratuit.

### 2. Déployer

```sh
cd serveur
npm install
npx wrangler login        # ouvre le navigateur, une fois pour toutes
npx wrangler deploy
```

La dernière commande affiche l'adresse du serveur, de cette forme :

```
https://riskelo-salon.VOTRE-SOUS-DOMAINE.workers.dev
```

**C'est fait.** Déployé le 16 septembre 2026 sur le compte
`bob.oulhen@gmail.com`, à l'adresse :

```
https://riskelo-salon.riskelo-salon.workers.dev
```

Elle est déjà inscrite aux trois endroits ci-dessous. Ce qui suit ne sert donc
qu'à redéployer ailleurs — un autre compte, un autre nom.

> **Ne renommez pas le sous-domaine.** Il se lit `riskelo-salon.riskelo-salon`
> — le nom du service, puis celui du compte, qui a pris le même par défaut.
> Cela ressemble à une faute de frappe et n'en est pas une. Le changer casse
> d'un coup tous les liens d'invitation déjà partagés, les deux fichiers de
> droits et le code Swift.

### 3. Dire au jeu où il est

La même adresse, à trois endroits. S'ils ne concordent pas, le jeu cherche un
serveur qui n'existe pas, et il le dit par « Rien n'a répondu ».

| Fichier | Ce qu'il faut y mettre |
|---|---|
| `Sources/Net/Relais.swift` | `serveurParDefaut` — l'adresse **sans** `https://` |
| `Resources/Riskelo-ios.entitlements` | `applinks:` suivi de la même adresse |
| `Resources/Riskelo-mac.entitlements` | la même ligne |

Puis `xcodegen generate` à la racine du projet.

### 4. Le lien vers l'App Store

Dans `src/index.js`, la constante `APP_STORE` porte un numéro d'exemple. La
page d'invitation s'en sert pour celui qui reçoit le lien sans avoir le jeu.
À remplacer par la vraie adresse de Riskelo sur l'App Store.

### 5. Chez Apple

Deux interrupteurs, sur l'identifiant `com.oulhen.riskelo` :

- **Game Center** ;
- **Associated Domains**.

Xcode les lève tout seul en signature automatique. Quand il n'y arrive pas, la
construction échoue sur un message de provisionnement qui **ne parle ni de
Game Center ni des domaines** — et l'on cherche longtemps. Dans ce cas, les
cocher à la main sur [developer.apple.com](https://developer.apple.com) →
Certificates, Identifiers & Profiles → Identifiers.

---

## Y travailler

```sh
npm run dev      # serveur local sur http://localhost:8787
npm test         # vingt-deux vérifications, dans une autre fenêtre
npm run tail     # les journaux du serveur déployé, en direct
```

Pour faire passer le **jeu** par le serveur local, sans toucher au code :

```sh
RISKELO_SALON=localhost:8787 open -a Xcode      # puis ⌘R
```

La même variable vaut pour les essais Swift : `Tests/SalonTests.swift`
éprouve l'application contre le vrai serveur, et se saute en silence quand il
n'y en a pas devant — il écrit dans la console laquelle des deux choses s'est
passée.

---

## Ce qu'il coûte

Le forfait gratuit comprend 100 000 requêtes par jour. Une partie en compte
deux — une connexion par appareil — plus les coups, qui ne sont pas facturés
séparément : ils passent dans une liaison déjà ouverte.

Le salon **s'endort** entre deux coups (`acceptWebSocket` plutôt que
`accept`). Un joueur qui réfléchit quinze secondes ne coûte donc rien du tout :
c'est le temps de calcul qui se facture, et il n'y en a pas.

En clair, il faudrait plusieurs milliers de parties par jour pour sortir du
gratuit.

---

## Ce qu'il sait, et pendant combien de temps

Trois valeurs par salon : qui l'a ouvert, quel dialecte on y parle, si la
partie est partie. Plus la liste des identifiants admis, qui sert uniquement à
laisser revenir quelqu'un après une coupure.

Un identifiant est un nombre tiré au sort à l'installation du jeu. Il ne
désigne personne.

**Aucun nom de joueur ne parvient au serveur** — pas même dans l'adresse de
connexion, où il finirait dans les journaux. Les prénoms sont à l'intérieur
des paquets, que le serveur recopie sans savoir les lire. Ce n'est pas un
détail de présentation : c'est ce qui permet à la politique de confidentialité
de rester ce qu'elle était.

Une semaine après le départ du dernier joueur, tout est effacé et le code
redevient libre. Une semaine, parce qu'une partie de Riskelo ne tient pas dans
une soirée : celui qui l'a ouverte rouvre son salon sous le même code, ceux qui
y étaient y rentrent, et l'on repart où l'on en était. Ce qui attend pendant ce
temps-là tient en quelques octets — qui a ouvert, quel dialecte, et la liste
des identifiants admis. **La partie, elle, n'est jamais ici** : elle dort sur
les appareils, et celui qui l'héberge la redonne à chacun quand tout le monde
est revenu.

Les journaux conservés sont **éteints** (`observability` dans
`wrangler.jsonc`), et ce n'est pas un choix technique : allumés, ils gardent
quelques jours l'adresse de chaque requête, laquelle porte l'identifiant de
l'appareil. Ce serait un identifiant gardé hors de l'appareil au-delà du temps
nécessaire — c'est-à-dire exactement ce qu'Apple appelle « collecter une
donnée ». `npm run tail` donne les journaux en direct sans rien conserver, ce
qui suffit pour déboguer.

---

## Les fichiers

| | |
|---|---|
| `src/index.js` | tout le serveur — le salon, la page d'invitation, le fichier qu'Apple vient lire |
| `wrangler.jsonc` | le nom du service et l'adossement SQLite (le seul du forfait gratuit) |
| `essai.mjs` | vingt-deux vérifications de bout en bout, y compris la coupure et le retour |
