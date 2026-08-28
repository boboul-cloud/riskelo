# Soumission à l'App Store — Riskelo 1.0

Tout ce qu'App Store Connect demande, préparé et vérifiable.

**Un seul fichier suffit le jour de la soumission :**
[FICHE-DE-SOUMISSION.md](FICHE-DE-SOUMISSION.md) — les identifiants, les
adresses, tous les textes à coller, les réponses aux questionnaires, les
captures, les commandes d'envoi et l'ordre des opérations, dans l'ordre où
App Store Connect les demande.

Les quatre fichiers ci-dessous en sont le détail, pour qui veut le pourquoi
plutôt que le quoi.

| Fichier | Ce qu'il contient |
|---|---|
| [metadonnees.md](metadonnees.md) | Nom, sous-titre, mots-clés, description, nouveautés, catégories, URL |
| [confidentialite-app-store.md](confidentialite-app-store.md) | Les réponses au questionnaire « Confidentialité des données » |
| [captures-decran.md](captures-decran.md) | Les tailles exigées, les écrans à photographier, la marche à suivre |
| [notes-pour-la-revue.md](notes-pour-la-revue.md) | Ce qu'il faut dire au relecteur d'Apple pour qu'il ne bloque pas |

Les URL publiques attendues par Apple sont servies par GitHub Pages depuis le
dossier `docs/` de ce dépôt :

- Assistance — <https://boboul-cloud.github.io/riskelo/assistance.html>
- Confidentialité — <https://boboul-cloud.github.io/riskelo/confidentialite.html>
- Marketing — <https://boboul-cloud.github.io/riskelo/>

---

## Liste de contrôle

### Avant tout — le compte

- [ ] Adhésion au **Apple Developer Program** active (99 $/an). Sans elle, rien
      ne se soumet.
- [ ] Contrat **Applications gratuites** signé dans App Store Connect ▸
      Contrats, taxes et opérations bancaires. Un contrat non signé bloque la
      publication sans expliquer pourquoi.
- [ ] Si l'application est payante : contrat payant, coordonnées bancaires et
      fiscales complétées.

### Le projet

- [x] Identifiant : `com.oulhen.riskelo`
- [x] Équipe de signature : `38DQ8FW23J`, signature automatique — posée dans
      `project.yml`, donc conservée à chaque `xcodegen generate`
- [x] Version affichée `1.0`, build `1` (`MARKETING_VERSION`,
      `CURRENT_PROJECT_VERSION`)
- [x] `ITSAppUsesNonExemptEncryption = false` — la déclaration de chiffrement
      est répondue une fois pour toutes dans l'Info.plist
- [x] `NSLocalNetworkUsageDescription` et `NSBonjourServices` renseignés — sans
      eux, le jeu à plusieurs appareils échoue en silence
- [x] Icône complète (11 images iOS + macOS), engendrée par `outils/icone.swift`
- [x] Orientations : portrait et paysage, iPhone et iPad
- [x] Cible minimale : iOS 17, macOS 14
- [ ] Créer l'enregistrement de l'app dans App Store Connect (nom réservé)
- [ ] `xcodebuild -scheme Riskelo -destination 'generic/platform=iOS' archive`
      puis distribution vers App Store Connect (ou Xcode ▸ Product ▸ Archive)

### Les tests avant l'envoi

- [ ] `xcodebuild -scheme Riskelo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
      — vert
- [ ] Une partie complète jouée sur iPhone, une sur iPad, une sur Mac
- [ ] Une partie à deux appareils, ouverte de chaque côté (l'inversion des
      rôles fait partie du test)
- [ ] Quitter en plein duel, relancer, reprendre : la partie revient intacte
- [ ] Refuser l'autorisation « réseau local » et vérifier que le jeu solo
      fonctionne quand même

### Les fiches App Store Connect

- [ ] Métadonnées collées depuis [metadonnees.md](metadonnees.md)
- [ ] Captures d'écran déposées — voir [captures-decran.md](captures-decran.md)
- [ ] Questionnaire de confidentialité rempli — voir
      [confidentialite-app-store.md](confidentialite-app-store.md)
- [ ] Classification par âge : répondre « Aucun » partout → **4+**
- [ ] Droits sur le contenu : aucun contenu de tiers
- [ ] Identifiant publicitaire (IDFA) : **non**
- [ ] Notes pour la revue collées depuis
      [notes-pour-la-revue.md](notes-pour-la-revue.md)
- [ ] Prix et disponibilité choisis
- [ ] Publication : automatique à l'approbation, ou manuelle

### Les deux plateformes

L'application est une **cible unique pour iOS et macOS**. Dans App Store
Connect, cela fait deux plateformes sous le même enregistrement : ajouter
**macOS** à l'app existante, avec ses propres captures d'écran et sa propre
build. Les métadonnées textuelles peuvent être identiques.

- [ ] **Avant la build macOS** : poser les entitlements du bac à sable, que le
      Mac App Store exige et que le projet n'a pas encore — les trois clés et
      le pourquoi sont à la section 9 de
      [FICHE-DE-SOUMISSION.md](FICHE-DE-SOUMISSION.md). Sans elles, le dépôt
      est refusé ; avec elles, il faut réessayer le jeu à plusieurs appareils
      depuis le Mac.

### Après l'envoi

- [ ] TestFlight : au moins un essai sur un appareil réel avant de soumettre à
      la revue
- [ ] Soumettre à la revue
- [ ] Compter deux à quarante-huit heures ; répondre vite à toute question du
      relecteur — un fil qui traîne repart en bas de la file
