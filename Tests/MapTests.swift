//
//  MapTests.swift
//  RiskeloTests
//
//  Le plateau est engendré par un dessin en toutes lettres, et non saisi
//  territoire par territoire. C'est justement pour cela qu'il faut le
//  vérifier : une lettre déplacée dans le plan ne se voit pas, et peut isoler
//  un territoire ou couper un continent en deux. Une partie ne pourrait plus
//  finir, et rien ne l'annoncerait.
//

import CoreGraphics
import Testing
@testable import Riskelo

/// Les mêmes vérifications s'appliquent à chaque plateau du catalogue : un
/// plateau ajouté ne doit pas pouvoir entrer sans les passer.
struct MapTests {

    let board = Boards.anneau.board

    @Test(arguments: Boards.allCases)
    func chaquePlateauSeTient(_ p: Boards) {
        let m = p.board.map
        #expect(m.isConnected, "\(p.label) est en morceaux")
        #expect(m.order.count >= 20, "\(p.label) est trop petit")
        #expect(m.continentsInOrder.count >= 4)
        for id in m.order {
            #expect(!m.neighbors(of: id).isEmpty, "\(p.label) : \(id) ne touche rien")
            for voisin in m.neighbors(of: id) {
                #expect(m.areAdjacent(voisin, id), "\(p.label) : voisinage à sens unique")
            }
        }
        let noms = m.order.compactMap { m[$0]?.name }
        #expect(Set(noms).count == noms.count, "\(p.label) : deux territoires du même nom")

        for continent in m.continentsInOrder {
            let dedans = Set(continent.territories)
            var vus: Set<TerritoryID> = [continent.territories[0]]
            var pile = [continent.territories[0]]
            while let id = pile.popLast() {
                for n in m.neighbors(of: id) where dedans.contains(n) && !vus.contains(n) {
                    vus.insert(n); pile.append(n)
                }
            }
            #expect(vus.count == dedans.count, "\(p.label) : \(continent.name) est en morceaux")
            let portes = Set(continent.territories.filter { id in
                m.neighbors(of: id).contains { m[$0]?.continent != continent.id }
            })
            #expect(portes.count >= 1, "\(p.label) : \(continent.name) est inatteignable")
        }

        // Un continent à porte unique est imprenable une fois tenu, et décide
        // la partie à lui seul : c'est l'Australie du Risk d'origine. Un
        // plateau a le droit d'en avoir une — c'est un parti pris de jeu —
        // mais jamais deux, sans quoi la partie se joue à qui les prend.
        let forteresses = m.continentsInOrder.filter { c in
            Set(c.territories.filter { id in
                m.neighbors(of: id).contains { m[$0]?.continent != c.id }
            }).count == 1
        }
        #expect(forteresses.count <= 1,
                "\(p.label) : \(forteresses.map(\.name).joined(separator: ", ")) sont toutes à porte unique")
    }

    @Test func lePlateauEstDUnSeulTenant() {
        #expect(board.map.isConnected)
        #expect(board.map.order.count == 28)
        #expect(board.map.continentsInOrder.count == 5)
    }

    @Test func leVoisinageEstReciproque() {
        for id in board.map.order {
            for voisin in board.map.neighbors(of: id) {
                #expect(board.map.areAdjacent(voisin, id),
                        "\(id) touche \(voisin), mais pas l'inverse")
            }
        }
    }

    @Test func personneNEstIsole() {
        for id in board.map.order {
            #expect(!board.map.neighbors(of: id).isEmpty, "\(id) ne touche rien")
        }
    }

    @Test func chaqueContinentEstDUnSeulTenant() {
        for continent in board.map.continentsInOrder {
            let dedans = Set(continent.territories)
            var vus: Set<TerritoryID> = [continent.territories[0]]
            var pile = [continent.territories[0]]
            while let id = pile.popLast() {
                for n in board.map.neighbors(of: id) where dedans.contains(n) && !vus.contains(n) {
                    vus.insert(n)
                    pile.append(n)
                }
            }
            #expect(vus.count == dedans.count, "\(continent.name) est en morceaux")
        }
    }

    /// Un continent à porte unique est imprenable, et décide la partie à lui
    /// seul — c'est le défaut de l'Australie du Risk d'origine.
    @Test func aucunContinentNAUneSeulePorte() {
        for continent in board.map.continentsInOrder {
            let portes = Set(continent.territories.filter { id in
                board.map.neighbors(of: id).contains { board.map[$0]?.continent != continent.id }
            })
            #expect(portes.count >= 2, "\(continent.name) n'a que \(portes.count) porte")
        }
    }

    @Test func chaqueTerritoireAUnNomEtUnePlace() {
        for id in board.map.order {
            let t = board.map[id]
            #expect(t != nil)
            #expect(!(t?.name.isEmpty ?? true))
            let centre = board.layout.centers[id]
            #expect(centre != nil)
            #expect((0...1).contains(centre?.x ?? -1))
            #expect((centre?.y ?? -1) >= 0 && (centre?.y ?? 99) <= board.layout.aspect)
        }
    }

    /// Une case a six côtés ; ceux qui ne donnent pas sur un voisin du même
    /// continent sont des frontières. Les traversées, elles, ne passent par
    /// aucun côté — c'est tout leur intérêt — et sont donc mises à part.
    @Test(arguments: Boards.allCases)
    func chaquePlateauSaitOuSontSesFrontieres(_ p: Boards) {
        let m = p.board.map
        for id in m.order {
            let outreMer = Set(p.board.layout.seaRoutes.compactMap { r -> TerritoryID? in
                r.from == id ? r.to : (r.to == id ? r.from : nil)
            })
            let memeContinent = m.neighbors(of: id).filter {
                !outreMer.contains($0) && m[$0]?.continent == m[id]?.continent
            }.count
            #expect(p.board.layout.frontierEdges[id]?.count == 6 - memeContinent,
                    "\(p.label) : \(m[id]?.name ?? id)")
        }
    }

    /// Une traversée doit être réciproque et mener quelque part. Écrite à la
    /// main, c'est la seule partie du plateau qui puisse être fausse.
    @Test(arguments: Boards.allCases)
    func lesTraverseesSontReciproques(_ p: Boards) {
        let m = p.board.map
        for route in p.board.layout.seaRoutes {
            #expect(m[route.from] != nil, "\(p.label) : traversée depuis nulle part")
            #expect(m[route.to] != nil, "\(p.label) : traversée vers nulle part")
            #expect(m.areAdjacent(route.from, route.to), "\(p.label) : traversée à sens unique")
            #expect(m.areAdjacent(route.to, route.from), "\(p.label) : traversée à sens unique")
            #expect(route.from != route.to)
        }
    }

    /// Les traits de frontière sont calculés une fois, à la fabrication du
    /// plan, et le plateau les dessine sans réfléchir. Si une lettre du plan
    /// bouge et que ce calcul se décale, les continents apparaîtront faux
    /// sans que rien ne plante — le joueur croira devoir prendre un territoire
    /// qui n'en fait pas partie.
    ///
    /// L'invariant est simple : une case a six côtés ; ceux qui ne donnent pas
    /// sur un voisin du même continent sont des frontières.
    @Test func lesFrontieresCollentAuxContinents() {
        for id in board.map.order {
            let memeContinent = board.map.neighbors(of: id).filter {
                board.map[$0]?.continent == board.map[id]?.continent
            }.count
            let traits = board.layout.frontierEdges[id]?.count ?? -1
            #expect(traits == 6 - memeContinent,
                    "\(board.map[id]?.name ?? id) : \(traits) traits pour \(6 - memeContinent) attendus")
        }
    }

    @Test func lesNomsSontUniques() {
        let noms = board.map.order.compactMap { board.map[$0]?.name }
        #expect(Set(noms).count == noms.count)
    }
}

// MARK: - Le cadrage

/// Jusqu'où le plateau peut se déplacer sous un panneau qui lui mange le bas.
///
/// Le recadrage visait juste et la borne l'arrêtait en chemin : les deux
/// places d'un assaut restaient sous le panneau, sur un téléphone où celui-ci
/// couvre les trois quarts de la carte. On ne voyait donc plus où l'on se
/// battait au moment de décider combien d'hommes avancent — et une capture
/// d'écran à la main était le seul moyen de s'en apercevoir. C'est de
/// l'arithmétique : elle se vérifie ici.
struct CadrageTests {

    /// Les mesures d'un iPhone ordinaire au moment du choix : le plateau
    /// dispose de 587 points de haut, la carte en occupe 400, et le panneau
    /// couvre les trois quarts de ce qui reste.
    let vue: CGFloat = 587, plateau: CGFloat = 400, couvert: CGFloat = 0.75

    /// Une place du bas de la carte doit pouvoir remonter dans la bande
    /// libre. C'est le cas qui a échoué deux fois de suite.
    @Test func onPeutRemonterUnePlaceDuBasDansLaBandeLibre() {
        let milieuDeLaBande = vue * (1 - couvert) / 2
        // Une place aux quatre cinquièmes de la carte, vue du haut du plateau.
        let place = (vue - plateau) / 2 + plateau * 0.8
        let vise = milieuDeLaBande - place
        let bornes = Cadrage.bornesVerticales(hauteurVue: vue, hauteurPlateau: plateau,
                                              couvert: couvert)
        #expect(bornes.contains(vise),
                "le recadrage vise \(vise) et la borne l'arrête à \(bornes.lowerBound)")
    }

    /// On ne perd pas le plateau pour autant : monté au maximum, il en reste
    /// une marge sous le haut de l'écran ; descendu au maximum, son haut
    /// reste dans la bande que rien ne couvre.
    @Test func lePlateauNeSortJamaisEntierement() {
        for couvert in [CGFloat(0), 0.4, 0.75, 0.9] {
            let bornes = Cadrage.bornesVerticales(hauteurVue: vue, hauteurPlateau: plateau,
                                                  couvert: couvert)
            let basDuPlateau = (vue + plateau) / 2 + bornes.lowerBound
            #expect(basDuPlateau >= Cadrage.marge - 0.01,
                    "couvert \(couvert) : il ne reste que \(basDuPlateau) points de plateau")
            let hautDuPlateau = (vue - plateau) / 2 + bornes.upperBound
            #expect(hautDuPlateau <= vue * (1 - couvert) - Cadrage.marge + 0.01,
                    "couvert \(couvert) : le haut du plateau passe sous la bande libre")
        }
    }

    /// Une carte plus grande que la vue se promène d'autant plus.
    @Test func unGrandPlateauSePromeneDavantage() {
        let petite = Cadrage.bornesVerticales(hauteurVue: vue, hauteurPlateau: 300, couvert: 0)
        let grande = Cadrage.bornesVerticales(hauteurVue: vue, hauteurPlateau: 900, couvert: 0)
        #expect(grande.lowerBound < petite.lowerBound)
        #expect(grande.upperBound > petite.upperBound)
    }

    /// Et sans rien qui couvre, la carte se promène des deux côtés.
    @Test func sansPanneauLeDeplacementResteDeDeuxCotes() {
        let bornes = Cadrage.bornesVerticales(hauteurVue: vue, hauteurPlateau: plateau,
                                              couvert: 0)
        #expect(bornes.lowerBound < 0 && bornes.upperBound > 0)
    }
}
