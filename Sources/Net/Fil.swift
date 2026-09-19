//
//  Fil.swift
//  Riskelo
//
//  Ce qu'une partie attend du fil, et rien de plus.
//
//  Il y a trois façons de relier deux appareils, et la partie n'a aucune
//  raison de savoir laquelle est en service :
//
//  - `Link` — la même pièce. Bonjour pour se trouver, TCP pour se parler.
//  - `Relais` — le loin. Un code à six lettres, et un serveur qui fait
//    passer les paquets d'un bout du monde à l'autre.
//  - `Arene` — Game Center. Apple tient le fil, et les comptes avec.
//
//  Ce fichier est le contrat entre les trois. Il tient en six fonctions,
//  parce que c'est tout ce que `GameSession` a jamais demandé : envoyer des
//  octets à tous, à un seul, à tous sauf un — et apprendre qui est là.
//
//  Il ne dit rien de la mise en place. Se trouver n'a rien de commun d'un
//  fil à l'autre : on cherche une table dans la pièce, on tape un code, ou
//  l'on choisit un ami. Chaque salon connaît donc son fil par son vrai nom,
//  et c'est seulement une fois la partie lancée qu'il n'en reste que ceci.
//

import Foundation

/// L'état d'une liaison, du point de vue de la partie.
///
/// Trois états et non deux. « Coupée » et « perdue » ne demandent pas la
/// même chose au joueur : dans un cas on attend, dans l'autre on s'en va.
/// Sans cette distinction, la moindre coupure de tunnel terminait la partie
/// — ce qui était vrai dans la même pièce, où une liaison qui tombe est un
/// appareil qu'on a éteint, et faux au loin, où elle revient toute seule.
enum Liaison: Equatable {
    /// Tout va bien.
    case tenue
    /// Coupée, et l'on essaie de revenir. Le joueur voit un bandeau.
    case rompue(depuis: Date)
    /// On renonce. La partie s'arrête là.
    case perdue(String)
}

@MainActor
protocol Fil: AnyObject {

    /// Les appareils reliés, dans l'ordre où ils sont arrivés.
    var relies: [Pair] { get }

    /// Est-ce nous qui tenons la partie ? L'hôte relaie les coups et renvoie
    /// l'état à qui l'a perdu.
    var jeSuisLHote: Bool { get }

    /// Notre identité sur le fil.
    var moi: Pair { get }

    /// De quoi retrouver cette table dans huit jours, quand il y a moyen.
    ///
    /// Les trois fils ne se valent pas là-dessus, et c'est pour cela que la
    /// question se pose ici plutôt que dans la partie. Le loin rend son code :
    /// six lettres qu'on retape, et le salon garde la place une semaine. La
    /// même pièce ne rend rien — on s'y retrouve en s'y retrouvant, il n'y a
    /// rien à retenir. Game Center non plus, pour l'instant.
    ///
    /// C'est aussi ce qui décide si la partie va dans le tiroir de la reprise.
    /// Une partie rangée sans de quoi rouvrir son fil se rouvrait **sans lui** :
    /// les deux camps redevenaient jouables sur un seul téléphone, chacun
    /// jouant l'adversaire de l'autre sans le savoir.
    var codeDeReprise: String? { get }

    /// Ce qui arrive d'un autre appareil, et de qui.
    var onReceive: ((Data, Pair) -> Void)? { get set }

    /// Un appareil est là. `true` si c'est nous qui avons ouvert la partie.
    ///
    /// Appelé **à chaque fois** qu'il arrive, y compris quand il revient
    /// après une coupure. C'est ce qui rend la reprise possible sans
    /// inventer un message pour elle : celui qui revient redemande la
    /// partie, celui qui la tient la renvoie, et les deux messages existent
    /// déjà.
    var onConnected: ((Bool, Pair) -> Void)? { get set }

    /// L'état de la liaison a changé.
    var onLiaison: ((Liaison) -> Void)? { get set }

    /// À tous.
    func envoyer(_ data: Data)
    /// À un seul : chacun doit apprendre son rang, et lui seul.
    func envoyer(_ data: Data, a pair: Pair)
    /// À tous sauf un : l'hôte relaie le coup d'un joueur aux autres sans le
    /// lui renvoyer.
    func envoyer(_ data: Data, saufA pair: Pair)

    /// Cesser d'accueillir : la partie part.
    ///
    /// Elle ne raccroche rien — les appareils déjà là restent reliés, et
    /// c'est bien tout l'objet. Ce qui se ferme, c'est la porte.
    func fermerLaTable()

    /// Raccrocher, pour de bon.
    func arreter()
}
