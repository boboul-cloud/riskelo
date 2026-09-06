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

    /// La question telle qu'elle est posée, la bonne réponse à la ligne
    /// demandée. Les leurres, eux, sont toujours mêlés entre eux : c'est la
    /// place de la bonne réponse, et elle seule, que la banque tient à l'œil.
    func asked<G: RandomNumberGenerator>(placingCorrectAt ligne: Int,
                                         using rng: inout G) -> AskedQuestion {
        var choices = decoys
        choices.shuffle(using: &rng)
        let place = min(max(0, ligne), choices.count)
        choices.insert(correct, at: place)
        return AskedQuestion(question: self, choices: choices, answer: place)
    }

    /// Sans consigne de place : elle est tirée au sort. C'est la porte des
    /// essais — la banque, elle, passe toujours par le sac des places.
    func asked<G: RandomNumberGenerator>(using rng: inout G) -> AskedQuestion {
        let ligne = Int.random(in: 0 ... decoys.count, using: &rng)
        return asked(placingCorrectAt: ligne, using: &rng)
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

/// Le stock de questions, et deux mémoires de ce qui a déjà été posé.
///
/// Celle de la partie : une question ne revient pas tant qu'il en reste
/// d'autres dans le thème. Et celle de l'appareil, qui passe d'une partie à
/// la suivante : à niveau égal, la banque sert d'abord ce qui n'est jamais
/// sorti.
struct QuestionBank {

    /// Combien de propositions porte une question : quatre lignes.
    static let lignes = 4

    private(set) var questions: [Question]
    private var served: Set<String> = []

    /// Ce que le joueur a déjà vu, d'une partie sur l'autre : combien de fois
    /// chaque question est sortie.
    ///
    /// `served` ne vaut que pour la partie en cours ; la suivante repart d'un
    /// sac plein, et les mêmes questions ressortent. Sur un millier de
    /// questions cela ne devrait pas se voir — mais une partie en pose une
    /// centaine, tirées au sort dans le sac entier, et deux parties de suite
    /// en partagent donc une bonne dizaine. Celui qui joue seul enchaîne les
    /// parties, et ne voit que ces retours-là.
    ///
    /// Le tirage prend d'abord parmi les moins vues — donc parmi celles
    /// jamais sorties tant qu'il en reste. Ce n'est pas un poids mais une
    /// priorité : la banque est un paquet de mille cartes qu'on distribue
    /// sans remise et qu'on ne rebat qu'une fois vide. Un poids aurait laissé
    /// revenir une question de la veille pendant que cent n'ont jamais servi,
    /// et c'est exactement ce qu'on reproche au jeu.
    ///
    /// Le compte voyage avec la partie — donc jusqu'au second appareil, qui
    /// doit tirer les mêmes questions que le premier. Il est arrêté à
    /// l'ouverture : ce que la partie pose ensuite est dans `served`, et
    /// s'ajoute au compte au moment de l'enregistrer.
    private var vues: [String: Int] = [:]

    /// Le sac des places — sur quelle ligne tombe la bonne réponse.
    ///
    /// Le tirage était honnête, et c'était le défaut. Une pièce honnête donne
    /// trois fois face d'affilée une fois sur huit ; sur les soixante
    /// questions d'une partie, voir trois fois de suite la bonne réponse à la
    /// même ligne arrive dans quatre-vingt-quinze parties sur cent. Le joueur
    /// n'y voit pas du hasard — il y voit une habitude de la machine, et il
    /// se met à jouer contre elle plutôt que contre la question. Une seule
    /// suite suffit à installer le soupçon, et rien ensuite ne l'enlève.
    ///
    /// Les quatre places se tirent donc comme quatre cartes d'un paquet :
    /// sans remise, et l'on rebat quand il est vide. Chaque groupe de quatre
    /// questions porte la bonne réponse une fois sur chaque ligne, dans un
    /// ordre imprévisible ; deux d'affilée au même endroit est le plus qu'on
    /// puisse voir, et jamais trois.
    private var places: [Int] = []

    init(questions: [Question] = QuestionBank.francaises, vues: [String: Int] = [:]) {
        self.questions = questions
        restore(vues: vues)
    }

    var count: Int { questions.count }

    /// Ce qui a déjà été posé, pour l'enregistrement de la partie. Les
    /// questions, elles, sont dans le code : il n'y a que cela à garder.
    var alreadyServed: Set<String> { served }

    mutating func restore(served: Set<String>) {
        self.served = served.filter { id in questions.contains { $0.id == id } }
    }

    /// Ce que la mémoire longue sait en ouvrant la partie.
    var dejaVues: [String: Int] { vues }

    /// Le compte tel qu'il est **maintenant** : ce qui était su en ouvrant,
    /// plus ce que la partie a posé depuis. C'est lui qu'on garde sur
    /// l'appareil.
    ///
    /// Il se recalcule à chaque fois au lieu de s'incrémenter : on peut donc
    /// l'enregistrer à chaque sauvegarde — il y en a une par coup — sans
    /// jamais compter deux fois la même question.
    var vuesAJour: [String: Int] { vuesAJour(depuis: vues, sauf: []) }

    /// Le même compte, posé sur une autre base que la sienne, et sans
    /// recompter ce qui l'était déjà.
    ///
    /// La base, parce que celui qui rejoint une partie en réseau reçoit la
    /// banque de l'hôte, et donc sa mémoire : il joue avec — c'est ce qui
    /// fait que les deux appareils tirent la même question — mais il n'a pas
    /// à hériter des soirées de l'autre. Il n'ajoute à la sienne que ce qui a
    /// été posé ici.
    ///
    /// L'exception, parce qu'une partie reprise retrouve ses questions de la
    /// veille dans `served`, et qu'elles sont déjà comptées : sans cela, une
    /// partie ouverte trois fois compterait trois fois ses premières
    /// questions.
    func vuesAJour(depuis base: [String: Int], sauf comptees: Set<String>) -> [String: Int] {
        var compte = base
        for id in served.subtracting(comptees) { compte[id, default: 0] += 1 }
        return compte
    }

    /// Une mémoire qui parle d'une autre banque ne vaut rien : les questions
    /// qu'elle nomme n'existent plus. On garde ce qui se retrouve.
    mutating func restore(vues: [String: Int]) {
        let connues = Set(questions.map(\.id))
        self.vues = vues.filter { connues.contains($0.key) && $0.value > 0 }
    }

    /// Ce qui reste dans le sac des places : une partie reprise doit le
    /// retrouver tel quel, sans quoi elle rebat au milieu d'un groupe.
    var placesRestantes: [Int] { places }

    mutating func restore(places: [Int]) {
        self.places = places.filter { (0 ..< QuestionBank.lignes).contains($0) }
    }

    /// La prochaine place, tirée du sac ; le sac se rebat quand il est vide.
    private mutating func placeSuivante<G: RandomNumberGenerator>(parmi nombre: Int,
                                                                  using rng: inout G) -> Int {
        if places.isEmpty {
            places = Array(0 ..< QuestionBank.lignes)
            places.shuffle(using: &rng)
        }
        let tiree = places.removeLast()
        // Une question qui n'aurait pas ses quatre propositions ne doit pas
        // pour autant tomber toujours au bout : elle reprend le tirage libre.
        return tiree < nombre ? tiree : Int.random(in: 0 ..< nombre, using: &rng)
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
        // Le niveau d'abord, la fraîcheur ensuite : le dosage des questions
        // est une règle choisie à la mise en place, la mémoire n'est qu'un
        // confort, et un confort ne défait pas une règle.
        let possibles = auNiveau.isEmpty ? libres : auNiveau
        let moindre = possibles.map { vues[$0.id] ?? 0 }.min() ?? 0
        let neuves = possibles.filter { (vues[$0.id] ?? 0) == moindre }
        guard let tiree = neuves.randomElement(using: &rng) else { return nil }

        served.insert(tiree.id)
        // La place d'abord, la question ensuite : deux accès à `rng` dans un
        // même appel ne passeraient pas, et l'ordre doit rester le même sur
        // les deux appareils.
        let ligne = placeSuivante(parmi: tiree.decoys.count + 1, using: &rng)
        return tiree.asked(placingCorrectAt: ligne, using: &rng)
    }
}
