# Questionnaire « Confidentialité des données » — les réponses

App Store Connect ▸ votre app ▸ **Confidentialité de l'app**.

## La réponse d'ensemble

> **Collectez-vous des données depuis cette app ?**
> → **Non, nous ne collectons aucune donnée de cette app.**

C'est exact et vérifiable :

- aucun kit tiers (pas de régie publicitaire, pas d'outil d'analyse, pas de
  service d'authentification) — le projet n'a **aucune dépendance externe** ;
- aucune requête réseau vers un serveur : les seules communications sont
  locales, d'appareil à appareil, par `MultipeerConnectivity` ;
- aucun identifiant publicitaire, aucun `IDFA`, aucun `identifierForVendor`
  transmis ;
- les fichiers de partie restent dans le conteneur de l'application et
  disparaissent avec elle.

Apple demande de cocher cette case **seulement** si aucune donnée n'est
transmise hors de l'appareil. Des données écrites localement et jamais envoyées
ne comptent pas comme collectées : c'est le cas ici.

## Les questions annexes

| Question | Réponse |
|---|---|
| Utilisez-vous l'identifiant publicitaire (IDFA) ? | Non |
| L'app contient-elle des achats intégrés ? | Non |
| L'app contient-elle de la publicité ? | Non |
| L'app utilise-t-elle le suivi (App Tracking Transparency) ? | Non |
| Contenu de tiers soumis à droits ? | Non — code, questions, plateaux et icône sont l'œuvre de l'éditeur |
| Chiffrement (déclaration d'exportation) | `ITSAppUsesNonExemptEncryption = false`, déjà dans l'Info.plist : rien à répondre à chaque envoi |
| Game Center | Non utilisé |
| Connexion à un compte | Aucune |

## Les autorisations demandées, et pourquoi

Une seule, et elle est facultative :

| Autorisation | Quand | Texte affiché |
|---|---|---|
| Réseau local (`NSLocalNetworkUsageDescription`) | À la première ouverture de l'écran « Jouer à plusieurs appareils » | « Riskelo s'en sert pour trouver l'autre appareil et jouer la partie à deux. » |

Refusée, l'application reste entièrement jouable : seul le jeu à plusieurs
appareils est indisponible. Aucune autre autorisation n'est demandée — ni
position, ni photos, ni contacts, ni micro, ni notifications.

## Le point à ne pas oublier

Le nom de l'appareil (« iPhone de Camille ») est visible des appareils proches
pendant la recherche d'une table, parce que `MultipeerConnectivity` s'en sert
comme étiquette. Ce n'est pas une collecte — rien n'est enregistré ni transmis
à l'éditeur — mais c'est dit explicitement dans la politique de
confidentialité, section 4. Si un relecteur pose la question, la réponse y est
déjà écrite.
