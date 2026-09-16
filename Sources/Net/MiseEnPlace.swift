//
//  MiseEnPlace.swift
//  Riskelo
//
//  Ce qui se passe entre « on est reliés » et « la partie commence ».
//
//  Il y a trois façons de se relier — la même pièce, un code, Game Center —
//  et il n'y a qu'une seule façon de commencer. Ces deux fonctions sont donc
//  ici et non dans les écrans : autrement, la troisième aurait recopié la
//  deuxième, qui aurait recopié la première, et un jour l'une des trois
//  aurait cessé de donner son nom aux camps sans que personne le remarque.
//
//  Elles ne connaissent du fil que `Fil`. C'est tout ce qu'il faut : dire
//  bonjour, écouter, distribuer les rangs.
//

import Foundation

@MainActor
enum MiseEnPlace {

    /// Poser les rappels du salon : chacun dit son nom en arrivant, et l'on
    /// attend la partie.
    ///
    /// Le nom part **sans qu'on le demande**. À quatre appareils, une demande
    /// par appareil serait quatre fois l'occasion de se perdre.
    static func preparer(
        _ fil: any Fil,
        nomVu: @escaping (Pair, String?) -> Void,
        partieRecue: @escaping (GameState, PlayerID, Int) -> Void,
        desaccord: @escaping () -> Void
    ) {
        fil.onConnected = { [weak fil] _, pair in
            guard let fil else { return }
            if let data = Message.bonjour(nom: Pseudo.actuel ?? "").data {
                fil.envoyer(data, a: pair)
            }
        }
        fil.onReceive = { data, pair in
            switch Message.lire(data) {
            case let .message(.bonjour(nom)):
                nomVu(pair, nom.isEmpty ? nil : nom)

            case let .message(.partie(etat, rang, numero)):
                partieRecue(etat, rang, numero)

            case .message:
                // Un coup, avant même d'avoir la partie : il n'y a rien à en
                // faire, et surtout ce n'est pas un désaccord. Tout ce qui
                // n'était pas la partie était compté comme tel, et un paquet
                // arrivé une fraction de seconde trop tôt affichait donc
                // « Versions différentes » à deux appareils parfaitement
                // d'accord.
                break

            case .autreDialecte, .illisible:
                desaccord()
            }
        }
    }

    /// L'hôte crée la partie et donne son rang à chacun, dans l'ordre
    /// d'arrivée. Chaque appareil reçoit le sien, et lui seul.
    ///
    /// Le nom de chacun est déjà connu — il est arrivé par `bonjour` — et il
    /// part **avec l'état**. Les quatre appareils voient donc les mêmes
    /// joueurs : c'est le seul endroit où cette composition se fait, et le
    /// seul moment où l'hôte les connaît tous.
    static func lancer(_ fil: any Fil, joueurs: Int, plateau: Boards, regles: Rules,
                       noms: [Pair: String]) -> GameSession {
        fil.fermerLaTable()

        let camps = (0..<joueurs).map { rang -> Player in
            let camp = Boards.nomDeCamp(rang)
            let choisi = rang == 0 ? Pseudo.actuel
                                   : fil.relies.indices.contains(rang - 1)
                                     ? noms[fil.relies[rang - 1]] : nil
            return Player(id: rang, name: choisi.map { "\(camp) · \($0)" } ?? camp)
        }

        // La mémoire de l'appareil qui héberge part avec la partie : les
        // appareils tirent alors les mêmes questions, et celui qui rejoint
        // n'a pas à connaître les soirées de l'autre.
        let partie = GameState.start(
            board: plateau, players: camps, rules: regles,
            bank: QuestionBank(vues: MemoireDesQuestions.shared.charger()))

        var rangs: [Pair: PlayerID] = [:]
        for (i, pair) in fil.relies.enumerated() {
            let rang = i + 1
            rangs[pair] = rang
            if let data = Message.partie(partie, votreRang: rang, numero: 0).data {
                fil.envoyer(data, a: pair)
            }
        }
        return GameSession(fil: fil, heberge: true, game: partie,
                           monRang: 0, rangs: rangs, compteur: 0)
    }
}
