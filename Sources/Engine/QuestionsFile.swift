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
//  Le fichier commence par se présenter. Les lignes qui ouvrent par « ! »
//  déclarent le thème — son nom, son élision, son icône, sa couleur, sa place
//  dans la grille. Elles sont des déclarations et non des commentaires, et le
//  signe les en distingue : un commentaire se perd sans conséquence, une
//  déclaration manquante doit se voir.
//
//      ! id     | histoire
//      ! nom    | Histoire
//
//  Les thèmes ne sont plus énumérés nulle part : on lit le dossier. Déposer
//  un fichier ajoute un thème, et c'est tout ce qu'il faut faire.
//

import Foundation

/// Sert à retrouver le paquet de l'application, y compris depuis les tests.
private final class BundleMarker {}

extension QuestionBank {

    /// Un thème et ses questions, tels qu'un fichier les porte.
    struct Fichier {
        let theme: Theme
        let questions: [Question]
    }

    /// Tout ce que l'appareil sait poser, thème par thème.
    ///
    /// Lu une fois. Le dossier est parcouru plutôt qu'énuméré : c'est ce qui
    /// permet d'ajouter un thème sans toucher au code.
    static let tousLesThemes: [Fichier] = charger()

    static let francaises: [Question] = tousLesThemes.flatMap(\.questions)

    /// Les questions d'un thème, telles que son fichier les porte.
    static func questions(in category: Category) -> [Question] {
        tousLesThemes.first { $0.theme.category == category }?.questions ?? []
    }

    // MARK: - Trouver les fichiers

    /// Les fichiers de questions, où qu'ils soient.
    ///
    /// Deux chemins, et il en faut deux. Le paquet de l'application d'abord —
    /// c'est celui de l'application et des tests. Puis le dossier des sources,
    /// pour les outils en ligne de commande : la simulation n'a pas de paquet,
    /// et le passage aux ressources l'avait laissée sans une seule question,
    /// sans rien dire.
    private static func fichiers() -> [URL] {
        let paquet = Bundle(for: BundleMarker.self)
        // Un outil en ligne de commande n'a pas de paquet. « Bundle(for:) »
        // rend alors le dossier du binaire — « /tmp » pour la simulation — et
        // l'on y ramassait n'importe quel « .txt » qui s'y trouvait, en croyant
        // avoir trouvé la banque. Le paquet ne compte que s'il en est un.
        let estUnPaquet = ["app", "xctest", "bundle", "framework"]
            .contains(paquet.bundleURL.pathExtension)
        if estUnPaquet {
            for sous in ["Questions", nil] {
                let trouves = paquet.urls(forResourcesWithExtension: "txt",
                                          subdirectory: sous) ?? []
                if !trouves.isEmpty { return trouves }
            }
        }
        // Le dossier des sources, pour les outils : la simulation n'a pas de
        // paquet, et le passage aux ressources l'avait laissée sans une seule
        // question, sans rien dire.
        let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/Questions")
        let contenu = (try? FileManager.default.contentsOfDirectory(at: source,
                                                                    includingPropertiesForKeys: nil))
        return (contenu ?? []).filter { $0.pathExtension == "txt" }
    }

    private static func charger() -> [Fichier] {
        var lus: [Fichier] = []
        for url in fichiers() {
            guard let texte = try? String(contentsOf: url, encoding: .utf8) else { continue }
            guard let fichier = lire(texte, nomDeFichier: url.deletingPathExtension().lastPathComponent)
            else { continue }
            guard !lus.contains(where: { $0.theme.id == fichier.theme.id }) else {
                assertionFailure("deux fichiers déclarent le thème « \(fichier.theme.id) »")
                continue
            }
            lus.append(fichier)
        }
        // Une banque vide rend le jeu injouable en silence : mieux vaut le
        // dire, y compris hors du débogage.
        if lus.isEmpty {
            FileHandle.standardError.write(Data("Riskelo — aucun thème trouvé\n".utf8))
        }
        return lus.sorted { $0.theme.id < $1.theme.id }
    }

    // MARK: - Lire un fichier

    /// L'analyse, isolée pour que les tests puissent la nourrir à la main.
    static func lire(_ texte: String, nomDeFichier: String) -> Fichier? {
        var entetes: [String: String] = [:]
        var lignes: [(rang: Int, champs: [String])] = []

        for (rang, brute) in texte.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let ligne = brute.trimmingCharacters(in: .whitespaces)
            guard !ligne.isEmpty, !ligne.hasPrefix("#") else { continue }

            if ligne.hasPrefix("!") {
                let champs = ligne.dropFirst().split(separator: "|", maxSplits: 1)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                guard champs.count == 2 else {
                    assertionFailure("\(nomDeFichier).txt ligne \(rang + 1) : "
                                     + "une déclaration s'écrit « ! clé | valeur »")
                    continue
                }
                entetes[champs[0]] = champs[1]
                continue
            }

            let champs = ligne.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard champs.count == 6 else {
                assertionFailure("\(nomDeFichier).txt ligne \(rang + 1) : "
                                 + "six champs attendus, \(champs.count) trouvés")
                continue
            }
            lignes.append((rang, champs))
        }

        guard let theme = theme(entetes, nomDeFichier: nomDeFichier) else { return nil }

        var questions: [Question] = []
        for (rang, champs) in lignes {
            guard let niveau = Difficulty(lettre: champs[0]) else {
                assertionFailure("\(nomDeFichier).txt ligne \(rang + 1) : "
                                 + "niveau « \(champs[0]) » inconnu")
                continue
            }
            questions.append(Question(id: identifiant(theme: theme.id, enonce: champs[1]),
                                      category: theme.category, difficulty: niveau,
                                      prompt: champs[1], correct: champs[2],
                                      decoys: Array(champs[3...])))
        }
        return Fichier(theme: theme, questions: questions)
    }

    /// La carte d'identité déclarée en tête. Le nom du fichier sert de dernier
    /// recours à l'identifiant, et à lui seul : un thème sans nom lisible est
    /// une faute qu'il faut voir, pas une faute qu'il faut deviner.
    private static func theme(_ e: [String: String], nomDeFichier: String) -> Theme? {
        let id = e["id"] ?? nomDeFichier
        guard let nom = e["nom"] else {
            assertionFailure("\(nomDeFichier).txt : « ! nom | … » manquant")
            return nil
        }
        return Theme(id: id,
                     nom: nom,
                     de: e["de"] ?? "de \(nom)",
                     icone: e["icone"] ?? "questionmark.circle",
                     teinte: teinte(e["teinte"]),
                     detail: e["detail"] ?? "",
                     // Un article vide vaut pas d'article : une déclaration
                     // laissée en blanc ne doit pas rendre un thème invendable
                     // et inutilisable à la fois.
                     produit: e["produit"].flatMap { $0.isEmpty ? nil : $0 },
                     rang: e["rang"].flatMap(Int.init) ?? 99)
    }

    /// « 0.85 0.66 0.22 » — trois nombres de 0 à 1. Un gris moyen à défaut :
    /// visible, et assez laid pour qu'on remarque l'oubli.
    private static func teinte(_ brut: String?) -> Theme.Teinte {
        let n = (brut ?? "").split(separator: " ").compactMap { Double($0) }
        guard n.count == 3 else { return Theme.Teinte(r: 0.5, v: 0.5, b: 0.5) }
        return Theme.Teinte(r: min(1, max(0, n[0])),
                            v: min(1, max(0, n[1])),
                            b: min(1, max(0, n[2])))
    }

    // MARK: - L'identifiant d'une question

    /// L'identifiant se calcule sur l'énoncé, et non sur la place dans le
    /// fichier.
    ///
    /// Il était le rang — « histoire-12 ». Insérer une question en tête
    /// décalait donc les mille suivantes, et la mémoire de ce qui a déjà été
    /// posé se mettait à parler d'autres questions que celles qu'elle nommait.
    /// Personne ne s'en apercevait : rien ne plante, les questions reviennent
    /// simplement plus tôt qu'elles ne devraient.
    ///
    /// Sur l'énoncé, l'identifiant survit à toutes les corrections qui ne
    /// touchent pas l'énoncé — un leurre remplacé, un niveau revu, une
    /// question ajoutée au milieu. Ce que le tri en tire est un ordre stable
    /// et le même sur les deux appareils, quel que soit l'ordre dans lequel le
    /// système a rendu les fichiers.
    static func identifiant(theme: String, enonce: String) -> String {
        "\(theme):\(String(empreinte(enonce), radix: 16))"
    }

    /// Un nombre tiré d'un texte, le même partout et à chaque lancement.
    ///
    /// Le hachage de Swift ne convient pas : il est salé à chaque démarrage,
    /// donc différent d'une ouverture à l'autre et d'un appareil à l'autre.
    /// Celui-ci ne l'est pas — c'est tout ce qu'on lui demande.
    static func empreinte(_ texte: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for octet in texte.utf8 {
            h ^= UInt64(octet)
            h &*= 0x0000_0100_0000_01B3
        }
        return h
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
