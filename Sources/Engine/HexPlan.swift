//
//  HexPlan.swift
//  Riskelo
//
//  Le plateau d'essai, écrit comme on le dessinerait sur un carnet.
//
//  Une carte de Risk se fabrique d'ordinaire à la main, territoire par
//  territoire, avec ses voisinages saisis un à un — et une erreur de voisinage
//  ne se voit pas : elle rend juste un territoire imprenable, trois parties
//  plus tard. Ici le plan est un damier d'hexagones décrit par un dessin en
//  toutes lettres ; les voisinages s'en déduisent, et ne peuvent donc pas être
//  faux. Le plateau se retouche en déplaçant une lettre.
//
//  Décalage « odd-r » : une ligne sur deux est poussée d'une demi-case vers la
//  droite, comme sur un nid d'abeilles.
//

import Foundation

enum HexPlan {

    struct ContinentSpec {
        let id: ContinentID
        let name: String
        let bonus: Int
        /// Les noms de territoires, consommés dans l'ordre de lecture du plan.
        let names: [String]
    }

    /// Construit carte et dessin à partir du plan. `rows` se lit ligne à ligne,
    /// un caractère par case ; le point est de la mer, les espaces sont ignorés.
    static func build(rows: [String], continents: [ContinentSpec],
                      seaRoutes: [(String, String)] = []) -> Board {
        var cells: [(col: Int, row: Int, key: Character)] = []
        for (r, line) in rows.enumerated() {
            var c = 0
            for ch in line where ch != " " {
                if ch != "." { cells.append((c, r, ch)) }
                c += 1
            }
        }

        // Nommage : chaque continent puise dans sa liste, dans l'ordre de
        // lecture. Si la liste est trop courte, on numérote plutôt que de
        // planter — un plan en cours de retouche doit rester jouable.
        var used: [Character: Int] = [:]
        var idOf: [String: TerritoryID] = [:]      // "col,row" -> identifiant
        var nameOf: [TerritoryID: String] = [:]
        var continentOf: [TerritoryID: ContinentID] = [:]
        let specs = Dictionary(uniqueKeysWithValues: continents.map { (Character($0.id), $0) })

        for cell in cells {
            let spec = specs[cell.key]
            let n = used[cell.key, default: 0]
            used[cell.key] = n + 1
            let name = spec.map { n < $0.names.count ? $0.names[n] : "\($0.name) \(n + 1)" } ?? "\(cell.key)\(n)"
            let id = "\(cell.key)\(n)"
            idOf["\(cell.col),\(cell.row)"] = id
            nameOf[id] = name
            continentOf[id] = spec?.id ?? String(cell.key)
        }

        // Voisinages « odd-r ».
        func neighbourKeys(col c: Int, row r: Int) -> [String] {
            let odd = r % 2 != 0
            let deltas: [(Int, Int)] = odd
                ? [(-1, 0), (1, 0), (0, -1), (1, -1), (0, 1), (1, 1)]
                : [(-1, 0), (1, 0), (-1, -1), (0, -1), (-1, 1), (0, 1)]
            return deltas.map { "\(c + $0.0),\(r + $0.1)" }
        }

        var territories: [Territory] = []
        for cell in cells {
            let id = idOf["\(cell.col),\(cell.row)"]!
            let ns = neighbourKeys(col: cell.col, row: cell.row).compactMap { idOf[$0] }
            territories.append(Territory(id: id, name: nameOf[id]!,
                                         continent: continentOf[id]!, neighbors: ns))
        }

        // Les traversées, désignées par les noms : c'est ce qui se relit.
        var idParNom: [String: TerritoryID] = [:]
        for (id, nom) in nameOf { idParNom[nom] = id }
        var routes: [SeaRoute] = []
        for (a, b) in seaRoutes {
            guard let ia = idParNom[a], let ib = idParNom[b] else {
                assertionFailure("Traversée vers un territoire inconnu : \(a) – \(b)")
                continue
            }
            routes.append(SeaRoute(from: ia, to: ib))
        }
        for route in routes {
            if let i = territories.firstIndex(where: { $0.id == route.from }),
               !territories[i].neighbors.contains(route.to) {
                territories[i].neighbors.append(route.to)
            }
            if let i = territories.firstIndex(where: { $0.id == route.to }),
               !territories[i].neighbors.contains(route.from) {
                territories[i].neighbors.append(route.from)
            }
        }

        var grouped: [ContinentID: [TerritoryID]] = [:]
        for t in territories { grouped[t.continent, default: []].append(t.id) }
        let conts = continents.enumerated().map { rang, spec in
            Continent(id: spec.id, name: spec.name, bonus: spec.bonus,
                      territories: grouped[spec.id] ?? [], tint: rang)
        }

        // Géométrie : hexagone pointe en haut, rayon 1. Largeur √3, hauteur 2,
        // les lignes se recouvrent d'un quart de hauteur.
        let w = 3.0.squareRoot()
        var raw: [TerritoryID: Point] = [:]
        for cell in cells {
            let id = idOf["\(cell.col),\(cell.row)"]!
            let dx = (cell.row % 2 != 0) ? w / 2 : 0
            raw[id] = Point(x: Double(cell.col) * w + dx, y: Double(cell.row) * 1.5)
        }

        // Mise à l'échelle sur x uniquement : les hexagones restent réguliers.
        let minX = raw.values.map(\.x).min() ?? 0, maxX = raw.values.map(\.x).max() ?? 1
        let minY = raw.values.map(\.y).min() ?? 0, maxY = raw.values.map(\.y).max() ?? 1
        let span = (maxX - minX) + w              // une case de marge : le bord
        let height = (maxY - minY) + 2.0          // ne doit pas rogner les pointes
        var centers: [TerritoryID: Point] = [:]
        for (id, p) in raw {
            centers[id] = Point(x: (p.x - minX + w / 2) / span,
                                y: (p.y - minY + 1.0) / span)
        }

        // Les six directions, dans l'ordre des arêtes du tracé : l'arête 0
        // part du sommet du haut vers la droite, et l'on tourne dans le sens
        // des aiguilles. À chacune correspond un voisin — ou la mer.
        func directions(row r: Int) -> [(Int, Int)] {
            let odd = r % 2 != 0
            return [
                odd ? (1, -1) : (0, -1),   // 0 — haut-droite
                (1, 0),                     // 1 — droite
                odd ? (1, 1) : (0, 1),      // 2 — bas-droite
                odd ? (0, 1) : (-1, 1),     // 3 — bas-gauche
                (-1, 0),                    // 4 — gauche
                odd ? (0, -1) : (-1, -1),   // 5 — haut-gauche
            ]
        }
        var frontieres: [TerritoryID: Set<Int>] = [:]
        for cell in cells {
            let id = idOf["\(cell.col),\(cell.row)"]!
            var bords = Set<Int>()
            for (k, d) in directions(row: cell.row).enumerated() {
                let voisin = idOf["\(cell.col + d.0),\(cell.row + d.1)"]
                if voisin == nil || continentOf[voisin!] != continentOf[id] { bords.insert(k) }
            }
            frontieres[id] = bords
        }

        let layout = BoardLayout(centers: centers,
                                 cellRadius: 1.0 / span,
                                 aspect: height / span,
                                 frontierEdges: frontieres,
                                 seaRoutes: routes)
        return Board(map: GameMap(territories: territories, continents: conts), layout: layout)
    }
}
