//
//  QuestionsFile.swift
//  Riskelo
//
//  La banque, lue d'un fichier par thème.
//
//  Elle était écrite en dur, et c'était juste tant qu'elle tenait en quelques
//  dizaines : le compilateur en était le meilleur relecteur. Passé le millier,
//  le calcul s'inverse — un littéral de mille éléments écroule le temps de
//  compilation, une coquille exige une reconstruction, et le fichier n'est
//  plus relisible.
//
//  Le format n'est pas du JSON : mille questions y feraient quatorze mille
//  lignes. Une ligne par question, six champs séparés par des barres. Un
//  fichier de mille questions fait mille lignes, se relit, se corrige, et se
//  trie.
//
//      M | Quel fleuve traverse Le Caire ? | Le Nil | L'Euphrate | Le Jourdain | Le Niger
//
//  Ce que le compilateur ne vérifie plus, les tests le vérifient — et mieux :
//  il n'a jamais su dire qu'un leurre était égal à la bonne réponse.
//

import Foundation

/// Sert à retrouver le paquet de l'application, y compris depuis les tests.
private final class BundleMarker {}

extension QuestionBank {

    static let francaises: [Question] = Category.allCases.flatMap { charger($0) }

    /// Lit un thème.
    ///
    /// Deux chemins, et il en faut deux. Le paquet de l'application d'abord —
    /// c'est celui de l'application et des tests. Puis le dossier des sources,
    /// pour les outils en ligne de commande : la simulation n'a pas de paquet,
    /// et le passage aux ressources l'avait laissée sans une seule question,
    /// sans rien dire.
    static func charger(_ categorie: Category) -> [Question] {
        let paquet = Bundle(for: BundleMarker.self)
        let pistes: [URL?] = [
            paquet.url(forResource: categorie.rawValue, withExtension: "txt",
                       subdirectory: "Questions"),
            paquet.url(forResource: categorie.rawValue, withExtension: "txt"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/Questions/\(categorie.rawValue).txt"),
        ]
        for url in pistes.compactMap({ $0 }) {
            guard let texte = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let lues = lire(texte, categorie: categorie)
            if !lues.isEmpty { return lues }
        }
        // Une banque vide rend le jeu injouable en silence : mieux vaut le dire,
        // y compris hors du débogage.
        FileHandle.standardError.write(
            Data("Riskelo — questions introuvables pour \(categorie.rawValue)\n".utf8))
        return []
    }

    /// L'analyse, isolée pour que les tests puissent la nourrir à la main.
    static func lire(_ texte: String, categorie: Category) -> [Question] {
        var sorties: [Question] = []
        for (rang, brute) in texte.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let ligne = brute.trimmingCharacters(in: .whitespaces)
            guard !ligne.isEmpty, !ligne.hasPrefix("#") else { continue }

            let champs = ligne.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard champs.count == 6, let niveau = Difficulty(lettre: champs[0]) else {
                assertionFailure("\(categorie.rawValue).txt ligne \(rang + 1) : "
                                 + "six champs attendus, \(champs.count) trouvés")
                continue
            }
            sorties.append(Question(id: "\(categorie.rawValue)-\(sorties.count)",
                                    category: categorie, difficulty: niveau,
                                    prompt: champs[1], correct: champs[2],
                                    decoys: Array(champs[3...])))
        }
        return sorties
    }
}

extension Difficulty {
    init?(lettre: String) {
        switch lettre.uppercased() {
        case "F": self = .facile
        case "M": self = .moyen
        case "D": self = .difficile
        default: return nil
        }
    }
}
