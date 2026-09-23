//
//  Boards.swift
//  Riskelo
//
//  Les plateaux, et le choix entre eux.
//
//  Chacun est un dessin en toutes lettres, dont les voisinages se déduisent :
//  c'est ce qui permet d'en ajouter un sans risquer la faute invisible — un
//  voisinage saisi de travers ne plante rien, il rend un territoire imprenable
//  et se découvre trois parties plus tard.
//
//  Deux façons de dessiner, et la même garantie.
//
//  L'Anneau et l'Europe sont des damiers d'hexagones : une case par
//  territoire, et le plan se retouche en déplaçant une lettre. Le Monde est
//  une grille fine où un territoire est un amas de cases, ce qui lui rend ses
//  côtes (voir `Atlas` et `PlanDuMonde`). Dans les deux cas les voisinages se
//  déduisent du dessin au lieu d'être saisis, et c'est tout ce qui compte :
//  un voisinage écrit de travers ne plante rien, il rend un territoire
//  imprenable et se découvre trois parties plus tard.
//

import Foundation

/// Le nom d'une chose de la carte, dans la langue de l'interface.
///
/// Les plateaux sont écrits en français dans les données — c'est la langue
/// d'origine du jeu — et le catalogue en porte l'anglais. La traduction se
/// fait ici, au moment de lire, et non dans les données : un territoire est
/// une case du plateau avant d'être un mot, et sa définition n'a pas à
/// exister en double.
func nomTraduit(_ brut: String) -> String {
    dit(String.LocalizationValue(brut))
}

enum Boards: String, CaseIterable, Identifiable, Codable {

    /// Le nom d'un camp. Il tient ici plutôt que dans une vue : deux appareils
    /// doivent nommer les mêmes joueurs de la même façon.
    static func nomDeCamp(_ rang: PlayerID) -> String {
        let noms = ["Bleu", "Rouge", "Vert", "Ambre", "Violet"].map(nomTraduit)
        return noms[((rang % noms.count) + noms.count) % noms.count]
    }

    case anneau, europe, monde

    var id: String { rawValue }

    var label: String {
        switch self {
        case .anneau: nomTraduit("L'Anneau")
        case .europe: nomTraduit("Europe")
        case .monde:  nomTraduit("Monde")
        }
    }

    var detail: String {
        switch self {
        case .anneau: nomTraduit("Un monde inventé, cinq terres en cercle. 28 territoires.")
        case .europe: nomTraduit("De l'Atlantique à la mer Noire. 38 territoires.")
        case .monde:  nomTraduit("La carte du monde, 42 territoires sur six continents.")
        }
    }

    /// Construit une fois pour toutes : un plateau ne change jamais.
    var board: Board { Boards.tous[self]! }

    private static let tous: [Boards: Board] = Dictionary(
        uniqueKeysWithValues: Boards.allCases.map { ($0, $0.build()) })

    private func build() -> Board {
        switch self {
        case .anneau: HexPlan.build(rows: Boards.planAnneau, continents: Boards.terresAnneau)
        case .europe: HexPlan.build(rows: Boards.planEurope, continents: Boards.terresEurope,
                                    seaRoutes: Boards.traverseesEurope)
        // Le monde est le seul plateau dessiné : ses côtes viennent de la
        // géographie et non d'un damier. Les deux autres sont des mondes
        // inventés, et l'hexagone leur va — il dit franchement qu'ils le sont.
        case .monde:  Atlas.build(rows: Boards.planDuMonde, terres: Boards.terresDuMonde,
                                  places: Boards.placesDuMonde,
                                  traversees: Boards.traverseesDuMonde)
        }
    }

    // MARK: - L'Anneau

    /// Cinq terres disposées en cercle — Boréa, Ostmark, Méridia, Zéphyrie,
    /// Ponant, et retour. Aucune n'a une seule porte : celle qui n'a qu'une
    /// entrée devient imprenable et décide la partie à elle seule, c'est le
    /// défaut de l'Australie du Risk d'origine.
    static let planAnneau = [
        ". A A A . .",
        ". A A . B .",
        "C C . B B B",
        "C C C . B .",
        ". C . . D D",
        ". C E . D .",
        ". E E E D D",
        ". . E E . .",
    ]

    static let terresAnneau: [HexPlan.ContinentSpec] = [
        .init(id: "A", name: "Boréa", bonus: 3,
              names: ["Fjordane", "Grise-Lande", "Havreterre", "Skerrie", "Cap Blanc"]),
        .init(id: "B", name: "Ostmark", bonus: 3,
              names: ["Steppe Haute", "Khanat", "Sablier", "Vieux-Port", "Mont Rouge"]),
        .init(id: "C", name: "Ponant", bonus: 4,
              names: ["Armorique", "Bocage", "Val-Clair", "Les Marches",
                      "Saline", "Pierregrise", "Landes Hautes"]),
        .init(id: "D", name: "Méridia", bonus: 2,
              names: ["Oliveraie", "Sirocco", "Baie d'Or", "Dune", "Serrat"]),
        .init(id: "E", name: "Zéphyrie", bonus: 3,
              names: ["Alizé", "Corail", "Récif", "Palmeraie", "Lagune", "Mangrove"]),
    ]

    // MARK: - Europe

    /// La silhouette de l'Europe, autant qu'un damier le permet : le bras
    /// scandinave qui monte au nord, la péninsule ibérique qui descend au
    /// sud-ouest, la botte italienne, la Grèce et ses îles en bas, et les
    /// Britanniques au large — reliées par la Manche, qui est une traversée.
    static let planEurope = [
        ". . . A A A . .",
        ". . . A . F . .",
        ". B . C F F . .",
        ". B C C E F . .",
        ". . C C E F F .",
        "D . C C E E F .",
        "D D C E E E F .",
        ". D D E E . . .",
        ". . D D . . . .",
    ]

    static let terresEurope: [HexPlan.ContinentSpec] = [
        .init(id: "A", name: "Scandinavie", bonus: 2,
              names: ["Norvège", "Suède", "Finlande", "Danemark"]),
        .init(id: "B", name: "Îles Britanniques", bonus: 2,
              names: ["Écosse", "Angleterre"]),
        .init(id: "C", name: "Europe de l'Ouest", bonus: 4,
              names: ["Pays-Bas", "Belgique", "Allemagne", "France",
                      "Tchéquie", "Autriche", "Suisse", "Italie du Nord"]),
        .init(id: "D", name: "Méditerranée", bonus: 3,
              names: ["Portugal", "Espagne", "Baléares", "Corse",
                      "Sardaigne", "Italie", "Sicile"]),
        .init(id: "E", name: "Europe centrale", bonus: 4,
              names: ["Pologne", "Slovaquie", "Hongrie", "Slovénie",
                      "Croatie", "Serbie", "Albanie", "Grèce", "Crète"]),
        .init(id: "F", name: "Europe de l'Est", bonus: 4,
              names: ["Pays baltes", "Russie", "Biélorussie", "Ukraine",
                      "Moldavie", "Roumanie", "Bulgarie", "Turquie"]),
    ]

    /// La Manche : sans elle, les îles seraient inatteignables.
    static let traverseesEurope: [(String, String)] = [
        ("Angleterre", "Belgique"),
        ("Angleterre", "France"),
        ("Écosse", "Norvège"),
    ]

}

/// Le plateau par défaut, celui des essais et des aperçus.
enum TestBoard {
    static var board: Board { Boards.anneau.board }
}
