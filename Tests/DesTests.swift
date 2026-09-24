//
//  DesTests.swift
//  RiskeloTests
//
//  Le mode « dés » : le jeu de plateau tel quel, sans question.
//
//  Il a deux propriétés qu'aucun autre mode n'a, et ce sont les deux qu'il
//  faut clouer. La première : l'assaut se tranche d'un seul jet — à la
//  déclaration quand la machine défend, au choix du défenseur quand c'est un
//  humain, et rien d'autre ne l'attend. La seconde : les faces sortent du
//  hasard de la partie, et non de celui de l'appareil, sans quoi deux
//  téléphones en réseau ne verraient pas tomber les mêmes hommes.
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

    /// Les premiers joueurs sont des humains, les autres des machines.
    ///
    /// Un seul humain par défaut, qui ouvre la partie : il attaque donc une
    /// machine, qui lance tout ce qu'elle peut sans rien choisir, et l'assaut
    /// se tranche à la déclaration. Le choix du défenseur humain a ses
    /// propres essais, plus bas.
    private func partie(_ n: Int = 2, seed: UInt64 = 42, humains: Int = 1) -> GameState {
        GameState.start(players: (0 ..< n).map { i in
                            Player(id: i, name: "J\(i)",
                                   kind: i < humains ? .humain
                                                     : .machine(niveau: 0.7, style: .moyenne))
                        },
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

    /// Contre la machine, tout est joué à la déclaration, et en un seul jet :
    /// aucune question n'attend, et l'assaut est déjà fini quand la fonction
    /// rend la main.
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

    /// La machine oppose deux dés dès qu'elle a deux hommes, et un seul si
    /// elle n'en a qu'un. Elle ne choisit pas : contre trois dés, le second
    /// lui fait perdre plus d'hommes mais en coûte davantage à l'assaillant.
    @Test func laMachineEnOpposeDeuxDesQuElleLePeut() {
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

    // MARK: - Le choix du défenseur

    /// Un humain qui défend choisit ses dés : l'assaut déclaré attend son
    /// coup, et rien n'est jeté d'ici là — ni hommes perdus, ni faces tirées.
    @Test func lHumainQuiDefendChoisitSesDes() {
        // Deux humains : le premier attaque le second.
        var g = partie(2, seed: 5, humains: 2)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 6, targetArmies: 4) else {
            Issue.record("pas de front"); return
        }
        var avant = g.rng
        let declare = g.declareAssault(from: base, to: cible, questions: 3, category: nil)
        #expect(declare)
        #expect(g.attendLaDefense)
        #expect(g.assault?.reports.isEmpty == true, "rien n'est jeté avant le choix")
        #expect(g.assault?.isOver == false)
        #expect(g.armies(base) == 6)
        #expect(g.armies(cible) == 4)
        var apres = g.rng
        let tirages = (apres.next(), avant.next())
        #expect(tirages.0 == tirages.1, "aucun dé n'est tiré d'avance")
        #expect(g.quiRepond == nil, "il n'y a toujours pas de question")
        // L'assaut en suspens ne se range pas, et on ne passe pas au
        // déplacement par-dessus.
        g.dismissAssault()
        g.advance()
        #expect(g.assault != nil)
        #expect(g.phase == .attack)
    }

    /// Un dé ou deux, et le lancer suit le choix.
    @Test func leLancerSuitLeChoix() {
        for des in [1, 2] {
            var g = partie(2, seed: 5, humains: 2)
            g.debugSkipToAttack()
            guard let (base, cible) = g.debugFirstAssault(minArmies: 6, targetArmies: 4)
            else { Issue.record("pas de front"); return }
            g.declareAssault(from: base, to: cible, questions: 3, category: nil)
            let defend = g.defendre(avec: des)
            #expect(defend)
            #expect(!g.attendLaDefense)
            guard let a = g.assault, let r = a.reports.first, let l = r.lancer else {
                Issue.record("aucun lancer"); return
            }
            #expect(l.attaque.count == 3)
            #expect(l.defense.count == des)
            #expect(a.isOver, "un jet épuise la salve")
            #expect(g.armies(base) == 6 - r.coutAttaquant)
            #expect(g.armies(cible) == 4 - r.coutDefenseur)
            #expect(r.coutDefenseur <= des, "on ne perd pas plus d'hommes que de dés")
        }
    }

    /// Contre la machine aussi : l'humain qui défend choisit, quand bien
    /// même il est seul à la table.
    @Test func contreLaMachineLHumainChoisitAussi() {
        // La machine ouvre, et l'humain défend.
        var g = GameState.start(
            players: [Player(id: 0, name: "M", kind: .machine(niveau: 0.7, style: .moyenne)),
                      Player(id: 1, name: "H")],
            rules: regles(), seed: 8)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 6, targetArmies: 4) else {
            Issue.record("pas de front"); return
        }
        g.declareAssault(from: base, to: cible, questions: 3, category: nil)
        #expect(g.attendLaDefense)
    }

    /// La machine attend le choix de l'humain au lieu de passer outre. Sans
    /// ce garde, elle tentait un nouvel assaut par-dessus celui en suspens.
    @Test func laMachineAttendLeChoixDuDefenseur() {
        var g = GameState.start(
            players: [Player(id: 0, name: "M", kind: .machine(niveau: 0.7, style: .moyenne)),
                      Player(id: 1, name: "H")],
            rules: regles(), seed: 8)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 6, targetArmies: 4) else {
            Issue.record("pas de front"); return
        }
        g.declareAssault(from: base, to: cible, questions: 3, category: nil)
        let empreinte = g.digest
        let premier = BotRunner.step(&g)
        let second = BotRunner.step(&g)
        #expect(premier == .waitingForHuman)
        #expect(second == .waitingForHuman)
        #expect(g.digest == empreinte, "rien n'a bougé")
        g.defendre(avec: 1)
        let ensuite = BotRunner.step(&g)
        #expect(ensuite != .waitingForHuman, "le choix fait, la machine reprend")
    }

    /// Un homme seul n'a qu'un dé : il n'y a rien à lui demander, et l'assaut
    /// se tranche à la déclaration, comme contre la machine.
    @Test func unHommeSeulNaRienAChoisir() {
        var g = partie(2, seed: 5, humains: 2)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 6, targetArmies: 1) else {
            Issue.record("pas de front"); return
        }
        g.declareAssault(from: base, to: cible, questions: 3, category: nil)
        #expect(!g.attendLaDefense)
        #expect(g.assault?.reports.first?.lancer?.defense.count == 1)
    }

    /// Ni zéro, ni trois dés, ni de choix hors de propos.
    @Test func unChoixHorsDeLaRegleEstRefuse() {
        var g = partie(2, seed: 5, humains: 2)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 6, targetArmies: 4) else {
            Issue.record("pas de front"); return
        }
        // Hors du `#expect` : le coup est mutant.
        let sansAssaut = g.defendre(avec: 2)
        #expect(!sansAssaut, "aucun assaut n'attend")
        g.declareAssault(from: base, to: cible, questions: 2, category: nil)
        let zero = g.defendre(avec: 0)
        let trois = g.defendre(avec: 3)
        #expect(!zero)
        #expect(!trois)
        #expect(g.attendLaDefense, "un refus ne jette rien")
        let deux = g.defendre(avec: 2)
        #expect(deux)
        let encore = g.defendre(avec: 1)
        #expect(!encore, "on ne choisit pas deux fois")
    }

    /// Le choix est un coup comme un autre : il passe le fil, il vient du
    /// défenseur, et deux appareils qui le reçoivent tirent les mêmes faces.
    @Test func leChoixVoyageSurLeFil() {
        var g = partie(2, seed: 21, humains: 2)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 9, targetArmies: 9) else {
            Issue.record("pas de front"); return
        }
        g.apply(.declareAssault(from: base, to: cible, questions: 3, category: nil))
        let coup = Action.defendre(1)
        #expect(coup.author(in: g) == g.owner[cible])

        guard let data = Message.coup(coup, numero: 4, empreinte: 1).data,
              case let .message(.coup(recu, _, _)) = Message.lire(data) else {
            Issue.record("le choix ne passe pas le fil"); return
        }
        #expect(recu == coup)

        var ici = g, laBas = g
        ici.apply(coup)
        laBas.apply(recu)
        #expect(ici.digest == laBas.digest)
        #expect(ici.digest != g.digest, "le lancer change la partie")
        #expect(ici.assault?.reports.first?.lancer == laBas.assault?.reports.first?.lancer)
    }

    /// Une partie enregistrée pendant que le défenseur hésite se rouvre sur
    /// la même hésitation, et jette ensuite les mêmes dés.
    @Test func unePartieRepriseAttendEncoreLeChoix() throws {
        var g = partie(2, seed: 34, humains: 2)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 9, targetArmies: 9) else {
            Issue.record("pas de front"); return
        }
        g.declareAssault(from: base, to: cible, questions: 3, category: nil)
        var reprise = try JSONDecoder().decode(GameState.self,
                                               from: JSONEncoder().encode(g))
        #expect(reprise.attendLaDefense)
        g.defendre(avec: 2)
        reprise.defendre(avec: 2)
        #expect(g.assault?.reports.first?.lancer == reprise.assault?.reports.first?.lancer)
        #expect(g.digest == reprise.digest)
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
