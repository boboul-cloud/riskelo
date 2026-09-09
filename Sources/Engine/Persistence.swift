//
//  Persistence.swift
//  Riskelo
//
//  Garder la partie en cours d'une fois sur l'autre.
//
//  Tout l'état du jeu est déjà une valeur — c'était le pari du moteur — et il
//  suffit donc de savoir l'écrire. Trois choix de fabrication :
//
//  Le plateau n'est pas enregistré : il se regénère du plan, à l'identique.
//  On garde sa signature — la liste de ses territoires — et l'on écarte la
//  sauvegarde si elle ne correspond plus. Un plan retouché ne doit pas
//  restaurer une partie de travers, il doit la refuser.
//
//  La banque de questions non plus : seule la liste de celles déjà posées est
//  gardée, les questions elles-mêmes sont dans le code.
//
//  Le tirage au sort, en revanche, est enregistré. Sans lui, une partie
//  reprise ne serait plus la même : ce serait une autre partie qui commence
//  au même endroit.
//

import Foundation

// MARK: - De quoi écrire les valeurs du moteur

extension SeededRandom: Codable {
    private enum CodingKeys: String, CodingKey { case state }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(seed: try c.decode(UInt64.self, forKey: .state))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(rawState, forKey: .state)
    }
}

extension QuestionBank: Codable {
    private enum CodingKeys: String, CodingKey { case served, places, vues }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        restore(served: try c.decode(Set<String>.self, forKey: .served))
        // Le sac des places voyage avec elle : une sauvegarde d'avant le sac
        // n'en a pas, et repart d'un sac plein — ce qui est sans conséquence.
        restore(places: try c.decodeIfPresent([Int].self, forKey: .places) ?? [])
        // La mémoire longue voyage aussi, et c'est indispensable au second
        // appareil : celui qui rejoint reçoit la partie entière et doit tirer
        // exactement les mêmes questions que celui qui l'héberge. S'il
        // repartait de sa propre mémoire, les deux écrans poseraient deux
        // questions différentes à la même seconde.
        restore(vues: try c.decodeIfPresent([String: Int].self, forKey: .vues) ?? [:])
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(alreadyServed, forKey: .served)
        try c.encode(placesRestantes, forKey: .places)
        try c.encode(dejaVues, forKey: .vues)
    }
}

// MARK: - La partie

extension GameState: Codable {

    private enum CodingKeys: String, CodingKey {
        case board, signature, rules, players, owner, armies, current, phase, assault
        case siege, knowledge, lastCategoryAgainst, bonusPaid, turn, journal, bank, rng
        case deck, discard, hands, exchanges, conqueredThisTurn, objectifs, elimines
    }

    /// Ce qui identifie le plateau : la liste de ses territoires, dans
    /// l'ordre. Deux plans différents ne peuvent pas la partager.
    static func signature(of board: Board) -> String {
        board.map.order.joined(separator: ",")
    }

    enum LoadError: Error, LocalizedError {
        case autrePlateau
        var errorDescription: String? {
            "Cette partie a été jouée sur un autre plateau."
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Le plateau lui-même n'est pas enregistré : on note lequel c'était,
        // et l'on vérifie qu'il n'a pas changé de dessin depuis.
        let board = try c.decodeIfPresent(Boards.self, forKey: .board) ?? .anneau
        guard try c.decode(String.self, forKey: .signature) == GameState.signature(of: board.board)
        else { throw LoadError.autrePlateau }
        self.init(restoring: board,
                  rules: try c.decode(Rules.self, forKey: .rules),
                  players: try c.decode([Player].self, forKey: .players),
                  bank: try c.decode(QuestionBank.self, forKey: .bank),
                  rng: try c.decode(SeededRandom.self, forKey: .rng),
                  owner: try c.decode([TerritoryID: PlayerID].self, forKey: .owner),
                  armies: try c.decode([TerritoryID: Int].self, forKey: .armies),
                  current: try c.decode(Int.self, forKey: .current),
                  phase: try c.decode(Phase.self, forKey: .phase),
                  assault: try c.decodeIfPresent(Assault.self, forKey: .assault),
                  siege: try c.decode([TerritoryID: Int].self, forKey: .siege),
                  knowledge: try c.decode([PlayerID: [Category: Score]].self, forKey: .knowledge),
                  lastCategoryAgainst: try c.decode([PlayerID: Category].self,
                                                    forKey: .lastCategoryAgainst),
                  bonusPaid: try c.decodeIfPresent([PlayerID: Int].self, forKey: .bonusPaid) ?? [:],
                  deck: try c.decodeIfPresent([Card].self, forKey: .deck) ?? [],
                  discard: try c.decodeIfPresent([Card].self, forKey: .discard) ?? [],
                  hands: try c.decodeIfPresent([PlayerID: [Card]].self, forKey: .hands) ?? [:],
                  exchanges: try c.decodeIfPresent(Int.self, forKey: .exchanges) ?? 0,
                  conqueredThisTurn: try c.decodeIfPresent(Bool.self,
                                                           forKey: .conqueredThisTurn) ?? false,
                  // Une sauvegarde d'avant les conquêtes personnelles n'en a
                  // pas : la partie reprend sans, ce qui est exactement ce
                  // qu'elle était.
                  objectifs: try c.decodeIfPresent([PlayerID: Objectif].self,
                                                   forKey: .objectifs) ?? [:],
                  elimines: try c.decodeIfPresent([PlayerID: PlayerID].self,
                                                  forKey: .elimines) ?? [:],
                  turn: try c.decode(Int.self, forKey: .turn),
                  journal: try c.decode([Entry].self, forKey: .journal))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(boardKind, forKey: .board)
        try c.encode(GameState.signature(of: board), forKey: .signature)
        try c.encode(rules, forKey: .rules)
        try c.encode(players, forKey: .players)
        try c.encode(owner, forKey: .owner)
        try c.encode(armies, forKey: .armies)
        try c.encode(current, forKey: .current)
        try c.encode(phase, forKey: .phase)
        try c.encodeIfPresent(assault, forKey: .assault)
        try c.encode(siege, forKey: .siege)
        try c.encode(knowledge, forKey: .knowledge)
        try c.encode(lastCategoryAgainst, forKey: .lastCategoryAgainst)
        try c.encode(bonusPaid, forKey: .bonusPaid)
        try c.encode(deck, forKey: .deck)
        try c.encode(discard, forKey: .discard)
        try c.encode(hands, forKey: .hands)
        try c.encode(exchanges, forKey: .exchanges)
        try c.encode(conqueredThisTurn, forKey: .conqueredThisTurn)
        try c.encode(objectifs, forKey: .objectifs)
        try c.encode(elimines, forKey: .elimines)
        try c.encode(turn, forKey: .turn)
        try c.encode(journal, forKey: .journal)
        try c.encode(bank, forKey: .bank)
        try c.encode(rng, forKey: .rng)
    }
}

// MARK: - Le tiroir

/// Où dort la partie en cours.
///
/// Un fichier, et non les réglages du système : une partie est un document.
/// L'écriture est atomique — une coupure de courant en plein enregistrement
/// laisserait sinon un fichier à moitié écrit, c'est-à-dire une partie perdue
/// en croyant la sauver.
struct GameStore {

    static let shared = GameStore()

    private let url: URL = {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dossier = base.appendingPathComponent("Riskelo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        return dossier.appendingPathComponent("partie-en-cours.json")
    }()

    /// L'identité de la partie en cours dans la bibliothèque. Elle vit à
    /// côté de l'état, et non dedans : la changer n'invalide pas les
    /// sauvegardes déjà écrites.
    private var idURL: URL {
        url.deletingLastPathComponent().appendingPathComponent("partie-en-cours-id.txt")
    }

    var hasSavedGame: Bool { FileManager.default.fileExists(atPath: url.path) }

    func saveID(_ id: UUID) {
        try? id.uuidString.write(to: idURL, atomically: true, encoding: .utf8)
    }

    func loadID() -> UUID? {
        (try? String(contentsOf: idURL, encoding: .utf8)).flatMap(UUID.init)
    }

    func save(_ game: GameState) {
        do {
            let data = try JSONEncoder().encode(game)
            try data.write(to: url, options: .atomic)
        } catch {
            // Une sauvegarde ratée ne doit pas interrompre une partie : on la
            // retentera au coup suivant, il y en a un toutes les secondes.
            print("Riskelo — sauvegarde impossible : \(error)")
        }
    }

    func load() -> GameState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(GameState.self, from: data)
        } catch {
            // Sauvegarde d'un autre plateau, ou d'une version qui ne se lit
            // plus : on l'écarte plutôt que de reprendre une partie fausse.
            print("Riskelo — sauvegarde écartée : \(error.localizedDescription)")
            discard()
            return nil
        }
    }

    func discard() {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - La mémoire des questions

/// Ce que cet appareil a déjà vu passer, d'une partie sur l'autre.
///
/// Une partie ne le sait pas d'elle-même : elle s'ouvre avec une banque
/// neuve, tire au sort dans le sac plein, et repose donc les questions de la
/// veille. Celui qui joue seul enchaîne les parties, et c'est le seul à qui
/// cela saute aux yeux — il reconnaît la question avant de l'avoir lue, et le
/// duel ne décide plus rien.
///
/// Le compte est gardé ici, à côté de la partie et sous la même forme : un
/// fichier, parce que c'est un registre de mille lignes qui grossit, et non
/// un réglage. Il survit à la partie, aux archives et à la reprise ; il ne
/// survit pas à la désinstallation, et c'est bien ainsi.
struct MemoireDesQuestions {

    static let shared = MemoireDesQuestions()

    private let url: URL = {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dossier = base.appendingPathComponent("Riskelo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        return dossier.appendingPathComponent("questions-deja-posees.json")
    }()

    /// Combien de fois chaque question est déjà sortie.
    func charger() -> [String: Int] {
        guard let data = try? Data(contentsOf: url),
              let compte = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        let traduit = MemoireDesQuestions.traduire(compte)
        // On réécrit une fois, et l'on n'y revient plus : sans cela, la
        // traduction se referait à chaque ouverture de partie.
        if traduit != compte { enregistrer(traduit) }
        return traduit
    }

    /// La mémoire d'avant les identifiants stables, remise à jour.
    ///
    /// Jusqu'à la 1.3, une question était nommée par son **rang** dans son
    /// fichier — « histoire-12 ». Elle l'est désormais par son énoncé. Une
    /// mémoire ancienne nomme donc des questions qui n'existent plus, et le
    /// jeu l'écarterait proprement : celui qui joue depuis des mois reverrait
    /// d'un coup ses premières questions, sans comprendre pourquoi.
    ///
    /// Le rang reste lisible : c'est la place dans le fichier, et les six
    /// thèmes d'origine n'ont pas bougé d'une ligne — on leur a seulement
    /// ajouté un en-tête, qui ne compte pas. La traduction est donc exacte.
    ///
    /// Un rang qui ne retrouve pas sa question est laissé de côté : il vaut
    /// mieux perdre une ligne qu'en inventer une.
    static func traduire(_ ancienne: [String: Int]) -> [String: Int] {
        // Les nouveaux identifiants portent deux points ; les anciens, jamais.
        guard ancienne.keys.contains(where: { !$0.contains(":") }) else { return ancienne }

        var parTheme: [String: [Question]] = [:]
        for fichier in QuestionBank.tousLesThemes {
            parTheme[fichier.theme.id] = fichier.questions
        }
        var neuve: [String: Int] = [:]
        for (cle, compte) in ancienne {
            if cle.contains(":") { neuve[cle] = compte; continue }
            guard let tiret = cle.lastIndex(of: "-"),
                  let rang = Int(cle[cle.index(after: tiret)...]),
                  let questions = parTheme[String(cle[..<tiret])],
                  questions.indices.contains(rang)
            else { continue }
            neuve[questions[rang].id, default: 0] += compte
        }
        return neuve
    }

    /// L'écriture est atomique, comme celle de la partie : une coupure au
    /// milieu laisserait un fichier illisible, donc une mémoire perdue.
    func enregistrer(_ comptes: [String: Int]) {
        guard let data = try? JSONEncoder().encode(comptes) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Tout oublier. Le joueur qui a fait le tour de la banque peut vouloir
    /// la reprendre à neuf plutôt que de la voir se répéter au deuxième tour.
    func oublier() {
        try? FileManager.default.removeItem(at: url)
    }

    /// Combien de questions différentes sont déjà sorties. C'est le seul
    /// chiffre qu'on montre au joueur.
    func combienDeVues() -> Int { charger().count }
}
