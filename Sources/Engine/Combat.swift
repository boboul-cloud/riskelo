//
//  Combat.swift
//  Riskelo
//
//  Le duel : une question à la place d'une paire de dés.
//
//  La règle tient en deux lignes. L'attaquant choisit une catégorie et pose
//  une ou deux questions — ses dés. Le défenseur répond.
//
//      bonne réponse  → le dé du défenseur est supérieur → l'attaquant perd un soldat
//      mauvaise, ou temps écoulé → le dé de l'attaquant l'emporte → le défenseur perd un soldat
//
//  Une paire de dés, une perte : c'est exactement la comparaison du Risk, et
//  le pari est le même — deux questions, c'est deux pertes possibles de son
//  propre côté.
//
//  L'égalité, au Risk, profite au défenseur. Elle n'a pas d'équivalent en
//  classique : une question n'a pas de match nul. Le principe est sauf — le
//  doute reste du côté de celui qui tient la place.
//
//  En **face à face**, elle en retrouve un. Les deux joueurs répondent à la
//  même question, et il n'y a plus une réponse mais deux à comparer :
//
//      un seul sait            → il emporte l'échange
//      les deux savent         → le plus vif l'emporte, l'égalité au défenseur
//      aucun des deux ne sait  → la place tient, l'assaillant laisse un homme
//
//  C'est là, et là seulement, que la vitesse décide quelque chose. Elle ne
//  départage jamais deux réponses inégales — un ignorant rapide ne bat pas un
//  savant lent — elle ne sert qu'à trancher ce que le Risk tranchait par le
//  chiffre du dé.
//

import Foundation

/// Ce que le défenseur a fait de la question.
enum Answer: Equatable, Codable {
    case chosen(Int, elapsed: TimeInterval)
    case timeout
}

enum DuelOutcome: Equatable {
    /// Bonne réponse : la place tient, l'assaillant laisse un homme.
    case defenderHolds
    /// Mauvaise réponse ou silence : la ligne cède.
    case attackerBreaks
}

/// La question en cours, avec le temps qui lui est accordé.
struct Duel: Equatable, Codable {
    let question: AskedQuestion
    let allowance: TimeInterval
    /// Combien de questions ce territoire a déjà subies dans le tour.
    let siege: Int
}

/// L'équivalence en dés. Elle ne décide de rien — elle montre la règle.
/// La bonne réponse passe au-dessus de l'assaut, d'autant plus haut qu'elle
/// est venue vite ; la mauvaise passe en dessous.
///
/// En classique elle est à moitié muette : l'attaquant ne répondant pas, son
/// dé est un 3 de convention. En face à face les deux faces sont vraies.
struct DiceEquivalence: Equatable {
    var attacker: Int
    var defender: Int

    /// Ce que vaut une réponse, sur six faces.
    static func face(_ answer: Answer?, allowance: TimeInterval, correct: Bool) -> Int {
        guard correct, case let .chosen(_, elapsed)? = answer else {
            return answer == .timeout ? 1 : 2
        }
        let part = allowance > 0 ? elapsed / allowance : 1
        return part < 0.34 ? 6 : (part < 0.67 ? 5 : 4)
    }

    static func from(_ answer: Answer, allowance: TimeInterval, correct: Bool) -> DiceEquivalence {
        DiceEquivalence(attacker: 3,
                        defender: face(answer, allowance: allowance, correct: correct))
    }
}

/// Comment l'échange s'est décidé. C'est ce que la feuille raconte au joueur,
/// et c'est la seule chose qui change vraiment d'un mode à l'autre.
enum DuelVerdict: String, Equatable, Codable {
    /// Classique : le défenseur seul répondait.
    case reponse
    /// Face à face : un seul des deux a su.
    case seul
    /// Face à face : les deux ont su, le sablier a tranché.
    case vitesse
    /// Face à face : aucun des deux n'a su. La place tient — l'égalité du Risk.
    case egalite
}

/// Le compte rendu d'un duel, tel que la vue le raconte.
struct DuelReport: Equatable, Identifiable {
    let id = UUID()
    let question: AskedQuestion
    /// Celle du défenseur : c'est lui qui répond dans les deux modes.
    let answer: Answer
    let correct: Bool
    /// En face à face, ce qu'a répondu l'attaquant.
    var attackerAnswer: Answer?
    var attackerCorrect = false
    let outcome: DuelOutcome
    var verdict: DuelVerdict = .reponse
    /// Ce que l'échange coûte au perdant : un homme, deux si le défenseur
    /// avait relancé.
    var mise = 1
    let dice: DiceEquivalence
    let allowance: TimeInterval

    static func == (a: DuelReport, b: DuelReport) -> Bool { a.id == b.id }
}

/// Un assaut : une déclaration, puis une ou deux questions.
struct Assault: Equatable, Codable {
    let attacker: PlayerID
    let defender: PlayerID
    let from: TerritoryID
    let to: TerritoryID
    /// La catégorie, choisie par l'attaquant. C'est là qu'est son adresse :
    /// il ne répond à rien, mais il choisit le terrain.
    let category: Category
    /// Le nombre de questions annoncées : un ou deux dés.
    let volley: Int

    /// Face à face : la réponse du défenseur attend celle de l'attaquant.
    /// La montrer plus tôt donnerait la solution à qui doit encore répondre —
    /// c'est la seule raison pour laquelle elle dort ici.
    var defenderAnswer: Answer?

    /// La mise du défenseur. Un homme, ou deux s'il a relancé : c'est son
    /// second dé, celui que le Risk lui donne et que le mode classique lui
    /// refusait.
    var mise = 1

    var asked = 0
    var attackerLosses = 0
    var defenderLosses = 0
    var conquered = false
    var current: Duel?
    var reports: [DuelReport] = []

    /// L'assaut est terminé quand la place est prise ou la salve épuisée.
    var isOver: Bool { conquered || (current == nil && asked >= volley) }

    static func == (a: Assault, b: Assault) -> Bool {
        a.from == b.from && a.to == b.to && a.asked == b.asked
            && a.conquered == b.conquered && a.current == b.current
    }

    /// Les comptes rendus ne sont pas enregistrés : ils ne servent qu'au
    /// bilan d'un assaut en cours, et une partie reprise repart de la
    /// question posée, pas de son résumé.
    private enum CodingKeys: String, CodingKey {
        case attacker, defender, from, to, category, volley
        case asked, attackerLosses, defenderLosses, conquered, current
        case defenderAnswer, mise
    }
}

enum Combat {

    /// Une réponse est-elle juste ? Le temps fait partie de la question :
    /// arrivée après le sablier, elle ne compte pas, même exacte.
    static func juste(_ answer: Answer, of duel: Duel) -> Bool {
        switch answer {
        case .timeout: false
        case let .chosen(index, elapsed):
            duel.question.isCorrect(index) && elapsed <= duel.allowance
        }
    }

    /// Le temps mis, plafonné au sablier. C'est lui qui départage deux
    /// bonnes réponses, et rien d'autre.
    static func delai(_ answer: Answer, of duel: Duel) -> TimeInterval {
        guard case let .chosen(_, elapsed) = answer else { return duel.allowance }
        return min(elapsed, duel.allowance)
    }

    /// Classique : le seul endroit où se décide l'issue d'une question.
    static func resolve(_ answer: Answer, of duel: Duel) -> DuelReport {
        let correct = juste(answer, of: duel)
        return DuelReport(question: duel.question,
                          answer: answer,
                          correct: correct,
                          outcome: correct ? .defenderHolds : .attackerBreaks,
                          dice: .from(answer, allowance: duel.allowance, correct: correct),
                          allowance: duel.allowance)
    }

    /// Face à face : les deux ont répondu à la même question.
    static func resolveCroise(defender: Answer, attacker: Answer,
                              of duel: Duel, mise: Int) -> DuelReport {
        let d = juste(defender, of: duel)
        let a = juste(attacker, of: duel)

        let outcome: DuelOutcome
        let verdict: DuelVerdict
        switch (d, a) {
        case (true, false):
            outcome = .defenderHolds
            verdict = .seul
        case (false, true):
            outcome = .attackerBreaks
            verdict = .seul
        case (true, true):
            // Les deux savent. Le sablier tranche, et l'égalité stricte reste
            // au défenseur : il faut être plus vif, pas aussi vif.
            outcome = delai(attacker, of: duel) < delai(defender, of: duel)
                ? .attackerBreaks : .defenderHolds
            verdict = .vitesse
        case (false, false):
            // Personne ne savait. Au Risk, l'égalité coûte un homme à
            // l'assaillant : la place tient.
            outcome = .defenderHolds
            verdict = .egalite
        }

        return DuelReport(question: duel.question,
                          answer: defender,
                          correct: d,
                          attackerAnswer: attacker,
                          attackerCorrect: a,
                          outcome: outcome,
                          verdict: verdict,
                          mise: mise,
                          dice: DiceEquivalence(
                            attacker: DiceEquivalence.face(attacker,
                                                           allowance: duel.allowance, correct: a),
                            defender: DiceEquivalence.face(defender,
                                                           allowance: duel.allowance, correct: d)),
                          allowance: duel.allowance)
    }
}
