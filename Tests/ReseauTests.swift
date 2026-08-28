//
//  ReseauTests.swift
//  RiskeloTests
//
//  Ce qui circule entre deux appareils.
//
//  Le fil est l'endroit du jeu où une panne ne dit rien : `Message.data` et
//  `Message.lire` avalent leurs erreurs, et un message qui ne s'encode pas ne
//  part tout simplement pas. Celui d'en face reste sur « en attente du
//  lancement… » sans que rien n'apparaisse nulle part.
//

import Foundation
import Testing
@testable import Riskelo

struct ReseauTests {

    private func partieNeuve(_ mode: Rules.Mode = .classique,
                             cartes: Bool = false, board: Boards = .anneau) -> GameState {
        var r = Rules(); r.mode = mode; r.territoryCards = cartes
        return GameState.start(board: board,
                               players: (0..<3).map { Player(id: $0, name: "J\($0)") },
                               rules: r, seed: 11)
    }

    /// La poignée de main : l'hôte envoie la partie entière, une fois.
    @Test func laPartieSurvitAuFil() {
        for board in Boards.allCases {
            for mode in Rules.Mode.allCases {
                let partie = partieNeuve(mode, cartes: true, board: board)
                guard let data = Message.partie(partie, votreRang: 1, numero: 0).data else {
                    Issue.record("\(board.label)/\(mode.label) : la partie ne s'encode pas")
                    continue
                }
                guard case let .message(.partie(recue, rang, numero)) = Message.lire(data) else {
                    Issue.record("\(board.label)/\(mode.label) : la partie ne se relit pas")
                    continue
                }
                #expect(rang == 1)
                #expect(numero == 0)
                // L'empreinte est ce que les deux appareils compareront à
                // chaque coup : si elle diffère dès la poignée de main, ils
                // joueront deux parties différentes en croyant la même.
                #expect(recue.digest == partie.digest, "\(board.label)/\(mode.label)")
                #expect(recue.map.order == partie.map.order)
                #expect(recue.rules == partie.rules)
            }
        }
    }

    /// Un assaut en cours voyage aussi : on peut reprendre une partie à
    /// n'importe quel instant, y compris au milieu d'un duel.
    @Test func unAssautEnCoursSurvitAuFil() {
        var r = Rules(); r.mode = .faceAFace
        var g = GameState.start(players: [Player(id: 0, name: "A"), Player(id: 1, name: "B")],
                                rules: r, seed: 42)
        g.debugSkipToAttack()
        guard let (base, cible) = g.debugFirstAssault(minArmies: 8, targetArmies: 4) else {
            Issue.record("pas d'assaut possible"); return
        }
        let declare = g.declareAssault(from: base, to: cible, questions: 2, category: .histoire)
        #expect(declare)
        g.relancer()
        _ = g.answer(.chosen(0, elapsed: 3.5))     // le défenseur a répondu

        guard let data = Message.partie(g, votreRang: 1, numero: 7).data,
              case let .message(.partie(recue, _, _)) = Message.lire(data) else {
            Issue.record("un assaut en cours ne passe pas le fil"); return
        }
        #expect(recue.assault?.mise == 2)
        #expect(recue.assault?.defenderAnswer != nil)
        #expect(recue.quiRepond == recue.assault?.attacker)
        #expect(recue.digest == g.digest)
    }

    /// Chaque coup du jeu doit pouvoir voyager : il n'y en a pas un seul qui
    /// ait le droit de rester à quai.
    @Test func tousLesCoupsPassentLeFil() {
        let coups: [Action] = [
            .place("A1"),
            .declareAssault(from: "A1", to: "A2", questions: 2, category: .sciences),
            .answer(.chosen(2, elapsed: 4.25)),
            .answer(.timeout),
            .relancer,
            .dismissAssault,
            .occupy(3),
            .fortify(from: "A1", to: "A2", count: 2),
            .advance,
            .endTurn,
            .exchangeCards([1, 2, 3]),
        ]
        for coup in coups {
            guard let data = Message.coup(coup, numero: 3, empreinte: 987_654).data,
                  case let .message(.coup(recu, numero, empreinte)) = Message.lire(data) else {
                Issue.record("\(coup) ne passe pas le fil"); continue
            }
            #expect(recu == coup)
            #expect(numero == 3)
            #expect(empreinte == 987_654)
        }
        guard let data = Message.perdu.data, case .message(.perdu) = Message.lire(data) else {
            Issue.record("« perdu » ne passe pas le fil"); return
        }
    }

    // MARK: - L'enveloppe

    /// Refait un paquet en tout point semblable au vrai, sauf le numéro de
    /// dialecte. C'est un appareil qui n'a pas la même version du jeu.
    private func paquet(_ message: Message, dialecte: Int) -> Data {
        guard let vrai = message.data,
              var objet = try? JSONSerialization.jsonObject(with: vrai) as? [String: Any]
        else { return Data() }
        objet["dialecte"] = dialecte
        return (try? JSONSerialization.data(withJSONObject: objet)) ?? Data()
    }

    /// Le dialecte se lit **sans décoder le message**. C'est toute la raison
    /// d'être de l'enveloppe : le lire de l'intérieur demandait de réussir
    /// d'abord ce qu'un désaccord de version fait précisément échouer.
    @Test func leDialecteEtrangerEstNomme() {
        let data = paquet(.perdu, dialecte: 99)
        #expect(!data.isEmpty)
        guard case let .autreDialecte(numero) = Message.lire(data) else {
            Issue.record("un dialecte étranger n'est pas reconnu comme tel"); return
        }
        #expect(numero == 99)
    }

    /// Et il se lit même quand le message qu'il enveloppe est illisible —
    /// c'est le cas réel : deux versions différentes, ce sont deux formes de
    /// message différentes.
    @Test func leDialecteEtrangerEstNommeMemeSousUnMessageIllisible() {
        let data = Data(#"{"dialecte":42,"message":{"sortilege":{"_0":"?"}}}"#.utf8)
        guard case let .autreDialecte(numero) = Message.lire(data) else {
            Issue.record("le dialecte doit se lire seul, sans le message"); return
        }
        #expect(numero == 42)
    }

    /// Une version d'avant l'enveloppe n'annonce aucun dialecte. C'est la
    /// panne qui a coûté une soirée : elle doit se nommer, elle aussi.
    @Test func uneVersionSansEnveloppeEstNommee() {
        guard let ancien = try? JSONEncoder().encode(Message.perdu) else {
            Issue.record("le message nu ne s'encode pas"); return
        }
        // Le paquet de l'ancêtre : le message, tout seul, sans en-tête.
        guard case let .autreDialecte(numero) = Message.lire(ancien) else {
            Issue.record("un paquet sans enveloppe n'est pas reconnu"); return
        }
        #expect(numero == nil, "une version qui n'annonce rien ne doit annoncer rien")
    }

    /// Ce qui n'est pas un paquet du jeu n'est pas un désaccord de version, et
    /// ne doit pas être annoncé comme tel.
    @Test func ceQuiNEstPasUnPaquetEstIllisible() {
        guard case .illisible = Message.lire(Data([0x00, 0x01, 0xFF])) else {
            Issue.record("des octets quelconques passent pour un dialecte"); return
        }
    }

    /// Tout ce qui part porte le dialecte, sans exception : c'est la seule
    /// façon que l'autre bout ait toujours de quoi trancher.
    @Test func toutPaquetPorteSonDialecte() {
        let messages: [Message] = [
            .partie(partieNeuve(), votreRang: 2, numero: 0),
            .coup(.endTurn, numero: 1, empreinte: 7),
            .perdu,
        ]
        for message in messages {
            guard let data = message.data,
                  let objet = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { Issue.record("\(message) ne s'encode pas"); continue }
            #expect(objet["dialecte"] as? Int == Message.dialecte)
            // Et l'en-tête est bien DEVANT, au premier niveau : rien à
            // décoder pour l'atteindre.
            #expect(objet["message"] != nil)
        }
    }
}
