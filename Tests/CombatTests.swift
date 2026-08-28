//
//  CombatTests.swift
//  RiskeloTests
//
//  La variante tient en une phrase — « une bonne réponse vaut un dé
//  supérieur » — et c'est cette phrase-là qu'il faut clouer. Le sens de la
//  perte s'inverse d'un caractère : si l'attaquant perdait un homme sur une
//  mauvaise réponse, le jeu tournerait quand même, à l'envers, et personne ne
//  saurait dire pourquoi il ne prend jamais rien.
//

import Foundation
import Testing
@testable import Riskelo

struct CombatTests {

    private func duel(_ allowance: TimeInterval = 15, siege: Int = 0) -> Duel {
        var rng = SeededRandom(seed: 1)
        let posee = QuestionBank.francaises[0].asked(using: &rng)
        return Duel(question: posee, allowance: allowance, siege: siege)
    }

    @Test func laBonneReponseRepousseLAssaut() {
        let d = duel()
        let r = Combat.resolve(.chosen(d.question.answer, elapsed: 4), of: d)
        #expect(r.correct)
        #expect(r.outcome == .defenderHolds)
    }

    @Test func laMauvaiseReponseOuvreLaPlace() {
        let d = duel()
        let faux = (0..<4).first { $0 != d.question.answer }!
        let r = Combat.resolve(.chosen(faux, elapsed: 4), of: d)
        #expect(!r.correct)
        #expect(r.outcome == .attackerBreaks)
    }

    @Test func leSilenceVautUneMauvaiseReponse() {
        let r = Combat.resolve(.timeout, of: duel())
        #expect(r.outcome == .attackerBreaks)
        #expect(r.dice.defender == 1)
    }

    /// Le temps fait partie de la question : juste mais en retard ne compte pas.
    @Test func laReponseJusteMaisTardiveNeComptePas() {
        let d = duel(15)
        let r = Combat.resolve(.chosen(d.question.answer, elapsed: 15.4), of: d)
        #expect(!r.correct)
        #expect(r.outcome == .attackerBreaks)
    }

    @Test func lEquivalenceEnDesSuitLaRegle() {
        let d = duel(15)
        let vite = Combat.resolve(.chosen(d.question.answer, elapsed: 2), of: d)
        let tard = Combat.resolve(.chosen(d.question.answer, elapsed: 13), of: d)
        let faux = Combat.resolve(.chosen((d.question.answer + 1) % 4, elapsed: 2), of: d)
        #expect(vite.dice.defender > vite.dice.attacker)
        #expect(tard.dice.defender > tard.dice.attacker)   // juste, donc supérieur
        #expect(vite.dice.defender > tard.dice.defender)   // mais vite vaut mieux
        #expect(faux.dice.defender < faux.dice.attacker)
    }

    /// Le jugement, éprouvé sur toute la banque : chaque question, plusieurs
    /// mélanges, et les quatre propositions l'une après l'autre. Une seule
    /// inversion — un `==` devenu `!=`, un index décalé par un mélange —
    /// retournerait le jeu sans rien casser, et personne ne saurait dire
    /// pourquoi il perd en répondant juste.
    @Test func aucuneReponseNEstJugeeALEnvers() {
        var rng = SeededRandom(seed: 77)
        for question in QuestionBank.francaises {
            for _ in 0 ..< 6 {
                let posee = question.asked(using: &rng)
                #expect(posee.choices[posee.answer] == question.correct,
                        "\(question.id) : le mélange a perdu la bonne réponse")
                let d = Duel(question: posee, allowance: 15, siege: 0)
                for i in posee.choices.indices {
                    let juste = posee.choices[i] == question.correct
                    let r = Combat.resolve(.chosen(i, elapsed: 3), of: d)
                    #expect(r.correct == juste, "\(question.id) : « \(posee.choices[i]) »")
                    #expect(r.outcome == (juste ? .defenderHolds : .attackerBreaks))
                    #expect(juste ? r.dice.defender > r.dice.attacker
                                  : r.dice.defender < r.dice.attacker)
                }
            }
        }
    }

    /// La machine répond toujours. Un temps écoulé ne marque aucune
    /// proposition à l'écran : on ne voyait que la bonne réponse en vert
    /// pendant que le verdict annonçait un silence, et l'on croyait
    /// l'application en train de juger une bonne réponse mauvaise.
    @Test func laMachineNeLaissePasPasserLeTemps() {
        var rng = SeededRandom(seed: 21)
        var bank = QuestionBank()
        let regles = Rules()
        for niveau in [0.20, 0.45, 0.70, 0.95] {
            for _ in 0 ..< 300 {
                let posee = bank.draw(category: nil, difficulty: nil, using: &rng)!
                let d = Duel(question: posee, allowance: regles.answerTime(siege: 4), siege: 4)
                let reponse = Bot.answer(to: d, level: niveau, rules: regles, using: &rng)
                #expect(reponse != .timeout, "la machine s'est tue (niveau \(niveau))")
            }
        }
    }

    /// L'usure du siège : c'est elle qui remplace l'avantage statistique de
    /// l'attaquant au Risk. Sans elle, un joueur qui sait ne perd jamais rien.
    @Test func leSablierSeResserreAChaqueQuestion() {
        let r = Rules()
        let temps = (0..<6).map { r.answerTime(siege: $0) }
        for (avant, apres) in zip(temps, temps.dropFirst()) {
            #expect(apres <= avant)
        }
        #expect(temps[0] == r.baseSeconds)
        #expect(temps.last == r.minSeconds)
        #expect(temps[1] < temps[0])
    }
}
