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

    /// L'égalité profite au défenseur — c'est la règle du jeu de plateau, et
    /// c'est ce seul caractère qui tient tout l'équilibre du mode. Inversée,
    /// l'assaut l'emporterait 21 fois sur 36 au lieu de 15, et plus aucune
    /// place ne tiendrait.
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
    }

    /// Quinze cas sur trente-six, à un dé contre un : la part exacte du jeu de
    /// plateau.
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

    // MARK: - Le lancer

    /// Les deux mains se comparent triées, la plus forte contre la plus forte.
    /// C'est là toute la règle, et c'est elle qui rend le troisième dé utile :
    /// il ne s'oppose à personne, il écarte seulement les faibles.
    @Test func lesMainsSeComparentTrieesEtParPaires() {
        let l = Lancer(attaque: [6, 3, 1], defense: [5, 4])
        #expect(l.paires == 2)
        #expect(l.issues == [.attackerBreaks, .defenderHolds])
        #expect(l.perteDefenseur == 1)
        #expect(l.perteAttaquant == 1)
    }

    /// Un même jet peut coûter un homme à chacun. C'est la seule chose qu'aucun
    /// des deux autres modes ne sait faire — une question n'a qu'un perdant —
    /// et tout le moteur doit la supporter, du compte des pertes au journal.
    @Test func unLancerPeutCouterUnHommeAChacun() {
        let r = Combat.resolveDes(Lancer(attaque: [6, 1], defense: [5, 3]))
        #expect(r.coutAttaquant == 1)
        #expect(r.coutDefenseur == 1)
        // La place n'est pas tombée : elle tient, même en payant.
        #expect(r.outcome == .defenderHolds)
    }

    /// Deux comparaisons perdues, deux hommes : le plafond d'un jet.
    @Test func unJetNeCouteJamaisPlusDeDeuxHommes() {
        let net = Combat.resolveDes(Lancer(attaque: [6, 5, 4], defense: [3, 2]))
        #expect(net.coutDefenseur == 2)
        #expect(net.coutAttaquant == 0)
    }

    /// À trois dés contre deux, l'assaut devient rentable : il perd moins
    /// d'hommes qu'il n'en prend. C'est l'inverse du duel à un contre un, et
    /// c'est ce qui fait qu'une partie aux dés se termine.
    @Test func troisDesContreDeuxFontPencherLAssaut() {
        var pris = 0, perdus = 0
        for a1 in 1 ... 6 { for a2 in 1 ... 6 { for a3 in 1 ... 6 {
            for d1 in 1 ... 6 { for d2 in 1 ... 6 {
                let l = Lancer(attaque: [a1, a2, a3].sorted(by: >),
                               defense: [d1, d2].sorted(by: >))
                pris += l.perteDefenseur
                perdus += l.perteAttaquant
            }}
        }}}
        #expect(pris > perdus, "l'assaut doit prendre plus qu'il ne laisse")
        // 1,079 contre 0,921 par jet : les proportions connues du jeu de plateau.
        let part = Double(pris) / Double(pris + perdus)
        #expect(part > 0.53 && part < 0.55, "part obtenue : \(part)")
    }

    // MARK: - L'assaut

    /// Tout est joué à la déclaration, et en un seul jet : aucune question
    /// n'attend, et l'assaut est déjà fini quand la fonction rend la main.
    @Test func lAssautSeTrancheEnUnLancer() {
        var g = partie()
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 8, targetArmies: 8) else {
            Issue.record("pas de front"); return
        }
        // Hors du `#expect` : le coup est mutant, et la macro capture l'état
        // sans droit d'y toucher.
        let declare = g.declareAssault(from: base, to: cible, questions: 3, category: .histoire)
        #expect(declare)
        let a = g.assault!
        #expect(a.current == nil, "aucune question ne reste en suspens")
        #expect(a.isOver, "un jet épuise la salve")
        #expect(a.reports.count == 1, "un assaut, un lancer")
        #expect(a.reports[0].lancer?.attaque.count == 3)
        #expect(g.quiRepond == nil, "personne n'a à répondre")
        #expect(!g.peutRelancer, "il n'y a rien sur quoi relancer")
    }

    /// Trois dés demandent quatre hommes : on n'attaque jamais avec sa
    /// garnison, et il en faut un de trop par dé annoncé.
    @Test func troisDesDemandentQuatreHommes() {
        var g = partie()
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 4, targetArmies: 5) else {
            Issue.record("pas de front"); return
        }
        #expect(g.volleyMax(from: base) == 3)
        g.seize(base, by: g.currentPlayer.id, armies: 3)
        #expect(g.volleyMax(from: base) == 2)
        g.seize(base, by: g.currentPlayer.id, armies: 2)
        #expect(g.volleyMax(from: base) == 1)
        #expect(!g.canDeclare(from: base, to: cible, questions: 2))
    }

    /// Le défenseur oppose deux dés dès qu'il a deux hommes, et un seul s'il
    /// n'en a qu'un. Il ne le choisit pas : au jeu de plateau le second dé est
    /// toujours à son avantage.
    @Test func leDefenseurEnOpposeDeuxDesQuIlLePeut() {
        for (garnison, attendu) in [(1, 1), (2, 2), (9, 2)] {
            var g = partie(2, seed: 3)
            g.debugSkipToAttack()
            guard let (base, cible) = g.debugFirstAssault(minArmies: 6, targetArmies: garnison)
            else { Issue.record("pas de front"); return }
            g.declareAssault(from: base, to: cible, questions: 3, category: nil)
            #expect(g.assault?.reports.first?.lancer?.defense.count == attendu,
                    "garnison \(garnison)")
        }
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

    /// Ce que le jet coûte tombe bien sur les deux piles, et rien ne s'invente
    /// en chemin.
    @Test func lesPertesTombentSurLesDeuxPiles() {
        var vuPartage = false
        for graine in UInt64(1) ... 60 {
            var g = partie(2, seed: graine)
            g.debugSkipToAttack()
            guard let (base, cible) = g.debugFirstAssault(minArmies: 9, targetArmies: 9)
            else { continue }
            g.declareAssault(from: base, to: cible, questions: 3, category: nil)
            guard let a = g.assault, let r = a.reports.first else { continue }
            #expect(g.armies(base) == 9 - r.coutAttaquant)
            #expect(g.armies(cible) == 9 - r.coutDefenseur)
            #expect(a.attackerLosses == r.coutAttaquant)
            #expect(a.defenderLosses == r.coutDefenseur)
            if r.coutAttaquant > 0 && r.coutDefenseur > 0 { vuPartage = true }
        }
        #expect(vuPartage, "aucune graine n'a donné de jet partagé un partout")
    }

    /// On n'attaque jamais avec sa garnison : une base à deux hommes n'a qu'un
    /// dé à jeter, et le garde toujours debout.
    @Test func laGarnisonNeMonteJamaisALAssaut() {
        var g = partie(2, seed: 11)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 2, targetArmies: 9) else {
            Issue.record("pas de front"); return
        }
        #expect(g.volleyMax(from: base) == 1)
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
        func lance(_ graine: UInt64) -> Lancer? {
            var g = partie(2, seed: graine)
            g.debugSkipToAttack()
            guard let (base, cible) = g.debugFirstAssault(minArmies: 9, targetArmies: 9)
            else { return nil }
            g.declareAssault(from: base, to: cible, questions: 3, category: nil)
            return g.assault?.reports.first?.lancer
        }
        let ici = lance(2026)
        let laBas = lance(2026)
        #expect(ici?.attaque.count == 3)
        #expect(ici?.defense.count == 2)
        #expect(ici == laBas)
        #expect(lance(2027) != ici, "une autre graine donne d'autres faces")
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
        g.declareAssault(from: base, to: cible, questions: 3, category: nil)
        reprise.declareAssault(from: base, to: cible, questions: 3, category: nil)
        #expect(g.assault?.reports.first?.lancer == reprise.assault?.reports.first?.lancer)
    }

    // MARK: - Le reste du jeu

    /// Des parties entières se finissent aux dés. C'est le test qui dit que le
    /// mode n'est pas un écran de plus mais une règle du jeu : les renforts,
    /// les continents, les cartes et l'occupation traversent la partie sans
    /// savoir qu'on ne leur pose plus de questions.
    ///
    /// Plusieurs graines, parce qu'une seule ne dit rien : une partie peut se
    /// terminer en dix-neuf jets comme en cent, selon la façon dont les trois
    /// machines se rencontrent.
    @Test func desPartiesEntieresSeJouentAuxDes() {
        var jets = 0
        for graine in UInt64(1) ... 6 {
            var r = regles()
            r.territoryCards = true
            var g = GameState.start(
                players: (0 ..< 3).map { Player(id: $0, name: "J\($0)",
                                                kind: .machine(niveau: 0.7, style: .moyenne)) },
                rules: r, seed: graine)
            var garde = 0
            while !g.isOver && garde < 200_000 {
                garde += 1
                let avant = g.assault?.reports.count ?? 0
                let pas = BotRunner.step(&g)
                jets += max(0, (g.assault?.reports.count ?? 0) - avant)
                if pas == .idle, case .fortify = g.phase { g.endTurn() }
            }
            #expect(g.isOver, "la partie \(graine) doit se finir")
        }
        // Une soixantaine de jets par partie en moyenne — moins qu'en
        // questions, où il en faut plus de cent, parce qu'un jet prend jusqu'à
        // deux hommes là où une question n'en prend qu'un.
        #expect(jets > 120, "seulement \(jets) jets sur six parties")
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
