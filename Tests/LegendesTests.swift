//
//  LegendesTests.swift
//  RiskeloTests
//
//  Les noms du plateau dessiné.
//
//  Ils se chevauchaient, et cela ne se voyait qu'à l'écran : rien ne plantait,
//  la carte devenait seulement illisible — « Ouest des » et « Est des
//  États-Unis » l'un dans l'autre, « Sibérie » collé à « Iakoutie ». Deux
//  choses sont clouées ici. Les rectangles où l'on écrit tombent dans leur
//  territoire, case pour case. Et aucun nom posé ne touche une autre
//  étiquette, du téléphone à l'iPad, de la carte entière au plus grand
//  rapprochement.
//
//  Rien ici n'ouvre de partie : le plateau et les étiquettes se calculent
//  sans elle.
//

import CoreGraphics
import Testing
@testable import Riskelo

@MainActor
struct LegendesTests {

    let board = Boards.mondeReel.board

    /// Chaque rectangle d'écriture est fait de cases du territoire, et d'elles
    /// seules. Un rectangle qui mordrait sur la mer ou sur le voisin y
    /// poserait un nom.
    @Test func lesRectanglesTombentDansLeurTerritoire() {
        let plan = Boards.planDuMonde.map { Array($0) }
        let largeur = Double(plan.map(\.count).max() ?? 1)
        for id in board.map.order {
            let boites = board.layout.labelBoxes[id] ?? []
            #expect(!boites.isEmpty, "\(board.map[id]?.name ?? id) sans rectangle")
            for b in boites {
                let x0 = Int(((b.center.x - b.width / 2) * largeur).rounded())
                let y0 = Int(((b.center.y - b.height / 2) * largeur).rounded())
                let w = Int((b.width * largeur).rounded())
                let h = Int((b.height * largeur).rounded())
                for y in y0 ..< y0 + h {
                    for x in x0 ..< x0 + w {
                        #expect(String(plan[y][x]) == id,
                                "\(board.map[id]?.name ?? id) : la case \(x),\(y) n'est pas à lui")
                    }
                }
            }
        }
    }

    /// Du plus plat au plus haut, chacun plus étroit que le précédent : un
    /// rectangle plus bas et pas plus large qu'un autre ne servirait à rien.
    @Test func unRectangleParHauteurUtile() {
        for id in board.map.order {
            let boites = board.layout.labelBoxes[id] ?? []
            for (a, b) in zip(boites, boites.dropFirst()) {
                #expect(a.height < b.height)
                #expect(a.width > b.width)
            }
        }
    }

    /// Le cœur de l'affaire : un nom affiché ne touche aucune autre étiquette.
    @Test(arguments: [393.0, 1000.0], [0.9, 1.0, 1.4, 2.2, 3.0, 4.0])
    func aucunNomNeTouchePersonne(cote: Double, echelle: Double) {
        let legendes = placer(cote: cote, echelle: echelle)
        let cadres = legendes.mapValues {
            Legendes.cadre($0, nombre: nombre($0), echelle: CGFloat(echelle))
        }
        for (id, legende) in legendes where legende.nom != nil {
            for (autre, cadre) in cadres where autre != id {
                #expect(!cadres[id]!.intersects(cadre),
                        "\(board.map[id]!.name) touche \(board.map[autre]!.name) à \(echelle)×")
            }
        }
    }

    /// Et ils paraissent : une règle qui ne poserait aucun nom ne ferait
    /// chevaucher personne. Au plus grand rapprochement du téléphone, tous
    /// ou presque se lisent — Madagascar, trop fine, garde son seul nombre.
    @Test func lesNomsParaissentQuandOnRapproche() {
        let loin = placer(cote: 393, echelle: 1.4).values.filter { $0.nom != nil }.count
        let pres = placer(cote: 393, echelle: 4).values.filter { $0.nom != nil }.count
        #expect(loin >= 10)
        #expect(pres >= 40)
        #expect(pres > loin)
    }

    /// Sous le doigt, une étiquette ne se promène pas. Quand le rectangle se
    /// choisissait à chaque image, un pincement de bout en bout la faisait
    /// sauter près d'une centaine de fois sur la carte ; elle ne bouge plus
    /// qu'au moment où son nom passe d'une ligne à deux, ou s'écarte d'un
    /// voisin.
    @Test func uneEtiquetteNeSautePasSousLeDoigt() {
        var avant: [TerritoryID: CGPoint] = [:]
        var sauts = 0
        for pas in 0 ... 300 {
            for (id, legende) in placer(cote: 393, echelle: 0.9 + 3.1 * Double(pas) / 300) {
                if let p = avant[id], p != legende.centre { sauts += 1 }
                avant[id] = legende.centre
            }
        }
        #expect(sauts <= 20, "\(sauts) sauts sur un pincement")
    }

    /// Le nombre, lui, paraît toujours : c'est lui qui sert à jouer.
    @Test func chaqueTerritoireASonNombre() {
        let legendes = placer(cote: 393, echelle: 0.9)
        #expect(legendes.count == board.map.order.count)
    }

    @Test func unNomSeCoupeLaOuLesLignesSEquilibrent() {
        #expect(Legendes.coupures("Territoires du Nord-Ouest").last == "Territoires du\nNord-Ouest")
        #expect(Legendes.coupures("Moyen-Orient").last == "Moyen-\nOrient")
        #expect(Legendes.coupures("Chine") == ["Chine"])
    }

    // MARK: -

    /// Douze hommes partout : c'est le nombre le plus large qu'on voie
    /// d'ordinaire, et donc celui qui gêne le plus.
    private func nombre(_ l: Legende) -> Int { 12 }

    private func placer(cote: Double, echelle: Double) -> [TerritoryID: Legende] {
        Legendes.placer(layout: board.layout, ordre: board.map.order,
                        nom: { board.map[$0]?.name ?? $0 }, nombre: { _ in 12 },
                        cote: CGFloat(cote), echelle: CGFloat(echelle))
    }
}
