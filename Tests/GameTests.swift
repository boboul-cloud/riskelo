//
//  GameTests.swift
//  RiskeloTests
//
//  L'enchaînement d'un tour, et les coups qu'il faut refuser.
//
//  Un jeu de plateau se triche par accident : attaquer avec sa garnison,
//  déplacer des hommes vers un territoire qu'on ne tient pas, poser trois
//  questions au lieu de deux. Rien de tout cela ne fait planter quoi que ce
//  soit — c'est pourquoi c'est ici et non à l'écran que ça se refuse.
//

import Foundation
import Testing
@testable import Riskelo

struct GameTests {

    private func partie(_ n: Int = 2, seed: UInt64 = 42, rules: Rules = Rules()) -> GameState {
        GameState.start(players: (0..<n).map { Player(id: $0, name: "J\($0)") },
                        rules: rules, seed: seed)
    }

    // MARK: - Mise en place

    @Test func toutLeMondeEstServi() {
        let g = partie()
        #expect(g.map.order.allSatisfy { g.owner[$0] != nil })
        #expect(g.map.order.allSatisfy { g.armies($0) >= 1 })
        let compte = (0..<2).map { g.territories(of: $0).count }
        #expect(compte.reduce(0, +) == g.map.order.count)
        #expect(abs(compte[0] - compte[1]) <= 1)
    }

    /// Ouvrir, dans un jeu où la défense l'emporte, vaut cinq hommes à deux
    /// joueurs. La simulation l'a mesuré ; le partage doit rester en place.
    @Test func leSecondJoueurEstCompense() {
        let g = partie()
        let armees = (0..<2).map { j in g.territories(of: j).reduce(0) { $0 + g.armies($1) } }
        #expect(armees[1] - armees[0] == Rules().compensation(playerCount: 2))
    }

    @Test func laPartieCommenceParLesRenforts() {
        let g = partie()
        guard case let .reinforcement(reste) = g.phase else { Issue.record("mauvaise phase"); return }
        #expect(reste == g.reinforcements(for: 0))
        #expect(reste >= 3)
    }

    // MARK: - Renforts

    @Test func leBonusDeContinentSAjoute() {
        var g = partie()
        let ponant = g.map.continentsInOrder.first { $0.name == "Ponant" }!
        let sans = g.reinforcements(for: 0)
        for id in ponant.territories { g.seize(id, by: 0, armies: 1) }
        #expect(g.reinforcements(for: 0) >= sans + ponant.bonus - 2)
        #expect(g.continentsHeld(by: 0).contains { $0.id == ponant.id })
    }

    @Test func onNePosePasDeRenfortChezLAdversaire() {
        var g = partie()
        let chezLautre = g.territories(of: 1)[0]
        #expect(g.place(on: chezLautre) == false)
    }

    @Test func lesRenfortsEpuisesOuvrentLaPhaseDAttaque() {
        var g = partie()
        guard case let .reinforcement(reste) = g.phase else { return }
        let chezMoi = g.territories(of: 0)[0]
        for _ in 0..<reste { g.place(on: chezMoi) }
        #expect(g.phase == .attack)
    }

    // MARK: - Assaut

    @Test func onNAttaquePasAvecSaGarnison() {
        var g = partie()
        g.debugSkipToAttack()
        let mien = g.territories(of: 0).first { g.armies($0) == 1 && !g.targets(from: $0).isEmpty }
        if let mien {
            #expect(g.maxQuestions(from: mien) == 0)
            let cible = g.targets(from: mien)[0]
            #expect(g.declareAssault(from: mien, to: cible, questions: 1, category: .histoire) == false)
        }
    }

    @Test func onNePosePasPlusDeDeuxQuestions() {
        var g = partie()
        g.debugSkipToAttack()
        let base = g.territories(of: 0).first { g.armies($0) >= 4 && !g.targets(from: $0).isEmpty }
        guard let base else { return }
        #expect(g.maxQuestions(from: base) == 2)
        #expect(g.declareAssault(from: base, to: g.targets(from: base)[0],
                                 questions: 3, category: .histoire) == false)
    }

    @Test func onNAttaquePasUnVoisinQuOnNeTouchePas() {
        var g = partie()
        g.debugSkipToAttack()
        let base = g.territories(of: 0).first { g.armies($0) >= 2 }!
        let loin = g.map.order.first { !g.map.areAdjacent(base, $0) && g.owner[$0] != 0 }!
        #expect(g.declareAssault(from: base, to: loin, questions: 1, category: .arts) == false)
    }

    @Test func laBonneReponseCouteUnHommeALAttaquant() {
        var g = partie()
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 3, targetArmies: 2) else { return }
        let avantAttaquant = g.armies(base), avantDefenseur = g.armies(cible)
        g.declareAssault(from: base, to: cible, questions: 1, category: .histoire)
        let bonne = g.assault!.current!.question.answer
        g.answer(.chosen(bonne, elapsed: 2))
        #expect(g.armies(base) == avantAttaquant - 1)
        #expect(g.armies(cible) == avantDefenseur)
    }

    @Test func laMauvaiseReponseCouteUnHommeAuDefenseur() {
        var g = partie()
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 3, targetArmies: 2) else { return }
        let avantAttaquant = g.armies(base), avantDefenseur = g.armies(cible)
        g.declareAssault(from: base, to: cible, questions: 1, category: .histoire)
        let mauvaise = (g.assault!.current!.question.answer + 1) % 4
        g.answer(.chosen(mauvaise, elapsed: 2))
        #expect(g.armies(base) == avantAttaquant)
        #expect(g.armies(cible) == avantDefenseur - 1)
    }

    @Test func deuxQuestionsFontDeuxDuels() {
        var g = partie()
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 4, targetArmies: 3) else { return }
        g.declareAssault(from: base, to: cible, questions: 2, category: .sciences)
        #expect(g.assault?.current != nil)
        g.answer(.chosen(g.assault!.current!.question.answer, elapsed: 2))
        #expect(g.assault?.current != nil, "la seconde question doit venir")
        g.answer(.chosen(g.assault!.current!.question.answer, elapsed: 2))
        #expect(g.assault?.current == nil)
        #expect(g.assault?.isOver == true)
        #expect(g.assault?.attackerLosses == 2)
    }

    /// Le sablier ne se remet pas à zéro entre deux assauts du même tour :
    /// c'est l'usure du siège.
    @Test func leSiegeSeSouvientDansLeTour() {
        var g = partie()
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 4, targetArmies: 3) else { return }
        g.declareAssault(from: base, to: cible, questions: 2, category: .sciences)
        let premier = g.assault!.current!.allowance
        g.answer(.chosen(g.assault!.current!.question.answer, elapsed: 1))
        let second = g.assault!.current!.allowance
        #expect(second < premier)
        #expect(g.assault!.current!.siege == 1)
    }

    @Test func laPlacePriseChangeDeMain() {
        var g = partie()
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 5, targetArmies: 1) else { return }
        g.declareAssault(from: base, to: cible, questions: 1, category: .arts)
        let mauvaise = (g.assault!.current!.question.answer + 1) % 4
        g.answer(.chosen(mauvaise, elapsed: 1))
        #expect(g.owner[cible] == 0)
        guard case let .occupation(_, _, minimum, maximum) = g.phase else {
            Issue.record("la conquête doit demander combien d'hommes avancent"); return
        }
        #expect(minimum >= 1 && maximum >= minimum)
        let avant = g.armies(base)
        g.occupy(maximum)
        #expect(g.armies(cible) == maximum)
        #expect(g.armies(base) == avant - maximum)
        #expect(g.phase == .attack)
    }

    // MARK: - Déplacement, tour, victoire

    @Test func leDeplacementSuitUneChaineAmie() {
        var g = partie()
        g.debugSkipToFortify()
        let mien = g.territories(of: 0)
        let ennemi = g.territories(of: 1)[0]
        #expect(g.areLinked(mien[0], mien[0], for: 0))
        #expect(g.fortify(from: mien[0], to: ennemi, count: 1) == false)
    }

    @Test func leTourPasseAuSuivant() {
        var g = partie()
        g.debugSkipToFortify()
        g.endTurn()
        #expect(g.currentPlayer.id == 1)
        if case .reinforcement = g.phase {} else { Issue.record("le tour doit ouvrir sur les renforts") }
    }

    @Test func laDominationSuffitAGagner() {
        var g = partie()
        #expect(g.dominationThreshold == 21)
        #expect(!g.dominates(0))
        for id in g.map.order.prefix(g.dominationThreshold) { g.seize(id, by: 0, armies: 1) }
        #expect(g.dominates(0))
    }

    /// Une faiblesse doit en être une : marquée d'une lunette à côté d'un
    /// score affiché en vert, elle donnait à croire que l'application se
    /// trompait sur ce qui est bon et ce qui ne l'est pas.
    @Test func uneFaiblesseEnEstVraimentUne() {
        var g = partie()
        #expect(g.weakness(of: 1) == nil, "sans données, aucune faiblesse")
        g.seize(.histoire, of: 1, asked: 4, correct: 3)   // 75 %
        #expect(g.weakness(of: 1) == nil, "trois sur quatre n'est pas une faiblesse")
        g.seize(.sports, of: 1, asked: 4, correct: 1)     // 25 %
        #expect(g.weakness(of: 1) == .sports)
    }

    /// Le sens des pertes, dans le moteur complet. Il s'inverse d'un
    /// caractère, et le jeu tournerait quand même — à l'envers.
    @Test func leSensDesPertesNeSInversePas() {
        for juste in [true, false] {
            var g = partie()
            g.debugSkipToAttack()
            guard let (base, cible) = g.debugFirstAssault(minArmies: 8, targetArmies: 5) else { return }
            g.declareAssault(from: base, to: cible, questions: 1, category: .histoire)
            let bon = g.assault!.current!.question.answer
            let avantMoi = g.armies(base), avantLui = g.armies(cible)
            g.answer(.chosen(juste ? bon : (bon + 1) % 4, elapsed: 2))
            if juste {
                #expect(g.armies(base) == avantMoi - 1, "bonne réponse : l'assaillant paie")
                #expect(g.armies(cible) == avantLui)
            } else {
                #expect(g.armies(base) == avantMoi)
                #expect(g.armies(cible) == avantLui - 1, "mauvaise réponse : le défenseur paie")
            }
        }
    }

    /// Le moteur tient déjà la question suivante quand on lui donne une
    /// réponse : il compte la perte et enchaîne. L'écran, lui, en est encore
    /// à dévoiler la précédente — et il montrait donc la suivante, bonne
    /// réponse déjà marquée, avant que personne n'y ait répondu. Ce test fixe
    /// la règle : c'est le compte rendu qui porte la question jugée.
    @Test func leCompteRenduPorteLaQuestionQuIlJuge() {
        var g = partie()
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 6, targetArmies: 4) else { return }
        g.declareAssault(from: base, to: cible, questions: 2, category: .sciences)
        let posee = g.assault!.current!.question.id
        let rapport = g.answer(.chosen(g.assault!.current!.question.answer, elapsed: 2))
        #expect(rapport?.question.id == posee)
        #expect(g.assault?.current != nil)
        #expect(g.assault?.current?.question.id != posee, "le moteur tient déjà la suivante")
    }

    /// Viser à chaque fois la faiblesse exacte est le coup optimal et le plus
    /// mauvais de tous : dix fois le même sujet, la catégorie s'épuise, et
    /// chaque duel ressemble au précédent.
    @Test func laMachineNeMartelePasLeMemeSujet() {
        var g = GameState.start(players: [Player(id: 0, name: "A", kind: .machine(niveau: 0.7, style: .forte)),
                                          Player(id: 1, name: "B", kind: .machine(niveau: 0.7, style: .forte))],
                                seed: 4242)
        var sujets: [Riskelo.Category] = []   // Foundation en expose un autre
        var precedent: String?
        var garde = 0
        while !g.isOver && garde < 200_000 {
            garde += 1
            let pas = BotRunner.step(&g)
            if let q = g.assault?.current?.question, q.id != precedent {
                sujets.append(q.category)
                precedent = q.id
            }
            if pas == .idle, g.phase == .fortify { g.endTurn() }
        }
        #expect(sujets.count > 20, "la partie doit poser assez de questions pour juger")

        var serie = 1, serieMax = 1
        for (avant, apres) in zip(sujets, sujets.dropFirst()) {
            serie = (avant == apres) ? serie + 1 : 1
            serieMax = max(serieMax, serie)
        }
        #expect(serieMax <= 5, "\(serieMax) fois le même sujet d'affilée")
        #expect(Set(sujets).count >= 5, "la machine n'explore que \(Set(sujets).count) sujets")
    }

    // MARK: - Renfort d'érudition

    /// Un homme de plus toutes les N bonnes réponses dans un même thème — et
    /// jamais deux fois le même : le compte des bonnes réponses ne redescend
    /// pas, c'est ce qui a été versé qu'il faut retenir.
    @Test func lEruditionRapporteUnHommeEtNePaiePasDeuxFois() {
        var r = Rules(); r.answersPerBonusMan = 3
        var g = partie(2, rules: r)

        #expect(g.eruditionOwed(1) == 0)
        g.seize(.histoire, of: 1, asked: 3, correct: 2)
        #expect(g.eruditionOwed(1) == 0, "deux bonnes réponses ne suffisent pas")
        g.seize(.histoire, of: 1, asked: 4, correct: 3)
        #expect(g.eruditionOwed(1) == 1)
        g.seize(.sports, of: 1, asked: 7, correct: 6)      // deux de plus
        #expect(g.eruditionOwed(1) == 3)

        // Le tour passe : le dû est versé, et ne revient pas au tour suivant.
        let avant = g.reinforcements(for: 1)
        g.debugSkipToFortify()
        g.endTurn()
        guard case let .reinforcement(recus) = g.phase else { Issue.record("phase"); return }
        #expect(g.currentPlayer.id == 1)
        #expect(recus == avant, "le versement doit inclure les trois hommes")
        #expect(g.eruditionOwed(1) == 0)
        #expect(g.reinforcements(for: 1) == avant - 3, "il ne se paie pas deux fois")
    }

    /// La règle retirée ne doit rien coûter ni rien rapporter.
    @Test func lEruditionSeRetire() {
        var r = Rules(); r.answersPerBonusMan = nil
        var g = partie(2, rules: r)
        g.seize(.histoire, of: 1, asked: 20, correct: 20)
        #expect(g.eruditionOwed(1) == 0)
        #expect(g.eruditionEarned(1) == 0)
    }

    // MARK: - Jouer à deux appareils

    /// Tout le jeu en réseau tient sur ceci : la même suite de coups, jouée
    /// sur deux parties identiques, donne deux parties identiques. Si ce n'est
    /// pas vrai, les deux écrans montrent chacun une partie cohérente — et ce
    /// sont deux parties différentes, ce qui ne se voit pas.
    @Test func lesMemesCoupsDonnentLaMemePartie() throws {
        var ici = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                  seed: 909)
        var laBas = try JSONDecoder().decode(GameState.self,
                                             from: JSONEncoder().encode(ici))
        #expect(ici.digest == laBas.digest)

        var coups: [Action] = []
        if case let .reinforcement(n) = ici.phase {
            let mien = ici.territories(of: 0)[0]
            coups += Array(repeating: Action.place(mien), count: n)
        }
        guard let base = ici.territories(of: 0).first(where: { !ici.targets(from: $0).isEmpty }),
              let cible = ici.targets(from: base).first else { return }
        ici.seize(base, by: 0, armies: 9); laBas.seize(base, by: 0, armies: 9)
        ici.seize(cible, by: 1, armies: 4); laBas.seize(cible, by: 1, armies: 4)
        coups.append(.declareAssault(from: base, to: cible, questions: 2, category: .histoire))

        for coup in coups {
            ici.apply(coup)
            laBas.apply(coup)
            #expect(ici.digest == laBas.digest, "divergence sur \(coup)")
        }
        // Y compris les questions tirées : c'est le tirage au sort qui décide.
        #expect(ici.assault?.current?.question.id == laBas.assault?.current?.question.id)

        let bonne = ici.assault!.current!.question.answer
        ici.apply(.answer(.chosen(bonne, elapsed: 2)))
        laBas.apply(.answer(.chosen(bonne, elapsed: 2)))
        #expect(ici.digest == laBas.digest)
        #expect(ici.assault?.current?.question.id == laBas.assault?.current?.question.id)
    }

    /// À quatre appareils, la même suite de coups doit tenir sur quatre
    /// parties : c'est la condition pour qu'aucun écran ne montre autre chose
    /// que les autres.
    @Test func lesMemesCoupsTiennentAQuatre() throws {
        let joueurs = (0..<4).map { Player(id: $0, name: Boards.nomDeCamp($0)) }
        var parties = [GameState.start(board: .monde, players: joueurs, seed: 4242)]
        for _ in 0 ..< 3 {
            parties.append(try JSONDecoder().decode(GameState.self,
                                                    from: JSONEncoder().encode(parties[0])))
        }
        #expect(Set(parties.map(\.digest)).count == 1)

        // On rejoue une partie entière, coup par coup, sur les quatre.
        var meneuse = parties[0]
        var coups: [Action] = []
        var garde = 0
        while !meneuse.isOver && garde < 60_000 {
            garde += 1
            let avant = meneuse.phase
            // La machine décide, mais le coup se transmet comme un autre.
            let pas = BotRunner.step(&meneuse)
            if pas == .idle, avant == meneuse.phase, case .fortify = meneuse.phase {
                meneuse.endTurn()
            }
            if coups.count > 400 { break }
            if pas == .idle && avant == meneuse.phase { break }
        }
        // La partie menée sert de référence : on vérifie que le rejeu d'une
        // suite d'actions donne bien la même empreinte sur chaque copie.
        let suite: [Action] = [.place(meneuse.map.order[0])]
        for i in parties.indices {
            for coup in suite { parties[i].apply(coup) }
        }
        #expect(Set(parties.map(\.digest)).count == 1, "les quatre parties ont divergé")
    }

    /// Un coup doit survivre au voyage.
    @Test func unCoupSeTransmet() throws {
        let coups: [Action] = [
            .place("A0"),
            .declareAssault(from: "A0", to: "A1", questions: 2, category: .sciences),
            .answer(.chosen(2, elapsed: 3.5)), .answer(.timeout),
            .dismissAssault, .occupy(3),
            .fortify(from: "A0", to: "A1", count: 2), .advance, .endTurn,
        ]
        for (i, coup) in coups.enumerated() {
            // Par `data`, et non par un encodeur monté ici : c'est lui qui
            // pose l'enveloppe, et un test qui l'évite ne mesure pas ce qui
            // voyage vraiment.
            let data = try #require(Message.coup(coup, numero: i + 1, empreinte: 42).data)
            guard case let .message(.coup(relu, numero, empreinte)) = Message.lire(data) else {
                Issue.record("message illisible : \(coup)"); continue
            }
            #expect(relu == coup)
            #expect(numero == i + 1)
            #expect(empreinte == 42)
        }
    }

    /// L'empreinte doit être la même d'un lancement à l'autre — sans quoi deux
    /// appareils en bonne santé se croiraient divergents.
    @Test func lEmpreinteNeDependPasDuLancement() throws {
        let g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                seed: 77)
        let relu = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(g))
        #expect(g.digest == relu.digest)
        var bouge = g
        bouge.seize(g.map.order[0], by: 1, armies: 9)
        #expect(bouge.digest != g.digest, "l'empreinte doit voir un changement")
    }

    // MARK: - Cartes de territoire

    @Test func uneCombinaisonSeReconnait() {
        let inf = Card(id: 0, territory: "A0", symbol: .infanterie)
        let inf2 = Card(id: 1, territory: "A1", symbol: .infanterie)
        let inf3 = Card(id: 2, territory: "A2", symbol: .infanterie)
        let cav = Card(id: 3, territory: "A3", symbol: .cavalerie)
        let art = Card(id: 4, territory: "A4", symbol: .artillerie)
        let joker = Card(id: 5, territory: nil, symbol: .infanterie)

        #expect(Deck.estUneCombinaison([inf, inf2, inf3]))       // trois pareils
        #expect(Deck.estUneCombinaison([inf, cav, art]))          // trois différents
        #expect(!Deck.estUneCombinaison([inf, inf2, cav]))        // deux et un
        #expect(Deck.estUneCombinaison([inf, inf2, joker]))       // le joker complète
        #expect(Deck.estUneCombinaison([inf, cav, joker]))
        #expect(!Deck.estUneCombinaison([inf, inf2]))             // il en faut trois
        #expect(!Deck.estUneCombinaison([inf, inf, inf]))         // pas deux fois la même
    }

    /// Le barème monte : c'est lui qui empêche une partie de s'enliser.
    @Test func leBaremeMonteEtNeRedescendPas() {
        let valeurs = (1...12).map { Deck.valeur(echangeNumero: $0) }
        #expect(valeurs.prefix(6) == [4, 6, 8, 10, 12, 15])
        for (avant, apres) in zip(valeurs, valeurs.dropFirst()) {
            #expect(apres > avant)
        }
        #expect(Deck.valeur(echangeNumero: 7) == 20)
    }

    /// Une carte se gagne en prenant une place, et pas autrement.
    @Test func laCarteSeGagneParLaConquete() {
        var r = Rules(); r.territoryCards = true
        var g = partie(2, rules: r)
        #expect(g.deck.count == g.map.order.count + 2, "une carte par territoire, plus deux jokers")
        #expect(g.hand(of: 0).isEmpty)

        g.debugSkipToFortify()
        g.endTurn()
        #expect(g.hand(of: 0).isEmpty, "un tour sans conquête ne rapporte rien")

        var h = partie(2, rules: r)
        h.debugSkipToAttack()
        guard let (base, cible) = h.debugFirstAssault(minArmies: 6, targetArmies: 1) else { return }
        h.declareAssault(from: base, to: cible, questions: 1, category: .histoire)
        let mauvaise = (h.assault!.current!.question.answer + 1) % 4
        h.answer(.chosen(mauvaise, elapsed: 1))
        h.occupy(1)
        h.advance()
        h.endTurn()
        #expect(h.hand(of: 0).count == 1, "une place prise vaut une carte")
    }

    /// L'échange verse les hommes dans les renforts en cours, une seule fois.
    @Test func lEchangeVerseLesHommesEtRetireLesCartes() {
        var r = Rules(); r.territoryCards = true
        var g = partie(2, rules: r)
        g.seizeHand(of: 0, [Card(id: 900, territory: nil, symbol: .infanterie),
                            Card(id: 901, territory: nil, symbol: .cavalerie),
                            Card(id: 902, territory: "A0", symbol: .artillerie)])
        guard case let .reinforcement(avant) = g.phase else { Issue.record("phase"); return }
        let valeur = g.prochainEchange
        // Un appel mutant ne peut pas vivre dans `#expect` : la macro le
        // capture dans une fermeture, où la partie est immuable.
        let echange = g.exchange([900, 901, 902])
        #expect(echange)
        guard case let .reinforcement(apres) = g.phase else { Issue.record("phase"); return }
        #expect(apres >= avant + valeur)
        #expect(g.hand(of: 0).isEmpty)
        #expect(g.exchanges == 1)
        let deuxieme = g.exchange([900, 901, 902])
        #expect(!deuxieme, "les cartes ne sont plus là")
    }

    /// Retirée, la règle ne doit rien coûter : ni paquet, ni carte, ni échange.
    @Test func sansLOptionIlNYAAucuneCarte() {
        var g = partie(2)
        #expect(g.deck.isEmpty)
        let refuse = g.exchange([0, 1, 2])
        #expect(!refuse)
        g.debugSkipToFortify(); g.endTurn()
        #expect(g.hand(of: 0).isEmpty)
    }

    /// La guerre totale exige tout le monde, sans exception.
    @Test func laGuerreTotaleExigeToutLePlateau() {
        var r = Rules(); r.dominationOverride = 0
        var g = partie(2, rules: r)
        #expect(g.dominationThreshold == g.map.order.count)
        // Le dernier va d'abord à l'adversaire : sans cela il pouvait déjà
        // appartenir au joueur 0 depuis la distribution, et le test se
        // vérifiait lui-même.
        g.seize(g.map.order.last!, by: 1, armies: 1)
        for id in g.map.order.dropLast() { g.seize(id, by: 0, armies: 1) }
        #expect(!g.dominates(0), "il en manque un, donc ce n'est pas gagné")
        g.seize(g.map.order.last!, by: 0, armies: 1)
        #expect(g.dominates(0))
    }

    // MARK: - La manœuvre de la machine

    /// Le défaut le plus visible de la première machine : elle prenait une
    /// place avec dix hommes et en laissait un dedans, en terre ennemie. Le
    /// stratège garde à sa base ce qu'il lui faut pour tenir, et fait avancer
    /// tout le reste.
    @Test func leStrategeNAbandonnePasSesHommes() {
        for style in [Bot.Style.facile, .moyenne, .forte] {
            var g = GameState.start(players: [
                Player(id: 0, name: "A", kind: .machine(niveau: 0.7, style: style)),
                Player(id: 1, name: "B", kind: .machine(niveau: 0.7, style: style)),
            ], seed: 12)
            g.debugSkipToAttack()
            guard let (base, cible) = g.debugFirstAssault(minArmies: 10, targetArmies: 1)
            else { return }
            g.declareAssault(from: base, to: cible, questions: 1, category: .histoire)
            let mauvaise = (g.assault!.current!.question.answer + 1) % 4
            g.answer(.chosen(mauvaise, elapsed: 1))

            let avance = Bot.occupation(g)
            if style.garnisonne {
                #expect(avance >= 6, "elle doit tenir la place prise, pas la semer")
            } else {
                #expect(avance <= 2, "la facile, elle, n'avance que le minimum")
            }
        }
    }

    // MARK: - L'héritage du vaincu

    /// Celui qui achève un joueur prend ses cartes. Sans cette ligne, la main
    /// du vaincu restait gelée là où elle était : ces cartes-là sortaient du
    /// jeu pour de bon, et le paquet s'appauvrissait à chaque élimination.
    @Test func lesCartesDuVaincuVontAuVainqueur() {
        var r = Rules(); r.territoryCards = true
        var g = GameState.start(players: (0..<3).map { Player(id: $0, name: "J\($0)") },
                                rules: r, seed: 42)
        g.debugSkipToAttack()
        let moi = g.currentPlayer.id

        // Le vaincu ne tient plus qu'une place, à un homme, voisine de la mienne.
        guard let base = g.territories(of: moi).first(where: { !g.targets(from: $0).isEmpty }),
              let derniere = g.targets(from: base).first, let vaincu = g.owner[derniere],
              let tiers = g.players.map(\.id).first(where: { $0 != moi && $0 != vaincu })
        else { Issue.record("pas de front"); return }
        for id in g.territories(of: vaincu) where id != derniere { g.seize(id, by: tiers) }
        g.seize(base, by: moi, armies: 6)
        g.seize(derniere, by: vaincu, armies: 1)

        let butin = Array(Deck.build(for: g.map).prefix(3))
        g.seizeHand(of: vaincu, butin)
        g.seizeHand(of: moi, [])

        let declare = g.declareAssault(from: base, to: derniere, questions: 1, category: .histoire)
        #expect(declare)
        _ = g.answer(.timeout)          // la place tombe

        #expect(g.players.first { $0.id == vaincu }?.eliminated == true)
        #expect(g.hand(of: vaincu).isEmpty, "le vaincu ne garde rien")
        #expect(g.hand(of: moi).map(\.id).sorted() == butin.map(\.id).sorted(),
                "les trois cartes passent au vainqueur")
    }

    /// Aucune carte ne disparaît du jeu : c'était tout le problème.
    @Test func aucuneCarteNeSortDuJeu() {
        var r = Rules(); r.territoryCards = true
        var g = GameState.start(players: (0..<3).map { Player(id: $0, name: "J\($0)") },
                                rules: r, seed: 7)
        func total(_ g: GameState) -> Int {
            g.players.reduce(0) { $0 + g.hand(of: $1.id).count } + g.deck.count + g.discard.count
        }
        let avant = total(g)
        g.debugSkipToAttack()
        let moi = g.currentPlayer.id
        guard let base = g.territories(of: moi).first(where: { !g.targets(from: $0).isEmpty }),
              let derniere = g.targets(from: base).first, let vaincu = g.owner[derniere],
              let tiers = g.players.map(\.id).first(where: { $0 != moi && $0 != vaincu })
        else { Issue.record("pas de front"); return }
        for id in g.territories(of: vaincu) where id != derniere { g.seize(id, by: tiers) }
        g.seize(base, by: moi, armies: 6)
        g.seize(derniere, by: vaincu, armies: 1)
        g.seizeHand(of: vaincu, Array(Deck.build(for: g.map).prefix(4)))

        let apresMise = total(g)
        let declare = g.declareAssault(from: base, to: derniere, questions: 1, category: .histoire)
        #expect(declare)
        _ = g.answer(.timeout)
        #expect(total(g) == apresMise, "le compte des cartes ne bouge pas")
        #expect(avant > 0)
    }

    /// Les trois niveaux doivent former une échelle, et pas trois noms.
    /// Chacun ajoute au précédent, et le flair — viser les faiblesses de
    /// l'adversaire en choisissant le terrain de la question — monte à chaque
    /// cran. C'est lui qui porte l'échelle : la manœuvre ne départage les
    /// machines que sur un grand plateau, parce qu'ailleurs la partie se règle
    /// en sept tours et que c'est le quiz qui décide.
    @Test func lesTroisNiveauxSOrdonnent() {
        let echelle: [Bot.Style] = [.facile, .moyenne, .forte]
        #expect(Bot.Style.allCases == echelle, "l'ordre affiché doit être celui de la force")
        for (bas, haut) in zip(echelle, echelle.dropFirst()) {
            #expect(haut.flair > bas.flair, "\(haut.label) doit viser mieux que \(bas.label)")
        }
        // Ce qui s'acquiert, et ne se reperd pas.
        #expect(!Bot.Style.facile.garnisonne)
        #expect(Bot.Style.moyenne.garnisonne && Bot.Style.forte.garnisonne)
        #expect(!Bot.Style.moyenne.concentre && Bot.Style.forte.concentre)
        #expect(!Bot.Style.moyenne.exploiteLeSablier && Bot.Style.forte.exploiteLeSablier)
    }

    /// Sans flair, la machine ne regarde même pas le dossier : elle doit donc
    /// répartir ses questions sur tous les thèmes.
    @Test func laFacileNeViseAucuneFaiblesse() {
        var g = partie(2)
        g.seize(.histoire, of: 1, asked: 10, correct: 0)   // faiblesse criante
        var rng = SeededRandom(seed: 4)
        var facile: [Riskelo.Category] = [], forte: [Riskelo.Category] = []
        for _ in 0 ..< 200 {
            g.players[0].kind = .machine(niveau: 0.7, style: .facile)
            facile.append(Bot.category(g, against: 1, using: &rng))
            g.players[0].kind = .machine(niveau: 0.7, style: .forte)
            forte.append(Bot.category(g, against: 1, using: &rng))
        }
        let visesFacile = facile.filter { $0 == .histoire }.count
        let visesForte = forte.filter { $0 == .histoire }.count
        #expect(visesForte > visesFacile * 2,
                "la forte doit frapper la faiblesse bien plus souvent (\(visesForte) contre \(visesFacile))")
    }

    /// Une pile de deux hommes menacée n'attaque pas : c'est la discipline qui
    /// sépare les deux machines, et je l'ai mesurée en la desserrant — le
    /// stratège tombait de 51 % à 32 % sur l'Europe.
    @Test func leStrategeNAttaquePasAvecSaDernierePaire() {
        var r = Rules()
        r.dominationOverride = nil
        var g = GameState.start(players: [
            Player(id: 0, name: "A", kind: .machine(niveau: 0.7, style: .forte)),
            Player(id: 1, name: "B", kind: .machine(niveau: 0.7, style: .forte)),
        ], rules: r, seed: 31)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 2, targetArmies: 3) else { return }
        // Toutes les autres places du camp sont réduites à un homme : la seule
        // attaque possible partirait de cette paire menacée.
        for id in g.territories(of: 0) where id != base { g.seize(id, by: 0, armies: 1) }
        var rng = SeededRandom(seed: 5)
        let plan = Bot.assault(g, boldness: 1.0, using: &rng)
        #expect(plan?.from != base, "il ne doit pas partir avec sa dernière paire")
        #expect(g.armies(cible) == 3)
    }

    // MARK: - Reprendre une partie

    /// Une partie reprise doit être la même partie, et non une autre qui
    /// commence au même endroit. C'est le tirage au sort qui en décide : s'il
    /// n'était pas enregistré, tout serait juste à l'œil et faux au coup
    /// suivant.
    @Test func unePartieRepriseSeDerouleALIdentique() throws {
        var g = GameState.start(players: [Player(id: 0, name: "A", kind: .machine(niveau: 0.7, style: .forte)),
                                          Player(id: 1, name: "B", kind: .machine(niveau: 0.6, style: .forte))],
                                seed: 1234)
        for _ in 0 ..< 60 { BotRunner.step(&g) }

        let data = try JSONEncoder().encode(g)
        var reprise = try JSONDecoder().decode(GameState.self, from: data)

        #expect(reprise.turn == g.turn)
        #expect(reprise.currentPlayer.id == g.currentPlayer.id)
        #expect(reprise.phase == g.phase)
        #expect(reprise.journal.count == g.journal.count)
        #expect(reprise.bank.alreadyServed == g.bank.alreadyServed)
        #expect(g.map.order.allSatisfy {
            reprise.owner[$0] == g.owner[$0] && reprise.armies($0) == g.armies($0)
        })
        #expect(Riskelo.Category.allCases.allSatisfy {
            reprise.record(of: 1, in: $0) == g.record(of: 1, in: $0)
        })

        // Et la suite, coup pour coup.
        var suivie = g
        for coup in 0 ..< 300 {
            BotRunner.step(&suivie)
            BotRunner.step(&reprise)
            #expect(reprise.turn == suivie.turn, "divergence au coup \(coup)")
            #expect(reprise.assault?.current?.question.id == suivie.assault?.current?.question.id,
                    "question différente au coup \(coup)")
        }
    }

    /// Une sauvegarde faite sur un autre plateau doit être refusée, et non
    /// restaurée de travers : un territoire manquant rendrait la partie
    /// injouable sans rien annoncer.
    @Test func uneSauvegardeDUnAutrePlateauEstRefusee() throws {
        let g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                seed: 7)
        let data = try JSONEncoder().encode(g)
        let faussee = String(data: data, encoding: .utf8)!
            .replacingOccurrences(of: "\"signature\":\"A0,", with: "\"signature\":\"Z9,")
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(GameState.self, from: Data(faussee.utf8))
        }
    }

    /// Une partie entière, jouée par la machine contre elle-même : elle doit
    /// se terminer, et sans jamais passer par un état interdit.
    @Test(arguments: [1 as UInt64, 2, 3, 4, 5, 6, 7, 8])
    func unePartieCompleteSeTermine(seed: UInt64) {
        var g = GameState.start(players: [Player(id: 0, name: "A", kind: .machine(niveau: 0.7, style: .forte)),
                                          Player(id: 1, name: "B", kind: .machine(niveau: 0.7, style: .forte))],
                                seed: seed)
        var garde = 0
        while !g.isOver && garde < 200_000 {
            garde += 1
            let avant = g.phase
            let pas = BotRunner.step(&g)
            if pas == .idle, g.phase == .fortify { g.endTurn() }
            if pas == .idle, avant == g.phase, case .reinforcement(let r) = g.phase, r == 0 { g.advance() }
            // Aucun territoire ne reste vide — sauf la place qu'on vient de
            // prendre, tant que les hommes qui doivent y entrer n'ont pas
            // avancé. C'est le seul instant où le plateau a un trou.
            if case let .occupation(_, prise, _, _) = g.phase {
                #expect(g.map.order.allSatisfy { $0 == prise || g.armies($0) >= 1 })
            } else {
                #expect(g.map.order.allSatisfy { g.armies($0) >= 1 })
            }
        }
        #expect(g.isOver, "partie \(seed) : pas de fin")
        if case let .finished(vainqueur) = g.phase {
            #expect(g.dominates(vainqueur) || g.players.filter { !$0.eliminated }.count == 1)
        }
    }
}
