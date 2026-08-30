//
//  Match.swift
//  Riskelo
//
//  Ce qui circule sur le fil.
//
//  Trois sortes de messages seulement. L'état complet une fois, à la
//  connexion — c'est plus simple et plus sûr que de faire deviner la mise en
//  place à l'autre appareil. Puis les coups, un par un. Et une demande de
//  renvoi, si jamais les deux parties divergent.
//
//  Chaque coup voyage avec l'empreinte de la partie telle qu'elle est APRÈS
//  l'avoir joué. Celui qui reçoit compare : s'il ne trouve pas la même, il
//  demande l'état complet plutôt que de continuer à jouer une autre partie
//  que son adversaire. C'est le seul garde-fou possible — une divergence ne
//  se voit pas, les deux écrans restent cohérents chacun de son côté.
//

import Foundation

enum Message: Codable {

    /// Le dialecte parlé sur le fil. À monter dès que la forme d'un message
    /// change — et elle change dès qu'on touche à `Action` ou à `GameState`.
    ///
    /// Deux appareils qui ne parlent pas le même dialecte ne peuvent pas
    /// jouer ensemble. Sans ce numéro, celui qui reçoit une partie qu'il ne
    /// sait pas lire ne la lit pas, ne dit rien, et attend indéfiniment : la
    /// panne la plus difficile à comprendre de tout le jeu, parce qu'elle
    /// ressemble à une panne de réseau alors que la liaison est parfaite.
    ///
    /// Il était **à l'intérieur** du message, et ne protégeait donc que d'un
    /// côté : pour le lire il fallait d'abord décoder le message, c'est-à-dire
    /// réussir précisément ce qu'un désaccord de version fait échouer. Il est
    /// désormais devant, dans une enveloppe qui ne change jamais de forme.
    ///
    /// 3 : le dialecte sort du message et passe dans l'enveloppe.
    /// 4 : chacun dit son nom en arrivant — `bonjour`.
    static let dialecte = 4

    /// La partie entière, envoyée par celui qui l'a ouverte — à chacun son
    /// rang, et le compte des coups déjà joués.
    case partie(GameState, votreRang: PlayerID, numero: Int)
    /// Un coup : son rang dans la suite, et l'empreinte attendue une fois
    /// qu'il est joué.
    ///
    /// Le numéro sert deux fois. À quatre appareils, l'hôte relaie les coups
    /// aux autres, et un appareil peut recevoir deux fois le même — il le
    /// reconnaît et l'ignore. Et si un numéro manque, c'est qu'un coup s'est
    /// perdu : mieux vaut redemander la partie que de continuer sans lui.
    case coup(Action, numero: Int, empreinte: UInt64)
    /// « Je ne suis plus à la même partie que vous, renvoyez-la. »
    case perdu
    /// « Voici comment je m'appelle. »
    ///
    /// Envoyé par chacun dès la liaison établie, avant toute partie. Celui
    /// qui héberge s'en sert pour nommer les camps : le nom part alors avec
    /// l'état, et tous les appareils voient les mêmes joueurs.
    ///
    /// Le nom de l'appareil n'aurait pas suffi. Depuis iOS 16, il répond
    /// « iPhone » à qui n'a pas l'autorisation d'en demander plus : deux
    /// téléphones se présentent au salon sous le même nom.
    ///
    /// Vide quand on ne s'est pas donné de nom — le camp garde alors sa
    /// couleur pour seul nom, et c'est très bien.
    case bonjour(nom: String)

    /// Ce qu'on trouve dans un paquet reçu.
    ///
    /// Trois issues et non deux. « Je n'ai pas compris » ne dit pas
    /// *pourquoi*, et c'est justement ce qu'il fallait pouvoir nommer : à
    /// l'écran, « installez la même version » et « ceci est un défaut du jeu »
    /// ne demandent pas la même chose au joueur.
    enum Lecture {
        case message(Message)
        /// Le paquet vient d'une autre version du jeu. Le numéro est celui
        /// qu'elle annonce — ou `nil` si elle est antérieure à l'enveloppe et
        /// n'en annonce aucun.
        case autreDialecte(Int?)
        /// Le dialecte est le bon et le contenu ne se lit pas. Ce n'est plus
        /// une affaire de version : c'est que la forme d'un message a changé
        /// sans que le numéro soit monté.
        case illisible
    }

    /// L'enveloppe : le dialecte devant, le message derrière.
    ///
    /// Sa forme est le seul contrat que toutes les versions à venir doivent
    /// tenir. Tout le reste peut bouger.
    private struct Paquet: Codable {
        let dialecte: Int
        let message: Message
    }

    /// L'en-tête seul.
    ///
    /// Il se lit **même quand le message qui suit est écrit dans une langue
    /// qu'on ignore** : un décodeur ne réclame que les clés qu'il connaît, et
    /// celui-ci n'en connaît qu'une. C'est toute la raison d'être de
    /// l'enveloppe.
    private struct Entete: Decodable {
        let dialecte: Int
    }

    var data: Data? {
        do {
            return try JSONEncoder().encode(Paquet(dialecte: Message.dialecte,
                                                   message: self))
        } catch {
            // Un message qui ne part pas laisse l'autre appareil en attente
            // sans que rien n'apparaisse nulle part. Au moins qu'il le dise.
            print("Riskelo — message non envoyé : \(error)")
            return nil
        }
    }

    static func lire(_ data: Data) -> Lecture {
        let decodeur = JSONDecoder()

        guard let entete = try? decodeur.decode(Entete.self, from: data) else {
            // Pas d'en-tête du tout. Deux cas, et il vaut la peine de les
            // séparer : du JSON sans enveloppe vient d'une version d'avant
            // celle-ci — c'est un désaccord de version, et il faut le dire.
            // Ce qui n'est pas du JSON n'est pas un paquet du jeu.
            if (try? JSONSerialization.jsonObject(with: data)) != nil {
                print("Riskelo — paquet sans dialecte : version antérieure à l'enveloppe")
                return .autreDialecte(nil)
            }
            print("Riskelo — paquet illisible : ce n'est pas du JSON")
            return .illisible
        }

        guard entete.dialecte == Message.dialecte else {
            print("Riskelo — dialecte \(entete.dialecte) reçu, \(Message.dialecte) attendu")
            return .autreDialecte(entete.dialecte)
        }

        do {
            return .message(try decodeur.decode(Paquet.self, from: data).message)
        } catch {
            print("Riskelo — message illisible sous le bon dialecte : \(error)")
            return .illisible
        }
    }
}
