//
//  ArchivesTests.swift
//  RiskeloTests
//
//  La bibliothèque promet de rendre exactement la position qu'on lui a
//  confiée. C'est une promesse qu'on ne peut pas vérifier à l'œil : une
//  position restaurée de travers ressemble à une position.
//

import Foundation
import Testing
@testable import Riskelo

struct ArchivesTests {

    private func rayonNeuf() -> Archives {
        let d = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("riskelo-tests-\(UUID().uuidString)", isDirectory: true)
        return Archives(dossier: d)
    }

    private func partie(_ seed: UInt64 = 42) -> GameState {
        GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")], seed: seed)
    }

    @Test func lInstantRenduEstLInstantConfie() {
        let rayon = rayonNeuf()
        var g = partie()
        g.debugSkipToAttack()
        let id = UUID()
        rayon.ranger(g, partie: id, etiquette: "Tour 1")

        guard let m = rayon.liste().first?.moments.first,
              let repris = rayon.charger(m) else {
            Issue.record("rien de rangé"); return
        }
        #expect(repris.turn == g.turn)
        #expect(repris.current == g.current)
        #expect(repris.map.order.allSatisfy { repris.owner[$0] == g.owner[$0] })
        #expect(repris.map.order.allSatisfy { repris.armies($0) == g.armies($0) })
        // Le tirage aussi, sans quoi la suite ne serait plus la même partie.
        #expect(repris.digest == g.digest)
    }

    /// Un instant par tour, et non un par coup : sans quoi une partie de dix
    /// tours déposerait mille positions indiscernables.
    @Test func unSeulInstantParTour() {
        let rayon = rayonNeuf()
        var g = partie()
        let id = UUID()
        for _ in 0 ..< 5 { rayon.ranger(g, partie: id, etiquette: "Tour \(g.turn)") }
        #expect(rayon.liste().first?.moments.count == 1)

        // Une marque posée à la main passe outre : c'est tout son objet.
        rayon.ranger(g, partie: id, etiquette: "Position marquée", marque: true)
        #expect(rayon.liste().first?.moments.count == 2)
        #expect(rayon.liste().first?.moments.last?.marque == true)

        // Le tour du joueur suivant, lui, dépose le sien — et c'est bien le
        // camp qui le distingue : `turn` ne bouge qu'au bout de la table.
        let tourAvant = g.turn
        g.debugSkipToFortify()
        g.endTurn()
        #expect(g.turn == tourAvant, "à deux joueurs, le compteur ne bouge qu'au second")
        rayon.ranger(g, partie: id, etiquette: "Tour \(g.turn) — \(g.currentPlayer.name)")
        #expect(rayon.liste().first?.moments.count == 3)
        #expect(rayon.liste().first?.moments.last?.camp == g.current)
    }

    @Test func laListePorteDeQuoiReconnaitreUnePartie() {
        let rayon = rayonNeuf()
        var r = Rules(); r.mode = .faceAFace
        var g = GameState.start(board: .europe,
                                players: [Player(id: 0, name: "Bleu"),
                                          Player(id: 1, name: "Rouge",
                                                 kind: .machine(niveau: 0.6, style: .forte))],
                                rules: r, seed: 7)
        g.debugSkipToAttack()
        rayon.ranger(g, partie: UUID(), etiquette: "Tour 1")

        guard let p = rayon.liste().first else { Issue.record("rien de rangé"); return }
        #expect(p.plateau == .europe)
        #expect(p.mode == .faceAFace)
        #expect(p.joueurs == ["Bleu", "Rouge"])
        #expect(p.machines == [1])
        #expect(!p.estTerminee)
        // Le rapport de forces est dans l'index : la liste doit le dessiner
        // sans ouvrir un seul état.
        let compte = p.moments[0].territoires
        #expect(compte.reduce(0, +) == g.map.order.count)
    }

    @Test func supprimerEmporteLesFichiers() {
        let rayon = rayonNeuf()
        let g = partie()
        let id = UUID()
        rayon.ranger(g, partie: id, etiquette: "Tour 1")
        guard let m = rayon.liste().first?.moments.first else {
            Issue.record("rien de rangé"); return
        }
        rayon.supprimer(id)
        #expect(rayon.liste().isEmpty)
        #expect(rayon.charger(m) == nil, "l'état ne doit plus traîner sur le disque")
    }

    /// Le rayon ne grossit pas sans fin.
    @Test func lesVieillesPartiesSEnVont() {
        let rayon = rayonNeuf()
        let g = partie()
        for _ in 0 ..< (Archives.partiesGardees + 4) {
            rayon.ranger(g, partie: UUID(), etiquette: "Tour 1")
        }
        #expect(rayon.liste().count == Archives.partiesGardees)
    }
}
