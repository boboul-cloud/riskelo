//
//  Atlas.swift
//  Riskelo
//
//  Le plateau dessiné en cases, et non en hexagones.
//
//  `HexPlan` posait une case par territoire : c'est ce qui rend ses
//  voisinages indiscutables, et c'est aussi ce qui interdit une côte. Ici un
//  territoire est un **amas** de cases d'une grille fine — une trentaine, une
//  centaine — et l'on retrouve les deux propriétés à la fois :
//
//      les voisinages se déduisent encore — deux amas qui se touchent —
//      et la forme suit la géographie, puisqu'on la dessine.
//
//  Le contour n'est pas saisi : il est **suivi**. On parcourt les arêtes de
//  l'amas qui donnent sur autre chose que lui, on les enchaîne en boucles, et
//  l'on arrondit ces boucles deux fois — la crénelure de la grille disparaît,
//  la côte reste. Un territoire fait de plusieurs îles rend plusieurs boucles,
//  et c'est ainsi que l'Indonésie existe.
//
//  Le même parcours donne, sans un calcul de plus, les traits de frontière :
//  une arête dont l'autre côté est la mer ou un autre continent en est une.
//  Elles étaient auparavant comptées à part, et rien ne garantissait qu'elles
//  tombent sur le bord dessiné.
//
//  Le nom et le compte d'hommes se posent au **pôle d'inaccessibilité** de
//  l'amas : la case la plus loin de tout bord. Un centre de gravité tombe hors
//  du Chili et hors de l'Indonésie ; celui-ci tombe toujours dans la terre.
//

import Foundation

enum Atlas {

    /// Un territoire du plan : son signe sur la grille, sa terre, son nom.
    struct Place {
        let symbole: Character
        let continent: ContinentID
        let nom: String

        init(_ symbole: String, _ continent: ContinentID, _ nom: String) {
            self.symbole = symbole.first ?? "?"
            self.continent = continent
            self.nom = nom
        }
    }

    /// Une terre, et ce qu'elle vaut par tour à qui la tient entière.
    struct Terre {
        let id: ContinentID
        let nom: String
        let bonus: Int

        init(_ id: ContinentID, _ nom: String, _ bonus: Int) {
            self.id = id
            self.nom = nom
            self.bonus = bonus
        }
    }

    private struct Case: Hashable {
        var x: Int
        var y: Int
    }

    /// Un sommet de la grille. Entier : deux arêtes voisines doivent tomber
    /// exactement sur le même point, et deux flottants « presque égaux » ne
    /// s'enchaîneraient pas.
    private struct Sommet: Hashable {
        var x: Int
        var y: Int
    }

    /// Les sommets sont comptés en soixante-quatrièmes de case. Trois arrondis
    /// divisent chacun par quatre : à cette finesse, tout reste entier, et deux
    /// sommets qui doivent coïncider coïncident exactement. En flottants ils
    /// divergeraient d'un cheveu, et les brins de frontière ne se
    /// raccorderaient plus au contour.
    private static let finesse = 64

    private struct Arete {
        var de: Sommet
        var vers: Sommet
        /// L'autre côté donne-t-il sur la mer ou sur un autre continent ?
        var frontiere: Bool
    }

    // MARK: - La construction

    static func build(rows: [String], terres: [Terre], places: [Place],
                      traversees: [(String, String)] = []) -> Board {

        let largeur = rows.map(\.count).max() ?? 1
        let hauteur = rows.count

        var deCase: [Case: Character] = [:]
        var cases: [Character: Set<Case>] = [:]
        for (y, ligne) in rows.enumerated() {
            for (x, ch) in ligne.enumerated() where ch != "." && ch != " " {
                let c = Case(x: x, y: y)
                deCase[c] = ch
                cases[ch, default: []].insert(c)
            }
        }

        let parSymbole = Dictionary(uniqueKeysWithValues: places.map { ($0.symbole, $0) })
        func continent(_ ch: Character?) -> ContinentID? {
            ch.flatMap { parSymbole[$0]?.continent }
        }
        func identifiant(_ ch: Character) -> TerritoryID { String(ch) }

        // MARK: Les voisinages, déduits du contact

        var voisins: [Character: Set<Character>] = [:]
        for (c, ch) in deCase {
            for d in [Case(x: c.x + 1, y: c.y), Case(x: c.x, y: c.y + 1)] {
                guard let autre = deCase[d], autre != ch else { continue }
                voisins[ch, default: []].insert(autre)
                voisins[autre, default: []].insert(ch)
            }
        }

        // MARK: Les traversées, désignées par les noms — c'est ce qui se relit

        var symboleParNom: [String: Character] = [:]
        for p in places { symboleParNom[p.nom] = p.symbole }
        var routes: [SeaRoute] = []
        for (a, b) in traversees {
            guard let sa = symboleParNom[a], let sb = symboleParNom[b] else {
                assertionFailure("Traversée vers un territoire inconnu : \(a) – \(b)")
                continue
            }
            voisins[sa, default: []].insert(sb)
            voisins[sb, default: []].insert(sa)
            routes.append(SeaRoute(from: identifiant(sa), to: identifiant(sb)))
        }

        // MARK: La carte au sens des règles

        let territoires = places.map { p in
            Territory(id: identifiant(p.symbole), name: p.nom, continent: p.continent,
                      neighbors: (voisins[p.symbole] ?? []).map(identifiant).sorted())
        }
        var groupes: [ContinentID: [TerritoryID]] = [:]
        for t in territoires { groupes[t.continent, default: []].append(t.id) }
        let continents = terres.enumerated().map { rang, t in
            Continent(id: t.id, name: t.nom, bonus: t.bonus,
                      territories: groupes[t.id] ?? [], tint: rang)
        }

        // MARK: Le dessin

        // Normalisation sur x seul, comme pour les hexagones : c'est à la vue
        // de réserver la hauteur, pas au plateau de se déformer.
        let echelle = 1.0 / Double(largeur)
        func point(_ s: Sommet) -> Point {
            Point(x: Double(s.x) / Double(finesse) * echelle,
                  y: Double(s.y) / Double(finesse) * echelle)
        }

        var formes: [TerritoryID: [[Point]]] = [:]
        var frontieres: [TerritoryID: [[Point]]] = [:]
        var centres: [TerritoryID: Point] = [:]
        var rayons: [TerritoryID: Double] = [:]
        var cartouches: [TerritoryID: [LabelBox]] = [:]

        for p in places {
            let amas = cases[p.symbole] ?? []
            let id = identifiant(p.symbole)
            guard !amas.isEmpty else {
                assertionFailure("Le plan ne montre aucune case pour \(p.nom)")
                centres[id] = Point(x: 0.5, y: 0.5)
                rayons[id] = echelle
                continue
            }

            let boucles = contours(of: amas, deCase: deCase, terre: p.continent,
                                   continent: continent)
            var dessin: [[Point]] = []
            var traits: [[Point]] = []
            for boucle in boucles {
                let lisse = arrondi(arrondi(arrondi(joint(boucle))))
                dessin.append(lisse.map { point($0.de) })
                traits.append(contentsOf: brins(lisse).map { $0.map(point) })
            }
            formes[id] = dessin
            frontieres[id] = traits

            let (pole, rayon) = poleDInaccessibilite(amas)
            centres[id] = Point(x: (Double(pole.x) + 0.5) * echelle,
                                y: (Double(pole.y) + 0.5) * echelle)
            rayons[id] = Double(rayon) * echelle
            cartouches[id] = rectanglesOuEcrire(amas, pole: pole).map { r in
                LabelBox(center: Point(x: (Double(r.x) + Double(r.largeur) / 2) * echelle,
                                       y: (Double(r.y) + Double(r.hauteur) / 2) * echelle),
                         width: Double(r.largeur) * echelle,
                         height: Double(r.hauteur) * echelle)
            }
        }

        let layout = BoardLayout(centers: centres,
                                 cellRadius: echelle,
                                 aspect: Double(hauteur) / Double(largeur),
                                 seaRoutes: routes,
                                 shapes: formes,
                                 frontierPaths: frontieres,
                                 radii: rayons,
                                 labelBoxes: cartouches)
        return Board(map: GameMap(territories: territoires, continents: continents),
                     layout: layout)
    }

    // MARK: - Suivre le bord

    /// Les arêtes du bord, enchaînées en boucles.
    ///
    /// Chaque case occupe le carré unité de son coin. Une arête est du bord
    /// quand la case d'en face n'appartient pas à l'amas ; on l'oriente pour
    /// que l'intérieur reste du même côté, et les arêtes s'enchaînent alors
    /// d'elles-mêmes, tête contre queue.
    private static func contours(of amas: Set<Case>, deCase: [Case: Character],
                                 terre: ContinentID,
                                 continent: (Character?) -> ContinentID?) -> [[Arete]] {
        var sortantes: [Sommet: [Arete]] = [:]
        var nombre = 0
        func coin(_ x: Int, _ y: Int) -> Sommet { Sommet(x: x * finesse, y: y * finesse) }
        for c in amas {
            let dehors: [(Case, Sommet, Sommet)] = [
                (Case(x: c.x, y: c.y - 1), coin(c.x + 1, c.y), coin(c.x, c.y)),
                (Case(x: c.x - 1, y: c.y), coin(c.x, c.y), coin(c.x, c.y + 1)),
                (Case(x: c.x, y: c.y + 1), coin(c.x, c.y + 1), coin(c.x + 1, c.y + 1)),
                (Case(x: c.x + 1, y: c.y), coin(c.x + 1, c.y + 1), coin(c.x + 1, c.y)),
            ]
            for (voisine, de, vers) in dehors where !amas.contains(voisine) {
                // Frontière : la mer, ou une autre terre. Une case voisine du
                // même continent n'en est pas une — c'est une ligne intérieure.
                let dehorsTerre = continent(deCase[voisine])
                sortantes[de, default: []].append(
                    Arete(de: de, vers: vers, frontiere: dehorsTerre != terre))
                nombre += 1
            }
        }

        var boucles: [[Arete]] = []
        while nombre > 0 {
            guard let depart = sortantes.first(where: { !$0.value.isEmpty })?.key else { break }
            var boucle: [Arete] = []
            var ici = depart
            while let suivante = sortantes[ici]?.last {
                sortantes[ici]?.removeLast()
                nombre -= 1
                boucle.append(suivante)
                ici = suivante.vers
                if ici == depart { break }
            }
            if boucle.count > 2 { boucles.append(boucle) }
        }
        return boucles
    }

    /// Les arêtes alignées, réunies en une seule.
    ///
    /// Ce n'est pas une économie de points, c'est ce qui donne sa forme à
    /// l'arrondi : Chaikin coupe chaque arête à son quart, si bien qu'une côte
    /// droite découpée en trente petites arêtes reste un trait dur, tandis que
    /// la même côte en une seule arête s'incurve à ses deux bouts. Une
    /// frontière et une côte ne se réunissent jamais : elles ne se tracent pas
    /// de la même façon.
    private static func joint(_ boucle: [Arete]) -> [Arete] {
        guard boucle.count > 2 else { return boucle }
        func alignees(_ a: Arete, _ b: Arete) -> Bool {
            a.frontiere == b.frontiere
                && (a.vers.x - a.de.x) * (b.vers.y - b.de.y)
                    == (a.vers.y - a.de.y) * (b.vers.x - b.de.x)
        }
        var out: [Arete] = []
        for a in boucle {
            if let last = out.last, alignees(last, a) {
                out[out.count - 1].vers = a.vers
            } else {
                out.append(a)
            }
        }
        // La boucle se referme : la dernière et la première peuvent l'être
        // aussi, et le point de départ du parcours n'a pas à laisser un angle.
        if out.count > 2, alignees(out[out.count - 1], out[0]) {
            out[0].de = out[out.count - 1].de
            out.removeLast()
        }
        return out
    }

    /// L'arrondi de Chaikin : chaque arête rend son quart et son trois-quarts,
    /// et les angles droits de la grille s'émoussent. Trois passes : à deux,
    /// la crénelure se devine encore le long d'une côte en biais.
    ///
    /// Le drapeau de frontière voyage avec l'arête. Le petit segment qui
    /// remplace un angle n'est frontière que si les deux arêtes qu'il joint le
    /// sont : sans cela, un trait de côte déborderait d'un cran sur la
    /// frontière intérieure voisine.
    private static func arrondi(_ boucle: [Arete]) -> [Arete] {
        guard boucle.count > 2 else { return boucle }
        var points: [(Sommet, Bool)] = []
        for (i, a) in boucle.enumerated() {
            let b = boucle[(i + 1) % boucle.count]
            points.append((quart(a.de, a.vers, 1), a.frontiere))
            points.append((quart(a.de, a.vers, 3), a.frontiere && b.frontiere))
        }
        return points.enumerated().map { i, p in
            Arete(de: p.0, vers: points[(i + 1) % points.count].0, frontiere: p.1)
        }
    }

    /// Le point au quart ou aux trois quarts de l'arête. Tout est entier : en
    /// seizièmes de case, deux divisions par quatre tombent juste.
    private static func quart(_ a: Sommet, _ b: Sommet, _ n: Int) -> Sommet {
        Sommet(x: (a.x * (4 - n) + b.x * n) / 4,
               y: (a.y * (4 - n) + b.y * n) / 4)
    }

    /// Les brins de frontière : les suites d'arêtes marquées, prêtes à tracer.
    private static func brins(_ boucle: [Arete]) -> [[Sommet]] {
        guard boucle.contains(where: \.frontiere) else { return [] }
        guard !boucle.allSatisfy(\.frontiere) else {
            return [boucle.map(\.de) + [boucle[0].de]]
        }
        // On repart d'une arête qui n'est pas frontière : le brin ne sera donc
        // jamais coupé en deux par le début du tableau.
        let debut = boucle.firstIndex { !$0.frontiere } ?? 0
        var brins: [[Sommet]] = []
        var courant: [Sommet] = []
        for k in 0 ..< boucle.count {
            let a = boucle[(debut + k) % boucle.count]
            if a.frontiere {
                if courant.isEmpty { courant.append(a.de) }
                courant.append(a.vers)
            } else if !courant.isEmpty {
                brins.append(courant)
                courant = []
            }
        }
        if !courant.isEmpty { brins.append(courant) }
        return brins
    }

    // MARK: - Où poser le nom

    /// La case la plus loin de tout bord, et sa distance.
    ///
    /// Un centre de gravité tombe dans la mer dès qu'un territoire est courbe
    /// — le Chili l'écrirait au large, l'Indonésie entre deux îles. Celui-ci
    /// est toujours dans la terre, et sa distance donne la place dont on
    /// dispose pour écrire.
    private static func poleDInaccessibilite(_ amas: Set<Case>) -> (Case, Int) {
        var distance: [Case: Int] = [:]
        var file: [Case] = []
        for c in amas {
            let bord = [Case(x: c.x + 1, y: c.y), Case(x: c.x - 1, y: c.y),
                        Case(x: c.x, y: c.y + 1), Case(x: c.x, y: c.y - 1)]
                .contains { !amas.contains($0) }
            if bord { distance[c] = 1; file.append(c) }
        }
        var i = 0
        while i < file.count {
            let c = file[i]; i += 1
            let d = distance[c]! + 1
            for n in [Case(x: c.x + 1, y: c.y), Case(x: c.x - 1, y: c.y),
                      Case(x: c.x, y: c.y + 1), Case(x: c.x, y: c.y - 1)]
            where amas.contains(n) && distance[n] == nil {
                distance[n] = d
                file.append(n)
            }
        }
        // À égalité, la case la plus haute puis la plus à gauche : un plan
        // relu deux fois doit poser le nom au même endroit.
        let meilleur = distance.max {
            ($0.value, -$0.key.y, -$0.key.x) < ($1.value, -$1.key.y, -$1.key.x)
        }
        guard let meilleur else { return (amas.first ?? Case(x: 0, y: 0), 1) }
        return (meilleur.key, meilleur.value)
    }

    /// Un rectangle de cases, compté depuis son coin haut gauche.
    private struct Rectangle {
        var x: Int
        var y: Int
        var largeur: Int
        var hauteur: Int
    }

    /// Pour chaque hauteur, le rectangle le plus large que l'amas contienne en
    /// entier — du plus plat au plus haut.
    ///
    /// Un rectangle plus bas et pas plus large qu'un autre ne servirait à
    /// rien : il est écarté. À largeur égale, le plus proche du pôle, qui est
    /// le cœur du territoire ; puis le plus haut et le plus à gauche, pour
    /// qu'un plan relu deux fois écrive au même endroit.
    ///
    /// On essaie toutes les bandes de lignes, et dans chacune toutes les suites
    /// de colonnes pleines : un territoire tient dans une trentaine de cases de
    /// côté, et cela ne se fait qu'une fois, à la fabrication du plateau.
    private static func rectanglesOuEcrire(_ amas: Set<Case>, pole: Case) -> [Rectangle] {
        guard let minX = amas.map(\.x).min(), let maxX = amas.map(\.x).max(),
              let minY = amas.map(\.y).min(), let maxY = amas.map(\.y).max() else { return [] }

        func eloignement(_ r: Rectangle) -> Int {
            // En demi-cases, pour rester entier.
            let dx = 2 * r.x + r.largeur - 1 - 2 * pole.x
            let dy = 2 * r.y + r.hauteur - 1 - 2 * pole.y
            return dx * dx + dy * dy
        }

        var parHauteur: [Int: Rectangle] = [:]
        for haut in minY ... maxY {
            var pleine = Array(repeating: true, count: maxX - minX + 1)
            for bas in haut ... maxY {
                for x in minX ... maxX where !amas.contains(Case(x: x, y: bas)) {
                    pleine[x - minX] = false
                }
                var debut = 0
                while debut < pleine.count {
                    guard pleine[debut] else { debut += 1; continue }
                    var fin = debut
                    while fin + 1 < pleine.count, pleine[fin + 1] { fin += 1 }
                    let r = Rectangle(x: minX + debut, y: haut,
                                      largeur: fin - debut + 1, hauteur: bas - haut + 1)
                    if let deja = parHauteur[r.hauteur],
                       (deja.largeur, -eloignement(deja)) >= (r.largeur, -eloignement(r)) {
                        // Déjà mieux.
                    } else {
                        parHauteur[r.hauteur] = r
                    }
                    debut = fin + 1
                }
            }
        }

        var retenus: [Rectangle] = []
        for hauteur in parHauteur.keys.sorted(by: >) {
            guard let r = parHauteur[hauteur] else { continue }
            if let plusHaut = retenus.last, plusHaut.largeur >= r.largeur { continue }
            retenus.append(r)
        }
        return retenus.reversed()
    }
}
