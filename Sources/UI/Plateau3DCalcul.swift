//
//  Plateau3DCalcul.swift
//  Riskelo
//
//  Ce que le plateau en relief calcule : où se pose chaque territoire dans
//  l'espace, où se tient la caméra, et quelle terre se trouve sous le doigt.
//
//  Rien ici ne dessine. C'est de la géométrie, et elle est sortie de la vue
//  pour la même raison que `Cadrage` l'a été du plateau à plat : elle se
//  vérifie. Un territoire qu'on touche et qui n'est pas celui qu'on visait ne
//  plante rien — il fait jouer le mauvais coup, et l'on ne sait pas pourquoi.
//

import CoreGraphics
import Foundation
import simd

// MARK: - Le plateau posé sur la table

/// Le passage du plateau (0…1 sur x, 0…aspect sur y) à la scène en relief.
///
/// Le plateau se couche sur le sol : son x reste le x de la scène, son y
/// devient la profondeur. Le bas de la carte vient vers celui qui regarde,
/// comme une carte posée sur une table — le nord au fond.
struct Repere3D: Equatable {

    /// La largeur du plateau dans la scène. Le chiffre n'a pas de sens en
    /// soi ; il est pris assez grand pour que les petites choses — un nom, un
    /// pion — ne tombent pas sous la précision du moteur.
    static let largeur: Float = 10

    let aspect: Float

    init(aspect: Double) { self.aspect = Float(aspect) }

    var demiLargeur: Float { Self.largeur / 2 }
    var demiProfondeur: Float { Self.largeur * aspect / 2 }

    /// Un point du plateau, posé dans la scène à la hauteur voulue.
    func monde(_ p: Point, hauteur: Float = 0) -> SIMD3<Float> {
        SIMD3(Float(p.x - 0.5) * Self.largeur,
              hauteur,
              (Float(p.y) - aspect / 2) * Self.largeur)
    }

    /// Le chemin inverse : un point du sol de la scène, rendu au plateau.
    func plateau(_ m: SIMD3<Float>) -> Point {
        Point(x: Double(m.x / Self.largeur) + 0.5,
              y: Double(m.z / Self.largeur + aspect / 2))
    }

    /// Une longueur du plateau, dans les unités de la scène.
    func longueur(_ l: Double) -> Float { Float(l) * Self.largeur }

    /// Le diamètre du fanion qui porte le nombre d'hommes — d'une terre, ou
    /// d'une terre ordinaire du plateau si l'on n'en nomme aucune.
    ///
    /// Sur un damier, le rayon est celui de la case, pointe à pointe ; sur
    /// une carte, celui de la place où écrire. Les deux ne se mesurent pas
    /// pareil, et un fanion pris à la mesure de la case cachait les cases de
    /// derrière.
    func fanion(_ id: TerritoryID?, layout: BoardLayout) -> Float {
        let r = longueur(layout.typicalRadius)
        guard !layout.shapes.isEmpty else { return r * 0.66 }
        guard let id else { return r }
        return min(r * 1.05, max(r * 0.62, longueur(layout.radius(of: id))))
    }
}

// MARK: - La caméra

/// Où se tient l'œil : un point du sol qu'il regarde, la distance, le tour
/// qu'il a fait autour de la table, et la hauteur d'où il la voit.
///
/// Elle tourne autour de son point de mire comme on tourne autour d'une table
/// de jeu — on ne vole pas au-dessus. Déplacer la carte, c'est déplacer ce
/// point ; la rapprocher, c'est réduire la distance.
struct Camera3D: Equatable {

    /// Le point du sol regardé, en (x, z) de la scène.
    var cible: SIMD2<Float> = .zero
    var distance: Float = 12
    /// Le tour autour de la table, en radians. Zéro : le nord au fond.
    var lacet: Float = 0
    /// La hauteur de l'œil au-dessus de l'horizon, en radians. Ni de face —
    /// on ne verrait que les tranches —, ni d'aplomb — on ne verrait plus le
    /// relief. Cinquante-six degrés, c'est l'angle d'un joueur assis.
    var tangage: Float = Camera3D.tangageOrdinaire

    static let tangageOrdinaire: Float = 56 * .pi / 180
    /// L'ouverture verticale de l'objectif, en degrés. Étroite : un grand
    /// angle déforme les bords du plateau, et les terres du coin paraissent
    /// plus vastes que celles du milieu.
    static let champ: Float = 38

    private var tangenteDemiChamp: Float { tan(Self.champ * .pi / 360) }

    /// Où se tient l'œil.
    var position: SIMD3<Float> {
        let horizontal = distance * cos(tangage)
        return SIMD3(cible.x + sin(lacet) * horizontal,
                     distance * sin(tangage),
                     cible.y + cos(lacet) * horizontal)
    }

    /// Dans quelle direction il regarde. Le tour d'abord, autour de la
    /// verticale ; l'inclinaison ensuite, vers le bas.
    var orientation: simd_quatf {
        simd_quatf(angle: lacet, axis: SIMD3(0, 1, 0))
            * simd_quatf(angle: -tangage, axis: SIMD3(1, 0, 0))
    }

    /// Le devant de la table, vu de l'œil, à plat sur le sol : la direction
    /// dans laquelle un point « monte » à l'écran.
    var devant: SIMD2<Float> { SIMD2(-sin(lacet), -cos(lacet)) }
    /// La droite de l'écran, à plat sur le sol.
    var droite: SIMD2<Float> { SIMD2(cos(lacet), -sin(lacet)) }

    /// Le rayon qui part de l'œil et passe par ce point de l'écran.
    func rayon(_ p: CGPoint, taille: CGSize) -> (origine: SIMD3<Float>, direction: SIMD3<Float>) {
        let w = max(1, Float(taille.width)), h = max(1, Float(taille.height))
        let t = tangenteDemiChamp
        let local = SIMD3<Float>((2 * Float(p.x) / w - 1) * t * w / h,
                                 (1 - 2 * Float(p.y) / h) * t,
                                 -1)
        return (position, orientation.act(simd_normalize(local)))
    }

    /// Le point du sol — à la hauteur dite — qui se trouve sous ce point de
    /// l'écran. Rien si le rayon file vers l'horizon.
    func sol(_ p: CGPoint, taille: CGSize, hauteur: Float = 0) -> SIMD3<Float>? {
        let r = rayon(p, taille: taille)
        guard r.direction.y < -0.0001 else { return nil }
        let t = (hauteur - r.origine.y) / r.direction.y
        guard t > 0 else { return nil }
        return r.origine + t * r.direction
    }

    /// Où ce point de la scène paraît à l'écran. Rien s'il est derrière l'œil.
    func ecran(_ m: SIMD3<Float>, taille: CGSize) -> CGPoint? {
        let local = orientation.inverse.act(m - position)
        guard local.z < -0.0001 else { return nil }
        let w = max(1, Float(taille.width)), h = max(1, Float(taille.height))
        let t = tangenteDemiChamp
        let nx = (local.x / -local.z) / (t * w / h)
        let ny = (local.y / -local.z) / t
        return CGPoint(x: CGFloat((nx + 1) / 2 * w), y: CGFloat((1 - ny) / 2 * h))
    }

    /// Combien de points d'écran mesure une longueur de la scène posée au
    /// point de mire. C'est ce qui décide qu'un nom se lit ou non.
    func points(pour longueur: Float, taille: CGSize) -> CGFloat {
        CGFloat(longueur / (2 * distance * tangenteDemiChamp)) * taille.height
    }

    // MARK: Les gestes

    /// Le doigt a glissé de tant de points : la carte le suit.
    ///
    /// Un point d'écran vaut plus de sol en profondeur qu'en largeur — la
    /// table est vue de biais —, d'où la division par le sinus : sans elle,
    /// la carte traînait derrière le doigt dès qu'on la tirait vers le haut.
    mutating func glisser(_ d: CGSize, taille: CGSize) {
        let parPoint = 2 * distance * tangenteDemiChamp / max(1, Float(taille.height))
        let dx = Float(d.width) * parPoint
        let dy = Float(d.height) * parPoint / max(0.3, sin(tangage))
        cible -= droite * dx
        cible += devant * dy
    }

    /// Le pincement : un facteur plus grand que un rapproche.
    mutating func pincer(_ facteur: CGFloat) {
        guard facteur > 0 else { return }
        distance /= Float(facteur)
    }

    /// Les deux doigts qui tournent : la table tourne avec eux.
    mutating func tourner(_ angle: Double) {
        lacet -= Float(angle)
    }

    /// Ramène la caméra dans ce qui a du sens : assez près pour que la carte
    /// ne soit pas un timbre, pas au point de n'en voir qu'un coin ; et le
    /// point de mire sur le plateau, à une marge près.
    mutating func borner(repere: Repere3D, ensemble: Float) {
        distance = min(ensemble * 1.5, max(ensemble * 0.16, distance))
        let mx = repere.demiLargeur * 1.05, mz = repere.demiProfondeur * 1.05 + 0.4
        cible.x = min(mx, max(-mx, cible.x))
        cible.y = min(mz, max(-mz, cible.y))
    }

    // MARK: Les cadrages

    /// Le plateau entier, vu de face, dans une vue de cette taille.
    ///
    /// C'est la largeur qui décide sur un téléphone tenu droit, la profondeur
    /// sur un écran couché — mais vu de biais, rien ne se calcule d'un trait :
    /// le bord proche paraît plus large que le bord du fond, et le plateau
    /// n'est pas au milieu de l'écran quand son milieu l'est. On cherche donc
    /// la distance à laquelle ses quatre coins tiennent, puis on le recentre
    /// en hauteur, et l'on recommence — trois tours suffisent.
    static func ensemble(repere: Repere3D, taille: CGSize) -> Camera3D {
        var c = Camera3D()
        guard taille.width > 1, taille.height > 1 else { return c }
        func tient(_ c: Camera3D) -> Bool {
            guard let e = c.etendue(repere, taille: taille) else { return false }
            return e.gauche >= Self.cote && e.droite <= taille.width - Self.cote
                && e.dessus >= Self.haut && e.dessous <= taille.height - Self.bas
        }
        for _ in 0 ..< 3 {
            var proche: Float = 1, loin: Float = 1000
            for _ in 0 ..< 40 {
                c.distance = (proche + loin) / 2
                if tient(c) { loin = c.distance } else { proche = c.distance }
            }
            c.distance = loin
            c = c.centreeEnHauteur(repere, taille: taille)
        }
        return c
    }

    /// Les marges du cadrage d'ensemble, en points. Davantage en haut : les
    /// fanions du fond dépassent du plateau, et le bouton 3D se tient dans ce
    /// coin.
    private static let cote: CGFloat = 6, haut: CGFloat = 36, bas: CGFloat = 10

    /// Ce que les quatre coins du plateau couvrent à l'écran.
    private func etendue(_ repere: Repere3D, taille: CGSize)
    -> (gauche: CGFloat, droite: CGFloat, dessus: CGFloat, dessous: CGFloat)? {
        let W = repere.demiLargeur, H = repere.demiProfondeur
        let coins = [SIMD3<Float>(-W, 0, -H), SIMD3(W, 0, -H), SIMD3(-W, 0, H), SIMD3(W, 0, H)]
        let p = coins.compactMap { ecran($0, taille: taille) }
        guard p.count == coins.count else { return nil }
        return (p.map(\.x).min()!, p.map(\.x).max()!, p.map(\.y).min()!, p.map(\.y).max()!)
    }

    /// Autant de vide au-dessus du plateau qu'au-dessous. Vu de biais, son
    /// milieu au milieu de l'écran ne suffit pas : le bord proche descend plus
    /// que le bord du fond ne monte.
    private func centreeEnHauteur(_ repere: Repere3D, taille: CGSize) -> Camera3D {
        var c = self
        for _ in 0 ..< 3 {
            guard let e = c.etendue(repere, taille: taille) else { break }
            let ecart = ((e.dessus - Self.haut) - (taille.height - Self.bas - e.dessous)) / 2
            let parPoint = 2 * c.distance * c.tangenteDemiChamp / Float(taille.height)
            c.cible.y += Float(ecart) * parPoint / max(0.3, sin(c.tangage))
        }
        return c
    }

    /// Le premier regard : le plateau entier, rapproché si ses nombres y sont
    /// trop petits pour se lire — jusqu'à une fois et demie, comme le plateau
    /// à plat, qui s'ouvre lui aussi rapproché sur une carte du monde. Le
    /// reste vient sous le doigt.
    func rapprochee(pourLire diametre: Float, repere: Repere3D, taille: CGSize) -> Camera3D {
        var c = self
        let lu = points(pour: diametre, taille: taille)
        guard lu > 0, lu < 22 else { return c }
        c.distance *= max(1 / 1.5, Float(lu / 22))
        return c.centreeEnHauteur(repere, taille: taille)
    }

    /// Amène ce point du sol au milieu de la bande que le panneau du bas
    /// laisse libre.
    ///
    /// Le panneau mange la part `couvert` du bas : le milieu de ce qui reste
    /// se trouve au-dessus du milieu de l'écran d'autant. Le point de mire
    /// recule donc vers l'œil de la distance qui fait monter ce point
    /// jusque-là — un calcul exact, et non une estimation : vu de biais, le
    /// sol ne monte pas d'un pas égal à l'écran.
    func centree(sur p: SIMD2<Float>, couvert: CGFloat) -> Camera3D {
        var c = self
        let v = Float(min(0.9, max(0, couvert)))
        let th = tangenteDemiChamp
        let diviseur = sin(tangage) - v * th * cos(tangage)
        let recul = diviseur > 0.05 ? v * th * distance / diviseur : 0
        c.cible = p - devant * recul
        return c
    }

    /// Un point du sol paraît-il dans la bande libre, à une marge près ?
    func voit(_ m: SIMD3<Float>, taille: CGSize, couvert: CGFloat, marge: CGFloat) -> Bool {
        guard let e = ecran(m, taille: taille) else { return false }
        let bas = taille.height * (1 - min(0.9, max(0, couvert)))
        return e.x > marge && e.x < taille.width - marge && e.y > marge && e.y < bas - marge
    }

    /// Le cadrage d'un assaut : les deux places dans la bande libre.
    ///
    /// Sans effet si elles y sont déjà — une carte qui glisse sans raison
    /// gêne plus que le recadrage ne rend service. Sinon le milieu des deux
    /// vient au centre de la bande.
    ///
    /// La caméra glisse, elle ne recule jamais. Elle reculait jusqu'à faire
    /// tenir les deux places au-dessus du panneau, et la carte qu'on venait
    /// de rapprocher se réduisait d'un coup au plus petit, juste au moment de
    /// l'assaut. Le panneau est translucide : une place qui déborde dessous
    /// se voit encore au travers.
    func cadrage(de a: SIMD3<Float>, vers b: SIMD3<Float>, taille: CGSize,
                 couvert: CGFloat, marge: CGFloat) -> Camera3D? {
        if voit(a, taille: taille, couvert: couvert, marge: marge),
           voit(b, taille: taille, couvert: couvert, marge: marge) { return nil }
        return centree(sur: SIMD2((a.x + b.x) / 2, (a.z + b.z) / 2), couvert: couvert)
    }
}

// MARK: - Ce qu'on touche

/// Quel territoire se trouve à ce point du plateau.
///
/// Sur un damier, c'est la case dont le centre est le plus proche : les
/// hexagones pavent le plan, et le plus proche centre est toujours celui de
/// la case qui contient le point. Sur une carte dessinée, c'est le contour
/// qui le contient — et, faute de mieux, la côte la plus proche à un pas
/// près : une île de la taille d'un ongle ne se toucherait pas autrement.
enum Touche3D {

    static func territoire(en p: Point, layout: BoardLayout,
                           ordre: [TerritoryID]) -> TerritoryID? {
        if layout.shapes.isEmpty {
            var meilleur: (id: TerritoryID, d: Double)?
            for id in ordre {
                guard let c = layout.centers[id] else { continue }
                let d = hypot(p.x - c.x, p.y - c.y)
                if d <= layout.cellRadius, d < (meilleur?.d ?? .infinity) { meilleur = (id, d) }
            }
            return meilleur?.id
        }
        for id in ordre {
            if let boucles = layout.shapes[id], contient(p, boucles: boucles) { return id }
        }
        // Le doigt est tombé dans la mer, tout près d'une côte.
        let tolerance = layout.typicalRadius * 0.4
        var meilleur: (id: TerritoryID, d: Double)?
        for id in ordre {
            guard let boucles = layout.shapes[id] else { continue }
            let d = distance(de: p, aux: boucles)
            if d <= tolerance, d < (meilleur?.d ?? .infinity) { meilleur = (id, d) }
        }
        return meilleur?.id
    }

    /// Pair-impair : la même règle que le remplissage du plateau à plat, donc
    /// la même réponse.
    static func contient(_ p: Point, boucles: [[Point]]) -> Bool {
        var dedans = false
        for boucle in boucles where boucle.count > 2 {
            var j = boucle.count - 1
            for i in boucle.indices {
                let a = boucle[i], b = boucle[j]
                if (a.y > p.y) != (b.y > p.y),
                   p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x {
                    dedans.toggle()
                }
                j = i
            }
        }
        return dedans
    }

    static func distance(de p: Point, aux boucles: [[Point]]) -> Double {
        var meilleure = Double.infinity
        for boucle in boucles where boucle.count > 1 {
            for i in boucle.indices {
                let a = boucle[i], b = boucle[(i + 1) % boucle.count]
                let dx = b.x - a.x, dy = b.y - a.y
                let l2 = dx * dx + dy * dy
                let t = l2 > 0 ? min(1, max(0, ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2)) : 0
                meilleure = min(meilleure, hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy)))
            }
        }
        return meilleure
    }
}

// MARK: - Ce que le plateau montre

/// L'état du plateau tel que le relief doit le montrer, réduit à ce qui se
/// voit. La scène compare l'instantané au précédent et ne retouche que ce qui
/// a changé : refaire quarante-deux terres à chaque battement du sablier
/// ferait ramer un téléphone pour rien.
struct Instantane3D: Equatable {

    struct Assaut: Equatable {
        let de: TerritoryID
        let vers: TerritoryID
        let camp: PlayerID
    }

    var proprietaires: [TerritoryID: PlayerID] = [:]
    var hommes: [TerritoryID: Int] = [:]
    var choisi: TerritoryID?
    /// Les cibles atteignables depuis la place choisie.
    var cibles: Set<TerritoryID> = []
    /// Ce sur quoi le joueur peut agir maintenant — le reste est dans l'ombre.
    var jouables: Set<TerritoryID> = []
    var assaut: Assaut?

    /// Lu sur une partie, avec les mêmes règles que le plateau à plat : ce
    /// qui est jouable ou visé ne doit pas dépendre de la façon de regarder.
    init(partie g: GameState, choisi: TerritoryID?, assaut: Assault?) {
        self.choisi = choisi
        if let a = assaut { self.assaut = Assaut(de: a.from, vers: a.to, camp: a.attacker) }
        for id in g.map.order {
            proprietaires[id] = g.owner[id] ?? 0
            hommes[id] = g.armies(id)
            if g.estJouable(id) { jouables.insert(id) }
            if g.estCible(id, depuis: choisi) { cibles.insert(id) }
        }
    }

    init() {}
}

extension GameState {

    /// Une case sur laquelle le joueur peut agir maintenant.
    func estJouable(_ id: TerritoryID) -> Bool {
        guard !currentPlayer.isBot else { return true }
        switch phase {
        case .reinforcement: return owner[id] == currentPlayer.id
        case .attack: return canLaunch(from: id)
        case .fortify: return owner[id] == currentPlayer.id
        default: return true
        }
    }

    /// Une cible atteignable depuis la case retenue.
    func estCible(_ id: TerritoryID, depuis base: TerritoryID?) -> Bool {
        guard let base else { return false }
        switch phase {
        case .attack:
            return map.areAdjacent(base, id) && owner[id] != currentPlayer.id
        case .fortify:
            return id != base && owner[id] == currentPlayer.id
                && areLinked(base, id, for: currentPlayer.id)
        default:
            return false
        }
    }
}
