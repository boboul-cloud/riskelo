//
//  BotRunner.swift
//  Riskelo
//
//  Le tour de la machine, joué un geste à la fois.
//
//  Un geste par appel, et non tout le tour d'un bloc : l'interface a besoin
//  de respirer entre deux coups pour qu'on voie ce qui se passe, et la
//  simulation, elle, n'a qu'à boucler. Le même code sert aux deux — c'est la
//  seule façon d'être sûr que ce qu'on simule est ce qu'on joue.
//

import Foundation

enum BotRunner {

    enum Step: Equatable {
        case exchanged(Int)
        case placed(TerritoryID)
        case declared(from: TerritoryID, to: TerritoryID)
        case answered(correct: Bool)
        /// Face à face : la première des deux réponses. Elle ne tranche rien,
        /// elle attend l'autre.
        case pending
        case occupied(Int)
        case fortified
        case endedTurn
        /// Un humain doit répondre : la machine s'arrête et rend la main.
        case waitingForHuman
        /// Plus rien à faire (partie finie, ou ce n'est pas son tour).
        case idle
    }

    @discardableResult
    static func step(_ g: inout GameState, boldness: Double = 1.0) -> Step {
        guard !g.isOver else { return .idle }

        // Un duel en cours prime sur tout : quelqu'un doit répondre.
        if let a = g.assault, let duel = a.current {
            // En face à face, ce n'est plus forcément le défenseur : les deux
            // répondent, chacun son tour, et le moteur dit lequel.
            guard let qui = g.quiRepond,
                  let repondeur = g.players.first(where: { $0.id == qui }) else { return .idle }
            guard case let .machine(niveau, style) = repondeur.kind else { return .waitingForHuman }
            if g.peutRelancer, qui == a.defender,
               Bot.relance(g, duel: duel, level: niveau, style: style, joueur: qui) {
                g.relancer()
            }
            let answer = Bot.answer(to: duel, level: niveau, rules: g.rules,
                                     joueur: qui, using: &g.rng)
            guard let report = g.answer(answer) else { return .pending }
            return .answered(correct: report.correct)
        }
        if let a = g.assault, a.isOver, case .attack = g.phase {
            g.dismissAssault()
        }

        guard g.currentPlayer.isBot else { return .idle }

        switch g.phase {
        case .reinforcement(let remaining):
            // Une combinaison en main part tout de suite : le barème monte
            // avec les échanges de la partie, garder ses cartes ne les fait
            // pas prendre de la valeur — cela laisse seulement la valeur monter
            // pour l'adversaire.
            if g.rules.territoryCards,
               let trio = Deck.premiereCombinaison(dans: g.hand(of: g.currentPlayer.id)) {
                let valeur = g.prochainEchange
                if g.exchange(trio.map(\.id)) { return .exchanged(valeur) }
            }
            guard remaining > 0 else { g.advance(); return .idle }
            guard let id = Bot.reinforcement(g) else { g.advance(); return .idle }
            g.place(on: id)
            return .placed(id)

        case .attack:
            // Le tirage est sorti de la partie, puis rendu aussitôt : on ne
            // peut pas passer `g` par valeur et `&g.rng` dans le même appel.
            // Il doit être rendu AVANT `declareAssault`, qui s'en sert à son
            // tour pour tirer la question — le confier à un `defer` écraserait
            // l'avancement que celui-ci vient de faire, et les tirages
            // suivants se répéteraient.
            var rng = g.rng
            // À défaut d'un assaut avantageux, un assaut à forces égales —
            // sans quoi deux prudents ne se rencontrent jamais.
            let choix = Bot.assault(g, boldness: boldness, using: &rng)
                ?? Bot.assault(g, boldness: boldness + 1, using: &rng)
            g.rng = rng
            guard let plan = choix else {
                g.advance()
                return .idle
            }
            guard g.declareAssault(from: plan.from, to: plan.to,
                                   questions: plan.questions, category: plan.category) else {
                g.advance()
                return .idle
            }
            return .declared(from: plan.from, to: plan.to)

        case .occupation:
            let n = Bot.occupation(g)
            g.occupy(n)
            return .occupied(n)

        case .fortify:
            if let move = Bot.fortification(g),
               g.fortify(from: move.from, to: move.to, count: move.count) {
                return .fortified
            }
            g.endTurn()
            return .endedTurn

        case .finished:
            return .idle
        }
    }

    /// Déroule le tour complet de la machine. Rend la main dès qu'un humain
    /// doit répondre, ou quand le tour est passé.
    @discardableResult
    static func runTurn(_ g: inout GameState, boldness: Double = 1.0, limit: Int = 4000) -> Step {
        let startedTurn = g.turn
        let startedPlayer = g.current
        for _ in 0 ..< limit {
            let step = step(&g, boldness: boldness)
            if step == .waitingForHuman { return step }
            if g.isOver { return .idle }
            if g.turn != startedTurn || g.current != startedPlayer { return .endedTurn }
            if step == .idle && !g.currentPlayer.isBot { return .idle }
        }
        return .idle
    }
}
