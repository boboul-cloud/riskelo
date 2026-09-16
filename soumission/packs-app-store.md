# Les trente-quatre packs, un par un

Une page par pack, dans l'ordre où ils apparaissent sur la page des packs du
jeu. Chaque bloc encadré est un formulaire d'App Store Connect : **Monétisation
▸ Achats intégrés ▸ +**, puis on recopie les cinq lignes. Les cases se cochent
au fur et à mesure.

Ils étaient dix-sept. La fusion en a apporté dix-sept autres : l'anglais est
devenu une langue de Riskelo au lieu d'une seconde application, et ses packs
sont des articles comme les autres, dans la même fiche, sous le même compte.

Le détail et le pourquoi sont en section 4 bis de
[FICHE-DE-SOUMISSION.md](FICHE-DE-SOUMISSION.md) ; cette page-ci est faite pour
être tenue ouverte à côté du navigateur.

---

## Deux séries dans une seule application

| | les français | les anglais |
|---|---|---|
| Combien | dix-sept | dix-sept |
| Famille d'identifiants | `com.oulhen.riskelo.pack.…` | `com.oulhen.riskelo.pack.us.…` |
| Langue de la fiche | Français (France) | Anglais (États-Unis) |
| Captures de revue | trois | trois |

La page des packs ne montre que la langue en cours : un Français n'y voit pas
les seize packs du programme américain. La langue se choisit en haut de cette
même page, par un bouton **Français / English** — ce qui permet au relecteur
d'Apple de voir les deux séries sans quitter l'écran ni toucher aux réglages de
son appareil.

Chaque article ne reçoit qu'une langue de fiche, la sienne. Un pack de français
de 5e n'a rien à dire à un lecteur américain, et Apple montre l'article dans la
langue principale de l'app quand la sienne manque.

---

## Ce qui est pareil pour les trente-quatre

| Champ | Valeur |
|---|---|
| Type | **Non consommable** — acheté une fois, gardé pour toujours |
| Partage familial | **activé** — le choix du fichier d'essai, encore à confirmer |
| Note pour la revue | la même phrase par série — voir plus bas |
| Prix | le même palier pour les trente-quatre — **à décider** ; le fichier d'essai porte 2,99, qui est une valeur pour pouvoir cliquer, pas une proposition |

Les quatre cases de chaque bloc :

- **créé** — l'article existe dans App Store Connect avec le bon identifiant.
- **localisé** — le nom d'affichage et la description sont saisis.
- **capture** — la capture de revue est déposée.
- **prix** — le palier est choisi.

---

## Cinq choses à savoir avant de commencer

**L'identifiant ne se rattrape pas.** Un article créé ne se supprime jamais et
son identifiant ne se réutilise pas. Une lettre de travers, et le jeu ne
trouvera jamais le pack : il faudra en créer un autre et vivre avec le premier.
Recopier, ne pas retaper.

**Les identifiants de l'app américaine sont morts.** Riskelo US avait ses
dix-sept articles, créés dans son propre enregistrement sous la famille
`com.oulhen.riskelo.us.pack.…`. Apple ne libère jamais un identifiant de
produit : supprimer l'enregistrement ne les rendrait pas. Les dix-sept anglais
de cette page portent donc une autre famille, sous le bundle français :
`com.oulhen.riskelo.pack.us.…`. Les deux ne diffèrent que par la place de
`us` — `.us.pack.` contre `.pack.us.` — et c'est la seule chose de cette page
qu'il ne faut pas se tromper de recopier. Dans la nouvelle famille, rien n'est
brûlé : `…pack.us.geography6` est libre, là où son homologue américain avait dû
devenir `geography6b`.

**Les descriptions sont courtes exprès.** App Store Connect limite la
description d'un achat intégré à **45 signes**, et le nom d'affichage à 30. Les
trente-quatre versions de cette page sont comptées : la plus longue en fait 44.
Celles de [FICHE-DE-SOUMISSION.md](FICHE-DE-SOUMISSION.md) et de
[LOCALISATION-EN.md](LOCALISATION-EN.md) sont écrites pour être lues, pas pour
entrer dans cette case — les dix-sept anglaises de la fiche de localisation ont
même été écrites pour une limite de 55 signes, et aucune ne rentre. Ce sont
celles d'ici qui vont dans le formulaire.

**Les captures : l'écran défile.** Apple exige une capture par achat intégré.
Elle ne sert qu'au relecteur, elle ne s'affiche nulle part — mais elle doit
montrer l'article qu'on lui demande de vérifier. Dix-sept packs ne tiennent pas
sur un écran : il en faut trois par langue, qui se recouvrent. Le piège a déjà
été payé une fois côté américain : deux captures espacées d'un écran plein
laissent une charnière où un pack n'apparaît sur aucune des deux.

`outils/captures-achats.py` les prend et vérifie lui-même son travail. Après
chaque photo il relit l'écran et note quelles lignes y tiennent **entières** ;
il descend tant qu'un pack n'a pas été vu, et un pack qui aurait manqué
déclencherait une photo de plus, centrée sur lui. La charnière ne peut donc
pas subsister. Puis il écrit dans chaque bloc de cette page la photo qui montre
son pack.

```bash
python3 outils/captures-achats.py --fiche
```

**L'app doit tourner depuis Xcode** (⌘R) quand on le lance. Xcode est le seul à
attacher `Resources/Riskelo.storekit` : lancée autrement, la page des packs
affiche « indisponible » partout au lieu des prix, et c'est exactement ce que
le relecteur ne doit pas voir. L'outil refuse de commencer s'il ne voit aucun
prix.

Deux tailles sortent : celle de l'appareil dans `_brut/`, et **1242 × 2688** à
côté de la fiche — la taille qu'App Store Connect prend.

**Le nom de référence ne se voit que par toi.** Il ne sort jamais d'App Store
Connect. Si l'un des dix-sept anglais est refusé comme déjà pris, c'est
l'enregistrement mort de Riskelo US qui le retient : ajouter « EN » à la fin, et
passer. Contrairement à l'identifiant, il se change après coup.

---

## La note pour la revue

À coller dans « Informations pour la vérification ». Le relecteur d'Apple lit
l'anglais ; les deux notes ne diffèrent que par le bouton à presser.

Pour les dix-sept français :

```
The pack appears on the Packs screen, reachable from the home screen. Select "Français" with the button at the top of that screen. The questions ship inside the app; the purchase unlocks choosing the pack, which is why a guest at a table can play the host's packs. See the review screenshot.
```

Pour les dix-sept anglais :

```
The pack appears on the Packs screen, reachable from the home screen. Select "English" with the button at the top of that screen. The questions ship inside the app; the purchase unlocks choosing the pack, which is why a guest at a table can play the host's packs. See the review screenshot.
```

---

# Les dix-sept français

## 1 / 17 — Rock 70-80

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack Rock 70-80
Identifiant produit   com.oulhen.riskelo.pack.rock7080
Nom d'affichage       Rock 70-80
Description           Rock des années 1970-1980. 400 questions.
Capture               soumission/captures/achats/fr-1.png
```

---

## 2 / 17 — Histoire — 6e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack Histoire 6e
Identifiant produit   com.oulhen.riskelo.pack.histoire6e
Nom d'affichage       Histoire — 6e
Description           Égypte, Grèce, Rome. 200 questions.
Capture               soumission/captures/achats/fr-1.png
```

---

## 3 / 17 — Géographie — 6e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack Géographie 6e
Identifiant produit   com.oulhen.riskelo.pack.geographie6e
Nom d'affichage       Géographie — 6e
Description           Habiter le monde, villes. 200 questions.
Capture               soumission/captures/achats/fr-1.png
```

---

## 4 / 17 — Français — 6e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack Français 6e
Identifiant produit   com.oulhen.riskelo.pack.francais6e
Nom d'affichage       Français — 6e
Description           Nature des mots, accords. 200 questions.
Capture               soumission/captures/achats/fr-1.png
```

---

## 5 / 17 — SVT — 6e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack SVT 6e
Identifiant produit   com.oulhen.riskelo.pack.svt6e
Nom d'affichage       SVT — 6e
Description           Le vivant, les milieux. 200 questions.
Capture               soumission/captures/achats/fr-1.png
```

---

## 6 / 17 — Histoire — 5e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack Histoire 5e
Identifiant produit   com.oulhen.riskelo.pack.histoire5e
Nom d'affichage       Histoire — 5e
Description           Moyen Âge, Renaissance. 200 questions.
Capture               soumission/captures/achats/fr-2.png
```

---

## 7 / 17 — Géographie — 5e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack Géographie 5e
Identifiant produit   com.oulhen.riskelo.pack.geographie5e
Nom d'affichage       Géographie — 5e
Description           Population, ressources. 200 questions.
Capture               soumission/captures/achats/fr-2.png
```

---

## 8 / 17 — Français — 5e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack Français 5e
Identifiant produit   com.oulhen.riskelo.pack.francais5e
Nom d'affichage       Français — 5e
Description           Participe passé, style. 200 questions.
Capture               soumission/captures/achats/fr-2.png
```

---

## 9 / 17 — SVT — 5e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack SVT 5e
Identifiant produit   com.oulhen.riskelo.pack.svt5e
Nom d'affichage       SVT — 5e
Description           Nutrition, respiration. 200 questions.
Capture               soumission/captures/achats/fr-2.png
```

---

## 10 / 17 — Histoire — 4e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack Histoire 4e
Identifiant produit   com.oulhen.riskelo.pack.histoire4e
Nom d'affichage       Histoire — 4e
Description           Révolutions, industrie. 200 questions.
Capture               soumission/captures/achats/fr-2.png
```

---

## 11 / 17 — Géographie — 4e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack Géographie 4e
Identifiant produit   com.oulhen.riskelo.pack.geographie4e
Nom d'affichage       Géographie — 4e
Description           Migrations, mondialisation. 200 questions.
Capture               soumission/captures/achats/fr-2.png
```

---

## 12 / 17 — Français — 4e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack Français 4e
Identifiant produit   com.oulhen.riskelo.pack.francais4e
Nom d'affichage       Français — 4e
Description           Subordonnées, modes. 200 questions.
Capture               soumission/captures/achats/fr-3.png
```

---

## 13 / 17 — SVT — 4e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack SVT 4e
Identifiant produit   com.oulhen.riskelo.pack.svt4e
Nom d'affichage       SVT — 4e
Description           Reproduction, volcans. 200 questions.
Capture               soumission/captures/achats/fr-3.png
```

---

## 14 / 17 — Histoire — 3e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack Histoire 3e
Identifiant produit   com.oulhen.riskelo.pack.histoire3e
Nom d'affichage       Histoire — 3e
Description           Guerres totales, après 1945. 200 questions.
Capture               soumission/captures/achats/fr-3.png
```

---

## 15 / 17 — Géographie — 3e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack Géographie 3e
Identifiant produit   com.oulhen.riskelo.pack.geographie3e
Nom d'affichage       Géographie — 3e
Description           La France, ses territoires. 200 questions.
Capture               soumission/captures/achats/fr-3.png
```

---

## 16 / 17 — Français — 3e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack Français 3e
Identifiant produit   com.oulhen.riskelo.pack.francais3e
Nom d'affichage       Français — 3e
Description           Phrase complexe, argumenter. 200 questions.
Capture               soumission/captures/achats/fr-3.png
```

---

## 17 / 17 — SVT — 3e

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Pack SVT 3e
Identifiant produit   com.oulhen.riskelo.pack.svt3e
Nom d'affichage       SVT — 3e
Description           Génétique, immunité, cerveau. 200 questions.
Capture               soumission/captures/achats/fr-3.png
```

---

# Les dix-sept anglais

## 1 / 17 — Rock 70-80

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Rock 70 80 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.rock7080
Nom d'affichage       Rock 70-80
Description           Rock of the 1970s and 1980s. 400 questions.
Capture               soumission/captures/achats/en-1.png
```

---

## 2 / 17 — History — Grade 6

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      History Grade 6 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.history6
Nom d'affichage       History — Grade 6
Description           Ancient Egypt, Greece, Rome. 200 questions.
Capture               soumission/captures/achats/en-1.png
```

---

## 3 / 17 — Geography — Grade 6

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Geography Grade 6 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.geography6
Nom d'affichage       Geography — Grade 6
Description           Map skills, Africa and Asia. 200 questions.
Capture               soumission/captures/achats/en-1.png
```

---

## 4 / 17 — English — Grade 6

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      English Grade 6 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.english6
Nom d'affichage       English — Grade 6
Description           Grammar, word roots, myths. 200 questions.
Capture               soumission/captures/achats/en-1.png
```

---

## 5 / 17 — Science — Grade 6

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Science Grade 6 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.science6
Nom d'affichage       Science — Grade 6
Description           Rocks, weather, space. 200 questions.
Capture               soumission/captures/achats/en-1.png
```

---

## 6 / 17 — History — Grade 7

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      History Grade 7 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.history7
Nom d'affichage       History — Grade 7
Description           Middle Ages to Columbus. 200 questions.
Capture               soumission/captures/achats/en-2.png
```

---

## 7 / 17 — Geography — Grade 7

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Geography Grade 7 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.geography7
Nom d'affichage       Geography — Grade 7
Description           Europe, Americas, Pacific. 200 questions.
Capture               soumission/captures/achats/en-2.png
```

---

## 8 / 17 — English — Grade 7

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      English Grade 7 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.english7
Nom d'affichage       English — Grade 7
Description           Poetry, fiction, drama. 200 questions.
Capture               soumission/captures/achats/en-2.png
```

---

## 9 / 17 — Science — Grade 7

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Science Grade 7 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.science7
Nom d'affichage       Science — Grade 7
Description           Cells, plants, animals. 200 questions.
Capture               soumission/captures/achats/en-2.png
```

---

## 10 / 17 — History — Grade 8

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      History Grade 8 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.history8
Nom d'affichage       History — Grade 8
Description           Colonies to Reconstruction. 200 questions.
Capture               soumission/captures/achats/en-2.png
```

---

## 11 / 17 — Geography — Grade 8

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Geography Grade 8 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.geography8
Nom d'affichage       Geography — Grade 8
Description           States, capitals, cities. 200 questions.
Capture               soumission/captures/achats/en-2.png
```

---

## 12 / 17 — English — Grade 8

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      English Grade 8 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.english8
Nom d'affichage       English — Grade 8
Description           Literature, Poe to Morrison. 200 questions.
Capture               soumission/captures/achats/en-3.png
```

---

## 13 / 17 — Science — Grade 8

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Science Grade 8 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.science8
Nom d'affichage       Science — Grade 8
Description           Atoms, forces, energy, waves. 200 questions.
Capture               soumission/captures/achats/en-3.png
```

---

## 14 / 17 — History — Grade 9

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      History Grade 9 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.history9
Nom d'affichage       History — Grade 9
Description           The modern world since 1750. 200 questions.
Capture               soumission/captures/achats/en-3.png
```

---

## 15 / 17 — Geography — Grade 9

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Geography Grade 9 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.geography9
Nom d'affichage       Geography — Grade 9
Description           Population, cities, trade. 200 questions.
Capture               soumission/captures/achats/en-3.png
```

---

## 16 / 17 — English — Grade 9

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      English Grade 9 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.english9
Nom d'affichage       English — Grade 9
Description           Shakespeare and the classics. 200 questions.
Capture               soumission/captures/achats/en-3.png
```

---

## 17 / 17 — Science — Grade 9

- [x] créé  - [x] localisé  - [x] capture  - [ ] prix

```
Nom de référence      Science Grade 9 Pack
Identifiant produit   com.oulhen.riskelo.pack.us.science9
Nom d'affichage       Science — Grade 9
Description           DNA, genetics, evolution. 200 questions.
Capture               soumission/captures/achats/en-3.png
```

---

## Quand les trente-quatre sont créés

- [ ] Les trente-quatre articles sont **joints à la version** dans la fiche de
      l'app. Créés mais non joints, ils restent « en attente d'envoi » et la
      page des packs dira « indisponible » à tout le monde.
- [ ] Une partie d'essai depuis Xcode avec `Resources/Riskelo.storekit`, **dans
      les deux langues** : dix-sept prix s'affichent en français, dix-sept en
      anglais, un achat se fait, la restauration marche. Le fichier d'essai
      porte déjà les trente-quatre articles.
- [ ] Un pack acheté en français se retrouve après un passage à l'anglais et
      retour : la boutique demande les trente-quatre articles, pas les dix-sept
      affichés.
- [ ] Les identifiants du jeu et ceux d'App Store Connect concordent —
      la commande qui le vérifie sans ouvrir le navigateur :

```bash
grep -hE '^! (produit|product)' Resources/Questions/*.txt | awk '{print $NF}' | sort
```

  Trente-quatre lignes : dix-sept en `…riskelo.pack.` et dix-sept en
  `…riskelo.pack.us.`, à comparer aux trente-quatre articles de la fiche
  d'Apple.

---

## Trente-quatre formulaires, ou une commande

`outils/asc-achats.py` fait les trois gestes de chaque bloc — créer l'article,
poser sa fiche dans sa langue, déposer sa capture — en passant par la porte
qu'Apple ouvre aux programmes. Il lit les identifiants dans les fichiers de
questions et tout le reste dans cette page : rien n'est retapé, donc rien ne
peut être mal retapé.

```bash
python3 outils/asc-achats.py            # à blanc, hors ligne : les 34 lignes
python3 outils/asc-achats.py --check    # à blanc, en comparant à ce qu'Apple a
python3 outils/asc-achats.py --apply    # écrit
```

Il refuse d'écrire tant qu'une capture manque, et il dit lesquelles. Un article
déjà créé n'est pas recréé : il regarde ce qui lui manque encore — sa fiche, sa
capture — et finit le travail. Le prix reste hors de sa portée : il se pose
dans l'interface, une fois le reste en place.

### La clé qu'il lui faut

App Store Connect ▸ **Utilisateurs et accès** ▸ **Intégrations** ▸ clés de
l'API App Store Connect. On en fabrique une avec le rôle **Gestionnaire d'app**
— « Développeur » ne suffit pas pour créer un achat intégré. Trois choses en
sortent :

| | où |
|---|---|
| Le fichier `AuthKey_….p8` | téléchargé à la création — **une seule fois**, Apple ne le redonne jamais |
| L'identifiant de la clé | en face d'elle dans la liste |
| L'identifiant de l'émetteur | en haut de la même page, le même pour toutes tes clés |

Le quatrième champ est l'identifiant Apple de l'app, sur sa fiche, dans
« Informations générales sur l'app ». Le `.p8` se range dans `outils/`, et
`outils/asc-config.json` les nomme tous les quatre :

```json
{
  "issuer_id": "…",
  "key_id": "…",
  "key_file": "AuthKey_….p8",
  "app_id": "…"
}
```

Cette clé ouvre le compte en écriture. `.gitignore` retient le `.p8` et le
fichier de configuration hors du dépôt, et une clé se révoque d'un clic dans la
même page si elle s'égare.
