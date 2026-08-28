//
//  Questions.swift
//  Riskelo
//
//  La question de culture générale, qui remplace le dé.
//
//  Une question ne stocke pas ses propositions dans l'ordre : elle garde sa
//  bonne réponse d'un côté, ses leurres de l'autre, et l'ordre est tiré au
//  moment de poser. Deux raisons : on ne peut pas se tromper d'indice en
//  écrivant la banque — l'erreur la plus commune et la plus invisible — et
//  personne ne finit par retenir que la bonne réponse est « souvent la
//  deuxième ».
//

import Foundation

enum Category: String, CaseIterable, Identifiable, Hashable, Codable {
    case geographie, histoire, sciences, arts, sports, spectacle
    var id: String { rawValue }

    var label: String {
        switch self {
        case .geographie: "Géographie"
        case .histoire:   "Histoire"
        case .sciences:   "Sciences & Nature"
        case .arts:       "Arts & Lettres"
        case .sports:     "Sports & Loisirs"
        case .spectacle:  "Écrans & Musique"
        }
    }

    /// Le nom précédé de « de », élidé quand il le faut : « de Géographie »
    /// mais « d'Histoire ». Le français élide devant une voyelle, et devant
    /// l'h muet d'« histoire ».
    var apresDe: String {
        switch self {
        case .histoire, .arts, .spectacle: "d'\(label)"
        default: "de \(label)"
        }
    }

    /// Le nom du camembert, pour l'œil : la vue y accroche sa couleur.
    var symbol: String {
        switch self {
        case .geographie: "globe.europe.africa"
        case .histoire:   "building.columns"
        case .sciences:   "leaf"
        case .arts:       "book"
        case .sports:     "figure.run"
        case .spectacle:  "music.note.tv"
        }
    }
}

enum Difficulty: Int, CaseIterable, Comparable, Hashable, Codable {
    case facile = 1, moyen = 2, difficile = 3
    static func < (a: Difficulty, b: Difficulty) -> Bool { a.rawValue < b.rawValue }
    var label: String {
        switch self {
        case .facile: "Facile"
        case .moyen: "Moyen"
        case .difficile: "Difficile"
        }
    }
}

struct Question: Identifiable, Hashable, Codable {
    let id: String
    let category: Category
    let difficulty: Difficulty
    let prompt: String
    let correct: String
    let decoys: [String]

    /// La question telle qu'elle est posée : propositions mêlées.
    func asked<G: RandomNumberGenerator>(using rng: inout G) -> AskedQuestion {
        var choices = decoys + [correct]
        choices.shuffle(using: &rng)
        return AskedQuestion(question: self,
                             choices: choices,
                             answer: choices.firstIndex(of: correct) ?? 0)
    }
}

struct AskedQuestion: Identifiable, Hashable, Codable {
    let question: Question
    let choices: [String]
    let answer: Int
    var id: String { question.id }
    var prompt: String { question.prompt }
    var category: Category { question.category }
    var difficulty: Difficulty { question.difficulty }
    func isCorrect(_ index: Int) -> Bool { index == answer }
}

/// Le stock de questions, et la mémoire de ce qui a déjà été posé : dans une
/// même partie, une question ne revient pas tant qu'il en reste d'autres.
struct QuestionBank {
    private(set) var questions: [Question]
    private var served: Set<String> = []

    init(questions: [Question] = QuestionBank.francaises) {
        self.questions = questions
    }

    var count: Int { questions.count }

    /// Ce qui a déjà été posé, pour l'enregistrement de la partie. Les
    /// questions, elles, sont dans le code : il n'y a que cela à garder.
    var alreadyServed: Set<String> { served }

    mutating func restore(served: Set<String>) {
        self.served = served.filter { id in questions.contains { $0.id == id } }
    }

    func count(in category: Category) -> Int {
        questions.filter { $0.category == category }.count
    }

    /// Tire une question dans la catégorie demandée — et n'en sort jamais.
    ///
    /// La première version élargissait quand la catégorie était épuisée : on
    /// demandait de l'Histoire et, passé la dixième question, on recevait
    /// « Qui a peint La Joconde ? ». C'était rompre en silence la seule
    /// promesse faite à l'attaquant, celle de choisir le terrain. Désormais
    /// une catégorie épuisée oublie ce qu'elle a servi et recommence : une
    /// question déjà vue est honnête — on a insisté sur ce sujet — là où une
    /// question hors sujet est un mensonge.
    ///
    /// La difficulté, elle, reste indicative : c'est un vœu, pas un contrat.
    mutating func draw<G: RandomNumberGenerator>(category: Category?,
                                                 difficulty: Difficulty?,
                                                 using rng: inout G) -> AskedQuestion? {
        let terrain = questions.filter { category == nil || $0.category == category }
        guard !terrain.isEmpty else { return nil }

        if terrain.allSatisfy({ served.contains($0.id) }) {
            for q in terrain { served.remove(q.id) }
        }
        let libres = terrain.filter { !served.contains($0.id) }
        let auNiveau = libres.filter { difficulty == nil || $0.difficulty == difficulty }
        guard let tiree = (auNiveau.isEmpty ? libres : auNiveau).randomElement(using: &rng)
        else { return nil }

        served.insert(tiree.id)
        return tiree.asked(using: &rng)
    }
}
