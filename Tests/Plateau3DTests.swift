//
//  Plateau3DTests.swift
//  RiskeloTests
//
//  Le plateau en relief se touche par le calcul : le doigt tombe sur un point
//  de l'écran, on remonte le rayon jusqu'à la table, et l'on cherche la terre
//  qui s'y trouve. Une erreur ici ne plante rien — elle fait jouer le coup
//  d'à côté. C'est pourquoi chaque terre de chaque plateau est touchée ici, de
//  l'œil même qui ouvre la partie.
//

import CoreGraphics
import Foundation
import Testing
@testable import Riskelo

struct Plateau3DTests {

    let telephone = CGSize(width: 393, height: 560)
    let mac = CGSize(width: 960, height: 620)

    @Test func leRepereFaitLAllerRetour() {
        let r = Repere3D(aspect: 0.58)
        for p in [Point(x: 0, y: 0), Point(x: 0.3, y: 0.41), Point(x: 1, y: 0.58)] {
            let retour = r.plateau(r.monde(p, hauteur: 0.7))
            #expect(abs(retour.x - p.x) < 1e-5 && abs(retour.y - p.y) < 1e-5)
        }
        // Le bas de la carte vient vers celui qui regarde.
        #expect(r.monde(Point(x: 0.5, y: 0.58)).z > r.monde(Point(x: 0.5, y: 0)).z)
    }

    /// Le point de mire paraît au milieu de l'écran, et un point du sol
    /// projeté puis repris par le rayon retombe sur lui-même.
    @Test(arguments: [0, 0.6, -2.1])
    func laCameraVoitCeQuElleVise(lacet: Double) throws {
        var c = Camera3D(cible: SIMD2(1.2, -0.8), distance: 14)
        c.lacet = Float(lacet)
        let milieu = try #require(c.ecran(SIMD3(1.2, 0, -0.8), taille: telephone))
        #expect(abs(milieu.x - telephone.width / 2) < 0.5)
        #expect(abs(milieu.y - telephone.height / 2) < 0.5)

        for p in [CGPoint(x: 20, y: 30), CGPoint(x: 300, y: 500), CGPoint(x: 196, y: 100)] {
            let m = try #require(c.sol(p, taille: telephone, hauteur: 0.2))
            #expect(abs(m.y - 0.2) < 1e-4)
            let e = try #require(c.ecran(m, taille: telephone))
            #expect(abs(e.x - p.x) < 0.5 && abs(e.y - p.y) < 0.5)
        }
    }

    /// Le haut de l'écran montre le fond de la table, pas l'inverse.
    @Test func leNordEstAuFond() throws {
        let c = Camera3D(distance: 14)
        let nord = try #require(c.ecran(SIMD3(0, 0, -3), taille: telephone))
        let sud = try #require(c.ecran(SIMD3(0, 0, 3), taille: telephone))
        #expect(nord.y < sud.y)
    }

    /// Le panneau mange le bas : le point visé se pose au milieu de ce qui
    /// reste, et non au milieu de l'écran.
    @Test(arguments: [0.3, 0.55, 0.8])
    func leCentrageTientCompteDuPanneau(couvert: Double) throws {
        let c = Camera3D(distance: 16).centree(sur: SIMD2(2, 1), couvert: couvert)
        let e = try #require(c.ecran(SIMD3(2, 0, 1), taille: telephone))
        let attendu = telephone.height * (1 - couvert) / 2
        #expect(abs(e.y - attendu) < 1, "le point paraît à \(e.y), on l'attendait à \(attendu)")
        #expect(abs(e.x - telephone.width / 2) < 0.5)
    }

    /// Quand le panneau monte, la caméra glisse sans reculer : le joueur garde
    /// le rapprochement qu'il avait choisi, même si les deux places ne
    /// tiennent pas toutes deux dans la bande libre.
    @Test func leCadrageGardeLeRapprochement() throws {
        let c = Camera3D(cible: .zero, distance: 6)
        // Deux places loin l'une de l'autre, et toutes deux hors de la bande.
        let a = SIMD3<Float>(-3, 0, 4), b = SIMD3<Float>(3, 0, 5)
        let cadre = try #require(c.cadrage(de: a, vers: b, taille: telephone,
                                           couvert: 0.6, marge: 16))
        #expect(cadre.distance == c.distance)
        #expect(cadre.lacet == c.lacet && cadre.tangage == c.tangage)
        // Le milieu des deux se pose au milieu de la bande libre.
        let milieu = try #require(cadre.ecran(SIMD3(0, 0, 4.5), taille: telephone))
        #expect(abs(milieu.y - telephone.height * 0.4 / 2) < 1)

        // Déjà en vue : rien ne bouge.
        let proches = Camera3D(cible: SIMD2(0, 0.3), distance: 30)
        #expect(proches.cadrage(de: SIMD3(-0.2, 0, 0), vers: SIMD3(0.2, 0, 0),
                                taille: telephone, couvert: 0.3, marge: 16) == nil)
    }

    /// Le cadrage d'ensemble montre bien tout le plateau : ses quatre coins
    /// sont à l'écran, sur un téléphone comme sur un Mac.
    @Test(arguments: Boards.allCases)
    func lEnsembleMontreToutLePlateau(_ p: Boards) throws {
        let r = Repere3D(aspect: p.board.layout.aspect)
        for taille in [telephone, mac] {
            let c = Camera3D.ensemble(repere: r, taille: taille)
            for coin in [Point(x: 0, y: 0), Point(x: 1, y: 0),
                         Point(x: 0, y: p.board.layout.aspect), Point(x: 1, y: p.board.layout.aspect)] {
                let e = try #require(c.ecran(r.monde(coin), taille: taille))
                #expect(e.x >= -1 && e.x <= taille.width + 1 && e.y >= -1 && e.y <= taille.height + 1,
                        "\(p.label) : un coin sort de l'écran (\(e))")
            }
        }
    }

    /// Chaque terre se touche en son centre.
    @Test(arguments: Boards.allCases)
    func chaqueTerreSeToucheEnSonCentre(_ p: Boards) {
        let b = p.board
        for id in b.map.order {
            guard let c = b.layout.centers[id] else { continue }
            #expect(Touche3D.territoire(en: c, layout: b.layout, ordre: b.map.order) == id,
                    "\(p.label) : le centre de \(id) ne la désigne pas")
        }
    }

    /// Et de bout en bout : la terre vue à l'écran, de l'œil qui ouvre la
    /// partie, est bien celle que le doigt désigne.
    @Test(arguments: Boards.allCases)
    func leDoigtTombeSurLaTerreQuIlVoit(_ p: Boards) throws {
        let b = p.board
        let r = Repere3D(aspect: b.layout.aspect)
        let c = Camera3D.ensemble(repere: r, taille: telephone)
        let hauteur: Float = 0.15
        for id in b.map.order {
            guard let centre = b.layout.centers[id] else { continue }
            let e = try #require(c.ecran(r.monde(centre, hauteur: hauteur), taille: telephone))
            let m = try #require(c.sol(e, taille: telephone, hauteur: hauteur))
            #expect(Touche3D.territoire(en: r.plateau(m), layout: b.layout, ordre: b.map.order) == id,
                    "\(p.label) : le doigt posé sur \(id) désigne une autre terre")
        }
    }

    /// La mer loin de toute côte ne désigne rien : un doigt posé à côté du
    /// plateau ne doit pas jouer un coup.
    @Test(arguments: Boards.allCases)
    func lePlateauNeSeToucheQueSurLesTerres(_ p: Boards) {
        let b = p.board
        #expect(Touche3D.territoire(en: Point(x: -0.2, y: -0.2), layout: b.layout,
                                    ordre: b.map.order) == nil)
    }

    /// La caméra reste dans ce qui a du sens, quoi que fassent les doigts.
    @Test func laCameraResteBornee() {
        let r = Repere3D(aspect: 0.58)
        var c = Camera3D(distance: 20)
        c.pincer(1000)
        c.glisser(CGSize(width: 1e5, height: -1e5), taille: telephone)
        c.borner(repere: r, ensemble: 20)
        #expect(c.distance >= 20 * 0.16 - 1e-4)
        #expect(abs(c.cible.x) <= r.demiLargeur * 1.05 + 1e-4)
        #expect(abs(c.cible.y) <= r.demiProfondeur * 1.05 + 0.4 + 1e-4)
    }

    /// Le plateau en relief lit la partie avec les règles du plateau à plat :
    /// en phase d'attaque, ce qui est jouable est ce d'où l'on peut lancer un
    /// assaut, et les cibles sont des voisins ennemis.
    @Test func lInstantaneSuitLesRegles() throws {
        var g = GameState.start(board: .anneau,
                                players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                seed: 7)
        g.debugSkipToAttack()
        let base = try #require(g.territories(of: 0).first { g.canLaunch(from: $0) })
        let e = Instantane3D(partie: g, choisi: base, assaut: nil)
        #expect(e.jouables.contains(base))
        #expect(!e.cibles.isEmpty)
        for cible in e.cibles {
            #expect(g.map.areAdjacent(base, cible) && g.owner[cible] != 0)
        }
        #expect(e.hommes.count == g.map.order.count)
    }
}
