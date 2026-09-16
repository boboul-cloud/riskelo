//
//  Themes.swift
//  Riskelo
//
//  Le thème d'une question, et la liste de ceux que l'appareil connaît.
//
//  C'était un enum à six cas, et le nom, l'icône et la couleur de chacun
//  étaient écrits dans trois `switch` répartis dans le code. Un enum ne
//  grandit pas après la compilation : tant qu'il en était un, ajouter un
//  thème voulait dire rouvrir quatre fichiers et recompiler le jeu.
//
//  Un thème est désormais une **valeur qui se déclare**, en tête de son
//  propre fichier de questions. Ajouter un thème, c'est déposer un fichier.
//  C'est ce qui rend possible un jour un thème vendu à part — mais le gain
//  est déjà là sans rien vendre : le nom d'un thème se corrige là où sont ses
//  questions, et non trois fichiers plus loin.
//
//  Ce que le thème garde en propre est réduit à son identifiant. Le nom, la
//  couleur, l'icône ne sont pas dans la partie : ils sont dans le catalogue,
//  et la partie n'emporte que le nom court. Une partie enregistrée reste donc
//  aussi petite qu'avant, et un thème renommé se relit sans conversion.
//

import Foundation

// MARK: - Le thème d'une question

/// Le thème, réduit à son identifiant — « histoire », « histoire-4e ».
///
/// Il s'encode comme un simple texte, exactement comme le faisait l'enum à
/// valeur texte qu'il remplace : les parties enregistrées se relisent, et la
/// forme des messages du réseau ne bouge pas d'un octet.
///
/// Il gagne au passage de ne plus jamais refuser une valeur qu'il ne connaît
/// pas. L'enum, lui, jetait une erreur sur un thème inconnu — et comme il
/// était au milieu de l'état de la partie, c'est la partie entière qui
/// devenait illisible, en silence.
struct Category: Hashable, Identifiable, Codable {

    let id: String

    init(_ id: String) { self.id = id }

    init(from decoder: Decoder) throws {
        id = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(id)
    }

    /// Le nom lisible. À défaut de catalogue — un thème reçu d'un appareil qui
    /// en sait plus — l'identifiant lui-même : illisible, mais jamais vide.
    var label: String { Themes.connu(self)?.nom ?? id }

    /// Le nom précédé de « de », élidé quand il le faut : « de Géographie »
    /// mais « d'Histoire ». Le français élide devant une voyelle, et devant
    /// l'h muet d'« histoire » — une règle qu'aucun calcul ne devine, et que
    /// le thème déclare donc lui-même.
    var apresDe: String { Themes.connu(self)?.de ?? "de \(label)" }

    /// Le nom du camembert, pour l'œil : la vue y accroche sa couleur.
    var symbol: String { Themes.connu(self)?.icone ?? "questionmark.circle" }

    /// Sa couleur, en trois valeurs de 0 à 1. Le moteur ne connaît pas
    /// SwiftUI, et n'a pas à le connaître pour porter une teinte.
    var teinte: Theme.Teinte { Themes.connu(self)?.teinte ?? Theme.Teinte(r: 0.5, v: 0.5, b: 0.5) }

    /// L'article qui l'ouvre, s'il se vend.
    var produit: String? { Themes.connu(self)?.produit }
}

// MARK: - La langue

/// La langue d'un thème, c'est-à-dire celle de ses questions.
///
/// Une seule application porte les deux banques, parce qu'Apple refuse deux
/// applications qui ne diffèrent que par la langue de leur contenu. Le thème
/// déclare la sienne en tête de son fichier ; l'appareil n'affiche que la
/// sienne, et le catalogue les garde toutes pour que la table à plusieurs
/// appareils reste possible entre deux langues.
enum Langue: String, Codable, CaseIterable {
    case fr, en

    /// Celle de l'appareil, à défaut d'un choix. Tout ce qui n'est pas
    /// français est servi en anglais : c'est la seule autre banque, et un
    /// joueur allemand préfère des questions qu'il peut lire.
    static var deLAppareil: Langue {
        // Ce qu'iOS a **réellement** choisi pour l'interface, et non ce que
        // l'appareil préfère dans l'absolu. Les deux diffèrent dès que la
        // langue du téléphone n'est ni le français ni l'anglais : un appareil
        // allemand voyait son interface tomber sur la langue de repli du
        // paquet et ses questions sur l'anglais. Un joueur ne doit jamais lire
        // un bouton dans une langue et sa question dans une autre.
        (Bundle.main.preferredLocalizations.first ?? "fr").hasPrefix("fr") ? .fr : .en
    }
}

/// Une phrase de l'interface, dans la langue choisie **dans l'application**.
///
/// `String(localized:)` seul interroge la langue du système. Tant que le choix
/// se faisait dans les Réglages d'iOS, cela suffisait ; du jour où l'app offre
/// le sien, une phrase assemblée hors d'une vue resterait dans la langue du
/// téléphone pendant que les boutons changeraient. D'où ce détour.
func dit(_ cle: String.LocalizationValue) -> String {
    // Par le paquet, et non par `locale:` — qui ne choisit que le format des
    // nombres et des dates, jamais la table de traduction. L'erreur ne se voit
    // pas à la compilation : la phrase sort simplement dans la langue du
    // système, au milieu d'une interface qui a changé.
    guard let chemin = Bundle.main.path(forResource: Themes.langue.rawValue,
                                        ofType: "lproj"),
          let paquet = Bundle(path: chemin) else { return String(localized: cle) }
    return String(localized: cle, bundle: paquet)
}

// MARK: - Ce qu'un thème déclare

/// La carte d'identité d'un thème, lue en tête de son fichier de questions.
struct Theme: Hashable, Identifiable, Codable {

    /// Une couleur, hors de toute bibliothèque d'affichage.
    struct Teinte: Hashable, Codable {
        let r: Double, v: Double, b: Double
    }

    let id: String
    let nom: String
    /// La forme élidée : « d'Histoire », « de Géographie ».
    let de: String
    /// La langue de ses questions.
    let langue: Langue
    let icone: String
    let teinte: Teinte
    /// Une phrase, pour la page des packs. Vide pour les thèmes du jeu : on
    /// n'explique pas « Histoire », on explique « Histoire — 3e ».
    let detail: String
    /// L'article de l'App Store qui l'ouvre.
    ///
    /// Absent, le thème est dans le jeu et appartient à tout le monde. Présent,
    /// il faut l'avoir acheté pour le **choisir** — mais son fichier est sur
    /// tous les appareils, ce qui permet à celui qui rejoint une table de jouer
    /// le pack de l'hôte sans l'avoir acheté.
    let produit: String?
    /// Sa place dans la grille des thèmes. Deux thèmes de même rang se
    /// départagent par leur identifiant : l'ordre affiché ne doit jamais
    /// dépendre de l'ordre dans lequel le système a rendu les fichiers.
    let rang: Int

    var category: Category { Category(id) }
}

// MARK: - Le catalogue

/// Les thèmes que cet appareil connaît.
///
/// Construit une fois, à la première demande, en lisant les fichiers du
/// paquet. Il ne change pas ensuite : un thème qui apparaîtrait au milieu
/// d'une partie changerait le tirage sous les pieds des joueurs.
///
/// Tous les thèmes livrés sont présents sur tous les appareils d'une même
/// version — c'est ce qui permet à deux appareils de tirer la même question
/// sans jamais s'envoyer une banque. Le jour où un thème se vendra, ce sera
/// le **choix** du thème qui sera réservé à l'acheteur, pas sa présence :
/// celui qui rejoint pourra jouer le thème de l'hôte sans l'avoir acheté.
enum Themes {

    private static let catalogue: [String: Theme] = {
        Dictionary(uniqueKeysWithValues: QuestionBank.tousLesThemes.map { ($0.theme.id, $0.theme) })
    }()

    /// Tous les thèmes livrés, les deux langues mêlées, dans l'ordre
    /// d'affichage. Sert aux tests et aux outils, qui doivent voir la banque
    /// entière ; le jeu, lui, passe par `tous`.
    static let toutesLangues: [Category] = catalogue.values
        .sorted { $0.rang != $1.rang ? $0.rang < $1.rang : $0.id < $1.id }
        .map(\.category)

    private static let parLangue: [Langue: [Category]] =
        Dictionary(grouping: toutesLangues) { connu($0)?.langue ?? .fr }

    /// La langue des questions. Elle suit l'appareil, et se change dans les
    /// réglages — hors partie : un catalogue qui bougerait en cours de jeu
    /// changerait le tirage sous les pieds des joueurs.
    static var langue: Langue {
        get { UserDefaults.standard.string(forKey: cleDeLangue)
                .flatMap(Langue.init(rawValue:)) ?? .deLAppareil }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: cleDeLangue) }
    }

    private static let cleDeLangue = "langue-des-questions"

    /// Les thèmes dans l'ordre où ils s'affichent, dans la langue en cours.
    static var tous: [Category] { parLangue[langue] ?? [] }

    /// Le thème nommé, **quelle que soit sa langue**. Un appareil qui rejoint
    /// une table doit savoir lire le thème de l'hôte, fût-il d'une autre
    /// banque que la sienne.
    static func connu(_ c: Category) -> Theme? { catalogue[c.id] }

    /// Les thèmes du jeu — ceux qui n'ont pas de prix.
    static var base: [Category] { tous.filter { connu($0)?.produit == nil } }

    /// Les packs, ceux qui s'achètent.
    static var packs: [Category] { tous.filter { connu($0)?.produit != nil } }

    /// Le thème nommé, s'il existe. Sert aux tests et aux outils.
    static func parNom(_ id: String) -> Category? { catalogue[id].map(\.category) }
}
