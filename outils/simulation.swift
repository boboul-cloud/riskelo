//
//  simulation.swift
//  Riskelo — outil, hors application
//
//  Mille parties en une seconde, machine contre machine.
//
//  Aucun réglage de ce jeu n'a été choisi à vue : le sablier, l'écart de
//  victoire, la compensation de rang, l'audace de l'adversaire sortent tous
//  de ce banc d'essai. Il est ici pour qu'on puisse le refaire — changer une
//  manette dans Rules.swift et savoir en dix secondes ce qu'elle coûte.
//
//  Ce fichier ne fait pas partie de la cible : le moteur étant du Swift pur,
//  il se compile seul.
//
//      swiftc -O -parse-as-library -o /tmp/sim \
//          Sources/Engine/*.swift outils/simulation.swift && /tmp/sim
//

import Foundation

func partie(seed: UInt64, niveaux: [Double], rules: Rules, maxTours: Int = 400,
            styles: [Bot.Style] = [])
-> (winner: Int?, tours: Int, duels: Int) {
    let joueurs = niveaux.enumerated().map { i, n in
        Player(id: i, name: "J\(i)",
               kind: .machine(niveau: n,
                              style: i < styles.count ? styles[i] : .forte))
    }
    var g = GameState.start(players: joueurs, rules: rules, seed: seed)
    var duels = 0, garde = 0
    while !g.isOver && g.turn <= maxTours && garde < 500_000 {
        garde += 1
        let pas = BotRunner.step(&g)
        if case .answered = pas { duels += 1 }
        // Un tour qui ne bouge plus se solde : la machine a fini de jouer.
        if pas == .idle, g.phase == .fortify { g.endTurn() }
    }
    if case let .finished(w) = g.phase { return (w, g.turn, duels) }
    return (nil, g.turn, duels)
}

@discardableResult
func campagne(_ titre: String, niveaux: [Double], n: Int, rules: Rules = Rules(),
              styles: [Bot.Style] = []) -> [Int] {
    var victoires = [Int: Int](), inacheves = 0, toursTotal = 0, duelsTotal = 0
    for i in 0 ..< n {
        let r = partie(seed: UInt64(i &* 2_654_435_761 &+ 12_345), niveaux: niveaux,
                       rules: rules, styles: styles)
        if let w = r.winner { victoires[w, default: 0] += 1 } else { inacheves += 1 }
        toursTotal += r.tours
        duelsTotal += r.duels
    }
    let parts = niveaux.indices.map {
        "J\($0) \(Int(100.0 * Double(victoires[$0] ?? 0) / Double(n)))%"
    }
    print("\(titre.padding(toLength: 26, withPad: " ", startingAt: 0)) \(parts.joined(separator: " | "))"
          + "   inachevées \(inacheves)   tours ~\(toursTotal / n)   questions ~\(duelsTotal / n)")
    return niveaux.indices.map { victoires[$0] ?? 0 }
}

@main
struct Simulation {
    static func main() {
        // MARK: - Le plateau et la banque


        let plateau = TestBoard.board
        print("PLATEAU — \(plateau.map.order.count) territoires, "
              + "\(plateau.map.continentsInOrder.count) continents, "
              + "d'un seul tenant : \(plateau.map.isConnected)")
        for c in plateau.map.continentsInOrder {
            let portes = Set(c.territories.filter { id in
                plateau.map.neighbors(of: id).contains { plateau.map[$0]?.continent != c.id }
            })
            print("   \(c.name) — \(c.territories.count) territoires, bonus \(c.bonus), \(portes.count) portes")
        }
        print("BANQUE — \(QuestionBank().count) questions : "
              + Category.allCases.map { "\($0.label.prefix(4)) \(QuestionBank().count(in: $0))" }
                .joined(separator: ", "))

        // MARK: - Le duel

        print("\nSABLIER —", (0..<6).map { String(format: "%.1f s", Rules().answerTime(siege: $0)) }
            .joined(separator: " → "))
        print("LE DÉFENSEUR TIENT (culture 0,70) —",
              (0..<6).map { s -> String in
                  let t = Rules().answerTime(siege: s)
                  let p = Difficulty.allCases.map {
                      Bot.probability(level: 0.70, difficulty: $0, allowance: t, rules: Rules())
                  }
                  return String(format: "%.0f%%", 100 * (0.4 * p[0] + 0.4 * p[1] + 0.2 * p[2]))
              }.joined(separator: " → "))

        for n in 2...5 {
            print("   \(n) joueurs : départ \(plateau.map.order.count / n) territoires, "
                  + "victoire à \(Rules().dominationThreshold(territories: plateau.map.order.count, playerCount: n)), "
                  + "compensation +\(Rules().compensation(playerCount: n)) par rang")
        }

        // MARK: - Le stratège contre le gourmand

        print("\n=== LE STRATÈGE CONTRE LE GOURMAND, À CULTURE ÉGALE ===")
        print("   (J0 = stratège, J1 = gourmand — puis l'inverse, pour ôter l'avantage du rang)")
        for plateau in Boards.allCases {
            var r = Rules()
            _ = plateau
            for (nom, styles) in [("stratège en premier", [Bot.Style.forte, .facile]),
                                  ("gourmand en premier", [Bot.Style.facile, .forte])] {
                campagne("\(plateau.label) — \(nom)", niveaux: [0.70, 0.70], n: 400,
                         rules: r, styles: styles)
            }
            r.territoryCards = true
            campagne("\(plateau.label) — avec cartes", niveaux: [0.70, 0.70], n: 300,
                     rules: r, styles: [.forte, .facile])
        }

        print("\n=== ET LE STRATÈGE CONTRE LUI-MÊME (l'équilibre doit tenir) ===")
        campagne("2 j. culture égale", niveaux: [0.70, 0.70], n: 500)
        campagne("2 j. 0,75 / 0,70", niveaux: [0.75, 0.70], n: 500)
        campagne("3 j. culture égale", niveaux: [0.70, 0.70, 0.70], n: 300)
        campagne("4 j. culture égale", niveaux: [0.70, 0.70, 0.70, 0.70], n: 250)
    }
}
