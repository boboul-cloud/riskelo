//
//  Helpers.swift
//  RiskeloTests
//
//  De quoi amener une partie à l'endroit qu'on veut examiner, sans rien
//  ouvrir dans le moteur : tout passe par les coups ordinaires, plus la
//  seule porte prévue pour cela, `seize`.
//

import Foundation
@testable import Riskelo

extension GameState {

    /// Solde les renforts sur ses propres terres et ouvre la phase d'attaque.
    mutating func debugSkipToAttack() {
        guard case let .reinforcement(reste) = phase else { return }
        let chezMoi = territories(of: currentPlayer.id)[0]
        for _ in 0 ..< reste { place(on: chezMoi) }
    }

    mutating func debugSkipToFortify() {
        debugSkipToAttack()
        advance()
    }

    /// Compose un assaut net : une base à soi, une cible voisine à l'ennemi,
    /// et les garnisons voulues de part et d'autre.
    mutating func debugFirstAssault(minArmies: Int, targetArmies: Int)
    -> (base: TerritoryID, cible: TerritoryID)? {
        let moi = currentPlayer.id
        guard let base = territories(of: moi).first(where: { !targets(from: $0).isEmpty }),
              let cible = targets(from: base).first, let lautre = owner[cible] else { return nil }
        seize(base, by: moi, armies: minArmies)
        seize(cible, by: lautre, armies: targetArmies)
        return (base, cible)
    }
}
