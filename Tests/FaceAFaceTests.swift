//
//  FaceAFaceTests.swift
//  RiskeloTests
//
//  Le mode où les deux répondent.
//
//  Trois règles y sont empruntées au dé et une seule d'entre elles se voit à
//  l'écran ; les deux autres décident silencieusement de l'équilibre du jeu :
//  l'égalité stricte revient au défenseur, et deux ignorances valent une
//  égalité. Sans elles l'attaquant tomberait à 23 % des échanges et plus
//  personne ne prendrait de territoire. C'est exactement le genre de règle
//  qu'un test doit tenir, parce qu'une partie jouée à l'envers a l'air d'une
//  partie.
//

import Foundation
import Testing
@testable import Riskelo

struct FaceAFaceTests {

    private var croise: Rules {
        var r = Rules(); r.mode = .faceAFace; return r
    }

    private func duel(_ allowance: TimeInterval = 15) -> Duel {
        var rng = SeededRandom(seed: 1)
        return Duel(question: QuestionBank.francaises[0].asked(using: &rng),
                    allowance: allowance, siege: 0)
    }

    private func faux(_ d: Duel) -> Int { (0..<4).first { $0 != d.question.answer }! }

    // MARK: - Les quatre issues

    @Test func celuiQuiSaitSeulEmporteLEchange() {
        let d = duel()
        let pris = Combat.resolveCroise(defender: .chosen(faux(d), elapsed: 3),
                                        attacker: .chosen(d.question.answer, elapsed: 9),
                                        of: d, mise: 1)
        #expect(pris.outcome == .attackerBreaks)
        #expect(pris.verdict == .seul)
        // La lenteur ne rattrape pas l'ignorance : un ignorant rapide ne bat
        // pas un savant lent.
        let tient = Combat.resolveCroise(defender: .chosen(d.question.answer, elapsed: 14),
                                         attacker: .chosen(faux(d), elapsed: 1),
                                         of: d, mise: 1)
        #expect(tient.outcome == .defenderHolds)
        #expect(tient.verdict == .seul)
    }

    @Test func quandLesDeuxSaventLeSablierTranche() {
        let d = duel()
        let vif = Combat.resolveCroise(defender: .chosen(d.question.answer, elapsed: 9),
                                       attacker: .chosen(d.question.answer, elapsed: 3),
                                       of: d, mise: 1)
        #expect(vif.outcome == .attackerBreaks)
        #expect(vif.verdict == .vitesse)
    }

    /// L'égalité du Risk : il faut être plus vif, pas aussi vif.
    @Test func lEgaliteStricteResteAuDefenseur() {
        let d = duel()
        let r = Combat.resolveCroise(defender: .chosen(d.question.answer, elapsed: 5),
                                     attacker: .chosen(d.question.answer, elapsed: 5),
                                     of: d, mise: 1)
        #expect(r.outcome == .defenderHolds)
    }

    /// Deux ignorances valent une égalité de dés : la place tient.
    @Test func personneNeSaitLaPlaceTient() {
        let d = duel()
        let r = Combat.resolveCroise(defender: .timeout, attacker: .chosen(faux(d), elapsed: 2),
                                     of: d, mise: 1)
        #expect(r.outcome == .defenderHolds)
        #expect(r.verdict == .egalite)
        #expect(!r.correct && !r.attackerCorrect)
    }

    // MARK: - L'enchaînement des deux réponses

    /// La première réponse ne fait rien couler, et surtout ne montre rien :
    /// la révéler donnerait la solution à celui qui doit encore répondre.
    @Test func laPremiereReponseNeTrancheRien() {
        var g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                rules: croise, seed: 42)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 8, targetArmies: 4) else {
            Issue.record("pas d'assaut possible"); return
        }
        let declare = g.declareAssault(from: base, to: cible, questions: 1, category: .histoire)
        #expect(declare)
        #expect(g.quiRepond == g.assault?.defender)

        let avantBase = g.armies(base), avantCible = g.armies(cible)
        let rien = g.answer(.chosen(0, elapsed: 3))
        #expect(rien == nil, "la réponse du défenseur ne rend aucun compte rendu")
        #expect(g.armies(base) == avantBase && g.armies(cible) == avantCible)
        #expect(g.assault?.current != nil, "la question reste posée pour l'attaquant")
        #expect(g.quiRepond == g.assault?.attacker)

        let rapport = g.answer(.chosen(0, elapsed: 3))
        #expect(rapport != nil, "la seconde réponse tranche")
        #expect(g.armies(base) + g.armies(cible) == avantBase + avantCible - 1)
    }

    /// En classique, rien de tout cela : une réponse, un compte rendu.
    @Test func leClassiqueTrancheDuPremierCoup() {
        var g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                seed: 42)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 8, targetArmies: 4) else {
            Issue.record("pas d'assaut possible"); return
        }
        let declare = g.declareAssault(from: base, to: cible, questions: 1, category: .histoire)
        #expect(declare)
        #expect(!g.peutRelancer, "on ne relance pas en classique")
        let tranche = g.answer(.chosen(0, elapsed: 3))
        #expect(tranche != nil)
    }

    // MARK: - La relance

    @Test func laRelanceDoubleCeQueLEchangeCoute() {
        var g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                rules: croise, seed: 42)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 9, targetArmies: 5) else {
            Issue.record("pas d'assaut possible"); return
        }
        let declare = g.declareAssault(from: base, to: cible, questions: 1, category: .histoire)
        #expect(declare)
        #expect(g.peutRelancer)
        g.relancer()
        #expect(g.assault?.mise == 2)
        #expect(!g.peutRelancer, "on ne relance qu'une fois, et avant de répondre")

        let bonne = g.assault!.current!.question.answer
        let mauvaise = (0..<4).first { $0 != bonne }!
        let avantCible = g.armies(cible)
        _ = g.answer(.chosen(mauvaise, elapsed: 3))   // le défenseur ignore
        _ = g.answer(.chosen(bonne, elapsed: 3))      // l'attaquant sait
        #expect(g.armies(cible) == avantCible - 2, "l'enjeu doublé coûte deux hommes")
    }

    /// Une mise de deux ne rapporte que ce que la pile d'en face peut payer :
    /// on ne prend jamais à l'assaillant sa dernière garnison.
    @Test func laRelanceNeVideJamaisLaGarnison() {
        var g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                rules: croise, seed: 42)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 2, targetArmies: 6) else {
            Issue.record("pas d'assaut possible"); return
        }
        let declare = g.declareAssault(from: base, to: cible, questions: 1, category: .histoire)
        #expect(declare)
        g.relancer()
        let bonne = g.assault!.current!.question.answer
        let mauvaise = (0..<4).first { $0 != bonne }!
        _ = g.answer(.chosen(bonne, elapsed: 3))      // le défenseur sait
        _ = g.answer(.chosen(mauvaise, elapsed: 3))   // l'attaquant non
        #expect(g.armies(base) == 1, "l'assaillant garde toujours un homme")
    }

    // MARK: - Ce que la machine y gagne

    /// Les deux répondent : la culture de l'attaquant compte enfin, et son
    /// renfort d'érudition avec elle.
    @Test func laCultureDeLAttaquantEstComptee() {
        var g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                rules: croise, seed: 42)
        g.debugSkipToAttack()
        let moi = g.currentPlayer.id
        guard let (base, cible) = g.debugFirstAssault(minArmies: 8, targetArmies: 4) else {
            Issue.record("pas d'assaut possible"); return
        }
        #expect(g.record(of: moi, in: .histoire).asked == 0)
        let declare = g.declareAssault(from: base, to: cible, questions: 1, category: .histoire)
        #expect(declare)
        let bonne = g.assault!.current!.question.answer
        _ = g.answer(.chosen(bonne, elapsed: 3))
        _ = g.answer(.chosen(bonne, elapsed: 8))
        #expect(g.record(of: moi, in: .histoire).asked == 1,
                "l'attaquant a répondu : cela doit compter pour lui")
        #expect(g.record(of: moi, in: .histoire).correct == 1)
    }

    /// La règle qui change de signe d'un mode à l'autre : la forte garde sa
    /// dernière paire en classique, et s'en sert en face à face. Mesuré — la
    /// retenir lui coûte quatorze points contre la moyenne.
    @Test func laDernierePaireSertEnFaceAFace() {
        for mode in Rules.Mode.allCases {
            var r = Rules(); r.mode = mode
            var g = GameState.start(
                players: [Player(id: 0, name: "A", kind: .machine(niveau: 0.7, style: .forte)),
                          Player(id: 1, name: "B")],
                rules: r, seed: 42)
            g.debugSkipToAttack()
            let moi = g.currentPlayer.id
            // Tout le monde à un homme, sauf une seule base à deux : la forte
            // n'a que sa dernière paire pour attaquer.
            for id in g.map.order { g.seize(id, by: g.owner[id] ?? moi, armies: 1) }
            guard let base = g.territories(of: moi).first(where: { !g.targets(from: $0).isEmpty })
            else { Issue.record("pas de front"); return }
            g.seize(base, by: moi, armies: 2)
            // Audace 2 : c'est le second essai de `BotRunner`, celui qui
            // accepte un assaut à forces égales. À audace 1, une pile de deux
            // ne passe la barre d'aucune façon et le test ne dirait rien.
            var rng = SeededRandom(seed: 3)
            let plan = Bot.assault(g, boldness: 2, using: &rng)
            if mode == .classique {
                #expect(plan == nil, "en classique elle tient sa dernière paire")
            } else {
                #expect(plan?.from == base, "en face à face elle s'en sert")
            }
        }
    }
}
