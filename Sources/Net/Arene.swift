//
//  Arene.swift
//  Riskelo
//
//  Le fil d'Apple.
//
//  Game Center fait gratuitement ce que le serveur de `Relais` fait pour
//  quelques euros : mettre deux appareils en présence où qu'ils soient, et
//  faire passer les paquets entre eux. Il ajoute même ce qu'aucun code à six
//  lettres ne donnera jamais — une liste d'amis, et quelqu'un à qui jouer
//  quand on n'a personne sous la main.
//
//  Il demande deux choses en échange, et il faut les dire avant que le joueur
//  les découvre :
//
//  - **un compte.** Game Center est lié à l'identifiant Apple. Qui n'y est
//    pas connecté ne peut pas jouer par ce fil-là — d'où le code, qui ne
//    demande rien à personne et reste le chemin par défaut.
//  - **pas de reprise.** Une partie en temps réel chez Apple ne se
//    reconnecte pas : un joueur qui perd le réseau est parti pour de bon.
//    C'est une limite du cadre, pas un oubli — et c'est la raison pour
//    laquelle le fil du loin ne s'est pas contenté de celui-ci.
//
//  ## Qui héberge, puisque personne ne l'a ouverte
//
//  Il n'y a pas d'hôte chez Apple : quatre appareils se retrouvent dans une
//  partie, et aucun n'est arrivé le premier. Or tout le reste du jeu suppose
//  quelqu'un qui tienne la partie, distribue les rangs et renvoie l'état.
//
//  On le désigne donc sans rien se demander : **le plus petit identifiant**
//  des quatre. Chaque appareil trie la même liste et trouve le même premier,
//  sans qu'un seul paquet ait à circuler. Un vote aurait demandé un message,
//  donc un désaccord possible, donc une panne de plus.
//

import Foundation
#if canImport(GameKit)
import GameKit
#endif
#if os(iOS)
import UIKit
#else
import AppKit
#endif

#if canImport(GameKit)

@Observable
@MainActor
final class Arene: NSObject, Fil {

    enum Etat: Equatable {
        case aLArret
        /// On demande au joueur de se connecter à Game Center.
        case identification
        /// Le joueur n'est pas connecté, et rien ne se fera sans cela.
        case sansCompte
        /// On cherche des joueurs.
        case cherche
        case relie
        case refuse(String)
    }

    private(set) var etat: Etat = .aLArret
    private(set) var relies: [Pair] = []

    /// Le plus petit identifiant tient la partie. Voir l'en-tête.
    var jeSuisLHote: Bool {
        guard !relies.isEmpty else { return true }
        return ([moi] + relies).map(\.id).min() == moi.id
    }

    private(set) var moi = Pair(id: "", nom: "")

    var onReceive: ((Data, Pair) -> Void)?
    var onConnected: ((Bool, Pair) -> Void)?
    var onLiaison: ((Liaison) -> Void)?

    /// Combien de joueurs en tout, celui-ci compris.
    var joueurs = 2

    /// La partie en cours chez Apple.
    private var match: GKMatch?
    /// Ce qui doit s'afficher : l'écran de connexion d'Apple, ou celui du
    /// choix des joueurs. La vue le regarde et le présente.
    private(set) var ecranAPresenter: GKMatchmakerViewController?
    private(set) var ecranDeConnexion: Any?

    /// Une invitation reçue d'un ami pendant que le jeu tourne.
    private(set) var invitation: GKInvite?

    /// Appelé quand tout le monde est là et que la partie peut partir.
    var onSalonPlein: (() -> Void)?

    // MARK: - S'identifier

    /// Game Center se connecte une fois par lancement, et il faut le lui
    /// demander avant tout le reste.
    ///
    /// Le rappel est gardé par le système et peut être appelé plusieurs fois
    /// — à chaque changement de compte, notamment. Il n'y a donc rien à
    /// attendre ici : on pose le rappel, et l'état suit.
    func identifier() {
        etat = .identification
        let local = GKLocalPlayer.local
        local.authenticateHandler = { [weak self] ecran, erreur in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let ecran {
                    // Apple veut montrer sa fenêtre de connexion.
                    self.ecranDeConnexion = ecran
                    return
                }
                self.ecranDeConnexion = nil
                guard local.isAuthenticated else {
                    if let erreur {
                        print("Riskelo — Game Center : \(erreur.localizedDescription)")
                    }
                    self.etat = .sansCompte
                    return
                }
                self.moi = Pair(id: local.gamePlayerID, nom: local.displayName)
                // Les invitations d'amis arrivent par là, et seulement par là.
                local.unregisterAllListeners()
                local.register(self)
                if case .identification = self.etat { self.etat = .aLArret }
            }
        }
    }

    var estIdentifie: Bool { GKLocalPlayer.local.isAuthenticated }

    // MARK: - Chercher des joueurs

    /// Ouvre l'écran d'Apple : inviter un ami, ou tomber sur quelqu'un.
    func chercher() {
        guard estIdentifie else { identifier(); return }
        let demande = GKMatchRequest()
        demande.minPlayers = joueurs
        demande.maxPlayers = joueurs
        guard let ecran = GKMatchmakerViewController(matchRequest: demande) else {
            etat = .refuse("Game Center n'a pas pu ouvrir la recherche.")
            return
        }
        ecran.matchmakerDelegate = self
        etat = .cherche
        ecranAPresenter = ecran
    }

    /// Répondre à l'invitation d'un ami.
    func accepter(_ invite: GKInvite) {
        guard let ecran = GKMatchmakerViewController(invite: invite) else {
            etat = .refuse("Cette invitation n'est plus valable.")
            return
        }
        ecran.matchmakerDelegate = self
        etat = .cherche
        invitation = nil
        ecranAPresenter = ecran
    }

    /// L'écran d'Apple a été refermé — par lui ou par nous.
    func ecranReferme() { ecranAPresenter = nil }

    /// La fenêtre de connexion a été refermée par le joueur.
    ///
    /// Sans ceci, elle revenait à l'instant même : elle est présentée tant que
    /// `ecranDeConnexion` n'est pas vide, et c'est Apple qui le vide — mais
    /// seulement quand il a fini. Un joueur qui balaye la fenêtre vers le bas
    /// n'a rien fini du tout, et se retrouvait enfermé dans une fenêtre qu'il
    /// ne pouvait plus quitter.
    func connexionRefermee() {
        ecranDeConnexion = nil
        if !estIdentifie { etat = .sansCompte }
    }

    /// Rien à faire : chez Apple, la partie est close dès qu'elle est
    /// rendue. Personne ne peut plus y entrer, et il n'y a donc pas de porte
    /// à refermer.
    func fermerLaTable() {}

    func arreter() {
        match?.disconnect()
        match = nil
        relies = []
        ecranAPresenter = nil
        GKMatchmaker.shared().cancel()
        etat = .aLArret
    }

    // MARK: - Envoyer

    func envoyer(_ data: Data) {
        guard let match, !match.players.isEmpty else { return }
        pousser(data, vers: match.players)
    }

    func envoyer(_ data: Data, a pair: Pair) {
        guard let match, let qui = match.players.first(where: { $0.gamePlayerID == pair.id })
        else { return }
        pousser(data, vers: [qui])
    }

    func envoyer(_ data: Data, saufA pair: Pair) {
        guard let match else { return }
        let autres = match.players.filter { $0.gamePlayerID != pair.id }
        guard !autres.isEmpty else { return }
        pousser(data, vers: autres)
    }

    /// `.reliable` et non `.unreliable` : un coup perdu ne se rattrape pas.
    /// C'est exactement ce que TCP donne d'office sur le fil de la même
    /// pièce, et il faut ici le demander.
    private func pousser(_ data: Data, vers qui: [GKPlayer]) {
        do {
            try match?.send(data, to: qui, dataMode: .reliable)
        } catch {
            print("Riskelo — Game Center : paquet non envoyé (\(error))")
        }
    }

    // MARK: - Dedans

    fileprivate func prendre(_ nouveau: GKMatch) {
        match = nouveau
        nouveau.delegate = self
        etat = .relie
        ecranAPresenter = nil
        rafraichir()
        // Tout le monde est là : c'est Apple qui le dit en rendant la partie.
        onSalonPlein?()
    }

    fileprivate func rafraichir() {
        guard let match else { relies = []; return }
        let vus = match.players.map { Pair(id: $0.gamePlayerID, nom: $0.displayName) }
        for pair in vus where !relies.contains(pair) {
            relies.append(pair)
            onConnected?(jeSuisLHote, pair)
        }
        relies.removeAll { pair in !vus.contains(pair) }
    }
}

// MARK: - Ce qu'Apple nous dit

extension Arene: GKMatchDelegate {

    nonisolated func match(_ match: GKMatch, didReceive data: Data,
                           fromRemotePlayer player: GKPlayer) {
        let pair = Pair(id: player.gamePlayerID, nom: player.displayName)
        Task { @MainActor [weak self] in self?.onReceive?(data, pair) }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer,
                           didChange state: GKPlayerConnectionState) {
        let pair = Pair(id: player.gamePlayerID, nom: player.displayName)
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch state {
            case .connected:
                self.rafraichir()
            case .disconnected:
                // Chez Apple, une partie en temps réel ne se reconnecte pas.
                // Dire « on attend son retour » serait un mensonge : il n'y a
                // rien à attendre.
                self.relies.removeAll { $0 == pair }
                self.onLiaison?(.perdue(pair.nom))
            default:
                break
            }
        }
    }

    nonisolated func match(_ match: GKMatch, didFailWithError error: Error?) {
        let dit = error?.localizedDescription ?? "la liaison s'est rompue"
        Task { @MainActor [weak self] in self?.onLiaison?(.perdue(dit)) }
    }
}

extension Arene: GKMatchmakerViewControllerDelegate {

    nonisolated func matchmakerViewControllerWasCancelled(
        _ viewController: GKMatchmakerViewController) {
        Task { @MainActor [weak self] in
            self?.ecranAPresenter = nil
            self?.etat = .aLArret
        }
    }

    nonisolated func matchmakerViewController(
        _ viewController: GKMatchmakerViewController,
        didFailWithError error: Error) {
        let dit = error.localizedDescription
        Task { @MainActor [weak self] in
            self?.ecranAPresenter = nil
            self?.etat = .refuse(dit)
        }
    }

    nonisolated func matchmakerViewController(
        _ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        Task { @MainActor [weak self] in self?.prendre(match) }
    }
}

extension Arene: GKLocalPlayerListener {

    /// Un ami invite. Le jeu tourne peut-être sur tout autre chose : on garde
    /// l'invitation, et l'accueil la propose.
    nonisolated func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        Task { @MainActor [weak self] in self?.invitation = invite }
    }
}

#endif
