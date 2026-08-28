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
    private enum CodingKeys: String, CodingKey { case served }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        restore(served: try c.decode(Set<String>.self, forKey: .served))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(alreadyServed, forKey: .served)
    }
}

// MARK: - La partie

extension GameState: Codable {

    private enum CodingKeys: String, CodingKey {
        case board, signature, rules, players, owner, armies, current, phase, assault
        case siege, knowledge, lastCategoryAgainst, bonusPaid, turn, journal, bank, rng
        case deck, discard, hands, exchanges, conqueredThisTurn
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
