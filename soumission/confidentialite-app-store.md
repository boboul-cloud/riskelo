# Questionnaire « Confidentialité des données » — les réponses

App Store Connect ▸ votre app ▸ **Confidentialité de l'app**.

## La réponse d'ensemble

> **Collectez-vous des données depuis cette app ?**
> → **Non, nous ne collectons aucune donnée de cette app.**

C'est exact et vérifiable :

- aucun kit tiers (pas de régie publicitaire, pas d'outil d'analyse, pas de
  service d'authentification) — le projet n'a **aucune dépendance externe** ;
- aucun identifiant publicitaire, aucun `IDFA`, aucun `identifierForVendor`
  transmis ;
- les fichiers de partie restent dans le conteneur de l'application et
  disparaissent avec elle.

Apple demande de cocher cette case **seulement** si aucune donnée n'est
transmise hors de l'appareil **et conservée**. Sa définition, mot pour mot :
« transmettre des données hors de l'appareil et les stocker sous une forme
lisible plus longtemps que nécessaire pour servir la requête immédiate ». Des
données écrites localement et jamais envoyées ne comptent pas.

### Ce qui a changé avec le jeu au loin — à relire avant d'envoyer

Depuis que « Jouer au loin » existe, l'affirmation « aucune requête réseau vers
un serveur » n'est plus vraie telle quelle, et cette section remplace
l'ancienne. Ce qui sort de l'appareil, quand et seulement quand le joueur
ouvre cet écran :

| Ce qui sort | Où | Combien de temps c'est gardé |
|---|---|---|
| Un identifiant tiré au sort à l'installation | Le relais, chez Cloudflare | ≤ 2 minutes après le départ du dernier joueur, puis effacé |
| Les coups de la partie, sous forme opaque | Le relais | le temps de les recopier — rien n'est écrit |

Ce qui **ne sort jamais** : le pseudo, le nom de l'appareil, aucune adresse,
aucun identifiant Apple. Le pseudo passait dans l'adresse de connexion ; il en
a été retiré exprès, précisément pour que cette ligne reste vraie.

Les **journaux conservés** du serveur sont éteints (`observability` dans
`serveur/wrangler.jsonc`). Allumés, ils garderaient trois jours l'adresse de
chaque requête, laquelle porte l'identifiant de l'appareil : ce serait un
identifiant conservé hors de l'appareil au-delà du nécessaire, et la réponse
d'ensemble devrait alors passer à **Oui**, catégorie *Identifiants ▸
Identifiant d'appareil*, usage *Fonctionnalité de l'app*, **non lié à
l'identité**.

**La réponse reste donc « Non ».** Les deux mouvements ci-dessus servent la
requête immédiate et rien d'autre, et les deux minutes du salon sont le délai
de reprise après coupure — sans elles, un joueur qui passe dans un tunnel perd
sa partie.

C'est un jugement, et il est défendable. Si vous préférez la prudence,
répondre « Oui » avec *Identifiant d'appareil · Fonctionnalité de l'app · non
lié à l'identité* est également exact, et n'a aucune conséquence sur le
classement ni sur la mise en avant de l'app.

## Les questions annexes

| Question | Réponse |
|---|---|
| Utilisez-vous l'identifiant publicitaire (IDFA) ? | Non |
| L'app contient-elle des achats intégrés ? | **Oui** — dix-sept packs de questions, non consommables |
| L'app contient-elle de la publicité ? | Non |
| L'app utilise-t-elle le suivi (App Tracking Transparency) ? | Non |
| Contenu de tiers soumis à droits ? | Non — code, questions, plateaux et icône sont l'œuvre de l'éditeur |
| Chiffrement (déclaration d'exportation) | `ITSAppUsesNonExemptEncryption = false`, déjà dans l'Info.plist : rien à répondre à chaque envoi |
| Game Center | **Oui** — l'un des trois chemins du jeu à plusieurs (facultatif). Ce que Game Center collecte relève d'Apple, et non de l'éditeur |
| Connexion à un compte | Aucune |

## Les autorisations demandées, et pourquoi

Une seule, et elle est facultative :

| Autorisation | Quand | Texte affiché |
|---|---|---|
| Réseau local (`NSLocalNetworkUsageDescription`) | À la première ouverture de « Jouer à plusieurs » ▸ « Dans la même pièce » | « Riskelo s'en sert pour trouver l'autre appareil et jouer la partie à deux. » |
| Game Center | À la première ouverture de « Jouer à plusieurs » ▸ « Par Game Center ». C'est le système qui la pose, et son texte n'est pas le nôtre | — |

Refusée, l'application reste entièrement jouable : seul le jeu à plusieurs
appareils est indisponible. Aucune autre autorisation n'est demandée — ni
position, ni photos, ni contacts, ni micro, ni notifications.

## Le point à ne pas oublier

Le nom de l'appareil (« iPhone de Camille ») est visible des appareils proches
pendant la recherche d'une table, parce que l'annonce Bonjour s'en sert
comme étiquette. Ce n'est pas une collecte — rien n'est enregistré ni transmis
à l'éditeur — mais c'est dit explicitement dans la politique de
confidentialité, section 4. Si un relecteur pose la question, la réponse y est
déjà écrite.
