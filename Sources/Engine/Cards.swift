//
//  Cards.swift
//  Riskelo
//
//  Les cartes de territoire, comme dans la boîte.
//
//  Une carte par territoire, plus deux jokers. On en tire une à la fin d'un
//  tour où l'on a pris au moins une place — c'est ce qui récompense l'audace
//  plutôt que l'attente. Trois cartes assorties s'échangent contre des hommes,
//  et le barème monte à chaque échange de la partie : quatre, six, huit, dix,
//  douze, quinze, puis cinq de plus à chaque fois. C'est ce qui empêche une
//  partie de s'enliser — plus elle dure, plus les échanges pèsent.
//
//  La règle est une option : elle change l'économie des renforts, et le
//  plateau se joue très bien sans elle.
//

import Foundation

struct Card: Codable, Equatable, Hashable, Identifiable {

    enum Symbol: Int, Codable, CaseIterable {
        case infanterie, cavalerie, artillerie

        var label: String {
            switch self {
            case .infanterie: "Infanterie"
            case .cavalerie:  "Cavalerie"
            case .artillerie: "Artillerie"
            }
        }

        var icone: String {
            switch self {
            case .infanterie: "figure.walk"
            case .cavalerie:  "hare.fill"
            case .artillerie: "burst.fill"
            }
        }
    }

    let id: Int
    /// Le territoire qu'elle porte. Absent, c'est un joker.
    let territory: TerritoryID?
    let symbol: Symbol

    var estJoker: Bool { territory == nil }
}

enum Deck {

    /// Le paquet d'un plateau : une carte par territoire, deux jokers.
    /// Les symboles sont distribués en tournant, pour qu'aucun ne manque.
    static func build(for map: GameMap) -> [Card] {
        var cartes = map.order.enumerated().map { rang, id in
            Card(id: rang, territory: id,
                 symbol: Card.Symbol.allCases[rang % Card.Symbol.allCases.count])
        }
        cartes.append(Card(id: cartes.count, territory: nil, symbol: .infanterie))
        cartes.append(Card(id: cartes.count, territory: nil, symbol: .infanterie))
        return cartes
    }

    /// Trois cartes forment-elles une combinaison ?
    ///
    /// Trois symboles identiques, ou trois différents. Un joker remplace
    /// n'importe quoi — avec un joker, deux cartes quelconques suffisent
    /// toujours à compléter l'un ou l'autre cas.
    static func estUneCombinaison(_ cartes: [Card]) -> Bool {
        guard cartes.count == 3, Set(cartes.map(\.id)).count == 3 else { return false }
        let vraies = cartes.filter { !$0.estJoker }.map(\.symbol)
        if vraies.count < 3 { return true }
        return Set(vraies).count == 1 || Set(vraies).count == 3
    }

    /// La première combinaison trouvée dans une main, s'il y en a une.
    static func premiereCombinaison(dans main: [Card]) -> [Card]? {
        guard main.count >= 3 else { return nil }
        for i in main.indices {
            for j in main.indices where j > i {
                for k in main.indices where k > j {
                    let trio = [main[i], main[j], main[k]]
                    if estUneCombinaison(trio) { return trio }
                }
            }
        }
        return nil
    }

    /// Le barème du Risk : 4, 6, 8, 10, 12, 15, puis cinq de plus à chaque
    /// échange. `rang` est le numéro de l'échange dans la partie, à partir de 1.
    static func valeur(echangeNumero rang: Int) -> Int {
        let bareme = [4, 6, 8, 10, 12, 15]
        guard rang >= 1 else { return bareme[0] }
        if rang <= bareme.count { return bareme[rang - 1] }
        return 15 + 5 * (rang - bareme.count)
    }
}
