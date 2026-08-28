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
//  Les cartes réelles sont ici des hexagones posés sur la géographie, et non
//  des contours relevés. On y gagne le plan qui se retouche en déplaçant une
//  lettre, le tracé des frontières, et les tests qui vérifient à chaque
//  compilation que le monde se tient. On y perd la silhouette des côtes — que
//  personne ne distinguerait à cette taille sur un téléphone. Le moteur ne
//  connaissant que le voisinage, un rendu réaliste pourra remplacer celui-ci
//  sans qu'une ligne des règles bouge.
//

import Foundation

enum Boards: String, CaseIterable, Identifiable, Codable {

    /// Le nom d'un camp. Il tient ici plutôt que dans une vue : deux appareils
    /// doivent nommer les mêmes joueurs de la même façon.
    static func nomDeCamp(_ rang: PlayerID) -> String {
        let noms = ["Bleu", "Rouge", "Vert", "Ambre", "Violet"]
        return noms[((rang % noms.count) + noms.count) % noms.count]
    }

    case anneau, europe, monde

    var id: String { rawValue }

    var label: String {
        switch self {
        case .anneau: "L'Anneau"
        case .europe: "Europe"
        case .monde:  "Monde"
        }
    }

    var detail: String {
        switch self {
        case .anneau: "Un monde inventé, cinq terres en cercle. 28 territoires."
        case .europe: "De l'Atlantique à la mer Noire. 38 territoires."
        case .monde:  "Les six continents, 42 territoires — comme la boîte."
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
        case .monde:  HexPlan.build(rows: Boards.planMonde, continents: Boards.terresMonde,
                                    seaRoutes: Boards.traverseesMonde)
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

    // MARK: - Monde

    /// Les six continents du Risk, posés comme sur la boîte : l'Amérique à
    /// gauche, l'Asie qui occupe tout le nord-est, l'Afrique au centre-sud,
    /// l'Océanie dans son coin. Les traversées font le reste — c'est ainsi
    /// que le jeu d'origine relie l'Alaska au Kamtchatka.
    static let planMonde = [
        "N N N . E E . A A A .",
        "N N N . E E E A A A A",
        ". N N . E E . A A . .",
        ". N . . F F A A A . .",
        ". S . . F F . . . O O",
        ". S S . F F . . . O O",
        ". S . . . . . . . . .",
    ]

    static let terresMonde: [HexPlan.ContinentSpec] = [
        .init(id: "N", name: "Amérique du Nord", bonus: 5,
              names: ["Alaska", "Territoires du Nord-Ouest", "Groenland",
                      "Alberta", "Ontario", "Québec",
                      "Ouest des États-Unis", "Est des États-Unis",
                      "Amérique centrale"]),
        .init(id: "S", name: "Amérique du Sud", bonus: 2,
              names: ["Venezuela", "Pérou", "Brésil", "Argentine"]),
        .init(id: "E", name: "Europe", bonus: 5,
              names: ["Islande", "Scandinavie", "Grande-Bretagne",
                      "Europe du Nord", "Ukraine", "Europe de l'Ouest",
                      "Europe du Sud"]),
        .init(id: "F", name: "Afrique", bonus: 3,
              names: ["Afrique du Nord", "Égypte", "Congo",
                      "Afrique de l'Est", "Afrique du Sud", "Madagascar"]),
        .init(id: "A", name: "Asie", bonus: 7,
              names: ["Sibérie", "Iakoutie", "Kamtchatka",
                      "Oural", "Irkoutsk", "Mongolie", "Japon",
                      "Afghanistan", "Chine",
                      "Moyen-Orient", "Inde", "Siam"]),
        .init(id: "O", name: "Océanie", bonus: 2,
              names: ["Indonésie", "Nouvelle-Guinée",
                      "Australie occidentale", "Australie orientale"]),
    ]

    /// Trois traversées, et trois seulement.
    ///
    /// L'Amérique du Sud a été écartée de l'Afrique : les deux se touchaient
    /// par le Brésil, ce qui faisait passer un continent dans l'autre à pied.
    /// Elles sont désormais séparées par la mer, avec une seule porte —
    /// Congo–Brésil. De même l'Océanie ne tient plus à l'Asie que par
    /// Siam–Indonésie, qui se touchent et n'ont donc pas besoin de route.
    static let traverseesMonde: [(String, String)] = [
        ("Alaska", "Kamtchatka"),
        ("Groenland", "Islande"),
        ("Congo", "Brésil"),
    ]
}

/// Le plateau par défaut, celui des essais et des aperçus.
enum TestBoard {
    static var board: Board { Boards.anneau.board }
}
