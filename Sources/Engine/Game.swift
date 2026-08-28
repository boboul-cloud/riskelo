//
//  Game.swift
//  Riskelo
//
//  La partie : l'état complet, et les seuls coups qui peuvent le changer.
//
//  Tout est ici une valeur — y compris le tirage au sort, y compris la banque
//  de questions. Une partie est donc copiable, rejouable et comparable : on
//  peut en faire tourner mille dans un test pour voir si l'attaquant l'emporte
//  trop souvent, ce qu'aucune règle écrite au fil de l'interface ne permet.
//
//  L'enchaînement d'un tour, comme au Risk : renforts, attaques, déplacement.
//

import Foundation

struct Player: Identifiable, Equatable, Codable {
    enum Kind: Equatable, Codable {
        case humain
        /// L'adversaire de la machine : sa culture — la part de bonnes
        /// réponses qu'il donne sur une question moyenne — et sa façon de
        /// jouer, qui n'a rien à voir avec elle. On peut être savant et
        /// manœuvrer mal.
        case machine(niveau: Double, style: Bot.Style)
    }
    let id: PlayerID
    var name: String
    var kind: Kind = .humain
    var eliminated = false
    var isBot: Bool { if case .machine = kind { return true } else { return false } }

    var style: Bot.Style {
        if case let .machine(_, style) = kind { return style } else { return .forte }
    }
}

enum Phase: Equatable, Codable {
    case reinforcement(remaining: Int)
    case attack
    /// Place prise : combien d'hommes avancent.
    case occupation(from: TerritoryID, to: TerritoryID, minimum: Int, maximum: Int)
    case fortify
    case finished(winner: PlayerID)
}

struct Entry: Identifiable, Equatable, Codable {
    enum Kind: Equatable, Codable { case tour, renfort, duel, conquete, elimination, fin }
    let id = UUID()
    let turn: Int
    let player: PlayerID?
    let kind: Kind
    let text: String
    static func == (a: Entry, b: Entry) -> Bool { a.id == b.id }

    /// L'identifiant ne sert qu'à l'affichage : il se refait à la lecture.
    private enum CodingKeys: String, CodingKey { case turn, player, kind, text }
}

/// Ce qu'un joueur a réussi dans une catégorie.
struct Score: Equatable, Codable {
    var asked = 0
    var correct = 0
    var rate: Double { asked == 0 ? 0.5 : Double(correct) / Double(asked) }
}

struct GameState {

    /// Le plateau, et lequel c'est : le second sert à le retrouver au chargement
    /// d'une partie, le premier évite de le rechercher à chaque coup d'œil.
    let boardKind: Boards
    let board: Board
    var rules: Rules
    var players: [Player]
    private(set) var owner: [TerritoryID: PlayerID] = [:]
    private(set) var armies: [TerritoryID: Int] = [:]
    private(set) var current: Int = 0
    private(set) var phase: Phase = .attack
    private(set) var assault: Assault?
    /// Ce que chaque joueur a montré savoir, catégorie par catégorie. C'est
    /// la contrepartie de la règle « l'attaquant pose la question » : celui
    /// qui attaque choisit le terrain, encore faut-il qu'il sache où frapper.
    private(set) var knowledge: [PlayerID: [Category: Score]] = [:]
    /// Ce qui a déjà été payé en renfort d'érudition, pour ne pas le payer
    /// deux fois : le compte des bonnes réponses, lui, ne redescend jamais.
    private(set) var bonusPaid: [PlayerID: Int] = [:]

    // MARK: - Les cartes de territoire

    /// Le paquet, la défausse, et la main de chacun.
    private(set) var deck: [Card] = []
    private(set) var discard: [Card] = []
    private(set) var hands: [PlayerID: [Card]] = [:]
    /// Combien d'échanges ont eu lieu dans la partie : le barème monte avec.
    private(set) var exchanges = 0
    /// A-t-on pris une place dans ce tour ? Une carte ne se gagne qu'ainsi.
    private(set) var conqueredThisTurn = false
    /// La dernière catégorie posée à chaque joueur. Sert à ne pas le
    /// travailler deux fois de suite sur le même sujet — ce qui épuise la
    /// catégorie et rend l'assaillant prévisible.
    private(set) var lastCategoryAgainst: [PlayerID: Category] = [:]
    /// Questions déjà subies par territoire, remis à zéro à chaque tour :
    /// c'est la mémoire du siège, et donc du temps qui se raccourcit.
    private(set) var siege: [TerritoryID: Int] = [:]
    private(set) var turn = 1
    private(set) var journal: [Entry] = []

    var bank: QuestionBank
    var rng: SeededRandom

    var map: GameMap { board.map }
    var currentPlayer: Player { players[current] }

    // MARK: - Mise en place

    /// Le noyau : le plateau, les règles, les joueurs, la banque et le
    /// tirage. Tout le reste se pose ensuite — par `start` pour une partie
    /// neuve, par `init(restoring:)` pour une partie reprise. Il est écrit à
    /// la main parce que déclarer un initialiseur supprime celui que Swift écrivait seul.
    private init(boardKind: Boards, rules: Rules, players: [Player],
                 bank: QuestionBank, rng: SeededRandom) {
        self.boardKind = boardKind
        self.board = boardKind.board
        self.rules = rules
        self.players = players
        self.bank = bank
        self.rng = rng
    }

    static func start(board: Boards = .anneau,
                      players: [Player],
                      rules: Rules = Rules(),
                      bank: QuestionBank = QuestionBank(),
                      seed: UInt64 = UInt64.random(in: .min ... .max)) -> GameState {
        var g = GameState(boardKind: board, rules: rules, players: players,
                          bank: bank, rng: SeededRandom(seed: seed))

        // Les territoires sont distribués au sort, un par un, comme on donne
        // les cartes : personne ne choisit sa position de départ.
        var ids = g.map.order
        ids.shuffle(using: &g.rng)
        for (i, id) in ids.enumerated() {
            let p = players[i % players.count].id
            g.owner[id] = p
            g.armies[id] = 1
        }

        // Puis le reste des armées, réparti au hasard sur ses propres terres.
        for (rank, player) in players.enumerated() {
            let stock = rules.startingArmies + rank * rules.compensation(playerCount: players.count)
            let mine = g.territories(of: player.id)
            guard !mine.isEmpty else { continue }
            for _ in 0 ..< max(0, stock - mine.count) {
                let id = mine.randomElement(using: &g.rng)!
                g.armies[id, default: 0] += 1
            }
        }

        if rules.territoryCards {
            g.deck = Deck.build(for: g.map)
            g.deck.shuffle(using: &g.rng)
        }
        g.phase = .reinforcement(remaining: g.reinforcements(for: g.currentPlayer.id))
        g.note(.tour, "Tour \(g.turn) — à \(g.currentPlayer.name) de jouer.")
        return g
    }

    /// Reconstruit une partie telle qu'elle a été enregistrée.
    ///
    /// Même esprit que `seize` : la porte est nommée, elle est unique, et la
    /// partie normale ne passe jamais par là. Tout ce qui est en lecture seule
    /// depuis l'extérieur se repose ici, et nulle part ailleurs.
    init(restoring board: Boards, rules: Rules, players: [Player],
         bank: QuestionBank, rng: SeededRandom,
         owner: [TerritoryID: PlayerID], armies: [TerritoryID: Int],
         current: Int, phase: Phase, assault: Assault?,
         siege: [TerritoryID: Int], knowledge: [PlayerID: [Category: Score]],
         lastCategoryAgainst: [PlayerID: Category], bonusPaid: [PlayerID: Int],
         deck: [Card], discard: [Card], hands: [PlayerID: [Card]],
         exchanges: Int, conqueredThisTurn: Bool,
         turn: Int, journal: [Entry]) {
        self.init(boardKind: board, rules: rules, players: players, bank: bank, rng: rng)
        self.owner = owner
        self.armies = armies
        self.current = min(max(0, current), max(0, players.count - 1))
        self.phase = phase
        self.assault = assault
        self.siege = siege
        self.knowledge = knowledge
        self.lastCategoryAgainst = lastCategoryAgainst
        self.bonusPaid = bonusPaid
        self.deck = deck
        self.discard = discard
        self.hands = hands
        self.exchanges = exchanges
        self.conqueredThisTurn = conqueredThisTurn
        self.turn = turn
        self.journal = journal
    }

    // MARK: - Les cartes

    func hand(of player: PlayerID) -> [Card] { hands[player] ?? [] }

    /// La valeur du prochain échange, pour l'annoncer avant de le faire.
    var prochainEchange: Int { Deck.valeur(echangeNumero: exchanges + 1) }

    /// Le Risk oblige à échanger dès cinq cartes en main : sans cela on
    /// accumulerait sans jamais rendre la partie plus vive, ce qui est tout
    /// l'objet du barème qui monte.
    func doitEchanger(_ player: PlayerID) -> Bool {
        rules.territoryCards && hand(of: player).count >= 5
            && Deck.premiereCombinaison(dans: hand(of: player)) != nil
    }

    /// Échange trois cartes contre des hommes, ajoutés aux renforts en cours.
    @discardableResult
    mutating func exchange(_ ids: [Int]) -> Bool {
        guard rules.territoryCards, case let .reinforcement(reste) = phase else { return false }
        let joueur = currentPlayer.id
        let main = hand(of: joueur)
        let trio = ids.compactMap { id in main.first { $0.id == id } }
        guard trio.count == 3, Deck.estUneCombinaison(trio) else { return false }

        var valeur = Deck.valeur(echangeNumero: exchanges + 1)
        // Le supplément du Risk : une carte qui porte une de vos places vaut
        // deux hommes de plus. Ils vont au tas commun plutôt que sur la case,
        // pour ne pas ajouter une étape de placement à part.
        if trio.contains(where: { carte in carte.territory.map { owner[$0] == joueur } ?? false }) {
            valeur += 2
        }
        exchanges += 1
        hands[joueur] = main.filter { !ids.contains($0.id) }
        discard.append(contentsOf: trio)
        phase = .reinforcement(remaining: reste + valeur)
        note(.renfort, "\(currentPlayer.name) échange trois cartes : \(valeur) hommes.")
        return true
    }

    /// Tire une carte, en remélangeant la défausse si le paquet est vide.
    private mutating func piocher(_ player: PlayerID) {
        if deck.isEmpty {
            deck = discard
            discard = []
            deck.shuffle(using: &rng)
        }
        guard let carte = deck.popLast() else { return }
        hands[player, default: []].append(carte)
        note(.renfort, "\(players.first { $0.id == player }?.name ?? "?") gagne une carte.")
    }

    // MARK: - Lecture

    func territories(of player: PlayerID) -> [TerritoryID] {
        map.order.filter { owner[$0] == player }
    }

    func armies(_ id: TerritoryID) -> Int { armies[id] ?? 0 }

    func continentsHeld(by player: PlayerID) -> [Continent] {
        map.continentsInOrder.filter { c in c.territories.allSatisfy { owner[$0] == player } }
    }

    func reinforcements(for player: PlayerID) -> Int {
        rules.reinforcements(territories: territories(of: player).count,
                             continentBonus: continentsHeld(by: player).reduce(0) { $0 + $1.bonus })
            + eruditionOwed(player)
    }

    /// Le total gagné depuis le début, tous thèmes confondus.
    func eruditionEarned(_ player: PlayerID) -> Int {
        guard let seuil = rules.answersPerBonusMan, seuil > 0 else { return 0 }
        return Category.allCases.reduce(0) { $0 + record(of: player, in: $1).correct / seuil }
    }

    /// Ce qui lui revient et ne lui a pas encore été versé.
    func eruditionOwed(_ player: PlayerID) -> Int {
        max(0, eruditionEarned(player) - (bonusPaid[player] ?? 0))
    }

    /// Solde le renfort d'érudition au moment où il est versé.
    private mutating func settleErudition(_ player: PlayerID) {
        let du = eruditionOwed(player)
        guard du > 0 else { return }
        bonusPaid[player] = eruditionEarned(player)
        note(.renfort, "\(du) homme\(du > 1 ? "s" : "") de plus pour "
             + "\(players.first { $0.id == player }?.name ?? "?") : ses bonnes réponses.")
    }

    /// D'où peut-on attaquer : ses propres terres, à plus d'un homme, qui
    /// touchent un voisin ennemi.
    func canLaunch(from id: TerritoryID) -> Bool {
        owner[id] == currentPlayer.id && armies(id) >= 2 && !targets(from: id).isEmpty
    }

    func targets(from id: TerritoryID) -> [TerritoryID] {
        map.neighbors(of: id).filter { owner[$0] != owner[id] }
    }

    /// Le nombre de questions possibles : un dé par homme au-delà du premier,
    /// dans la limite de la règle. Il faut toujours laisser une garnison.
    func maxQuestions(from id: TerritoryID) -> Int {
        max(0, min(rules.maxQuestions, armies(id) - 1))
    }

    /// Deux territoires amis reliés par une chaîne de territoires amis.
    func areLinked(_ a: TerritoryID, _ b: TerritoryID, for player: PlayerID) -> Bool {
        guard owner[a] == player, owner[b] == player else { return false }
        if !rules.fortifyAlongChain { return map.areAdjacent(a, b) }
        var seen: Set<TerritoryID> = [a]
        var stack = [a]
        while let id = stack.popLast() {
            if id == b { return true }
            for n in map.neighbors(of: id) where owner[n] == player && !seen.contains(n) {
                seen.insert(n)
                stack.append(n)
            }
        }
        return false
    }

    /// La catégorie où ce joueur a le plus trébuché — et où il trébuche
    /// vraiment : à partir de deux questions posées, et à moins d'une bonne
    /// réponse sur deux. En dessous du seuil, ce n'est pas une faiblesse,
    /// c'est un hasard ; au-dessus, ce n'en est pas une du tout, et la
    /// marquer d'une lunette contredirait le score affiché en vert juste à
    /// côté.
    func weakness(of player: PlayerID) -> Category? {
        knowledge[player]?
            .filter { $0.value.asked >= 2 && $0.value.rate < 0.5 }
            .min { $0.value.rate < $1.value.rate ? true
                 : $0.value.rate > $1.value.rate ? false
                 : $0.key.rawValue < $1.key.rawValue }?.key
    }

    func record(of player: PlayerID, in category: Category) -> Score {
        knowledge[player]?[category] ?? Score()
    }

    /// Tient-il assez du monde pour que la partie soit jouée ?
    func dominates(_ player: PlayerID) -> Bool {
        territories(of: player).count >= dominationThreshold
    }

    /// Combien de territoires il faut tenir pour que la partie soit jouée.
    var dominationThreshold: Int {
        rules.dominationThreshold(territories: map.order.count, playerCount: players.count)
    }

    var isOver: Bool { if case .finished = phase { true } else { false } }

    /// Poser une situation de toutes pièces : un territoire, son propriétaire,
    /// sa garnison. La partie normale ne passe jamais par là — c'est la porte
    /// des essais et des scénarios, et la seule.
    mutating func seize(_ id: TerritoryID, by player: PlayerID, armies count: Int = 1) {
        owner[id] = player
        armies[id] = max(0, count)
    }

    /// Même porte, pour une main de cartes.
    mutating func seizeHand(of player: PlayerID, _ cartes: [Card]) {
        hands[player] = cartes
    }

    /// Même porte, pour ce qu'un joueur a montré savoir dans une catégorie.
    mutating func seize(_ category: Category, of player: PlayerID, asked: Int, correct: Int) {
        knowledge[player, default: [:]][category] = Score(asked: max(0, asked),
                                                          correct: max(0, min(asked, correct)))
    }

    // MARK: - Renforts

    @discardableResult
    mutating func place(on id: TerritoryID, count: Int = 1) -> Bool {
        guard case let .reinforcement(remaining) = phase,
              owner[id] == currentPlayer.id, count > 0, count <= remaining else { return false }
        armies[id, default: 0] += count
        let left = remaining - count
        phase = .reinforcement(remaining: left)
        if left == 0 {
            note(.renfort, "\(currentPlayer.name) a placé ses renforts.")
            phase = .attack
        }
        return true
    }

    // MARK: - Assaut

    /// L'assaut est-il permis ? Séparé de son exécution parce qu'un coup joué
    /// en réseau doit être vérifié avant d'être envoyé, pas après.
    func canDeclare(from: TerritoryID, to: TerritoryID, questions: Int) -> Bool {
        guard case .attack = phase, assault == nil,
              owner[from] == currentPlayer.id,
              let defenseur = owner[to], defenseur != currentPlayer.id,
              map.areAdjacent(from, to),
              questions >= 1, questions <= maxQuestions(from: from) else { return false }
        return true
    }

    @discardableResult
    mutating func declareAssault(from: TerritoryID, to: TerritoryID,
                                 questions: Int, category: Category) -> Bool {
        guard canDeclare(from: from, to: to, questions: questions),
              let defender = owner[to] else { return false }

        var a = Assault(attacker: currentPlayer.id, defender: defender,
                        from: from, to: to, category: category, volley: questions)
        note(.duel, "\(currentPlayer.name) attaque \(name(to)) depuis \(name(from)) — "
             + "\(questions) question\(questions > 1 ? "s" : "") \(category.apresDe).")
        lastCategoryAgainst[defender] = category
        if !drawQuestion(&a) { assault = nil; return false }
        assault = a
        return true
    }

    private mutating func drawQuestion(_ a: inout Assault) -> Bool {
        let level = rules.drawDifficulty(using: &rng)
        guard let asked = bank.draw(category: a.category, difficulty: level, using: &rng) else {
            return false
        }
        let pressure = siege[a.to] ?? 0
        a.current = Duel(question: asked,
                         allowance: rules.answerTime(siege: pressure),
                         siege: pressure)
        return true
    }

    /// Qui doit répondre à la question posée.
    ///
    /// En classique, le défenseur, et lui seul. En face à face, le défenseur
    /// **puis** l'attaquant — dans cet ordre, et l'ordre n'est pas indifférent.
    /// Sur un appareil partagé, celui qui répond en second a eu le temps de
    /// réfléchir pendant que l'autre cherchait ; cet avantage revient donc à
    /// l'attaquant, qui perd déjà toutes les égalités.
    var quiRepond: PlayerID? {
        guard let a = assault, a.current != nil else { return nil }
        guard rules.mode == .faceAFace else { return a.defender }
        return a.defenderAnswer == nil ? a.defender : a.attacker
    }

    /// Le défenseur peut-il encore doubler l'enjeu ? Une fois par question,
    /// et avant d'avoir répondu — après, ce ne serait plus un pari.
    var peutRelancer: Bool {
        guard rules.mode == .faceAFace, let a = assault, a.current != nil else { return false }
        return a.defenderAnswer == nil && a.mise == 1
    }

    /// La relance : le second dé du défenseur.
    ///
    /// Au Risk, le défenseur choisit un ou deux dés, et deux dés font gagner
    /// ou perdre davantage. Ici il mise sur sa propre connaissance du thème
    /// que l'attaquant vient de choisir : l'échange vaudra deux hommes au lieu
    /// d'un, dans le sens où il tombera.
    mutating func relancer() {
        guard peutRelancer else { return }
        assault?.mise = 2
        note(.duel, "\(playerName(assault?.defender ?? -1)) relance : "
             + "l'échange vaudra deux hommes.")
    }

    func playerName(_ id: PlayerID) -> String {
        players.first { $0.id == id }?.name ?? "?"
    }

    private mutating func crediter(_ joueur: PlayerID, _ categorie: Category, juste: Bool) {
        var score = knowledge[joueur]?[categorie] ?? Score()
        score.asked += 1
        if juste { score.correct += 1 }
        knowledge[joueur, default: [:]][categorie] = score
    }

    private func hommes(_ n: Int) -> String { "\(n) homme\(n > 1 ? "s" : "")" }

    /// Une réponse arrive. C'est le seul coup qui fait couler du sang — sauf
    /// la première des deux en face à face, qui ne fait qu'attendre l'autre.
    @discardableResult
    mutating func answer(_ response: Answer) -> DuelReport? {
        guard var a = assault, let duel = a.current else { return nil }

        // Face à face, premier temps : le défenseur a répondu, sa réponse
        // dort jusqu'à celle de l'attaquant. Rien n'est révélé, sans quoi
        // l'attaquant lirait la solution avant de répondre à la même question.
        if rules.mode == .faceAFace, a.defenderAnswer == nil {
            a.defenderAnswer = response
            assault = a
            return nil
        }

        let report: DuelReport
        if rules.mode == .faceAFace, let defense = a.defenderAnswer {
            report = Combat.resolveCroise(defender: defense, attacker: response,
                                          of: duel, mise: a.mise)
            crediter(a.defender, duel.question.category, juste: report.correct)
            // L'attaquant répond, donc sa culture compte aussi : c'est tout
            // le propos du mode, et le renfort d'érudition suit.
            crediter(a.attacker, duel.question.category, juste: report.attackerCorrect)
        } else {
            report = Combat.resolve(response, of: duel)
            crediter(a.defender, duel.question.category, juste: report.correct)
        }

        a.current = nil
        a.defenderAnswer = nil
        a.asked += 1
        a.reports.append(report)
        siege[a.to, default: 0] += 1

        switch report.outcome {
        case .defenderHolds:
            // On n'enlève jamais à l'assaillant sa garnison : une mise de deux
            // ne rapporte que ce que la pile d'en face peut payer.
            let perte = max(0, min(report.mise, armies(a.from) - 1))
            armies[a.from, default: 0] -= perte
            a.attackerLosses += perte
            note(.duel, recit(report, place: name(a.to), perte: perte))
        case .attackerBreaks:
            let perte = min(report.mise, armies(a.to))
            armies[a.to, default: 0] -= perte
            a.defenderLosses += perte
            note(.duel, recit(report, place: name(a.to), perte: perte))
        }

        a.mise = 1
        if armies(a.to) <= 0 {
            a.conquered = true
            assault = a
            conquer(from: a.from, to: a.to, volley: a.volley)
            return report
        }

        // La salve continue tant qu'il reste une question annoncée et un homme
        // de trop pour la mener : on n'attaque jamais avec sa garnison.
        if a.asked < a.volley && armies(a.from) >= 2 {
            _ = drawQuestion(&a)
        }
        assault = a
        return report
    }

    /// Ce que le journal retient de l'échange. Le mode face à face a quatre
    /// issues là où le classique en a deux, et il faut les nommer : un joueur
    /// qui perd une place doit savoir si c'est parce qu'il ignorait, ou parce
    /// qu'il a été moins vif.
    private func recit(_ r: DuelReport, place: String, perte: Int) -> String {
        let tient = r.outcome == .defenderHolds
        switch r.verdict {
        case .reponse:
            return tient
                ? "\(place) tient : bonne réponse, l'assaillant laisse \(hommes(perte))."
                : (r.answer == .timeout
                   ? "Temps écoulé : \(place) perd \(hommes(perte))."
                   : "Mauvaise réponse : \(place) perd \(hommes(perte)).")
        case .seul:
            return tient
                ? "\(place) tient : le défenseur savait, l'assaillant non — \(hommes(perte)) de moins pour lui."
                : "L'assaillant savait, la place non : \(place) perd \(hommes(perte))."
        case .vitesse:
            return tient
                ? "Les deux savaient : le défenseur a été le plus vif, \(place) tient et coûte \(hommes(perte))."
                : "Les deux savaient : l'assaillant a été le plus vif, \(place) perd \(hommes(perte))."
        case .egalite:
            return "Personne ne savait : \(place) tient, et l'assaillant laisse \(hommes(perte))."
        }
    }

    /// Range l'assaut terminé et rend la main.
    mutating func dismissAssault() {
        guard let a = assault, a.isOver else { return }
        assault = nil
    }

    /// Les cartes du vaincu passent à celui qui l'achève.
    ///
    /// C'est la règle du Risk, et elle a une raison qu'on ne voit qu'en la
    /// retirant : sans elle, la main du vaincu reste gelée là où elle est et
    /// ces cartes sortent du jeu pour de bon. Le paquet s'appauvrit à chaque
    /// élimination, silencieusement, jusqu'à ne plus rien pouvoir donner.
    ///
    /// Le Risk oblige à redescendre sous cinq cartes sur-le-champ, hommes
    /// posés dans la foulée. On laisse ici la règle qui existe déjà s'en
    /// charger : `doitEchanger` bloque à cinq, et le surplus se solde à
    /// l'ouverture du tour suivant. Le seul écart avec la règle d'origine est
    /// le moment où les hommes arrivent — et il évite d'inventer une étape de
    /// placement au milieu d'un assaut, seul endroit du jeu où l'on ne pose
    /// jamais rien.
    private mutating func heriter(de vaincu: PlayerID) {
        let butin = hand(of: vaincu)
        guard !butin.isEmpty else { return }
        hands[vaincu] = []
        hands[currentPlayer.id, default: []].append(contentsOf: butin)
        note(.renfort, "\(currentPlayer.name) hérite de \(butin.count) carte"
             + "\(butin.count > 1 ? "s" : "") du vaincu.")
    }

    private mutating func conquer(from: TerritoryID, to: TerritoryID, volley: Int) {
        let loser = owner[to]
        owner[to] = currentPlayer.id
        armies[to] = 0
        conqueredThisTurn = true
        note(.conquete, "\(name(to)) tombe. \(currentPlayer.name) s'en empare.")

        if let loser, territories(of: loser).isEmpty,
           let i = players.firstIndex(where: { $0.id == loser }) {
            players[i].eliminated = true
            note(.elimination, "\(players[i].name) est éliminé.")
            heriter(de: loser)
        }

        let survivors = players.filter { !$0.eliminated }
        guard survivors.count > 1, !dominates(currentPlayer.id) else {
            // Tout est pris : la garnison suit, et la partie s'arrête.
            armies[to] = max(1, armies(from) - 1)
            armies[from] = 1
            assault = nil
            phase = .finished(winner: currentPlayer.id)
            note(.fin, survivors.count > 1
                 ? "\(currentPlayer.name) tient assez du monde pour que le reste ne compte plus."
                 : "\(currentPlayer.name) tient le monde entier.")
            return
        }

        let available = max(1, armies(from) - 1)
        phase = .occupation(from: from, to: to,
                            minimum: min(volley, available), maximum: available)
    }

    /// Combien d'hommes avancent dans la place conquise. Au moins autant que
    /// de questions posées — l'équivalent du « au moins autant que de dés ».
    @discardableResult
    mutating func occupy(_ count: Int) -> Bool {
        guard case let .occupation(from, to, minimum, maximum) = phase else { return false }
        let n = min(max(count, minimum), maximum)
        armies[from, default: 0] -= n
        armies[to, default: 0] += n
        assault = nil
        phase = .attack
        note(.conquete, "\(n) homme\(n > 1 ? "s avancent" : " avance") sur \(name(to)).")
        return true
    }

    // MARK: - Déplacement et fin de tour

    @discardableResult
    mutating func fortify(from: TerritoryID, to: TerritoryID, count: Int) -> Bool {
        guard case .fortify = phase,
              areLinked(from, to, for: currentPlayer.id), from != to,
              count > 0, count <= armies(from) - 1 else { return false }
        armies[from, default: 0] -= count
        armies[to, default: 0] += count
        note(.renfort, "\(count) homme\(count > 1 ? "s" : "") de \(name(from)) vers \(name(to)).")
        endTurn()
        return true
    }

    /// Passe à l'étape suivante du tour, et au joueur suivant s'il n'y en a plus.
    mutating func advance() {
        switch phase {
        case .reinforcement(let remaining):
            // On ne passe pas son tour avec des renforts en poche.
            if remaining == 0 { phase = .attack }
        case .attack:
            guard assault == nil else { return }
            phase = .fortify
        case .occupation:
            return
        case .fortify:
            endTurn()
        case .finished:
            return
        }
    }

    mutating func endTurn() {
        guard !isOver else { return }
        if rules.territoryCards, conqueredThisTurn { piocher(currentPlayer.id) }
        conqueredThisTurn = false
        assault = nil
        siege.removeAll()     // le souffle du défenseur revient entre deux tours
        var next = current
        repeat {
            next = (next + 1) % players.count
            if next == 0 { turn += 1 }
        } while players[next].eliminated
        current = next
        let renforts = reinforcements(for: currentPlayer.id)
        settleErudition(currentPlayer.id)
        phase = .reinforcement(remaining: renforts)
        note(.tour, "Tour \(turn) — à \(currentPlayer.name) de jouer.")
    }

    // MARK: - Journal

    func name(_ id: TerritoryID) -> String { map[id]?.name ?? id }

    private mutating func note(_ kind: Entry.Kind, _ text: String) {
        journal.append(Entry(turn: turn, player: players.indices.contains(current) ? currentPlayer.id : nil,
                             kind: kind, text: text))
        if journal.count > 400 { journal.removeFirst(journal.count - 400) }
    }
}
