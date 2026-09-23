//
//  DesTests.swift
//  RiskeloTests
//
//  Le mode « dés » : le jeu de plateau tel quel, sans question.
//
//  Il a deux propriétés qu'aucun autre mode n'a, et ce sont les deux qu'il
//  faut clouer. La première : l'assaut se tranche entièrement au moment où on
//  le déclare — il n'attend rien, et rien ne peut donc l'attendre. La
//  seconde : les faces sortent du hasard de la partie, et non de celui de
//  l'appareil, sans quoi deux téléphones en réseau ne verraient pas tomber
//  les mêmes hommes.
//
//  Le reste — les renforts, les continents, les cartes, les conquêtes — ne
//  sait même pas que le mode existe, et c'est ce qu'on vérifie en finissant
//  une partie entière.
//

import Foundation
import Testing
@testable import Riskelo

struct DesTests {

    private func regles() -> Rules {
        var r = Rules(); r.mode = .des; return r
    }

    private func partie(_ n: Int = 2, seed: UInt64 = 42) -> GameState {
        GameState.start(players: (0 ..< n).map { Player(id: $0, name: "J\($0)") },
                        rules: regles(), seed: seed)
    }

    // MARK: - La comparaison

    @Test func leDeLePlusFortLEmporte() {
        #expect(Combat.resolveDes(attacker: 6, defender: 1).outcome == .attackerBreaks)
        #expect(Combat.resolveDes(attacker: 1, defender: 6).outcome == .defenderHolds)
    }

    /// L'égalité profite au défenseur — c'est la règle du Risk, et c'est ce
    /// seul caractère qui tient tout l'équilibre du mode. Inversée, l'assaut
    /// l'emporterait 21 fois sur 36 au lieu de 15, et plus aucune place ne
    /// tiendrait.
    @Test func lEgaliteProfiteAuDefenseur() {
        for face in 1 ... 6 {
            #expect(Combat.resolveDes(attacker: face, defender: face).outcome == .defenderHolds)
        }
    }

    /// Aux dés, personne ne sait rien : le champ qui dit « le défenseur a
    /// répondu juste » n'a plus de sens et ne doit rien prétendre.
    @Test func leCompteRenduNePorteNiQuestionNiReponse() {
        let r = Combat.resolveDes(attacker: 5, defender: 2)
        #expect(r.question == nil)
        #expect(r.answer == nil)
        #expect(!r.correct)
        #expect(r.verdict == .des)
        #expect(r.dice == DiceEquivalence(attacker: 5, defender: 2))
    }

    /// Quinze cas sur trente-six. C'est la part exacte du Risk à un dé contre
    /// un, et c'est elle qui fait que les trois modes se jouent à la même
    /// longueur : la question à quinze secondes en donne 48 %, le face à face
    /// 44 %.
    @Test func lAssaillantLEmporteQuinzeFoisSurTrenteSix() {
        var passe = 0
        for a in 1 ... 6 {
            for d in 1 ... 6 where Combat.resolveDes(attacker: a, defender: d).outcome
                                    == .attackerBreaks {
                passe += 1
            }
        }
        #expect(passe == 15)
    }

    // MARK: - L'assaut

    /// Tout est joué à la déclaration : aucune question n'attend, et l'assaut
    /// est déjà fini quand la fonction rend la main.
    @Test func lAssautSeTrancheALaDeclaration() {
        var g = partie()
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 8, targetArmies: 8) else {
            Issue.record("pas de front"); return
        }
        // Hors du `#expect` : le coup est mutant, et la macro capture l'état
        // sans droit d'y toucher.
        let declare = g.declareAssault(from: base, to: cible, questions: 2, category: .histoire)
        #expect(declare)
        let a = g.assault!
        #expect(a.current == nil, "aucune question ne reste en suspens")
        #expect(a.isOver, "la salve est consommée")
        #expect(a.reports.count == 2)
        #expect(a.reports.allSatisfy { $0.verdict == .des })
        #expect(g.quiRepond == nil, "personne n'a à répondre")
        #expect(!g.peutRelancer, "il n'y a rien sur quoi relancer")
    }

    /// Le terrain annoncé est ignoré, et non pas seulement inutile : la
    /// machine le choisit encore dans son plan, et le garder lui ferait croire
    /// qu'elle a déjà usé ce thème contre ce joueur.
    @Test func leTerrainAnnonceEstOublie() {
        var g = partie()
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 6, targetArmies: 6) else {
            Issue.record("pas de front"); return
        }
        let defenseur = g.owner[cible]!
        g.declareAssault(from: base, to: cible, questions: 1, category: .sciences)
        #expect(g.assault?.category == nil)
        #expect(g.lastCategoryAgainst[defenseur] == nil)
    }

    /// Un homme par échange, dans un sens ou dans l'autre, jamais les deux.
    @Test func chaqueDeCouteUnHommeAUnSeulCamp() {
        var g = partie(2, seed: 7)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 9, targetArmies: 9) else {
            Issue.record("pas de front"); return
        }
        g.declareAssault(from: base, to: cible, questions: 2, category: nil)
        let a = g.assault!
        #expect(a.attackerLosses + a.defenderLosses == a.reports.count)
        #expect(g.armies(base) == 9 - a.attackerLosses)
        #expect(g.armies(cible) == 9 - a.defenderLosses)
    }

    /// La salve s'arrête quand la place tombe : on ne jette pas le second dé
    /// sur un territoire déjà pris.
    @Test func laSalveSArreteQuandLaPlaceTombe() {
        // Une place à un homme : le premier dé gagnant la prend, et le second
        // ne doit pas être jeté. On essaie plusieurs graines pour tomber sur
        // un premier dé gagnant.
        var vu = false
        for graine in UInt64(1) ... 40 {
            var g = partie(2, seed: graine)
            g.debugSkipToAttack()
            guard let (base, cible) = g.debugFirstAssault(minArmies: 6, targetArmies: 1) else {
                continue
            }
            g.declareAssault(from: base, to: cible, questions: 2, category: nil)
            guard let a = g.assault, a.conquered, a.reports.count == 1 else { continue }
            vu = true
            #expect(a.asked == 1)
            break
        }
        #expect(vu, "aucune graine n'a donné de prise au premier dé")
    }

    /// On n'attaque jamais avec sa garnison : une base à deux hommes n'a qu'un
    /// dé à jeter, quoi qu'elle en annonce.
    @Test func laGarnisonNeMonteJamaisALAssaut() {
        var g = partie(2, seed: 11)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 2, targetArmies: 9) else {
            Issue.record("pas de front"); return
        }
        #expect(g.maxQuestions(from: base) == 1)
        g.declareAssault(from: base, to: cible, questions: 1, category: nil)
        #expect(g.armies(base) >= 1, "la garnison reste")
    }

    // MARK: - Le réseau

    /// Les deux appareils rejouent la même suite depuis la même graine : rien
    /// ne voyage sur le fil qu'une déclaration d'assaut, et les faces tombent
    /// pourtant les mêmes des deux côtés. C'est la seule condition pour que
    /// les dés existent en réseau, et elle tient au fait que `Combat.de` tire
    /// du hasard de la partie et non de celui de l'appareil.
    @Test func lesDeuxAppareilsTirentLesMemesFaces() {
        func salve(_ graine: UInt64) -> [DiceEquivalence] {
            var g = partie(2, seed: graine)
            g.debugSkipToAttack()
            guard let (base, cible) = g.debugFirstAssault(minArmies: 9, targetArmies: 9)
            else { return [] }
            g.declareAssault(from: base, to: cible, questions: 2, category: nil)
            return g.assault?.reports.map(\.dice) ?? []
        }
        let ici = salve(2026)
        let laBas = salve(2026)
        #expect(ici.count == 2)
        #expect(ici == laBas)
        #expect(salve(2027) != ici, "une autre graine donne d'autres faces")
    }

    /// Une partie reprise là où on l'a laissée jette les mêmes dés que si on
    /// ne l'avait jamais quittée : le tirage est dans l'état, pas à côté.
    @Test func unePartieRepriseJetteLesMemesDes() throws {
        var g = partie(2, seed: 99)
        g.debugSkipToAttack()
        let data = try JSONEncoder().encode(g)
        var reprise = try JSONDecoder().decode(GameState.self, from: data)

        guard let (base, cible) = g.debugFirstAssault(minArmies: 9, targetArmies: 9) else {
            Issue.record("pas de front"); return
        }
        _ = reprise.debugFirstAssault(minArmies: 9, targetArmies: 9)
        g.declareAssault(from: base, to: cible, questions: 2, category: nil)
        reprise.declareAssault(from: base, to: cible, questions: 2, category: nil)
        #expect(g.assault?.reports.map(\.dice) == reprise.assault?.reports.map(\.dice))
    }

    // MARK: - Le reste du jeu

    /// Une partie entière se finit aux dés. C'est le test qui dit que le mode
    /// n'est pas un écran de plus mais une règle du jeu : les renforts, les
    /// continents, les cartes et l'occupation traversent la partie sans savoir
    /// qu'on ne leur pose plus de questions.
    @Test func unePartieEntiereSeJoueAuxDes() {
        var r = regles()
        r.territoryCards = true
        var g = GameState.start(
            players: (0 ..< 3).map { Player(id: $0, name: "J\($0)",
                                            kind: .machine(niveau: 0.7, style: .moyenne)) },
            rules: r, seed: 5)
        var garde = 0
        var des = 0
        while !g.isOver && garde < 200_000 {
            garde += 1
            let avant = g.assault?.reports.count ?? 0
            let pas = BotRunner.step(&g)
            des += max(0, (g.assault?.reports.count ?? 0) - avant)
            if pas == .idle, case .fortify = g.phase { g.endTurn() }
        }
        #expect(g.isOver, "la partie doit se finir")
        #expect(des > 40, "elle doit avoir jeté des dés, et pas deux")
    }

    /// Aucune question n'est tirée de la banque. Sans quoi le mode dépendrait
    /// des thèmes achetés, et une partie aux dés pourrait être refusée faute
    /// de questions dans la langue choisie.
    @Test func aucuneQuestionNEstTiree() {
        var g = partie(2, seed: 13)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 9, targetArmies: 9) else {
            Issue.record("pas de front"); return
        }
        let avant = g.bank.vuesAJour
        g.declareAssault(from: base, to: cible, questions: 2, category: nil)
        #expect(g.bank.vuesAJour == avant, "la banque n'a pas bougé")
        #expect(g.assault?.reports.allSatisfy { $0.question == nil } == true)
    }
}
