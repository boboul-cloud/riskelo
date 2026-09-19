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

// MARK: - Le rendez-vous

/// De quoi retrouver une partie au loin, une soirée plus tard.
///
/// Une partie de Riskelo ne tient pas toujours dans une soirée, et deux
/// personnes ne sont pas libres à la même heure. Ce qu'il faut pour reprendre
/// tient pourtant en peu de chose : **six lettres**, et de quoi savoir qui
/// l'on était à cette table. Le reste — la partie elle-même — dort déjà à côté
/// dans `GameStore`.
///
/// Ce n'est pas la partie par correspondance, et il ne faut pas le laisser
/// croire : un duel se joue sablier en main, les deux appareils allumés en
/// même temps. Ce qui se reprend, c'est le **rendez-vous** — on se retrouve
/// demain soir, et la partie repart où on l'avait laissée.
///
/// Rangé à côté de la partie et non dedans : une partie est une partie, elle
/// ne sait pas par quel fil elle est arrivée, et c'est très bien ainsi.
struct RendezVous: Codable {

    /// Le salon. C'est lui qui fait tout : celui qui héberge le rouvre, les
    /// autres le retapent, et l'on est de nouveau ensemble.
    let code: String
    /// Étions-nous celui qui a ouvert la partie ? Il fait foi — c'est sa
    /// partie qu'on redonne à chacun au retour — et il est le seul à qui le
    /// serveur rende son ancien code.
    let jHeberge: Bool
    /// Quel camp est le nôtre.
    let monRang: PlayerID
    /// Où en était le compte des coups. Il repart de là, des deux côtés.
    let compteur: Int
    /// Le camp de chaque appareil, par son identifiant. Sans lui, celui qui
    /// héberge ne saurait plus à qui renvoyer quel rang — et ne renverrait
    /// donc rien du tout.
    let rangs: [String: PlayerID]
    /// La partie dans la bibliothèque. Gardée pour que trois soirées ne
    /// fassent pas trois parties différentes.
    let partieID: UUID
    /// Quand on s'est quittés.
    let quand: Date

    /// Contre qui l'on joue, tels que les camps s'appellent. Recopié ici, et
    /// non lu dans la partie : l'écran en montre plusieurs à la fois, et
    /// décoder trois parties entières pour afficher trois lignes serait payer
    /// cher un nom de camp.
    let contre: [String]
    /// Où l'on en était. Même raison : « tour 7 » se lit d'un coup d'œil, et
    /// c'est ce qui distingue une partie d'une autre bien mieux qu'un code.
    let tour: Int

    init(code: String, jHeberge: Bool, monRang: PlayerID, compteur: Int,
         rangs: [String: PlayerID], partieID: UUID, quand: Date,
         contre: [String] = [], tour: Int = 1) {
        self.code = code
        self.jHeberge = jHeberge
        self.monRang = monRang
        self.compteur = compteur
        self.rangs = rangs
        self.partieID = partieID
        self.quand = quand
        self.contre = contre
        self.tour = tour
    }

    /// Écrit à la main pour les deux derniers : un rendez-vous posé par la
    /// version d'avant ne les porte pas, et un décodage qui les exigerait
    /// perdrait la partie en cours de celui qui met à jour.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decode(String.self, forKey: .code)
        jHeberge = try c.decode(Bool.self, forKey: .jHeberge)
        monRang = try c.decode(PlayerID.self, forKey: .monRang)
        compteur = try c.decode(Int.self, forKey: .compteur)
        rangs = try c.decode([String: PlayerID].self, forKey: .rangs)
        partieID = try c.decode(UUID.self, forKey: .partieID)
        quand = try c.decode(Date.self, forKey: .quand)
        contre = try c.decodeIfPresent([String].self, forKey: .contre) ?? []
        tour = try c.decodeIfPresent(Int.self, forKey: .tour) ?? 1
    }

    /// Une semaine, la même valeur que le salon garde de son côté — voir
    /// `GRACE_MS` dans `serveur/src/index.js`. Les deux doivent s'accorder :
    /// proposer de reprendre une partie dont le code est mort ne mène qu'à un
    /// écran de refus, et laisser mourir un rendez-vous que le serveur tient
    /// encore serait perdre une partie pour rien.
    static let dureeDeVie: TimeInterval = 7 * 24 * 60 * 60

    var perime: Bool { Date().timeIntervalSince(quand) > RendezVous.dureeDeVie }

    /// Ce qu'on attend : les autres appareils, et rien d'autre. Un curieux
    /// qui aurait tapé le code au hasard ne compte pas dans le rendez-vous.
    var attendus: Set<String> { Set(rangs.keys) }
}

/// Où dorment les parties en cours.
///
/// Un fichier, et non les réglages du système : une partie est un document.
/// L'écriture est atomique — une coupure de courant en plein enregistrement
/// laisserait sinon un fichier à moitié écrit, c'est-à-dire une partie perdue
/// en croyant la sauver.
///
/// **Une partie d'ici, et autant de parties au loin qu'on en a ouvert.** Elles
/// n'attendent pas la même chose. Celle d'ici attend qu'on rouvre
/// l'application, et cela peut être dans dix minutes. Celles du loin attendent
/// chacune leur monde, et ce n'est pas le même monde : celle de Marie n'a rien
/// à voir avec celle de Paul, elles vont à leur rythme et ne se croisent
/// jamais. Elles tenaient toutes dans le même fichier, et chacune chassait les
/// autres — ouvrir une partie avec Paul effaçait celle de Marie, rendez-vous
/// compris, sans rien dire.
///
/// Le code du salon fait la clé : il est unique par partie, il est déjà ce que
/// les joueurs s'échangent, et le serveur le garde une semaine de son côté.
struct GameStore {

    static let shared = GameStore()

    /// Quel tiroir.
    enum Tiroir: Equatable {
        /// Ce qui se joue sur cet appareil : seul contre la machine, ou à
        /// plusieurs autour du même téléphone. Il n'y en a qu'un.
        case ici
        /// Une partie au loin, désignée par le code de son salon.
        case auLoin(code: String)

        /// Le nom du fichier, sous le dossier de l'application.
        var nom: String {
            switch self {
            case .ici: return "partie-en-cours"
            case let .auLoin(code): return "\(GameStore.auLoin)/\(code)"
            }
        }
    }

    /// Le sous-dossier des parties au loin. Un dossier plutôt que des noms à
    /// rallonge : on a besoin d'en faire la liste, et lister un dossier est
    /// plus honnête que de deviner des noms de fichiers.
    fileprivate static let auLoin = "au-loin"

    private let dossier: URL

    /// `dossier` n'est donné que par les essais.
    ///
    /// Sans cette porte, le rangement ne s'éprouvait pas : `GameStore.shared`
    /// écrit dans le vrai dossier de l'application, et un essai qui y toucherait
    /// coûterait à celui qui le lance la partie qu'il avait en cours. On s'en
    /// remettait donc à la lecture — et des tiroirs qui ne doivent pas se
    /// chasser l'un l'autre sont précisément ce qui se lit mal.
    init(dossier: URL? = nil) {
        if let dossier {
            self.dossier = dossier
        } else {
            let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil, create: true))
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.dossier = base.appendingPathComponent("Riskelo", isDirectory: true)
        }
        try? FileManager.default.createDirectory(
            at: self.dossier.appendingPathComponent(GameStore.auLoin, isDirectory: true),
            withIntermediateDirectories: true)
    }

    private func url(_ tiroir: Tiroir) -> URL {
        dossier.appendingPathComponent("\(tiroir.nom).json")
    }

    /// L'identité de la partie dans la bibliothèque. Elle vit à côté de
    /// l'état, et non dedans : la changer n'invalide pas les sauvegardes déjà
    /// écrites. Les parties au loin, elles, la portent dans leur rendez-vous.
    private var idURL: URL {
        dossier.appendingPathComponent("partie-en-cours-id.txt")
    }

    /// Le rendez-vous d'une partie au loin : son code, son camp, où elle en
    /// est. Il vit à côté de l'état, comme l'identité — une partie ne sait pas
    /// par quel fil elle est arrivée.
    private func rendezVousURL(_ code: String) -> URL {
        dossier.appendingPathComponent("\(GameStore.auLoin)/\(code)-rendez-vous.json")
    }

    func has(_ tiroir: Tiroir) -> Bool {
        ranger()
        return FileManager.default.fileExists(atPath: url(tiroir).path)
    }

    // MARK: - Les parties au loin

    func saveRendezVous(_ rendezVous: RendezVous) {
        guard let data = try? JSONEncoder().encode(rendezVous) else { return }
        try? data.write(to: rendezVousURL(rendezVous.code), options: .atomic)
    }

    /// Le rendez-vous d'un code, s'il tient encore.
    ///
    /// Passé le délai, il s'oublie — et sa partie avec lui. C'est un ménage et
    /// non une perte : une partie au loin sans son code ne se joue pas, et la
    /// rendre telle quelle ouvrirait les deux camps sur un seul téléphone.
    /// La bibliothèque, elle, la garde.
    func rendezVous(_ code: String) -> RendezVous? {
        ranger()
        guard let data = try? Data(contentsOf: rendezVousURL(code)),
              let rendezVous = try? JSONDecoder().decode(RendezVous.self, from: data)
        else { return nil }
        guard !rendezVous.perime else {
            discard(.auLoin(code: code))
            return nil
        }
        return rendezVous
    }

    /// Toutes les parties au loin qui attendent, la dernière jouée en tête.
    ///
    /// C'est ce que montre « Jouer au loin ». Les périmées sont écartées au
    /// passage : une liste qui propose une partie dont le code est mort ne
    /// rend service à personne.
    func partiesAuLoin() -> [RendezVous] {
        ranger()
        let coin = dossier.appendingPathComponent(GameStore.auLoin, isDirectory: true)
        let fichiers = (try? FileManager.default.contentsOfDirectory(atPath: coin.path)) ?? []
        let codes = fichiers
            .filter { $0.hasSuffix("-rendez-vous.json") }
            .map { String($0.dropLast("-rendez-vous.json".count)) }
        return codes
            .compactMap { code -> RendezVous? in
                // Un rendez-vous sans sa partie ne mène nulle part : c'est un
                // reste d'écriture interrompue, et on le balaie.
                guard let rendezVous = rendezVous(code) else { return nil }
                guard FileManager.default
                    .fileExists(atPath: url(.auLoin(code: code)).path) else {
                    discard(.auLoin(code: code))
                    return nil
                }
                return rendezVous
            }
            .sorted { $0.quand > $1.quand }
    }

    // MARK: - La partie

    func saveID(_ id: UUID, dans tiroir: Tiroir) {
        guard tiroir == .ici else { return }
        try? id.uuidString.write(to: idURL, atomically: true, encoding: .utf8)
    }

    func loadID(_ tiroir: Tiroir) -> UUID? {
        guard tiroir == .ici else { return nil }
        return (try? String(contentsOf: idURL, encoding: .utf8)).flatMap(UUID.init)
    }

    func save(_ game: GameState, dans tiroir: Tiroir) {
        do {
            let data = try JSONEncoder().encode(game)
            try data.write(to: url(tiroir), options: .atomic)
        } catch {
            // Une sauvegarde ratée ne doit pas interrompre une partie : on la
            // retentera au coup suivant, il y en a un toutes les secondes.
            print("Riskelo — sauvegarde impossible : \(error)")
        }
    }

    func load(_ tiroir: Tiroir) -> GameState? {
        ranger()
        guard let data = try? Data(contentsOf: url(tiroir)) else { return nil }
        do {
            return try JSONDecoder().decode(GameState.self, from: data)
        } catch {
            // Sauvegarde d'un autre plateau, ou d'une version qui ne se lit
            // plus : on l'écarte plutôt que de reprendre une partie fausse.
            print("Riskelo — sauvegarde écartée : \(error.localizedDescription)")
            discard(tiroir)
            return nil
        }
    }

    /// Vider un tiroir. Une partie au loin emporte son rendez-vous : l'un sans
    /// l'autre ne mène nulle part.
    func discard(_ tiroir: Tiroir) {
        try? FileManager.default.removeItem(at: url(tiroir))
        if case let .auLoin(code) = tiroir {
            try? FileManager.default.removeItem(at: rendezVousURL(code))
        } else {
            try? FileManager.default.removeItem(at: idURL)
        }
    }

    // MARK: - Ce qui reste d'avant

    /// Les parties au loin n'étaient qu'une, et elle a dormi à deux endroits
    /// avant celui-ci : d'abord dans le tiroir d'ici, avec son rendez-vous posé
    /// à côté, puis dans un tiroir « partie-au-loin » unique. On la déménage au
    /// premier regard, sous son code, plutôt que de la perdre ou de la rendre
    /// sans son fil.
    ///
    /// Silencieux et sans risque : s'il n'y a rien à déménager, il n'y a rien à
    /// faire, et ce cas-là est le seul qui se présentera passé la première fois.
    private func ranger() {
        let fichiers = FileManager.default
        let ancienRendezVous = dossier.appendingPathComponent("rendez-vous.json")
        guard fichiers.fileExists(atPath: ancienRendezVous.path),
              let data = try? Data(contentsOf: ancienRendezVous),
              let rendezVous = try? JSONDecoder().decode(RendezVous.self, from: data)
        else { return }

        // La partie était soit dans le tiroir unique du loin, soit, plus tôt
        // encore, dans celui d'ici.
        let ancienneAuLoin = dossier.appendingPathComponent("partie-au-loin.json")
        let depart = fichiers.fileExists(atPath: ancienneAuLoin.path)
            ? ancienneAuLoin
            : dossier.appendingPathComponent("partie-en-cours.json")
        let arrivee = url(.auLoin(code: rendezVous.code))
        if fichiers.fileExists(atPath: depart.path),
           !fichiers.fileExists(atPath: arrivee.path) {
            try? fichiers.moveItem(at: depart, to: arrivee)
        }
        try? fichiers.moveItem(at: ancienRendezVous, to: rendezVousURL(rendezVous.code))
        // Les restes de l'étape intermédiaire, qui ne désignent plus rien.
        try? fichiers.removeItem(at: dossier.appendingPathComponent("partie-au-loin.json"))
        try? fichiers.removeItem(at: dossier.appendingPathComponent("partie-au-loin-id.txt"))
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
