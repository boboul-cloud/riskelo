//
//  Action.swift
//  Riskelo
//
//  Un coup, sous forme de valeur.
//
//  Le moteur savait déjà se laisser modifier par des méthodes nommées ; il lui
//  manquait de pouvoir recevoir ces coups sous une forme qu'on transmet. C'est
//  toute la condition du jeu entre deux appareils : chacun tient la même
//  partie, et l'on ne s'envoie que ce qui la fait changer — quelques dizaines
//  d'octets par coup au lieu de recopier l'état entier.
//
//  Cela ne marche que parce que le moteur est reproductible : mêmes coups,
//  même tirage au sort, même partie. C'est la propriété qu'a prouvée la
//  reprise de partie, et le test qui la garde vaut aussi pour le réseau.
//

import Foundation

enum Action: Codable, Equatable {
    case place(TerritoryID)
    case declareAssault(from: TerritoryID, to: TerritoryID, questions: Int, category: Category)
    case answer(Answer)
    /// Le défenseur double l'enjeu, en face à face.
    case relancer
    case dismissAssault
    case occupy(Int)
    case fortify(from: TerritoryID, to: TerritoryID, count: Int)
    case advance
    case endTurn
    /// L'échange de trois cartes contre des hommes. Les cartes voyagent par
    /// leur numéro : c'est ce qui les rend identiques d'un appareil à l'autre.
    case exchangeCards([Int])

    /// Qui a le droit de jouer ce coup : celui dont c'est le tour, sauf
    /// autour du duel. En classique le défenseur seul répond ; en face à face
    /// les deux répondent, chacun son tour, et c'est le moteur qui dit lequel.
    func author(in game: GameState) -> PlayerID? {
        switch self {
        case .answer: game.quiRepond ?? game.assault?.defender
        case .relancer: game.assault?.defender
        default: game.currentPlayer.id
        }
    }
}

extension GameState {

    /// Le seul chemin par lequel une partie change. Tout ce que fait
    /// l'interface passe ici — et donc tout ce qui passe ici peut être envoyé
    /// à l'autre appareil, ou rejoué.
    @discardableResult
    mutating func apply(_ action: Action) -> DuelReport? {
        switch action {
        case .place(let id):
            place(on: id)
        case let .declareAssault(from, to, questions, category):
            declareAssault(from: from, to: to, questions: questions, category: category)
        case .answer(let reponse):
            return answer(reponse)
        case .relancer:
            relancer()
        case .dismissAssault:
            dismissAssault()
        case .occupy(let n):
            occupy(n)
        case let .fortify(from, to, count):
            fortify(from: from, to: to, count: count)
        case .advance:
            advance()
        case .endTurn:
            endTurn()
        case .exchangeCards(let ids):
            exchange(ids)
        }
        return nil
    }

    /// Une empreinte de la partie, pour vérifier que les deux appareils n'ont
    /// pas divergé. Une divergence ne se voit pas : les deux écrans montrent
    /// chacun une partie cohérente, et ce sont deux parties différentes.
    /// Mieux vaut s'en apercevoir au coup suivant qu'à la fin.
    var digest: UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        func avale(_ v: Int) {
            h = (h ^ UInt64(bitPattern: Int64(v))) &* 0x100_0000_01b3
        }
        avale(turn); avale(current)
        for id in map.order {
            avale((owner[id] ?? -1) &* 97 &+ armies(id))
        }
        avale(assault?.asked ?? -1)
        avale(assault?.mise ?? 0)
        avale(exchanges)
        for j in players { avale(hand(of: j.id).count) }
        // Surtout pas `hashValue` : Swift le sale à chaque lancement, et deux
        // appareils en bonne santé se croiraient divergents. Le rang du
        // territoire, lui, est le même partout.
        avale(assault.flatMap { map.order.firstIndex(of: $0.from) } ?? -1)
        return h
    }
}
