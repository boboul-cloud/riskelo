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
}
