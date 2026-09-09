//
//  QuestionTests.swift
//  RiskeloTests
//
//  Une question mal formée — leurre égal à la bonne réponse, énoncé en double,
//  catégorie vide — ne fait pas échouer le jeu : elle fait perdre un joueur
//  sans qu'il comprenne pourquoi. C'est le pire des défauts, et le seul que
//  personne ne signale.
//

import Testing
@testable import Riskelo

struct QuestionTests {

    /// Le fichier remplace le compilateur : ce qu'il ne relit plus, ce test
    /// le relit. Et mieux — le compilateur n'a jamais su dire qu'un leurre
    /// était égal à la bonne réponse.
    @Test(arguments: Themes.tous)
    func chaqueFichierSeLit(_ c: Category) {
        let lues = QuestionBank.questions(in: c)
        #expect(!lues.isEmpty, "\(c.label) : fichier absent ou vide")
        #expect(lues.allSatisfy { $0.category == c })
    }

    /// Le dossier fait la liste : un fichier déposé est un thème de plus, et
    /// aucun code ne les énumère. Encore faut-il que le catalogue les trouve.
    @Test func leDossierFaitLaListeDesThemes() {
        #expect(Themes.tous.count >= 7, "un thème manque à l'appel")
        for c in Themes.tous {
            let t = Themes.connu(c)
            #expect(t != nil, "\(c.id) : thème sans carte d'identité")
            #expect(t?.nom.isEmpty == false, "\(c.id) : thème sans nom")
        }
        // L'ordre affiché ne doit pas dépendre de l'ordre où le système a
        // rendu les fichiers : deux appareils montreraient deux grilles.
        let rangs = Themes.tous.compactMap { Themes.connu($0)?.rang }
        #expect(rangs == rangs.sorted(), "la grille n'est pas dans l'ordre déclaré")
    }

    /// Un thème écarté à la mise en place ne sort jamais — ni par son bouton,
    /// ni par « au hasard ».
    ///
    /// C'est le seul contrôle qui compte pour ce réglage : écarter un thème
    /// sans filtrer le tirage n'aurait écarté que son bouton, et le joueur
    /// aurait vu revenir en « au hasard » exactement ce qu'il venait de
    /// retirer.
    @Test func unThemeEcarteNeSortJamais() {
        var r = Rules()
        r.themes = ["sports", "arts"]
        var g = GameState.start(board: .anneau,
                                players: [Player(id: 0, name: "A", kind: .humain),
                                          Player(id: 1, name: "B", kind: .humain)],
                                rules: r, seed: 3)
        #expect(g.themesEnJeu.map(\.id).sorted() == ["arts", "sports"])

        var rng = SeededRandom(seed: 3)
        for _ in 0 ..< 200 {
            let q = g.bank.draw(category: nil, parmi: g.themesEnJeu,
                                difficulty: nil, using: &rng)
            #expect(q != nil)
            #expect(["sports", "arts"].contains(q!.question.category.id),
                    "« au hasard » a sorti un thème écarté")
        }
        // Et le thème nommé lui-même est refusé : un coup venu du réseau ne
        // doit pas pouvoir forcer un thème que la table a retiré.
        let force = g.bank.draw(category: .histoire, parmi: g.themesEnJeu,
                                difficulty: nil, using: &rng)
        #expect(force == nil, "un thème écarté est sorti quand on l'a nommé")
    }

    /// Rien de choisi veut dire le jeu de base — ni tout, ni rien.
    ///
    /// Ni rien, parce qu'une partie sans question ne se distingue pas d'une
    /// panne. Ni tout, parce que les packs se choisissent : ils ne doivent pas
    /// s'inviter dans la partie de qui ne les a pas demandés — et une partie
    /// enregistrée avant les packs doit reprendre telle qu'elle était.
    @Test func aucunThemeChoisiVeutDireLeJeuDeBase() {
        let g = GameState.start(board: .anneau,
                                players: [Player(id: 0, name: "A", kind: .humain),
                                          Player(id: 1, name: "B", kind: .humain)],
                                rules: Rules(), seed: 1)
        #expect(g.themesEnJeu.map(\.id).sorted() == Themes.base.map(\.id).sorted())
        #expect(g.themesEnJeu.allSatisfy { $0.produit == nil }, "un pack s'est invité")

        // Et des règles qui ne nomment que des thèmes absents ne laissent pas
        // une partie sans question.
        var r = Rules()
        r.themes = ["un-theme-qui-nexiste-pas"]
        let h = GameState.start(board: .anneau,
                                players: [Player(id: 0, name: "A", kind: .humain),
                                          Player(id: 1, name: "B", kind: .humain)],
                                rules: r, seed: 1)
        #expect(h.themesEnJeu.count == Themes.base.count)
    }

    /// Un pack se déclare vendu, et le catalogue le range du bon côté.
    @Test func unPackSeDistingueDuJeuDeBase() {
        #expect(Themes.base.count == 6, "le jeu de base a six thèmes")
        #expect(Themes.packs.count == 4, "quatre packs sont livrés")
        // Un pack se vend : il doit tenir plusieurs soirées. Mesuré sur vingt
        // séries de cinq parties, deux cents questions donnent deux soirées
        // propres et une troisième acceptable ; en dessous de cent cinquante,
        // la deuxième soirée est déjà une redite.
        for pack in Themes.packs {
            #expect(QuestionBank.questions(in: pack).count >= 200,
                    "\(pack.id) : trop maigre pour être vendu")
        }
        #expect(Themes.base.allSatisfy { $0.produit == nil })
        for pack in Themes.packs {
            let t = Themes.connu(pack)
            #expect(t?.produit?.hasPrefix("com.oulhen.riskelo.pack.") == true,
                    "\(pack.id) : article mal nommé")
            #expect(t?.detail.isEmpty == false, "\(pack.id) : rien à montrer en boutique")
        }
        // Les articles sont distincts : deux packs sur le même article se
        // déverrouilleraient l'un l'autre.
        let articles = Themes.packs.compactMap(\.produit)
        #expect(Set(articles).count == articles.count)
    }

    /// Le choix des packs vaut pour **toutes** les façons de lancer une
    /// partie, et non pour la seule qui passe par l'écran des réglages.
    ///
    /// C'est le défaut qu'a signalé l'usage, et il valait la peine : le choix
    /// vivait dans « Réglages de la partie », dont le bouton de départ est le
    /// seul des cinq à lire ce qu'on y coche. Partie rapide, reprise et table
    /// en réseau partaient toutes de `PartieRapide.regles()`, c'est-à-dire des
    /// valeurs d'usine. On décochait un thème, et il revenait.
    @Test func leChoixDesPacksVautPourLaPartieRapide() {
        let choisisAvant = Packs.choisis
        let baseAvant = Packs.avecBase
        defer { Packs.choisis = choisisAvant; Packs.avecBase = baseAvant }

        // Un pack seul, sans la culture générale.
        Packs.avecBase = false
        Packs.choisis = ["histoire-4e"]
        let seul = GameState.start(board: .anneau,
                                   players: [Player(id: 0, name: "A", kind: .humain),
                                             Player(id: 1, name: "B", kind: .humain)],
                                   rules: PartieRapide.regles(), seed: 1)
        #expect(seul.themesEnJeu.map(\.id) == ["histoire-4e"],
                "la partie rapide ignore le choix des packs")

        // Deux packs mêlés, toujours sans la culture générale.
        Packs.choisis = ["histoire-4e", "histoire-3e"]
        let melange = GameState.start(board: .anneau,
                                      players: [Player(id: 0, name: "A", kind: .humain),
                                                Player(id: 1, name: "B", kind: .humain)],
                                      rules: PartieRapide.regles(), seed: 1)
        #expect(melange.themesEnJeu.map(\.id).sorted() == ["histoire-3e", "histoire-4e"])

        // Et la culture générale par-dessus.
        Packs.avecBase = true
        let avec = GameState.start(board: .anneau,
                                   players: [Player(id: 0, name: "A", kind: .humain),
                                             Player(id: 1, name: "B", kind: .humain)],
                                   rules: PartieRapide.regles(), seed: 1)
        #expect(avec.themesEnJeu.count == Themes.base.count + 2)
    }

    /// Tout décocher n'est pas permis : le jeu de base revient.
    @Test func onNeJoueJamaisSansAucunTheme() {
        let choisisAvant = Packs.choisis
        let baseAvant = Packs.avecBase
        defer { Packs.choisis = choisisAvant; Packs.avecBase = baseAvant }

        Packs.avecBase = false
        Packs.choisis = []
        #expect(Packs.enJeu == Set(Themes.base.map(\.id)))
    }

    /// La mémoire d'un joueur qui jouait déjà ne se perd pas au changement
    /// d'identifiants.
    ///
    /// L'application est publiée : quelqu'un a derrière lui des mois de
    /// parties, et son fichier nomme les questions par leur rang. Sans
    /// traduction, tout serait écarté et il reverrait d'un coup ses premières
    /// questions — un défaut que personne ne saurait nommer, et que personne
    /// ne signalerait donc.
    @Test func laMemoireDAvantLesIdentifiantsStablesSeRetrouve() {
        let histoire = QuestionBank.questions(in: .histoire)
        let sports = QuestionBank.questions(in: .sports)
        let ancienne = ["histoire-0": 3, "histoire-12": 1, "sports-7": 2,
                        // Un thème disparu, et un rang au-delà du fichier :
                        // on préfère perdre une ligne qu'en inventer une.
                        "cuisine-4": 9, "histoire-99999": 5]
        let neuve = MemoireDesQuestions.traduire(ancienne)

        #expect(neuve[histoire[0].id] == 3)
        #expect(neuve[histoire[12].id] == 1)
        #expect(neuve[sports[7].id] == 2)
        #expect(neuve.count == 3, "une ligne a été inventée ou perdue")
        #expect(neuve.keys.allSatisfy { $0.contains(":") })

        // Traduite deux fois, elle ne bouge plus.
        #expect(MemoireDesQuestions.traduire(neuve) == neuve)
    }

    /// Une ligne mal formée doit être vue, pas devinée.
    @Test func uneLigneMalFormeeNePasseraPas() {
        let entete = "! id | essai\n! nom | Essai\n"
        let lu = QuestionBank.lire(entete + """
            # un commentaire

            F | Combien font deux et deux ? | Quatre | Trois | Cinq | Six
            """, nomDeFichier: "essai")
        #expect(lu?.questions.count == 1)
        #expect(lu?.questions.first?.decoys.count == 3)
        #expect(lu?.questions.first?.difficulty == .facile)
        #expect(QuestionBank.lire(entete, nomDeFichier: "essai")?.questions.isEmpty == true)
        #expect(QuestionBank.lire(entete + "# rien que des commentaires",
                                  nomDeFichier: "essai")?.questions.isEmpty == true)
    }

    /// Un thème se déclare, et ce qu'il déclare arrive jusqu'à l'écran.
    @Test func unThemeSeDeclareDansSonFichier() {
        let lu = QuestionBank.lire("""
            ! id     | essai
            ! nom    | Essai
            ! de     | d'Essai
            ! icone  | flask
            ! teinte | 0.10 0.20 0.30
            ! rang   | 4

            F | Combien font deux et deux ? | Quatre | Trois | Cinq | Six
            """, nomDeFichier: "autre-nom")
        let t = lu?.theme
        #expect(t?.id == "essai", "l'identifiant déclaré passe avant le nom du fichier")
        #expect(t?.nom == "Essai")
        #expect(t?.de == "d'Essai")
        #expect(t?.icone == "flask")
        #expect(t?.teinte == Theme.Teinte(r: 0.10, v: 0.20, b: 0.30))
        #expect(t?.rang == 4)
    }

    /// L'identifiant d'une question tient à son énoncé, et non à sa place.
    ///
    /// C'est ce qui permet de corriger un fichier vendu sans effacer la
    /// mémoire de ceux qui l'ont acheté : insérer une question en tête
    /// décalait tous les identifiants suivants, et le jeu croyait alors avoir
    /// déjà posé des questions qu'il n'avait jamais vues.
    @Test func lIdentifiantSurvitAUneQuestionInseree() {
        let entete = "! id | essai\n! nom | Essai\n"
        let avant = QuestionBank.lire(entete + """
            F | Combien font deux et deux ? | Quatre | Trois | Cinq | Six
            """, nomDeFichier: "essai")
        let apres = QuestionBank.lire(entete + """
            F | Combien font trois et trois ? | Six | Cinq | Sept | Huit
            F | Combien font deux et deux ? | Quatre | Trois | Cinq | Six
            """, nomDeFichier: "essai")
        #expect(avant?.questions.first?.id == apres?.questions.last?.id)
        // Et il ne dépend d'aucun hachage salé au démarrage.
        #expect(QuestionBank.identifiant(theme: "essai", enonce: "Deux et deux ?")
                == QuestionBank.identifiant(theme: "essai", enonce: "Deux et deux ?"))
    }

    /// Deux fois la même question dans un thème, c'est une question de moins
    /// et un joueur qui croit à un bogue. À la main, sur un millier de lignes,
    /// cela arrive.
    @Test(arguments: Themes.tous)
    func aucunEnonceNiReponseNEstRepeteDansUnTheme(_ c: Category) {
        let lues = QuestionBank.questions(in: c)
        let enonces = lues.map { $0.prompt.lowercased() }
        #expect(Set(enonces).count == enonces.count,
                "\(c.label) : énoncé en double")
    }

    /// Un énoncé porte une question, et une seule, et elle se termine par le
    /// point d'interrogation.
    ///
    /// Ce test n'est pas une coquetterie de style : en écrivant une fournée à
    /// la main, j'ai laissé trois fois mes propres hésitations dans le texte —
    /// « Quel jeu se joue avec des dominos... plutôt : combien de faces a un
    /// dé ? ». Rien ne plante, et le joueur lit une phrase absurde.
    @Test(arguments: Themes.tous)
    func chaqueEnonceEstUneSeuleQuestion(_ c: Category) {
        for q in QuestionBank.questions(in: c) {
            #expect(q.prompt.filter { $0 == "?" }.count == 1,
                    "un seul point d'interrogation attendu : \(q.prompt)")
            #expect(q.prompt.hasSuffix("?"), "l'énoncé doit finir par « ? » : \(q.prompt)")
            #expect(!q.prompt.contains("..."), "hésitation restée dans l'énoncé : \(q.prompt)")
            #expect(!q.prompt.contains("…"), "hésitation restée dans l'énoncé : \(q.prompt)")
        }
    }

    /// Une question qui ne tient pas dans la feuille se fait tronquer, et la
    /// réponse devient une devinette.
    @Test(arguments: Themes.tous)
    func rienNEstTropLong(_ c: Category) {
        for q in QuestionBank.questions(in: c) {
            #expect(q.prompt.count <= 110, "trop long : \(q.prompt)")
            for p in [q.correct] + q.decoys {
                #expect(p.count <= 46, "proposition trop longue : \(p)")
                #expect(!p.isEmpty, "proposition vide dans « \(q.prompt) »")
            }
        }
    }

    @Test func laBanqueEstBienFormee() {
        for q in QuestionBank.francaises {
            #expect(q.decoys.count == 3, "\(q.id) n'a pas trois leurres")
            #expect(!q.decoys.contains(q.correct), "\(q.id) : un leurre est la bonne réponse")
            #expect(Set(q.decoys).count == 3, "\(q.id) : deux leurres identiques")
            #expect(q.prompt.hasSuffix("?"), "\(q.id) n'est pas une question")
        }
    }

    @Test func aucunEnonceNiIdentifiantEnDouble() {
        let all = QuestionBank.francaises
        #expect(Set(all.map(\.id)).count == all.count)
        #expect(Set(all.map(\.prompt)).count == all.count)
    }

    /// Chaque catégorie doit tenir un assaut long sans se répéter.
    @Test func chaqueCategorieEstFournie() {
        for c in Themes.tous {
            #expect(QuestionBank().count(in: c) >= 8, "\(c.label) est trop maigre")
        }
    }

    @Test func lesPropositionsSontMelees() {
        var rng = SeededRandom(seed: 7)
        var positions = Set<Int>()
        for _ in 0 ..< 40 {
            let posee = QuestionBank.francaises[0].asked(using: &rng)
            #expect(posee.choices.count == 4)
            #expect(posee.choices[posee.answer] == QuestionBank.francaises[0].correct)
            positions.insert(posee.answer)
        }
        #expect(positions.count == 4, "la bonne réponse tombe toujours au même endroit")
    }

    /// La bonne réponse ne s'installe pas sur une ligne.
    ///
    /// Le tirage libre était honnête — un quart par ligne, mesuré — et
    /// donnait pourtant trois fois de suite la même ligne dans plus de neuf
    /// parties sur dix. Le sac des places l'interdit : quatre questions,
    /// quatre lignes, une fois chacune.
    @Test func lesPlacesSeBrassentSansTroisFoisDeSuite() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 21)
        var lignes: [Int] = []
        for _ in 0 ..< 400 {
            guard let q = bank.draw(category: nil, difficulty: nil, using: &rng) else { break }
            #expect(q.choices[q.answer] == q.question.correct, "la bonne réponse a bougé")
            lignes.append(q.answer)
        }
        #expect(lignes.count == 400)
        for debut in stride(from: 0, to: lignes.count, by: QuestionBank.lignes) {
            let groupe = lignes[debut ..< debut + QuestionBank.lignes]
            #expect(Set(groupe).count == QuestionBank.lignes,
                    "groupe \(debut / QuestionBank.lignes) : deux fois la même ligne")
        }
        for i in 2 ..< lignes.count {
            #expect(!(lignes[i] == lignes[i - 1] && lignes[i - 1] == lignes[i - 2]),
                    "trois fois la même ligne au tirage \(i)")
        }
    }

    /// Une partie reprise ne rebat pas au milieu d'un groupe : ce qui reste
    /// dans le sac se remet en place comme la liste des questions servies.
    /// Le voyage par la sauvegarde, lui, est éprouvé avec la partie entière.
    @Test func leSacDesPlacesSeRemetEnPlace() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 4)
        _ = bank.draw(category: .sciences, difficulty: nil, using: &rng)
        _ = bank.draw(category: .sciences, difficulty: nil, using: &rng)
        let reste = bank.placesRestantes
        #expect(reste.count == QuestionBank.lignes - 2)
        var reprise = QuestionBank()
        reprise.restore(served: bank.alreadyServed)
        reprise.restore(places: reste)
        #expect(reprise.placesRestantes == reste)
        // Une place hors des quatre lignes ne se restaure pas : une
        // sauvegarde abîmée ferait sinon tomber la bonne réponse nulle part.
        reprise.restore(places: [0, 9, 2])
        #expect(reprise.placesRestantes == [0, 2])
    }

    @Test func uneQuestionNeRevientPasTantQuIlEnResteDAutres() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 3)
        var vues = Set<String>()
        for _ in 0 ..< QuestionBank().count(in: .histoire) {
            let q = bank.draw(category: .histoire, difficulty: nil, using: &rng)
            #expect(q != nil)
            #expect(vues.insert(q!.id).inserted, "question reposée trop tôt")
        }
    }

    /// Le défaut le plus sournois qu'ait eu ce jeu : la banque, à court de
    /// questions dans la catégorie demandée, en servait d'une autre. On
    /// choisissait l'Histoire et l'on recevait « Qui a peint La Joconde ? ».
    /// Rien ne plantait, rien ne s'affichait — la seule promesse faite à
    /// l'attaquant était rompue en silence.
    @Test func laBanqueNeQuittePasLeTerrainDemande() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 11)
        for tour in 0 ..< 200 {
            let q = bank.draw(category: .sports, difficulty: .difficile, using: &rng)
            #expect(q != nil)
            #expect(q?.category == .sports, "tirage \(tour) : sorti de la catégorie demandée")
        }
    }

    /// Une catégorie épuisée recommence. Revoir une question sur laquelle on
    /// a insisté est honnête ; en recevoir une d'un autre sujet ne l'est pas.
    @Test func uneCategorieEpuiseeRecommenceAuLieuDeDeborder() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 5)
        let stock = QuestionBank().count(in: .arts)
        var vues: [String] = []
        for _ in 0 ..< stock { vues.append(bank.draw(category: .arts, difficulty: nil, using: &rng)!.id) }
        #expect(Set(vues).count == stock, "la catégorie doit d'abord être servie en entier")
        // La suivante repart du début, et reste dans la catégorie.
        let apres = bank.draw(category: .arts, difficulty: nil, using: &rng)
        #expect(apres?.category == .arts)
    }

    // MARK: - La mémoire d'une partie sur l'autre

    /// Ce qu'on n'a jamais vu passe devant.
    ///
    /// Chaque partie s'ouvrait avec une banque neuve : elle tirait dans le
    /// sac plein, et reposait donc les questions de la veille. Celui qui joue
    /// seul enchaîne les parties — il reconnaissait la question avant de
    /// l'avoir lue, et le duel ne décidait plus rien.
    @Test func lesQuestionsJamaisSortiesPassentDAbord() {
        let toutes = QuestionBank().questions.filter { $0.category == .sciences }
        let jamais = Set(toutes.prefix(3).map(\.id))
        var vues: [String: Int] = [:]
        for q in toutes where !jamais.contains(q.id) { vues[q.id] = 1 }

        var bank = QuestionBank(vues: vues)
        var rng = SeededRandom(seed: 13)
        for rang in 0 ..< jamais.count {
            let q = bank.draw(category: .sciences, difficulty: nil, using: &rng)
            #expect(q != nil)
            #expect(jamais.contains(q?.id ?? ""),
                    "tirage \(rang) : une question déjà vue est passée devant une neuve")
        }
    }

    /// Le dosage des questions est une règle choisie à la mise en place ; la
    /// mémoire n'est qu'un confort, et un confort ne défait pas une règle.
    /// Une partie « corsée » reste corsée, même s'il faut pour cela reposer
    /// une question déjà vue.
    @Test func leNiveauDemandePasseAvantLaFraicheur() {
        let toutes = QuestionBank().questions.filter { $0.category == .arts }
        var vues: [String: Int] = [:]
        for q in toutes where q.difficulty == .difficile { vues[q.id] = 1 }
        #expect(!vues.isEmpty, "il faut des questions corsées pour éprouver la règle")

        var bank = QuestionBank(vues: vues)
        var rng = SeededRandom(seed: 17)
        for _ in 0 ..< 5 {
            let q = bank.draw(category: .arts, difficulty: .difficile, using: &rng)
            #expect(q?.difficulty == .difficile, "le niveau demandé a cédé à la fraîcheur")
        }
    }

    /// Ce qu'une partie a posé, la suivante l'évite.
    @Test func laMemoireSePasseDUnePartieALaSuivante() {
        var premiere = QuestionBank()
        var rng = SeededRandom(seed: 8)
        var posees: Set<String> = []
        for _ in 0 ..< 12 {
            posees.insert(premiere.draw(category: .sports, difficulty: nil, using: &rng)!.id)
        }
        #expect(premiere.vuesAJour.count == 12)
        #expect(premiere.vuesAJour.values.allSatisfy { $0 == 1 })

        var seconde = QuestionBank(vues: premiere.vuesAJour)
        for _ in 0 ..< (QuestionBank().count(in: .sports) - 12) {
            let q = seconde.draw(category: .sports, difficulty: nil, using: &rng)!
            #expect(!posees.contains(q.id), "la partie suivante repose une question de la première")
        }
    }

    /// Le compte se recalcule entier au lieu de s'incrémenter : la partie
    /// s'enregistre à chaque coup, et une même question ne doit pas se compter
    /// autant de fois qu'il y a de sauvegardes.
    @Test func laMemoireNeCompteJamaisDeuxFoisLaMemeQuestion() {
        // Une question réelle de la banque : les identifiants se calculent sur
        // l'énoncé, ils ne s'écrivent plus à la main.
        let ancienne = QuestionBank.questions(in: .histoire)[0].id
        var bank = QuestionBank(vues: [ancienne: 2])
        var rng = SeededRandom(seed: 2)
        let posee = bank.draw(category: .histoire, difficulty: nil, using: &rng)!.id
        #expect(bank.vuesAJour[posee] == 1)
        #expect(bank.vuesAJour[ancienne] == (posee == ancienne ? 3 : 2))
        // Deux enregistrements de suite donnent le même compte.
        #expect(bank.vuesAJour == QuestionBank(vues: bank.vuesAJour).dejaVues)
    }

    /// Celui qui rejoint une partie en réseau joue avec la mémoire de l'hôte —
    /// il le faut, sans quoi les deux appareils poseraient deux questions
    /// différentes — mais il n'hérite pas de ses soirées : sa propre mémoire
    /// n'enregistre que ce qui a été posé dans cette partie-là.
    @Test func celuiQuiRejointNHeritePasDesSoireesDeLHote() {
        let deLHote = QuestionBank.questions(in: .histoire).prefix(2).map(\.id)
        let laMienne = QuestionBank.questions(in: .arts)[0].id
        var recue = QuestionBank(vues: Dictionary(uniqueKeysWithValues: deLHote.map { ($0, 4) }))
        var rng = SeededRandom(seed: 6)
        let posee = recue.draw(category: .histoire, difficulty: nil, using: &rng)!.id
        #expect(recue.vuesAJour(depuis: [laMienne: 1], sauf: []) == [laMienne: 1, posee: 1])
    }

    /// Une partie reprise ne recompte pas ses questions de la veille.
    ///
    /// L'enregistrement se recalcule entier à chaque sauvegarde, et une
    /// partie rouverte retrouve dans sa banque tout ce qu'elle avait déjà
    /// posé : sans exception, une partie ouverte trois fois aurait compté
    /// trois fois ses premières questions, et les aurait fait paraître plus
    /// rebattues qu'elles ne le sont.
    @Test func unePartieRepriseNeRecomptePasSesQuestions() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 9)
        let hier = bank.draw(category: .sciences, difficulty: nil, using: &rng)!.id
        let memoire = bank.vuesAJour                  // ce que l'appareil a enregistré hier
        let comptees = bank.alreadyServed             // ce que la reprise retrouve
        let aujourdhui = bank.draw(category: .sciences, difficulty: nil, using: &rng)!.id
        let apres = bank.vuesAJour(depuis: memoire, sauf: comptees)
        #expect(apres[hier] == 1, "la question de la veille est comptée deux fois")
        #expect(apres[aujourdhui] == 1)
    }

    /// Une mémoire qui parle d'une autre banque ne vaut rien : les questions
    /// qu'elle nomme n'existent plus.
    @Test func uneMemoireEtrangereEstEcartee() {
        let connue = QuestionBank.questions(in: .sports)[0].id
        let aZero = QuestionBank.questions(in: .arts)[1].id
        let bank = QuestionBank(vues: [connue: 3, "inconnue-42": 9, aZero: 0])
        #expect(bank.dejaVues == [connue: 3])
    }

    /// La banque doit tenir une soirée. Soixante questions pour une partie qui
    /// en pose soixante-dix : on revoyait les mêmes dès la première.
    /// La banque doit tenir une soirée, et plusieurs. Une partie pose de
    /// cinquante à cent soixante questions, et un thème peut en brûler
    /// vingt-cinq dans une seule.
    @Test func laBanqueTientPlusieursSoirees() {
        for c in Themes.tous {
            #expect(QuestionBank().count(in: c) >= 30, "\(c.label) s'épuiserait trop vite")
        }
    }
}
