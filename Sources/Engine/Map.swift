//
//  Map.swift
//  Riskelo
//
//  Le territoire, le continent, et ce qui touche quoi.
//
//  Deux choses sont séparées ici, et il faut qu'elles le restent : la carte
//  au sens des règles — qui est voisin de qui, quel continent vaut combien —
//  et le dessin du plateau. La première décide des coups permis ; la seconde
//  n'est qu'une façon de la montrer. Le plateau d'essai est un damier
//  d'hexagones ; le jour où une vraie carte du monde le remplacera, seule la
//  seconde partie changera.
//

import Foundation

typealias TerritoryID = String
typealias ContinentID = String
typealias PlayerID = Int

/// Un point du plateau, en coordonnées normalisées 0…1. Ni CGPoint ni SwiftUI :
/// le moteur doit pouvoir tourner seul, hors de toute application.
struct Point: Hashable, Codable {
    var x: Double
    var y: Double
}

struct Territory: Identifiable, Hashable {
    let id: TerritoryID
    let name: String
    let continent: ContinentID
    /// Les territoires attaquables depuis celui-ci, et réciproquement.
    var neighbors: [TerritoryID]
}

struct Continent: Identifiable, Hashable {
    let id: ContinentID
    let name: String
    /// Renfort supplémentaire par tour, pour qui le tient en entier.
    let bonus: Int
    let territories: [TerritoryID]
    /// Son rang sur le plateau, d'où la vue tire sa teinte. La couleur était
    /// auparavant accrochée à la lettre du plan — cinq lettres connues, et
    /// tous les continents d'un nouveau plateau se retrouvaient de la même
    /// couleur.
    let tint: Int
}

/// La carte au sens des règles.
struct GameMap {
    private(set) var territories: [TerritoryID: Territory]
    private(set) var continents: [ContinentID: Continent]
    /// Ordre de parcours stable : un dictionnaire n'en a pas, et une partie
    /// rejouée doit distribuer les territoires dans le même ordre.
    private(set) var order: [TerritoryID]

    init(territories: [Territory], continents: [Continent]) {
        self.territories = Dictionary(uniqueKeysWithValues: territories.map { ($0.id, $0) })
        self.continents = Dictionary(uniqueKeysWithValues: continents.map { ($0.id, $0) })
        self.order = territories.map(\.id)
    }

    subscript(id: TerritoryID) -> Territory? { territories[id] }

    func neighbors(of id: TerritoryID) -> [TerritoryID] { territories[id]?.neighbors ?? [] }

    func areAdjacent(_ a: TerritoryID, _ b: TerritoryID) -> Bool {
        territories[a]?.neighbors.contains(b) ?? false
    }

    var continentsInOrder: [Continent] {
        continents.values.sorted { $0.tint < $1.tint }
    }

    /// Le rang du continent auquel appartient ce territoire.
    func tint(of id: TerritoryID) -> Int {
        territories[id].flatMap { continents[$0.continent]?.tint } ?? 0
    }

    /// Toute la carte se tient-elle d'un seul tenant ? Un territoire isolé
    /// serait imprenable, et la partie ne pourrait plus finir.
    var isConnected: Bool {
        guard let start = order.first else { return false }
        var seen: Set<TerritoryID> = [start]
        var stack = [start]
        while let id = stack.popLast() {
            for n in neighbors(of: id) where !seen.contains(n) {
                seen.insert(n)
                stack.append(n)
            }
        }
        return seen.count == territories.count
    }

    /// Les liens qui franchissent une frontière de continent. C'est par là que
    /// passe toute la tension du plateau : trop nombreux, aucun continent ne se
    /// défend ; trop rares, la partie s'enlise.
    var continentalGateways: [(TerritoryID, TerritoryID)] {
        var seen = Set<String>()
        var links: [(TerritoryID, TerritoryID)] = []
        for id in order {
            guard let t = territories[id] else { continue }
            for n in t.neighbors {
                guard let other = territories[n], other.continent != t.continent else { continue }
                let key = [id, n].sorted().joined(separator: "|")
                if seen.insert(key).inserted { links.append((id, n)) }
            }
        }
        return links
    }
}

/// Une traversée : deux territoires que la mer sépare et qu'une route relie.
///
/// Sur un damier d'hexagones, seules les cases qui se touchent sont voisines.
/// C'est ce qui met les voisinages à l'abri de la faute — mais cela interdit
/// les îles et les détroits, donc toute carte qui ressemble au monde. Les
/// traversées sont donc déclarées à la main, une poignée par plateau, et les
/// tests vérifient qu'elles sont réciproques et qu'elles mènent quelque part.
/// C'est ainsi que le Risk d'origine procède : Alaska–Kamtchatka,
/// Brésil–Afrique du Nord.
struct SeaRoute: Hashable {
    let from: TerritoryID
    let to: TerritoryID
}

/// Où poser chaque territoire à l'écran. Pure présentation.
struct BoardLayout {
    /// Centre de chaque territoire, en 0…1.
    var centers: [TerritoryID: Point]
    /// Rayon du cercle circonscrit d'une case, dans les mêmes unités.
    var cellRadius: Double
    /// Hauteur du plateau rapportée à sa largeur. Les centres sont normalisés
    /// sur x seul : mettre x et y chacun sur 0…1 écraserait les hexagones dès
    /// que la carte n'est pas carrée. C'est à la vue de réserver la bonne
    /// hauteur, pas au plateau de se déformer.
    var aspect: Double
    /// Les arêtes de chaque case qui donnent sur un autre continent ou sur la
    /// mer — celles qui font la frontière. Numérotées comme les sommets :
    /// l'arête `k` joint le sommet `k` au suivant.
    ///
    /// Sans elles, un continent est invisible : les cases portent la couleur
    /// de celui qui les tient, pas celle de la terre à laquelle elles
    /// appartiennent, et le joueur ne peut pas voir ce qu'il lui reste à
    /// prendre pour toucher le bonus.
    var frontierEdges: [TerritoryID: Set<Int>] = [:]

    /// Les traversées, pour les tracer : une liaison qu'on ne voit pas est
    /// une liaison qui n'existe pas, du point de vue du joueur.
    var seaRoutes: [SeaRoute] = []

    /// Sommets de la case, prêts à tracer.
    func corners(of id: TerritoryID) -> [Point] {
        guard let c = centers[id] else { return [] }
        // Hexagone « pointe en haut » : le premier sommet est plein nord.
        return (0..<6).map { i -> Point in
            let angle = Double(i) * .pi / 3 - .pi / 2
            return Point(x: c.x + cellRadius * cos(angle),
                         y: c.y + cellRadius * sin(angle))
        }
    }
}

/// Une carte et son dessin, livrés ensemble.
struct Board {
    var map: GameMap
    var layout: BoardLayout
}
