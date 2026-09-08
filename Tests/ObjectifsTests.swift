//
//  ObjectifsTests.swift
//  RiskeloTests
//
//  Une conquête personnelle se joue en secret : elle ne se vérifie donc pas
//  en jouant. Si elle se remplit sans qu'on s'en aperçoive, ou si elle devient
//  impossible sans se retourner, personne ne le signalera — le joueur croira
//  simplement que la partie a mal tourné.
//

import Foundation
import Testing
@testable import Riskelo

struct ObjectifsTests {

    private func avecObjectifs() -> Rules {
        var r = Rules()
        r.objectifs = true
        return r
    }

    private func partie(_ n: Int = 2, seed: UInt64 = 42) -> GameState {
        GameState.start(players: (0..<n).map { Player(id: $0, name: "J\($0)") },
                        rules: avecObjectifs(), seed: seed)
    }

    /// Tout le plateau à un seul camp : de quoi poser une situation sans que
    /// la distribution de départ vienne compter dans le dos du test.
    private func vider(_ g: inout GameState, pour joueur: PlayerID = 1) {
        for id in g.map.order { g.seize(id, by: joueur, armies: 1) }
    }

    // MARK: - Le paquet et sa distribution

    @Test func chacunRecoitUneConqueteEtUneSeule() {
        var rng = SeededRandom(seed: 3)
        let donnes = Objectif.distribuer(pour: Boards.monde.board, joueurs: 4, using: &rng)
        #expect(donnes.count == 4)
        #expect(Set(donnes.values).count == 4, "deux joueurs ont reçu la même conquête")
        for (rang, carte) in donnes {
            #expect(carte != .eliminer(rang), "on ne demande à personne de disparaître")
        }
    }

    /// Les deux appareils rejouent la même partie : ils doivent distribuer les
    /// mêmes conquêtes, sinon chacun joue à un jeu différent sans le savoir.
    @Test func leTirageEstReproductible() {
        var a = SeededRandom(seed: 9), b = SeededRandom(seed: 9)
        let ici = Objectif.distribuer(pour: Boards.anneau.board, joueurs: 3, using: &a)
        let laBas = Objectif.distribuer(pour: Boards.anneau.board, joueurs: 3, using: &b)
        #expect(ici == laBas)
    }

    /// À deux, « faites tomber le camp d'en face » n'est pas une conquête
    /// personnelle : c'est la partie ordinaire.
    @Test func aDeuxLaDisparitionNEntrePasAuPaquet() {
        let paquet = Objectif.paquet(pour: Boards.anneau.board, joueurs: 2)
        #expect(!paquet.contains { if case .eliminer = $0 { true } else { false } })
        #expect(Objectif.paquet(pour: Boards.anneau.board, joueurs: 3)
            .contains { if case .eliminer = $0 { true } else { false } })
    }

    /// Chaque plateau doit avoir de quoi servir quatre joueurs, et aucune
    /// conquête ne doit demander plus que le seuil de domination — elle ne
    /// serait plus un raccourci mais un détour.
    @Test(arguments: Boards.allCases)
    func chaquePlateauADeQuoiDistribuer(_ plateau: Boards) {
        let board = plateau.board
        let paquet = Objectif.paquet(pour: board, joueurs: 4)
        #expect(paquet.count >= 8, "\(plateau.label) : seulement \(paquet.count) conquêtes")

        let seuil = Rules().dominationThreshold(territories: board.map.order.count,
                                                playerCount: 2)
        for carte in paquet {
            switch carte {
            case .continents(let ids):
                let taille = ids.reduce(0) { $0 + (board.map.continents[$1]?.territories.count ?? 0) }
                #expect(taille < seuil,
                        "\(plateau.label) : \(ids) demande \(taille) places pour un seuil de \(seuil)")
            case let .territoires(nombre, _):
                #expect(nombre <= seuil,
                        "\(plateau.label) : \(nombre) places demandées pour un seuil de \(seuil)")
            case .eliminer:
                break
            }
        }
    }

    // MARK: - Ce qu'elles demandent

    @Test func tenirLesContinentsDemandes() {
        var g = partie()
        let vises = g.map.continentsInOrder.prefix(2).map(\.id)
        vider(&g)
        g.seize(objectif: .continents(Array(vises)), of: 0)
        #expect(!g.objectifAccompli(0))

        for id in vises.dropLast() {
            for t in g.map.continents[id]!.territories { g.seize(t, by: 0, armies: 1) }
        }
        #expect(!g.objectifAccompli(0), "un continent sur deux ne suffit pas")

        for t in g.map.continents[vises.last!]!.territories { g.seize(t, by: 0, armies: 1) }
        #expect(g.objectifAccompli(0))
    }

    /// « Tenir tant de places avec deux hommes » ne compte pas les places
    /// tenues à un seul : c'est toute la différence entre les deux cartes.
    @Test func lesPlacesComptentLeursHommes() {
        var g = partie()
        vider(&g)
        let mien = Array(g.map.order.prefix(4))
        for id in mien { g.seize(id, by: 0, armies: 1) }
        g.seize(objectif: .territoires(nombre: 3, hommes: 2), of: 0)
        #expect(g.territoires(de: 0, dAuMoins: 1) == 4)
        #expect(!g.objectifAccompli(0), "quatre places à un homme ne valent pas trois à deux")

        for id in mien.prefix(3) { g.seize(id, by: 0, armies: 2) }
        #expect(g.objectifAccompli(0))
    }

    @Test func laDisparitionCompteQuandCEstVousQuiLAvezFaite() {
        var g = partie(3)
        g.seize(objectif: .eliminer(2), of: 0)
        #expect(!g.objectifAccompli(0))
        g.seize(elimine: 2, par: 0)
        #expect(g.objectifAccompli(0))
    }

    /// La carte se retourne quand un tiers vous prend votre proie : sans cela
    /// l'objectif deviendrait impossible sans qu'on y puisse rien, et le
    /// joueur passerait le reste de la partie à ne plus pouvoir gagner.
    @Test func laCarteSeRetourneQuandUnAutreFaitTomberLaCible() {
        var g = partie(3)
        g.seize(objectif: .eliminer(2), of: 0)
        #expect(g.objectif(de: 0) == .eliminer(2))
        g.seize(elimine: 2, par: 1)
        #expect(g.objectif(de: 0) == Objectif.repli(g.board))
        #expect(!g.objectifAccompli(0), "le repli ne se gagne pas tout seul")
    }

    /// Et de même si le sort désigne votre propre camp — le paquet l'évite,
    /// mais une sauvegarde d'une autre version pourrait le porter.
    @Test func onNeSeFaitPasDisparaitreSoiMeme() {
        var g = partie(3)
        g.seize(objectif: .eliminer(0), of: 0)
        #expect(g.objectif(de: 0) == Objectif.repli(g.board))
    }

    // MARK: - La fin de partie

    @Test func laPartieSArreteDesQueLaConqueteEstRemplie() {
        var g = partie()
        vider(&g)
        let mien = Array(g.map.order.prefix(2))
        for id in mien { g.seize(id, by: 0, armies: 1) }
        g.seize(objectif: .territoires(nombre: 2, hommes: 2), of: 0)

        #expect(!g.isOver)
        g.place(on: mien[0])
        #expect(!g.isOver, "une place sur deux ne finit pas la partie")
        g.place(on: mien[1])
        #expect(g.isOver)
        if case let .finished(winner) = g.phase {
            #expect(winner == 0)
        } else {
            Issue.record("la partie devait être gagnée")
        }
        #expect(g.journal.last?.kind == .fin)
    }

    /// Sans la règle, rien n'est distribué et rien ne se vérifie : la partie
    /// est exactement celle d'avant.
    @Test func sansLaRegleRienNeChange() {
        var g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                rules: Rules(), seed: 7)
        #expect(g.objectifs.isEmpty)
        g.seize(objectif: .territoires(nombre: 1, hommes: 1), of: 0)
        #expect(!g.objectifAccompli(0), "la règle éteinte, la conquête ne compte pas")
    }

    @Test func lesConquetesSurviventALaSauvegarde() throws {
        var g = partie(3)
        g.seize(elimine: 2, par: 1)
        let relu = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(g))
        #expect(relu.objectifs == g.objectifs)
        #expect(relu.elimines == g.elimines)
        #expect(!relu.objectifs.isEmpty, "la partie devait en distribuer")
    }

    /// Ce que le joueur lit. Une conquête qui ne se dit pas en français ne
    /// sert à rien : c'est le seul endroit où il apprend ce qu'on lui demande.
    @Test func chaqueConqueteSeDit() {
        var g = partie(3)
        for carte in Objectif.paquet(pour: g.board, joueurs: 3) {
            g.seize(objectif: carte, of: 0)
            let texte = g.texte(carte)
            #expect(texte.count > 12 && texte.hasSuffix("."), "mal dite : \(texte)")
            #expect(!g.avancement(carte, pour: 0).isEmpty)
        }
    }

    // MARK: - Le seuil se retire

    /// La règle voulue : la conquête décide, ou personne. Le seuil ne doit
    /// plus pouvoir gagner une partie à conquêtes — il la gagnait cinq fois
    /// sur six à deux joueurs, et toutes les fois à quatre.
    @Test(arguments: Boards.allCases)
    func leSeuilSeRetireDevantLesConquetes(_ plateau: Boards) {
        let total = plateau.board.map.order.count
        for camps in 2 ... 4 {
            var r = Rules(); r.objectifs = true
            #expect(r.dominationThreshold(territories: total, playerCount: camps) == total,
                    "\(plateau.label) à \(camps) : le seuil passe encore devant la conquête")
            #expect(Rules().dominationThreshold(territories: total, playerCount: camps) < total,
                    "sans la règle, le seuil doit rester ce qu'il était")
        }
    }

    /// Tout le plateau moins une place ne gagne pas : il n'y a plus de compte
    /// à franchir, et c'est tout le propos.
    @Test func tenirPresqueToutNeGagnePas() {
        var g = partie()
        vider(&g, pour: 0)
        g.seize(g.map.order.last!, by: 1, armies: 1)
        g.seize(objectif: .continents([g.map[g.map.order.last!]!.continent]), of: 0)
        #expect(!g.dominates(0), "27 places sur 28 ne sont pas une victoire")
        #expect(!g.objectifAccompli(0))
    }

    /// Le repli porte le seuil, et pour lui seul. Moins cher, la malchance
    /// deviendrait un raccourci : celui dont on a tué la proie gagnerait plus
    /// vite que ceux qui doivent tenir des continents entiers.
    @Test(arguments: Boards.allCases)
    func leRepliDemandeQuatrePlacesSurCinq(_ plateau: Boards) {
        let total = plateau.board.map.order.count
        guard case let .territoires(nombre, hommes) = Objectif.repli(plateau.board) else {
            Issue.record("le repli doit être une conquête de territoires"); return
        }
        #expect(hommes == 1)
        #expect(nombre == Int((Double(total) * 0.80).rounded()),
                "\(plateau.label) : \(nombre) places au lieu de quatre sur cinq")
        for carte in Objectif.paquet(pour: plateau.board, joueurs: 4) {
            if case let .territoires(demande, exigence) = carte, exigence == 1 {
                #expect(demande < nombre,
                        "\(plateau.label) : le repli doit coûter plus cher que la carte ordinaire, sinon la carte morte est une aubaine")
            }
        }
    }

    // MARK: - Par quelle porte on a gagné

    /// L'écran de victoire doit le dire. Gagner au seuil avec sa conquête
    /// affichée juste en dessous, non remplie et sans un mot d'explication,
    /// se lit comme une règle en panne.
    @Test func lecranDeVictoireDitParQuellePorte() {
        var g = partie()
        vider(&g, pour: 0)
        #expect(g.porteDeLaVictoire(0) == .plateauEntier)

        // Une place laissée à l'autre camp, et la conquête remplie.
        g.seize(g.map.order.last!, by: 1, armies: 1)
        g.seize(objectif: .territoires(nombre: 2, hommes: 1), of: 0)
        #expect(g.porteDeLaVictoire(0) == .conquete)
        #expect(g.porteDite(0).contains(g.texte(g.objectif(de: 0)!)))

        // Sans la règle, c'est le seuil qui gagne, et il se nomme.
        var ordinaire = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                        rules: Rules(), seed: 42)
        for id in ordinaire.map.order.dropLast() { ordinaire.seize(id, by: 0, armies: 1) }
        ordinaire.seize(ordinaire.map.order.last!, by: 1, armies: 1)
        #expect(ordinaire.porteDeLaVictoire(0) == .seuil)
        #expect(ordinaire.porteDite(0).contains("\(ordinaire.dominationThreshold) territoires"))
    }

    /// Ce que le journal retient quand la carte paye : la phrase de la
    /// conquête, et non un compte de territoires. C'est elle qu'on relit pour
    /// comprendre pourquoi la partie s'est arrêtée là.
    @Test func leJournalRaconteLaConqueteQuandElleGagne() {
        var g = partie()
        let vises = g.map.continentsInOrder.sorted { $0.territories.count > $1.territories.count }
            .prefix(2).map(\.id)
        g.seize(objectif: .continents(Array(vises)), of: 0)
        vider(&g, pour: 0)

        // Une place du premier continent reste à l'autre camp, plus quelques
        // terres ailleurs pour qu'il survive à sa chute.
        let manquante = g.map.continents[vises[0]]!.territories[0]
        let ailleurs = g.map.order.filter { id in
            !vises.contains { g.map.continents[$0]!.territories.contains(id) }
        }.prefix(4)
        for id in ailleurs { g.seize(id, by: 1, armies: 1) }
        g.seize(manquante, by: 1, armies: 1)

        let base = g.map.neighbors(of: manquante).first { g.owner[$0] == 0 }!
        g.seize(base, by: 0, armies: 6)
        g.debugSkipToAttack()
        #expect(!g.dominates(0), "le seuil ne doit plus pouvoir gagner cette partie")
        #expect(!g.objectifAccompli(0))

        // C'est le défenseur qui répond : sa mauvaise réponse lui coûte la place.
        g.declareAssault(from: base, to: manquante, questions: 1, category: .histoire)
        let mauvaise = (g.assault!.current!.question.answer + 1) % 4
        g.answer(.chosen(mauvaise, elapsed: 2))
        #expect(g.isOver, "la conquête remplie doit arrêter la partie sur-le-champ")
        #expect(g.porteDeLaVictoire(0) == .conquete)
        #expect(g.journal.last?.text == g.recitDeLObjectif(0),
                "le journal n'a pas raconté la conquête : \(g.journal.last?.text ?? "rien")")
    }
}
