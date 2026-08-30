//
//  Theme.swift
//  Riskelo
//
//  Les couleurs, et rien d'autre.
//
//  Elles sont écrites ici plutôt que dans un catalogue d'images pour une
//  raison de lecture : sur un plateau, ce qui compte est l'écart entre deux
//  camps, et un écart se règle en regardant les valeurs côte à côte. Elles
//  tiennent sur l'ardoise comme sur le papier — le fond du jeu est sombre
//  dans les deux cas, c'est une table de nuit, pas un document.
//

import SwiftUI

enum Palette {

    /// Les camps. Choisies pour rester distinctes une fois délavées par
    /// l'ombre d'un territoire non sélectionné, et pour ne pas se confondre
    /// deux à deux pour un œil qui distingue mal le rouge du vert.
    static let camps: [Color] = [
        Color(red: 0.24, green: 0.51, blue: 0.78),   // bleu ardoise
        Color(red: 0.80, green: 0.31, blue: 0.24),   // rouge brique
        Color(red: 0.36, green: 0.60, blue: 0.36),   // vert olive
        Color(red: 0.87, green: 0.66, blue: 0.20),   // ambre
        Color(red: 0.55, green: 0.40, blue: 0.72),   // violet
    ]

    static func camp(_ player: PlayerID) -> Color {
        camps[((player % camps.count) + camps.count) % camps.count]
    }

    /// Les mêmes camps, mais assez clairs pour se lire en petit.
    ///
    /// Les couleurs ci-dessus sont faites pour **remplir** un hexagone :
    /// sombres, afin que le chiffre blanc posé dessus se détache. Réduites à
    /// un filet, à un point de huit points ou à une coche de neuf, sur le fond
    /// mat du panneau, la même valeur disparaît — le rouge brique à 50 %
    /// d'opacité donne 1,7 de contraste sur 21, autant dire rien. Le bleu et
    /// le violet ne valent guère mieux.
    ///
    /// D'où ce second jeu, plus clair d'un cran et demi : on reconnaît le
    /// camp, mais on le voit. Il est réservé à ce qui est mince ou petit — un
    /// trait, une pastille, une coche. Une surface pleine garde la couleur
    /// sombre, sans quoi le texte blanc qu'elle porte s'y perdrait à son tour.
    static let campsVifs: [Color] = [
        Color(red: 0.45, green: 0.70, blue: 0.98),   // bleu ardoise, éclairci
        Color(red: 0.98, green: 0.48, blue: 0.41),   // rouge brique, éclairci
        Color(red: 0.54, green: 0.82, blue: 0.54),   // vert olive, éclairci
        Color(red: 1.00, green: 0.79, blue: 0.34),   // ambre, éclairci
        Color(red: 0.74, green: 0.60, blue: 0.94),   // violet, éclairci
    ]

    static func campVif(_ player: PlayerID) -> Color {
        campsVifs[((player % campsVifs.count) + campsVifs.count) % campsVifs.count]
    }

    /// Les continents. Prises au rang du continent et non à la lettre de son
    /// plan — un plateau peut en avoir six ou huit, et ils doivent tous se
    /// distinguer.
    ///
    /// Elles étaient rabattues pour ne pas disputer la couleur du camp qui
    /// tient la case ; le trait était large et la teinte éteinte, et l'on ne
    /// voyait plus les continents. Le marché s'est inversé : **teintes vives,
    /// trait deux fois plus fin**. Un filet vif se lit comme une frontière,
    /// un bandeau vif se serait battu avec le remplissage.
    ///
    /// Toutes sont claires, là où les camps sont sombres : c'est cet écart de
    /// valeur, et non la teinte, qui empêche de confondre un contour de
    /// continent avec la couleur d'un joueur.
    static let continents: [Color] = [
        Color(red: 0.42, green: 0.78, blue: 1.00),   // ciel
        Color(red: 1.00, green: 0.84, blue: 0.30),   // or
        Color(red: 0.42, green: 0.92, blue: 0.55),   // vert vif
        Color(red: 1.00, green: 0.55, blue: 0.42),   // corail
        Color(red: 0.76, green: 0.58, blue: 1.00),   // violet clair
        Color(red: 0.30, green: 0.90, blue: 0.85),   // turquoise
        Color(red: 1.00, green: 0.52, blue: 0.75),   // rose vif
        Color(red: 0.85, green: 0.92, blue: 0.35),   // citron
    ]

    static func continent(rang: Int) -> Color {
        continents[((rang % continents.count) + continents.count) % continents.count]
    }

    /// Les six camemberts.
    static func category(_ c: Category) -> Color {
        switch c {
        case .geographie: Color(red: 0.26, green: 0.55, blue: 0.80)
        case .histoire:   Color(red: 0.85, green: 0.66, blue: 0.22)
        case .sciences:   Color(red: 0.34, green: 0.65, blue: 0.42)
        case .arts:       Color(red: 0.62, green: 0.45, blue: 0.34)
        case .sports:     Color(red: 0.88, green: 0.52, blue: 0.24)
        case .spectacle:  Color(red: 0.75, green: 0.40, blue: 0.62)
        }
    }

    static let sea = Color(red: 0.09, green: 0.12, blue: 0.16)
    static let ink = Color(red: 0.93, green: 0.94, blue: 0.95)
    static let dim = Color(red: 0.58, green: 0.62, blue: 0.68)
    static let panel = Color(red: 0.14, green: 0.17, blue: 0.21)
    static let held = Color(red: 0.36, green: 0.72, blue: 0.45)
    static let lost = Color(red: 0.86, green: 0.35, blue: 0.30)
    /// Le rouge de l'alerte, pour les mêmes usages menus que `campsVifs` :
    /// un filet ou un signe sur le panneau, jamais une surface pleine.
    static let lostVif = Color(red: 0.99, green: 0.53, blue: 0.47)
}

/// Une traversée, droite ou en arc.
///
/// L'arc n'est pas une coquetterie : l'Alaska et le Kamtchatka sont aux deux
/// bouts de la carte, et le trait droit qui les reliait passait au travers du
/// Groenland, de l'Islande et de toute la Sibérie. On ne pouvait pas dire ce
/// qu'il reliait. Une route qui contourne le monde par le haut se lit d'un
/// coup.
struct SeaLink: Shape {
    var from: CGPoint
    var to: CGPoint
    var recul: CGFloat
    /// Le point qui creuse la courbe. Absent, la route est droite.
    var controle: CGPoint?

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let controle else {
            let dx = to.x - from.x, dy = to.y - from.y
            let d = max(0.001, (dx * dx + dy * dy).squareRoot())
            p.move(to: CGPoint(x: from.x + dx / d * recul, y: from.y + dy / d * recul))
            p.addLine(to: CGPoint(x: to.x - dx / d * recul, y: to.y - dy / d * recul))
            return p
        }
        // Les extrémités reculent vers le point de contrôle, qui est la
        // tangente de la courbe : la route sort de la case dans le bon sens.
        func versControle(_ p0: CGPoint) -> CGPoint {
            let dx = controle.x - p0.x, dy = controle.y - p0.y
            let d = max(0.001, (dx * dx + dy * dy).squareRoot())
            return CGPoint(x: p0.x + dx / d * recul, y: p0.y + dy / d * recul)
        }
        p.move(to: versControle(from))
        p.addQuadCurve(to: versControle(to), control: controle)
        return p
    }
}

/// La flèche d'un assaut, d'une case à l'autre.
///
/// Elle recule de part et d'autre pour ne pas mordre sur les deux hexagones :
/// c'est le trajet entre les deux places qu'on veut voir, pas un trait posé
/// par-dessus les chiffres.
struct AttackArrow: Shape {
    var from: CGPoint
    var to: CGPoint
    var recul: CGFloat
    var tete: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let dx = to.x - from.x, dy = to.y - from.y
        let d = max(0.001, (dx * dx + dy * dy).squareRoot())
        let ux = dx / d, uy = dy / d
        let depart = CGPoint(x: from.x + ux * recul, y: from.y + uy * recul)
        let arrivee = CGPoint(x: to.x - ux * recul, y: to.y - uy * recul)
        p.move(to: depart)
        p.addLine(to: arrivee)
        // La pointe, deux traits obliques plutôt qu'un triangle plein : elle
        // se lit aussi bien et ne bouche pas la case visée.
        let ailes: CGFloat = 0.55
        p.move(to: CGPoint(x: arrivee.x - ux * tete - uy * tete * ailes,
                           y: arrivee.y - uy * tete + ux * tete * ailes))
        p.addLine(to: arrivee)
        p.addLine(to: CGPoint(x: arrivee.x - ux * tete + uy * tete * ailes,
                              y: arrivee.y - uy * tete - ux * tete * ailes))
        return p
    }
}

/// Les arêtes d'une case qui font frontière, tracées seules.
///
/// Elles sont rentrées vers le centre plutôt que posées sur le bord : deux
/// continents voisins tracent chacun la sienne, et superposées elles se
/// disputeraient la même ligne. Rentrées, elles font un double trait — celui
/// des atlas, qui montre bien qu'il y a deux terres et non une couture.
struct BorderEdges: Shape {
    let edges: Set<Int>
    var inset: CGFloat = 0.10

    func path(in rect: CGRect) -> Path {
        guard !edges.isEmpty else { return Path() }
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2 * (1 - inset)
        let ry = rect.height / 2 * (1 - inset)
        func sommet(_ i: Int) -> CGPoint {
            let a = Double(i % 6) * .pi / 3 - .pi / 2
            return CGPoint(x: c.x + rx * cos(a) * 2 / 3.0.squareRoot(),
                           y: c.y + ry * sin(a))
        }
        var p = Path()
        for k in edges {
            p.move(to: sommet(k))
            p.addLine(to: sommet(k + 1))
        }
        return p
    }
}

/// L'hexagone pointe en haut, tracé dans son rectangle.
///
/// Il sait se rétracter — `InsettableShape` — pour que le trait du contour
/// tienne à l'intérieur de la case au lieu de mordre sur la voisine.
struct Hexagon: InsettableShape {
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> Hexagon {
        Hexagon(inset: inset + amount)
    }

    func path(in bounds: CGRect) -> Path {
        let rect = bounds.insetBy(dx: inset, dy: inset)
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: rect.minX + w / 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.25))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.75))
        p.addLine(to: CGPoint(x: rect.minX + w / 2, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.75))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.25))
        p.closeSubpath()
        return p
    }
}
