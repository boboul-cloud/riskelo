# Les dix-sept packs, un par un

Une page par pack, dans l'ordre où ils apparaissent sur la page des packs du
jeu. Chaque bloc encadré est un formulaire d'App Store Connect : **Monétisation
▸ Achats intégrés ▸ +**, puis on recopie les quatre lignes. Les cases se
cochent au fur et à mesure.

Le détail et le pourquoi sont en section 4 bis de
[FICHE-DE-SOUMISSION.md](FICHE-DE-SOUMISSION.md) ; cette page-ci est faite pour
être tenue ouverte à côté du navigateur.

---

## Ce qui est pareil pour les dix-sept

| Champ | Valeur |
|---|---|
| Type | **Non consommable** — acheté une fois, gardé pour toujours |
| Partage familial | **activé** — le choix du fichier d'essai, encore à confirmer |
| Langue de la fiche | Français (France) |
| Capture de revue | la même pour les dix-sept — voir plus bas |
| Prix | le même palier pour les dix-sept — **à décider** |

Les quatre cases de chaque bloc :

- **créé** — l'article existe dans App Store Connect avec le bon identifiant.
- **localisé** — le nom d'affichage et la description sont saisis en français.
- **capture** — la capture de revue est déposée.
- **prix** — le palier est choisi.

---

## Trois choses à savoir avant de commencer

**L'identifiant ne se rattrape pas.** Un article créé ne se supprime jamais et
son identifiant ne se réutilise pas. Une lettre de travers, et le jeu ne
trouvera jamais le pack : il faudra en créer un autre et vivre avec le premier.
Recopier, ne pas retaper.

**Les descriptions ci-dessous sont courtes exprès.** App Store Connect limite
la description d'un achat intégré à **45 signes** — celles de la fiche de
soumission en font près du double, elles sont écrites pour être lues, pas pour
entrer dans cette case. Les dix-sept versions courtes de cette page tiennent
toutes dans la limite. Le nom d'affichage, lui, est limité à 30 signes : aucun
des dix-sept n'en approche.

**La capture de revue n'est pas encore prise.** Apple en exige une par achat
intégré, mais elle ne sert qu'au relecteur : elle ne s'affiche nulle part, et
la même image convient aux dix-sept, puisque les dix-sept se trouvent sur le
même écran. Il faut donc une photographie de la page des packs :

```bash
xcrun simctl boot "iPhone 17 Pro Max"
open -a Simulator
# lancer Riskelo, accueil ▸ Packs, puis :
mkdir -p soumission/captures/achats
xcrun simctl io booted screenshot soumission/captures/achats/packs.png
```

---

## 1 / 17 — Rock 70-80

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack Rock 70-80
Identifiant produit   com.oulhen.riskelo.pack.rock7080
Nom d'affichage       Rock 70-80
Description           Rock des années 1970-1980. 400 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 2 / 17 — Histoire — 6e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack Histoire 6e
Identifiant produit   com.oulhen.riskelo.pack.histoire6e
Nom d'affichage       Histoire — 6e
Description           Égypte, Grèce, Rome. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 3 / 17 — Géographie — 6e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack Géographie 6e
Identifiant produit   com.oulhen.riskelo.pack.geographie6e
Nom d'affichage       Géographie — 6e
Description           Habiter le monde, villes. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 4 / 17 — Français — 6e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack Français 6e
Identifiant produit   com.oulhen.riskelo.pack.francais6e
Nom d'affichage       Français — 6e
Description           Nature des mots, accords. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 5 / 17 — SVT — 6e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack SVT 6e
Identifiant produit   com.oulhen.riskelo.pack.svt6e
Nom d'affichage       SVT — 6e
Description           Le vivant, les milieux. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 6 / 17 — Histoire — 5e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack Histoire 5e
Identifiant produit   com.oulhen.riskelo.pack.histoire5e
Nom d'affichage       Histoire — 5e
Description           Moyen Âge, Renaissance. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 7 / 17 — Géographie — 5e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack Géographie 5e
Identifiant produit   com.oulhen.riskelo.pack.geographie5e
Nom d'affichage       Géographie — 5e
Description           Population, ressources. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 8 / 17 — Français — 5e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack Français 5e
Identifiant produit   com.oulhen.riskelo.pack.francais5e
Nom d'affichage       Français — 5e
Description           Participe passé, style. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 9 / 17 — SVT — 5e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack SVT 5e
Identifiant produit   com.oulhen.riskelo.pack.svt5e
Nom d'affichage       SVT — 5e
Description           Nutrition, respiration. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 10 / 17 — Histoire — 4e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack Histoire 4e
Identifiant produit   com.oulhen.riskelo.pack.histoire4e
Nom d'affichage       Histoire — 4e
Description           Révolutions, industrie. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 11 / 17 — Géographie — 4e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack Géographie 4e
Identifiant produit   com.oulhen.riskelo.pack.geographie4e
Nom d'affichage       Géographie — 4e
Description           Migrations, mondialisation. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 12 / 17 — Français — 4e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack Français 4e
Identifiant produit   com.oulhen.riskelo.pack.francais4e
Nom d'affichage       Français — 4e
Description           Subordonnées, modes. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 13 / 17 — SVT — 4e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack SVT 4e
Identifiant produit   com.oulhen.riskelo.pack.svt4e
Nom d'affichage       SVT — 4e
Description           Reproduction, volcans. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 14 / 17 — Histoire — 3e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack Histoire 3e
Identifiant produit   com.oulhen.riskelo.pack.histoire3e
Nom d'affichage       Histoire — 3e
Description           Guerres totales, après 1945. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 15 / 17 — Géographie — 3e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack Géographie 3e
Identifiant produit   com.oulhen.riskelo.pack.geographie3e
Nom d'affichage       Géographie — 3e
Description           La France, ses territoires. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 16 / 17 — Français — 3e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack Français 3e
Identifiant produit   com.oulhen.riskelo.pack.francais3e
Nom d'affichage       Français — 3e
Description           Phrase complexe, argumenter. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## 17 / 17 — SVT — 3e

- [ ] créé  - [ ] localisé  - [ ] capture  - [ ] prix

```
Nom de référence      Pack SVT 3e
Identifiant produit   com.oulhen.riskelo.pack.svt3e
Nom d'affichage       SVT — 3e
Description           Génétique, immunité, cerveau. 200 questions.
Capture               soumission/captures/achats/packs.png
```

---

## Quand les dix-sept sont créés

- [ ] Les dix-sept articles sont **joints à la version** dans la fiche de
      l'app. Créés mais non joints, ils restent « en attente d'envoi » et la
      page des packs dira « indisponible » à tout le monde.
- [ ] Une partie d'essai depuis Xcode avec `Resources/Riskelo.storekit` : les
      dix-sept prix s'affichent, un achat se fait, la restauration marche.
- [ ] Les identifiants du jeu et ceux d'App Store Connect concordent —
      la commande qui le vérifie sans ouvrir le navigateur :

```bash
grep -h '^! produit' Resources/Questions/*.txt | awk '{print $NF}' | sort
```

  Dix-sept lignes, à comparer aux dix-sept articles de la fiche d'Apple.
