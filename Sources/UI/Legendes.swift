//
//  Legendes.swift
//  Riskelo
//
//  Ce qu'on écrit sur un plateau dessiné, et où.
//
//  Sur un damier, chaque case a la place de son nom ou ne l'a pas, et la même
//  règle vaut pour toutes. Sur une carte, rien n'est égal : la Sibérie fait dix
//  fois l'Islande, et les Territoires du Nord-Ouest sont une bande là où
//  l'Afrique du Nord est un pavé. Un nom posé au cœur du territoire et mesuré
//  au plateau débordait donc sur ses voisins — « Ouest des » et « Est des
//  États-Unis » se lisaient l'un dans l'autre, et les deux Australies aussi.
//
//  La règle est celle des cartes routières. Le nombre d'hommes paraît
//  toujours : c'est lui qui sert à jouer. Le nom paraît s'il tient, à une
//  taille qui se lit, dans un rectangle de son territoire, et sans toucher
//  l'étiquette d'un autre. Sinon il attend qu'on rapproche la carte.
//
//  Les tailles sont dites **en points d'écran**, et non en points du plateau
//  : le plateau se rapproche en grossissant tout ce qu'il porte, et un nom
//  qui grossirait avec lui n'aurait jamais plus de place qu'avant. Tenu à
//  taille constante, il en gagne à chaque pincement — c'est ce qui fait
//  paraître les noms un à un quand on rapproche la carte.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// L'étiquette d'un territoire : le nombre, et le nom quand il tient.
struct Legende: Equatable {
    /// Le milieu de l'étiquette, en points du plateau non rapproché.
    var centre: CGPoint
    /// Le nom, coupé en deux lignes s'il le faut. Absent, il ne tient pas.
    var nom: String?
    /// Les deux tailles, en points d'écran.
    var corpsNom: CGFloat
    var corpsNombre: CGFloat
}

enum Legendes {

    /// En dessous, un nom ne se lit plus sur un téléphone tenu à la main.
    static let plancher: CGFloat = 8.5
    /// Au-delà, les grands territoires criaient leur nom plus fort que les
    /// petits, sans rien dire de plus.
    static let plafond: CGFloat = 12
    static let nombreMin: CGFloat = 10
    static let nombreMax: CGFloat = 15
    /// De combien un nom peut sortir de son rectangle. Le rectangle est pris
    /// en cases entières, bien à l'intérieur du contour arrondi : un nom qui
    /// le dépasse d'un peu reste dans sa terre. Ce qui compte vraiment — ne
    /// rien toucher d'autre — est vérifié à part.
    static let debord: CGFloat = 1.15
    /// L'air laissé autour d'une étiquette, en points d'écran. Deux noms
    /// voisins séparés de moins se lisaient d'un seul tenant — « Afrique
    /// Égypte », puis « du Nord » en dessous.
    static let air: CGFloat = 3.5

    /// Les étiquettes de tout le plateau.
    ///
    /// Elles se décident ensemble et non une à une : un nom qui tient dans sa
    /// terre peut encore toucher celui d'à côté, et c'est au moment de les
    /// poser tous qu'on le voit. Les plus grands passent les premiers ; celui
    /// qui toucherait une étiquette déjà posée, ou le nombre d'un voisin, se
    /// tait.
    @MainActor
    static func placer(layout: BoardLayout, ordre: [TerritoryID],
                       nom: (TerritoryID) -> String, nombre: (TerritoryID) -> Int,
                       cote: CGFloat, echelle: CGFloat) -> [TerritoryID: Legende] {
        struct Choix {
            let id: TerritoryID
            let rang: Int
            let seul: Legende
            let seulCadre: CGRect
            /// Les façons d'écrire le nom, de la plus grande à la plus petite.
            let completes: [(legende: Legende, cadre: CGRect)]
        }

        var choix: [Choix] = []
        for (rang, id) in ordre.enumerated() {
            guard let boites = layout.labelBoxes[id], !boites.isEmpty else { continue }
            let hommes = nombre(id)
            func centre(_ b: LabelBox) -> CGPoint {
                CGPoint(x: b.center.x * cote, y: b.center.y * cote)
            }

            // Chaque façon d'écrire le nom — sur une ligne, sur deux — a son
            // rectangle, et il ne dépend pas du rapprochement. Choisi à
            // nouveau à chaque image, il changeait d'un pincement à l'autre,
            // et l'étiquette sautait de quelques cases sous le doigt. Seul le
            // passage d'une ligne à deux la déplace encore.
            let formes = coupures(nom(id)).map { texte in
                (texte: texte, place: rectangle(pour: texte, parmi: boites))
            }
            var essais: [(texte: String, boite: LabelBox, corps: CGFloat, corpsNombre: CGFloat)] =
                formes.map { forme in
                    let l = CGFloat(forme.place.boite.width) * cote * echelle
                    let h = CGFloat(forme.place.boite.height) * cote * echelle
                    let corpsNombre = min(nombreMax, max(nombreMin, h * 0.55))
                    let corps = min(plafond, taille(forme.texte, largeur: l, hauteur: h,
                                                    corpsNombre: corpsNombre))
                    return (forme.texte, forme.place.boite, corps, corpsNombre)
                }
            // Une ligne vaut mieux que deux : il faut que la coupure fasse
            // vraiment gagner quelque chose pour la préférer.
            if essais.count > 1, essais[1].corps > essais[0].corps + 0.5 { essais.swapAt(0, 1) }

            // Le nombre seul se pose là où son nom viendra, pour ne pas sauter
            // au moment où le nom paraît : dans le rectangle de la forme qui
            // s'y écrirait le plus gros.
            guard let reference = formes.indices.max(by: {
                formes[$0].place.aisance < formes[$1].place.aisance
            }) else { continue }
            let prevue = essais.first { $0.texte == formes[reference].texte } ?? essais[0]
            let legendeSeule = Legende(centre: centre(prevue.boite), nom: nil,
                                       corpsNom: 0, corpsNombre: prevue.corpsNombre)

            // Le nom, de la plus grande façon à la plus petite. En plus petit
            // aussi : le Brésil perdait son nom, écrit en grand, pour un coin
            // qui touchait l'étiquette du Pérou — et il avait toute la place
            // de l'écrire un cran en dessous.
            var completes: [(legende: Legende, cadre: CGRect)] = []
            for essai in essais where essai.corps >= plancher {
                var tailles = [essai.corps]
                if essai.corps - plancher > 1.5 { tailles.append((essai.corps + plancher) / 2) }
                if essai.corps - plancher > 0.5 { tailles.append(plancher) }
                for corps in tailles {
                    let legende = Legende(centre: centre(essai.boite), nom: essai.texte,
                                          corpsNom: corps, corpsNombre: essai.corpsNombre)
                    completes.append((legende, cadre(legende, nombre: hommes, echelle: echelle)))
                }
            }

            choix.append(Choix(id: id, rang: rang, seul: legendeSeule,
                               seulCadre: cadre(legendeSeule, nombre: hommes, echelle: echelle),
                               completes: completes))
        }

        // Les plus grands noms d'abord : ce sont ceux qu'on voit de loin.
        func plusGrand(_ c: Choix) -> CGFloat { c.completes.first?.legende.corpsNom ?? 0 }
        let parTaille = choix.sorted { (plusGrand($0), -$0.rang) > (plusGrand($1), -$1.rang) }
        var poses: [TerritoryID: Legende] = [:]
        var occupe: [TerritoryID: CGRect] = [:]
        for c in parTaille {
            for complete in c.completes {
                let gene = choix.contains { autre in
                    guard autre.id != c.id else { return false }
                    return (occupe[autre.id] ?? autre.seulCadre).intersects(complete.cadre)
                }
                if !gene {
                    poses[c.id] = complete.legende
                    occupe[c.id] = complete.cadre
                    break
                }
            }
        }
        for c in choix where poses[c.id] == nil { poses[c.id] = c.seul }
        return poses
    }

    // MARK: - Mesurer

    /// Le rectangle où cette forme du nom s'écrit le plus gros, le nombre
    /// au-dessus d'elle.
    ///
    /// Le calcul se fait en unités du plateau, le nombre pris à proportion du
    /// nom — un quart de plus, le rapport de leurs plafonds. Tout y grandit
    /// ensemble quand on rapproche la carte : le choix ne dépend donc pas du
    /// rapprochement, et ne change pas sous le doigt. À égalité, le plus plat,
    /// qui vient le premier.
    @MainActor
    static func rectangle(pour texte: String,
                          parmi boites: [LabelBox]) -> (boite: LabelBox, aisance: Double) {
        let lignes = texte.split(separator: "\n").map(String.init)
        let large = Double(lignes.map(largeurNom).max() ?? 1)
        let haut = 0.95 * Double(nombreMax / plafond) + Double(lignes.count) * 1.1
        var meilleur = (boite: boites[0], aisance: -Double.infinity)
        for b in boites {
            let aisance = min(b.width * Double(debord) / large, b.height * Double(debord) / haut)
            if aisance > meilleur.aisance { meilleur = (b, aisance) }
        }
        return meilleur
    }

    /// La plus grande taille, en points d'écran, à laquelle cette forme du nom
    /// tient dans le rectangle avec le nombre au-dessus. Négative, le
    /// rectangle n'a même pas la place du nombre.
    @MainActor
    static func taille(_ texte: String, largeur: CGFloat, hauteur: CGFloat,
                       corpsNombre: CGFloat) -> CGFloat {
        let lignes = texte.split(separator: "\n").map(String.init)
        let large = lignes.map(largeurNom).max() ?? 0
        guard large > 0 else { return 0 }
        return min(largeur * debord / large,
                   (hauteur * debord - corpsNombre * 0.95) / (CGFloat(lignes.count) * 1.1))
    }

    /// Le nom tel quel, et coupé en deux là où les lignes s'équilibrent le
    /// mieux — à une espace, ou après un trait d'union : « Moyen-Orient » et
    /// « Nouvelle-Guinée » n'ont pas d'espace, et ne tenaient sur une seule
    /// ligne que dans les plus grands rapprochements.
    @MainActor
    static func coupures(_ nom: String) -> [String] {
        if let deja = coupuresRetenues[nom] { return deja }
        var coupes: [(String, String)] = []
        for i in nom.indices where nom[i] == " " || nom[i] == "-" {
            let avant = nom[..<i]
            let apres = nom[nom.index(after: i)...]
            guard !avant.isEmpty, !apres.isEmpty else { continue }
            coupes.append(nom[i] == " " ? (String(avant), String(apres))
                                        : (String(avant) + "-", String(apres)))
        }
        let equilibree = coupes.min {
            max(largeurNom($0.0), largeurNom($0.1)) < max(largeurNom($1.0), largeurNom($1.1))
        }
        let retenues = [nom] + (equilibree.map { ["\($0.0)\n\($0.1)"] } ?? [])
        coupuresRetenues[nom] = retenues
        return retenues
    }

    @MainActor private static var coupuresRetenues: [String: [String]] = [:]

    /// Ce que l'étiquette occupe à l'écran, nombre compris, avec l'air qu'on
    /// laisse autour. Sa position est en points du plateau : elle se
    /// rapproche ici.
    ///
    /// Les hauteurs sont celles de l'encre et non des lignes : un chiffre n'a
    /// pas de jambage, et l'interligne est resserré à l'affichage.
    @MainActor
    static func cadre(_ legende: Legende, nombre: Int, echelle: CGFloat) -> CGRect {
        let chiffres = largeurChiffres(nombre) * legende.corpsNombre
        var largeur = chiffres
        var hauteur = legende.corpsNombre * 0.8
        if let nom = legende.nom {
            let lignes = nom.split(separator: "\n").map(String.init)
            largeur = max(chiffres, (lignes.map(largeurNom).max() ?? 0) * legende.corpsNom)
            hauteur = legende.corpsNombre * 0.95 + CGFloat(lignes.count) * legende.corpsNom * 1.1
        }
        return CGRect(x: legende.centre.x * echelle - largeur / 2 - air,
                      y: legende.centre.y * echelle - hauteur / 2 - air,
                      width: largeur + 2 * air, height: hauteur + 2 * air)
    }

    // La largeur des textes, pour une taille d'un point. Elle se mesure une
    // fois par nom : le plateau se redessine à chaque image d'un pincement.
    //
    // Elle se mesure à la taille où l'on écrit, et non en grand. La police du
    // système n'a pas le même dessin à 10 points qu'à 100 : en petit, elle
    // s'espace pour rester lisible. Mesurés à 100 points, les noms sortaient
    // plus étroits d'un bon dixième qu'à l'écran, et deux étiquettes jugées
    // à distance se touchaient — « États-Unis » contre « États-Unis ».

    @MainActor private static var largeursNoms: [String: CGFloat] = [:]
    @MainActor private static var largeursChiffres: [Int: CGFloat] = [:]

    @MainActor
    static func largeurNom(_ texte: String) -> CGFloat {
        if let l = largeursNoms[texte] { return l }
        let l = mesurer(texte, police: .systemFont(ofSize: 10, weight: .semibold)) / 10
        largeursNoms[texte] = l
        return l
    }

    @MainActor
    static func largeurChiffres(_ n: Int) -> CGFloat {
        if let l = largeursChiffres[n] { return l }
        let droite = PoliceSysteme.systemFont(ofSize: 12, weight: .bold)
        let ronde = droite.fontDescriptor.withDesign(.rounded)
            .flatMap { PoliceSysteme(descriptor: $0, size: 12) } ?? droite
        let l = mesurer("\(n)", police: ronde) / 12
        largeursChiffres[n] = l
        return l
    }

    private static func mesurer(_ texte: String, police: PoliceSysteme) -> CGFloat {
        (texte as NSString).size(withAttributes: [.font: police]).width
    }
}

#if canImport(UIKit)
private typealias PoliceSysteme = UIFont
#else
private typealias PoliceSysteme = NSFont
#endif

/// Une étiquette posée sur le plateau dessiné.
///
/// Le plateau se grossit d'un bloc quand on le rapproche : les tailles se
/// divisent donc par le rapprochement, pour rester à l'écran celles que
/// `Legendes` a choisies.
struct EtiquetteDessinee: View {
    let legende: Legende
    let nombre: Int
    let echelle: CGFloat

    var body: some View {
        // Les lignes sont resserrées à la main : l'interligne ordinaire
        // laissait entre le nombre et le nom, puis entre les deux lignes du
        // nom, un vide qui mangeait la place gagnée. Deux textes empilés se
        // resserrent, l'interligne d'un seul texte ne descend pas sous zéro.
        VStack(spacing: -legende.corpsNombre * 0.14 / echelle) {
            Text("\(nombre)")
                .font(.system(size: legende.corpsNombre / echelle, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.55), radius: 1.5 / echelle, y: 1 / echelle)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: nombre)
            if let nom = legende.nom {
                VStack(spacing: -legende.corpsNom * 0.12 / echelle) {
                    ForEach(nom.split(separator: "\n").map(String.init), id: \.self) { ligne in
                        Text(ligne)
                    }
                }
                .font(.system(size: legende.corpsNom / echelle, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.7), radius: 1.5 / echelle, y: 0.5 / echelle)
            }
        }
        .fixedSize()
        .position(legende.centre)
        .allowsHitTesting(false)
    }
}
