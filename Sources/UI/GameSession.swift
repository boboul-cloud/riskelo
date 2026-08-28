//
//  GameSession.swift
//  Riskelo
//
//  Ce qui relie le moteur à l'écran : le temps qui passe, l'adversaire qui
//  réfléchit, et l'ordre dans lequel les choses se montrent.
//
//  Le moteur, lui, ne connaît ni l'un ni l'autre : il reçoit une réponse et
//  rend un compte rendu. Tout ce qui suit — le sablier, la seconde d'attente
//  avant que la machine ne réponde, le temps qu'on laisse pour lire le
//  résultat — est du théâtre, et le théâtre est ici.
//

import Foundation
import MultipeerConnectivity
import Observation
import SwiftUI

@Observable
@MainActor
final class GameSession {

    /// Où en est le duel à l'écran. Le moteur n'a pas ces états : pour lui,
    /// une question est posée ou elle ne l'est pas.
    enum Stage: Equatable {
        /// La carte, le temps de voir d'où part l'assaut et où il tombe.
        /// Sans elle, l'écran de duel recouvrait tout dès la déclaration et
        /// l'on ne savait jamais ce que la machine était en train de faire.
        case announcing
        /// « Passez l'appareil », ou « prêt ? » : le sablier ne part pas sans
        /// que celui qui répond ait dit qu'il l'était.
        case handover
        /// Face à face : l'autre répond, et la question ne doit pas encore
        /// paraître. Elle paraissait, et l'on voyait donc l'énoncé, puis un
        /// écran « prêt ? », puis le même énoncé — deux écrans pour une seule
        /// question, et l'impression que le jeu bégayait.
        case adversaireRepond
        case asking
        case revealed
        /// L'assaut est fini : ce qu'il a coûté, et ce qu'il a pris.
        case summary
    }

    /// L'identité de cette partie dans la bibliothèque.
    ///
    /// Elle survit à une reprise — rouvrir l'application ne doit pas ouvrir
    /// une seconde partie — mais **pas** à un retour en arrière : revenir à
    /// un instant archivé ouvre une nouvelle branche, sans quoi rejouer la
    /// fin d'une partie effacerait la fin qu'on voulait justement garder.
    let partieID: UUID

    /// Range l'instant présent dans la bibliothèque.
    ///
    /// Hors du fil principal : ranger un instant relit tout l'index, encode la
    /// partie et écrit deux fichiers. C'était fait au beau milieu de l'appui
    /// sur « Fin du tour », qui marquait donc un temps.
    ///
    /// Les rangements se suivent à la queue leu leu — chacun attend le
    /// précédent — parce que `ranger` lit l'index, le modifie et le réécrit :
    /// deux à la fois s'écraseraient l'un l'autre.
    private func archiver(_ etiquette: String, marque: Bool = false) {
        let partie = game, id = partieID
        let precedent = rangement
        rangement = Task.detached(priority: .utility) {
            await precedent?.value
            Archives.shared.ranger(partie, partie: id, etiquette: etiquette, marque: marque)
        }
    }

    private var rangement: Task<Void, Never>?

    /// Le joueur pose un signet sur la position. Le tour qui passe en pose un
    /// tout seul ; celui-ci sert à retenir un moment au milieu d'un tour.
    func marquer() {
        archiver("Position marquée", marque: true)
    }

    /// Toute mutation de la partie déclenche son enregistrement — c'est le
    /// seul endroit d'où il part, et il n'y a donc aucun coup qui puisse
    /// l'oublier. L'écriture est différée d'une demi-seconde : pendant le tour
    /// de la machine, les coups s'enchaînent plusieurs fois par seconde, et
    /// seul le dernier compte.
    private(set) var game: GameState {
        didSet {
            scheduleSave()
            noterChangementDePhase(depuis: oldValue)
        }
    }

    /// La part du bas de l'écran que prend la feuille du duel. Le plateau s'en
    /// sert pour recadrer : le combat doit rester visible AU-DESSUS d'elle, et
    /// non sous elle.
    var partCouverte: Double {
        switch stage {
        case .handover, .asking, .revealed, .summary: 0.55
        case .adversaireRepond: 0.4
        default: 0
        }
    }

    /// Repère les changements d'étape et les annonce. Passe par le `didSet` de
    /// la partie : c'est le seul endroit d'où elle peut changer, donc aucun
    /// changement ne peut échapper.
    private func noterChangementDePhase(depuis avant: GameState) {
        guard !game.isOver else {
            if case let .finished(gagnant) = game.phase, !avant.isOver {
                montrer(Annonce(titre: "\(game.players.first { $0.id == gagnant }?.name ?? "?") l'emporte !",
                                sous: nil, camp: gagnant))
                archiver("Fin de partie")
            }
            return
        }
        let nouveauTour = avant.current != game.current
        if nouveauTour {
            // Un instant par tour, posé sans qu'on le demande : c'est après
            // coup qu'on sait lequel comptait.
            archiver("Tour \(game.turn) — \(game.currentPlayer.name)")
            let nom = game.currentPlayer.name
            let aMoi = !enReseau || game.currentPlayer.id == monRang
            montrer(Annonce(titre: aMoi ? "\(nom), c'est à vous !" : "Au tour de \(nom)",
                            sous: "Renforts", camp: game.currentPlayer.id))
            return
        }
        switch (avant.phase, game.phase) {
        case (.reinforcement, .attack):
            montrer(Annonce(titre: "À l'attaque !", sous: nil, camp: game.currentPlayer.id))
        case (.attack, .fortify), (.occupation, .fortify):
            montrer(Annonce(titre: "Déplacement", sous: "Un seul, puis le tour passe",
                            camp: game.currentPlayer.id))
        case (_, .occupation):
            montrer(Annonce(titre: "Place prise !", sous: nil, camp: game.currentPlayer.id))
        default:
            break
        }
    }

    /// L'ouverture. Elle ne passe pas par le `didSet` — la partie est posée
    /// dans l'initialiseur, et une propriété qu'on installe ne se surveille
    /// pas elle-même. Le premier tour restait donc muet.
    private func annoncerOuverture() {
        guard !game.isOver else { return }
        let nom = game.currentPlayer.name
        let aMoi = !enReseau || game.currentPlayer.id == monRang
        montrer(Annonce(titre: aMoi ? "\(nom), c'est à vous !" : "Au tour de \(nom)",
                        sous: "Renforts", camp: game.currentPlayer.id))
    }

    private func montrer(_ a: Annonce) {
        annonce = a
        annonceWork?.cancel()
        annonceWork = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1_400))
            guard let self, !Task.isCancelled else { return }
            self.annonce = nil
        }
    }
    /// Ce qui s'annonce à l'écran, le temps d'un battement : « Bleu, c'est à
    /// vous ! », « À l'attaque ! ». Rien qui décide de quoi que ce soit — mais
    /// sans cela, on ne sait pas qu'on vient de changer d'étape.
    struct Annonce: Equatable, Identifiable {
        let id = UUID()
        let titre: String
        let sous: String?
        let camp: PlayerID
        static func == (a: Annonce, b: Annonce) -> Bool { a.id == b.id }
    }

    private(set) var annonce: Annonce?
    private var annonceWork: Task<Void, Never>?

    private(set) var stage: Stage?
    private(set) var report: DuelReport?
    private(set) var remaining: TimeInterval = 0
    private(set) var thinking = false

    var selected: TerritoryID?
    var target: TerritoryID?
    private(set) var draftCategory: Category = .geographie
    var draftQuestions = 1
    /// Le joueur a-t-il déjà choisi un terrain lui-même ? Tant que non,
    /// l'application lui suggère la faiblesse de l'adversaire — une fois, pour
    /// montrer à quoi sert ce choix. Ensuite elle se tait : re-suggérer à
    /// chaque assaut, c'est le pousser à marteler la même catégorie, et une
    /// catégorie martelée s'épuise.
    private var categoryChosen = false

    func chooseCategory(_ c: Category) {
        draftCategory = c
        categoryChosen = true
    }
    var journalOpen = false
    var dossierOpen = false
    var cartesOpen = false
    /// Les cartes retenues dans la main, en attente d'échange.
    var cartesChoisies: Set<Int> = []

    func basculerCarte(_ id: Int) {
        if cartesChoisies.contains(id) { cartesChoisies.remove(id) }
        else if cartesChoisies.count < 3 { cartesChoisies.insert(id) }
    }

    /// Les trois cartes retenues forment-elles une combinaison ?
    var combinaisonPrete: Bool {
        let main = game.hand(of: game.currentPlayer.id)
        let trio = main.filter { cartesChoisies.contains($0.id) }
        return Deck.estUneCombinaison(trio)
    }

    func echanger() {
        guard combinaisonPrete else { return }
        jouer(.exchangeCards(Array(cartesChoisies)))
        cartesChoisies = []
        resume()
    }

    /// Le tempo de l'écran. Rien ici ne touche aux règles : c'est le temps
    /// qu'on laisse à l'œil, et lui seul.
    ///
    /// Une question posée à la machine se réglait en trois secondes — le temps
    /// de la voir passer, pas de la lire. Or c'est le moment le plus vivant du
    /// jeu pour l'attaquant : il a choisi le terrain, il connaît la question,
    /// et il y répond dans sa tête avant l'adversaire. Il faut lui en laisser
    /// le temps. Mais soixante questions dans une partie font soixante
    /// attentes : chacune se coupe d'une touche.
    private enum Tempo {
        /// Plancher et plafond du temps de lecture, selon la longueur du texte.
        static let lectureMin: Double = 4.0
        static let lectureMax: Double = 9.0
        /// Signes lus par seconde, lecture attentive.
        static let signesParSeconde: Double = 17
        /// Le temps laissé sur le résultat : la bonne réponse, les dés, et qui
        /// perd un homme. C'est trois choses à lire.
        static let verdict: Double = 4.5
        /// En face à face, il y a deux réponses et deux temps à lire en plus
        /// de la bonne réponse : le même moment ne suffit plus.
        static let verdictCroise: Double = 9.5
        /// Le bilan d'un assaut que l'on a subi : ce qu'il a coûté, et ce
        /// qu'il a pris. Quand on attaque soi-même, il attend un appui ; quand
        /// on le subit, il passe seul pour ne pas hacher le tour d'en face.
        static let bilan: Double = 5.5
        /// Le temps passé sur la carte avant un assaut de la machine : de quoi
        /// suivre la flèche et reconnaître les deux places. Cinq secondes, et
        /// non trois et demie : sur un grand plateau la vue se déplace d'abord
        /// vers le combat, et il faut laisser le temps d'arriver puis de
        /// regarder.
        static let annonce: Double = 5.0
        /// Face à face : le temps que la machine a l'air de chercher, quand sa
        /// réponse ne sera pas montrée.
        static let reflexion: Double = 2.2
    }

    /// Le temps laissé sur le résultat, selon ce qu'il y a à y lire.
    private var tempsDeVerdict: Double {
        game.rules.mode == .faceAFace ? Tempo.verdictCroise : Tempo.verdict
    }

    /// Ce qui reste du moment en cours, de 1 à 0. La barre du haut s'en sert
    /// quand c'est la machine qui défend — un humain, lui, a son vrai sablier.
    ///
    /// Une seule descente par question, lecture et verdict compris. La
    /// première version en faisait deux : la barre se vidait pendant la
    /// lecture, se remplissait, et se vidait à nouveau pendant le verdict. On
    /// croyait à un second compte à rebours pour la même question.
    private(set) var waitPart: Double = 1
    /// Une touche pendant une attente : on passe à la suite.
    private var skipped = false

    /// Y a-t-il quelque chose à écourter ?
    /// Le moment se laisse écourter — mais pas dans sa première seconde. Un
    /// appui parti trop tôt, ou le second d'un double appui, emportait le
    /// verdict avant qu'on ait pu le lire.
    var canSkip: Bool {
        (thinking || stage == .revealed || stage == .announcing || stage == .summary)
            && waitPart < 0.85
    }

    func skipAhead() { skipped = true }

    private var pump: Task<Void, Never>?
    private var ticker: Timer?
    private var saveWork: Task<Void, Never>?

    // MARK: - Le second appareil

    private(set) var link: Link?
    /// Lequel des joueurs est celui qui tient cet appareil.
    private(set) var monRang: PlayerID = 0
    private var jHeberge = false
    /// Combien de coups ont été joués depuis le début. Sert d'ordre : un coup
    /// déjà vu se reconnaît, un coup manquant se voit.
    private var compteur = 0
    /// Le rang de chaque appareil relié, pour savoir à qui renvoyer quoi.
    private var rangs: [MCPeerID: PlayerID] = [:]

    var enReseau: Bool { link != nil }

    /// À moi d'agir ? Hors réseau, cela veut dire « pas à la machine ».
    var aMoiDeJouer: Bool {
        guard !game.isOver else { return false }
        guard enReseau else { return !game.currentPlayer.isBot }
        return game.currentPlayer.id == monRang
    }

    /// À moi de répondre ? En classique c'est toujours le défenseur ; en
    /// face à face, le défenseur puis l'attaquant.
    var aMoiDeRepondre: Bool {
        guard game.assault != nil else { return false }
        guard enReseau else { return repondeurEstHumain }
        return repondeur == monRang
    }

    /// Le seul point par lequel une partie change, et donc le seul d'où un
    /// coup part vers l'autre appareil. Aucun coup ne peut être oublié : il
    /// n'y a pas d'autre porte.
    @discardableResult
    private func jouer(_ action: Action) -> DuelReport? {
        let rapport = game.apply(action)
        if let link {
            compteur += 1
            if let data = Message.coup(action, numero: compteur, empreinte: game.digest).data {
                link.envoyer(data)
            }
        }
        return rapport
    }

    /// Ce qui arrive d'un autre appareil.
    private func recu(_ data: Data, de pair: MCPeerID) {
        // Un paquet qu'on ne sait pas lire en cours de partie ne peut plus
        // être un désaccord de version — la poignée de main l'aurait dit — et
        // il n'y a donc rien de mieux à faire que de l'ignorer. `Message.lire`
        // laisse une trace dans la console pour les deux cas.
        guard case let .message(message) = Message.lire(data) else { return }
        switch message {
        case let .partie(etat, votreRang, numero):
            monRang = votreRang
            compteur = numero
            game = etat
            report = nil
            stage = nil
            annoncerOuverture()
            resume()

        case let .coup(action, numero, empreinte):
            // Déjà joué : à quatre, l'hôte relaie, et le coup peut arriver
            // deux fois. On le reconnaît à son numéro.
            guard numero > compteur else { return }
            // Il en manque un : reprendre ici jouerait une autre partie.
            guard numero == compteur + 1 else { redemanderLaPartie(); return }

            compteur = numero
            let rapport = game.apply(action)
            guard game.digest == empreinte else {
                // Les parties ont divergé. Chacune reste cohérente de son côté
                // — c'est bien le danger — donc on ne continue pas.
                redemanderLaPartie()
                return
            }
            // L'hôte fait suivre aux autres : rien ne garantit que deux
            // invités se voient directement.
            if jHeberge, let link { link.envoyer(data, saufA: pair) }

            pump?.cancel()
            pump = Task { @MainActor [weak self] in
                await self?.apresCoupDistant(action, rapport)
            }

        case .perdu:
            guard jHeberge, let link, let rang = rangs[pair],
                  let data = Message.partie(game, votreRang: rang, numero: compteur).data
            else { return }
            link.envoyer(data, a: pair)
        }
    }

    private func redemanderLaPartie() {
        guard let data = Message.perdu.data else { return }
        link?.envoyer(data)
    }

    /// Ce que l'écran doit montrer d'un coup joué en face.
    private func apresCoupDistant(_ action: Action, _ rapport: DuelReport?) async {
        switch action {
        case .declareAssault:
            stage = .announcing
            await pause(Tempo.annonce)
            if Task.isCancelled { return }
        case .answer:
            report = rapport
            stage = .revealed
            await pause(Tempo.verdict)
            if Task.isCancelled { return }
            report = nil
        default:
            break
        }
        stage = nil
        resume()
    }


    // MARK: - Le tiroir

    /// Enregistre tout de suite. À appeler quand l'application passe à
    /// l'arrière-plan : elle peut être arrêtée sans autre préavis.
    func saveNow() {
        saveWork?.cancel()
        if game.isOver { GameStore.shared.discard() } else { GameStore.shared.save(game) }
    }

    private func scheduleSave() {
        saveWork?.cancel()
        saveWork = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            self.saveNow()
        }
    }

    init(players: [Player], rules: Rules = Rules(), board: Boards = .anneau,
         seed: UInt64 = UInt64.random(in: .min ... .max)) {
        game = GameState.start(board: board, players: players, rules: rules, seed: seed)
        partieID = UUID()
        GameStore.shared.saveID(partieID)
        saveNow()
        archiver("Ouverture")
        annoncerOuverture()
        resume()
    }

    /// Ouvre une partie sur deux appareils. Celui qui héberge crée la partie
    /// et l'envoie ; celui qui rejoint la reçoit avant d'afficher quoi que ce
    /// soit.
    init(link: Link, heberge: Bool, game partie: GameState, monRang rang: PlayerID,
         rangs: [MCPeerID: PlayerID] = [:], compteur: Int = 0) {
        game = partie
        partieID = UUID()
        self.link = link
        self.jHeberge = heberge
        self.monRang = rang
        self.rangs = rangs
        self.compteur = compteur
        link.onReceive = { [weak self] data, pair in self?.recu(data, de: pair) }
        annoncerOuverture()
        resume()
    }

    /// Reprend une partie enregistrée. Un duel en attente d'un humain
    /// repassera de lui-même par « prêt ? » : le sablier ne doit pas courir
    /// pendant qu'on rallume l'appareil.
    ///
    /// `partie` n'est donné que par la bibliothèque, qui ouvre alors une
    /// branche neuve ; la reprise ordinaire retrouve l'identité laissée à
    /// côté de la sauvegarde.
    init(resuming saved: GameState, partie: UUID? = nil) {
        game = saved
        partieID = partie ?? GameStore.shared.loadID() ?? UUID()
        GameStore.shared.saveID(partieID)
        if partie != nil { archiver("Repris ici") }
        annoncerOuverture()
        resume()
    }

    // MARK: - Ce que l'écran demande

    var duel: Duel? { game.assault?.current }
    var assault: Assault? { game.assault }

    /// Qui doit répondre — ou, la question une fois résolue, qui vient de le
    /// faire : la feuille du verdict s'affiche après que le moteur a rangé la
    /// question, et elle a encore besoin de nommer quelqu'un.
    var repondeur: PlayerID? { game.quiRepond ?? game.assault?.defender }

    var repondeurEstHumain: Bool {
        guard let qui = repondeur else { return false }
        return !(player(qui)?.isBot ?? true)
    }

    /// Le défenseur peut-il doubler, et est-ce à moi de le décider ?
    var puisJeRelancer: Bool {
        game.peutRelancer && aMoiDeRepondre && stage == .asking && report == nil
    }

    func relancer() {
        guard puisJeRelancer else { return }
        jouer(.relancer)
    }

    func player(_ id: PlayerID) -> Player? { game.players.first { $0.id == id } }

    /// Le territoire touché du doigt. Ce qu'il déclenche dépend de la phase :
    /// c'est le seul endroit où le plateau se pilote.
    func tap(_ id: TerritoryID) {
        guard stage == nil, aMoiDeJouer else { return }
        let moi = game.currentPlayer.id
        switch game.phase {
        case .reinforcement:
            if game.owner[id] == moi { jouer(.place(id)) }
            if case .attack = game.phase { selected = nil }

        case .attack:
            if game.owner[id] == moi {
                selected = (selected == id) ? nil : (game.canLaunch(from: id) ? id : nil)
                target = nil
            } else if let base = selected, game.map.areAdjacent(base, id) {
                target = id
                draftQuestions = min(draftQuestions, game.maxQuestions(from: base))
                if !categoryChosen {
                    draftCategory = game.weakness(of: game.owner[id] ?? -1) ?? draftCategory
                }
            }

        case .fortify:
            if game.owner[id] == moi {
                if let base = selected, base != id, game.areLinked(base, id, for: moi),
                   game.armies(base) >= 2 {
                    target = id
                } else {
                    selected = (selected == id) ? nil : id
                    target = nil
                }
            }

        case .occupation, .finished:
            break
        }
    }

    func cancelDraft() { target = nil }

    // MARK: - L'assaut

    func declare() {
        guard let base = selected, let cible = target else { return }
        guard game.canDeclare(from: base, to: cible, questions: draftQuestions) else { return }
        jouer(.declareAssault(from: base, to: cible,
                              questions: draftQuestions, category: draftCategory))
        target = nil
        resume()
    }

    /// Celui qui répond dit qu'il est prêt : le sablier part à cet instant,
    /// et pas avant. Sans cela, un joueur qui passe l'appareil à un autre lui
    /// offre trois secondes de moins.
    func beginAnswering() {
        guard let duel else { return }
        stage = .asking
        startCountdown(duel.allowance)
    }

    func answer(_ index: Int?) {
        guard let duel, stage == .asking else { return }
        stopCountdown()
        let elapsed = max(0, duel.allowance - remaining)
        let rapport = jouer(.answer(index.map { .chosen($0, elapsed: elapsed) } ?? .timeout))
        // Face à face : la première des deux réponses ne montre rien. La
        // dévoiler donnerait la solution à celui qui doit encore répondre.
        guard let rapport else {
            // Face à face : votre réponse est prise, mais elle ne tranche
            // rien tant que l'autre n'a pas répondu. Refermer la feuille ici
            // était le pire des choix — l'écran revenait sur la même
            // question, l'appui semblait perdu, et l'on tapait une seconde
            // fois. Ce second appui tombait alors sur le verdict et
            // l'escamotait : les deux défauts n'en faisaient qu'un.
            report = nil
            stage = .adversaireRepond
            resume()
            return
        }
        report = rapport
        stage = .revealed
        pump?.cancel()
        pump = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.pause(self.tempsDeVerdict)
            guard !Task.isCancelled else { return }
            self.report = nil
            self.stage = nil
            self.resume()
        }
    }

    /// Après un assaut terminé : ranger, et reprendre la main.
    func closeAssault() {
        jouer(.dismissAssault)
        report = nil
        stage = nil
        selected = nil
        resume()
    }

    func occupy(_ count: Int) {
        jouer(.occupy(count))
        report = nil
        stage = nil
        selected = nil
        resume()
    }

    // MARK: - Le tour

    func endPhase() {
        guard aMoiDeJouer else { return }
        jouer(.advance)
        selected = nil
        target = nil
        resume()
    }

    func fortify(_ count: Int) {
        guard let base = selected, let cible = target else { return }
        jouer(.fortify(from: base, to: cible, count: count))
        selected = nil
        target = nil
        resume()
    }

    func endTurn() {
        jouer(.endTurn)
        selected = nil
        target = nil
        resume()
    }

    // MARK: - Le sablier

    private func startCountdown(_ allowance: TimeInterval) {
        remaining = allowance
        ticker?.invalidate()
        // Le minuteur ne retient pas la partie : si elle a disparu, il se
        // débranche lui-même. Un `deinit` ne peut pas le faire — il n'est pas
        // sur l'acteur principal, et le minuteur, lui, y vit.
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] minuteur in
            Task { @MainActor in
                guard let self else { minuteur.invalidate(); return }
                guard self.stage == .asking else { return }
                self.remaining = max(0, self.remaining - 0.1)
                if self.remaining <= 0 { self.answer(nil) }
            }
        }
        // Mode « common » : le sablier ne doit pas s'arrêter parce qu'on fait
        // défiler le journal d'une main pendant qu'on réfléchit de l'autre.
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopCountdown() {
        ticker?.invalidate()
        ticker = nil
    }

    /// Une attente que l'on peut écourter, et dont on voit la fin venir.
    ///
    /// `de` et `à` disent où la barre se trouve au début et où elle doit
    /// arriver : deux attentes qui se suivent peuvent ainsi n'en dessiner
    /// qu'une seule, continue.
    private func pause(_ seconds: Double, de debut: Double = 1, a fin: Double = 0) async {
        skipped = false
        waitPart = debut
        let depart = Date()
        while !skipped {
            let passe = min(1, Date().timeIntervalSince(depart) / seconds)
            waitPart = debut + (fin - debut) * passe
            if passe >= 1 { break }
            try? await Task.sleep(for: .milliseconds(50))
            if Task.isCancelled { return }
        }
        skipped = false
        waitPart = fin
    }

    /// Le temps de lire l'énoncé et ses quatre propositions.
    private func readingTime(_ q: AskedQuestion) -> Double {
        let signes = q.prompt.count + q.choices.reduce(0) { $0 + $1.count }
        return min(Tempo.lectureMax,
                   max(Tempo.lectureMin, Double(signes) / Tempo.signesParSeconde))
    }

    // MARK: - Le fil des machines

    private func resume() {
        pump?.cancel()
        pump = Task { @MainActor [weak self] in await self?.loop() }
    }

    private func loop() async {
        while !game.isOver {
            // 1. Une question attend une réponse.
            if let a = game.assault, let duel = a.current {
                report = nil
                // En réseau, personne ne « réfléchit » ici : ou bien c'est à
                // moi de répondre, ou bien j'attends le coup d'en face.
                if enReseau {
                    if aMoiDeRepondre {
                        stage = .handover
                    } else {
                        stage = game.rules.mode == .faceAFace ? .adversaireRepond : .asking
                    }
                    thinking = !aMoiDeRepondre
                    return
                }
                guard let qui = game.quiRepond, let repondeur = player(qui) else { return }
                guard case let .machine(niveau, style) = repondeur.kind else {
                    stage = .handover        // à un humain de dire « prêt »
                    return
                }
                // Face à face : la machine qui défend décide d'abord si elle
                // double la mise, avant de répondre — après, ce ne serait plus
                // un pari.
                if game.peutRelancer, qui == a.defender,
                   Bot.relance(game, duel: duel, level: niveau,
                               style: style, joueur: qui) {
                    game.relancer()
                }
                // La première des deux réponses ne révèle rien : pas de
                // verdict à lire, juste le temps de la voir réfléchir.
                // En face à face, la question ne reparaît jamais pendant
                // qu'un autre y répond : celui qui regarde l'a déjà lue, et
                // souvent déjà tranchée.
                let croise = game.rules.mode == .faceAFace
                let muette = croise && a.defenderAnswer == nil
                stage = croise ? .adversaireRepond : .asking
                thinking = true
                // Lecture puis verdict ne font qu'un seul moment, et donc une
                // seule descente de la barre : on lit la question et l'on y
                // répond dans sa tête, puis on voit ce qu'elle a donné.
                let lecture = croise ? Tempo.reflexion : readingTime(duel.question)
                let charniere = muette ? 0 : tempsDeVerdict / (lecture + tempsDeVerdict)
                await pause(lecture, de: 1, a: charniere)
                if Task.isCancelled { return }
                thinking = false
                let rapport = game.answer(Bot.answer(to: duel, level: niveau,
                                                     rules: game.rules, joueur: qui,
                                                     using: &game.rng))
                guard let rapport else { stage = nil; continue }
                report = rapport
                stage = .revealed
                await pause(tempsDeVerdict, de: charniere, a: 0)
                if Task.isCancelled { return }
                report = nil
                stage = nil
                continue
            }

            // 2. Un assaut terminé. La machine range seule ; l'humain veut voir.
            if let a = game.assault, a.isOver {
                if game.currentPlayer.isBot {
                    // Un assaut que l'on subit mérite son bilan lui aussi.
                    // Sans lui, la place tombait et la machine enchaînait :
                    // on n'avait pas le temps de voir ce qu'on venait de
                    // perdre. Il passe seul, pour ne pas hacher son tour.
                    let jySuisPour = enReseau
                        ? a.defender == monRang
                        : !(player(a.defender)?.isBot ?? true)
                    if jySuisPour {
                        report = nil
                        stage = .summary
                        await pause(Tempo.bilan)
                        if Task.isCancelled { return }
                        stage = nil
                    }
                    if case .attack = game.phase { game.dismissAssault() }
                } else {
                    stage = .summary
                    return
                }
            }

            // 3. Sinon : à la machine de jouer, ou à l'humain de décider.
            guard game.currentPlayer.isBot else { stage = nil; return }
            let avant = game.phase
            let pas = BotRunner.step(&game)
            if pas == .idle, avant == game.phase, case .fortify = game.phase {
                game.endTurn()
            }
            // La machine vient de déclarer : on reste sur la carte le temps de
            // voir d'où part l'assaut et où il tombe.
            if case .declared = pas {
                stage = .announcing
                await pause(Tempo.annonce)
                if Task.isCancelled { return }
                stage = nil
                continue
            }
            try? await Task.sleep(for: .milliseconds(pas == .idle ? 120 : 380))
            if Task.isCancelled { return }
        }
        stage = nil
        thinking = false
    }
}
