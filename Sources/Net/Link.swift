//
//  Link.swift
//  Riskelo
//
//  Le fil entre deux appareils.
//
//  MultipeerConnectivity, et non un serveur : il prend le Bluetooth et le
//  Wi-Fi direct sans qu'on ait à choisir, ne demande ni compte ni réseau, et
//  marche dans un train. C'est exactement l'usage — deux personnes dans la
//  même pièce, un appareil chacune.
//
//  Ce fichier ne connaît rien au jeu : il transporte des paquets d'octets et
//  dit qui est là. Ce qui circule dedans est l'affaire de `Match`.
//

import Foundation
import MultipeerConnectivity

@Observable
@MainActor
final class Link: NSObject {

    /// Le nom du service. Quinze caractères au plus, minuscules et tirets :
    /// c'est une contrainte de Bonjour, pas un goût.
    ///
    /// `nonisolated`, comme tout le vocabulaire qui suit : la classe est
    /// posée sur l'acteur principal — c'est ce que veut son état — mais une
    /// chaîne de caractères figée à la compilation n'est pas de l'état, et il
    /// n'y a rien à y protéger. Or elle se lit précisément là où l'acteur
    /// n'est pas : les rappels de MultipeerConnectivity arrivent sur son
    /// propre fil, et les tests s'exécutent hors acteur. Sans ce mot, le
    /// compilateur avertit à chaque lecture — et Swift 6 en fera une erreur.
    nonisolated static let service = "riskelo-jeu"

    /// Ce que chaque appareil dit de lui dans son annonce.
    ///
    /// Les clés sont courtes parce que tout ceci voyage dans un enregistrement
    /// Bonjour, qui est petit — et parce qu'un nom d'appareil peut déjà en
    /// prendre trente caractères.
    ///
    /// La liaison n'allait que dans un sens : l'hôte annonçait, l'invité
    /// cherchait et invitait. Quand ce sens-là ne passe pas, tout est bloqué —
    /// alors que l'autre peut être grand ouvert. C'est arrivé, et sur du vrai
    /// matériel : un iPad hébergeait, l'iPhone le voyait parfaitement et ne
    /// parvenait jamais à résoudre son adresse ; les rôles inversés, la partie
    /// démarrait en onze secondes.
    nonisolated static let cleRole = "r", cleCible = "c"
    nonisolated static let hote = "h", invite = "i"

    enum State: Equatable {
        case aLArret
        /// On se montre et l'on attend qu'on vienne.
        case ouvert
        /// On cherche qui se montre.
        case cherche
        /// L'invitation est partie, on attend qu'on décroche.
        ///
        /// Cet état manquait, et son absence était une panne à elle seule :
        /// toucher le nom d'un appareil ne changeait rien à l'écran. La liste
        /// restait la liste, et l'on croyait que l'appui n'avait pas été pris.
        case invite(String)
        case relie(String)
        case perdu(String)
        /// Le système a refusé, ou personne n'a décroché. Presque toujours
        /// l'autorisation « réseau local », qui se refuse une fois et ne se
        /// redemande jamais.
        case refuse(String)
    }

    private(set) var state: State = .aLArret
    /// Les parties trouvées autour, pour le joueur qui cherche.
    private(set) var trouves: [MCPeerID] = []

    var jeSuisLHote: Bool { jHeberge }

    /// Ce qui arrive d'un autre appareil, et de qui.
    var onReceive: ((Data, MCPeerID) -> Void)?
    /// Appelé à chaque appareil relié, avec `true` si c'est nous qui avons
    /// ouvert la partie. À quatre, il est appelé trois fois.
    var onConnected: ((Bool, MCPeerID) -> Void)?

    /// Les appareils reliés, dans l'ordre où ils sont arrivés : c'est cet
    /// ordre qui décide des rangs.
    private(set) var relies: [MCPeerID] = []

    /// Combien d'appareils l'hôte attend en tout, lui non compris.
    ///
    /// Il cesse d'annoncer dès que la table est pleine. À deux appareils,
    /// c'est le comportement d'origine : le second arrive, l'annonce s'arrête.
    /// Le passage à quatre l'a fait continuer — il fallait bien pouvoir en
    /// accueillir trois — et l'annonceur restait donc en marche **pendant que
    /// la session se négociait**. Sur du vrai matériel, une annonce qui
    /// continue par-dessus une négociation en cours la brouille : le pair
    /// passe « en cours » puis retombe « non relié », sans erreur.
    var attendus = 1

    private let moi = Link.identite()
    private var session: MCSession?

    /// La même session, lisible depuis n'importe quel fil.
    ///
    /// `invitationHandler` doit être appelé **dans le rappel lui-même**. Ce
    /// n'était pas le cas : la réponse passait par un saut vers le fil
    /// principal, et une invitation à laquelle on répond en différé peut être
    /// tenue pour sans réponse. Celui qui invitait voyait « n'a pas répondu »
    /// alors que la table était grande ouverte en face — la panne la plus
    /// longue à trouver de tout ce jeu, parce que tout le reste marchait.
    ///
    /// `MCSession` supporte d'être lue depuis plusieurs fils. L'accès à la
    /// **référence**, lui, passe par un verrou : elle est écrite sur le fil
    /// principal et lue ailleurs, et sans verrou rien ne garantit que le
    /// rappel voie la session qu'on vient de poser.
    ///
    /// Hors observation : le macro `@Observable` transforme les propriétés
    /// suivies en propriétés calculées, et une propriété calculée ne peut pas
    /// être `nonisolated`. Celle-ci ne sert qu'aux rappels du système, qui
    /// n'ont rien à observer.
    @ObservationIgnored nonisolated(unsafe) private var _sessionPartagee: MCSession?
    @ObservationIgnored private let verrou = NSLock()

    nonisolated private var sessionPartagee: MCSession? {
        get { verrou.lock(); defer { verrou.unlock() }; return _sessionPartagee }
        set { verrou.lock(); defer { verrou.unlock() }; _sessionPartagee = newValue }
    }
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var jHeberge = false
    /// Le délai d'une invitation en cours.
    private var attente: Task<Void, Never>?
    /// Les secours en attente, un par invité qui nous appelle. Voir
    /// `secourir`.
    private var secours: [MCPeerID: Task<Void, Never>] = [:]

    /// L'identité de cet appareil sur le fil, **gardée d'un lancement sur
    /// l'autre**.
    ///
    /// Elle était refaite à chaque démarrage. C'est précisément ce qu'Apple
    /// demande de ne pas faire : un `MCPeerID` doit être archivé et réutilisé.
    /// Le système garde trace des appareils qu'il a vus, et un appareil qui se
    /// présente sous une identité neuve à chaque lancement finit par en
    /// accumuler des dizaines pour un seul et même téléphone. La liaison
    /// marche la première fois, puis échoue — sans erreur, sans message, et
    /// sans rien qui change entre les deux essais. C'est la signature exacte
    /// de « ça a fonctionné après l'installation ».
    ///
    /// On la refait dans un seul cas : si le nom de l'appareil a changé.
    static func identite() -> MCPeerID {
        let nom = nomDeLAppareil
        let cle = "riskelo.pair", cleDuNom = "riskelo.pair.nom"
        let reglages = UserDefaults.standard
        if reglages.string(forKey: cleDuNom) == nom,
           let data = reglages.data(forKey: cle),
           let gardee = try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self,
                                                               from: data) {
            return gardee
        }
        let neuve = MCPeerID(displayName: nom)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: neuve,
                                                       requiringSecureCoding: true) {
            reglages.set(data, forKey: cle)
            reglages.set(nom, forKey: cleDuNom)
        }
        return neuve
    }

    private static var nomDeLAppareil: String {
        #if os(iOS)
        String(UIDevice.current.name.prefix(30))
        #else
        String((Host.current().localizedName ?? "Mac").prefix(30))
        #endif
    }

    // MARK: - Ouvrir, chercher, raccrocher

    // Il y avait ici une reprise automatique au retour au premier plan, qui
    // relançait `startAdvertisingPeer()` sur un annonceur déjà en marche.
    // Retirée : je ne l'avais mise que sur une intuition, sans avoir vu la
    // panne qu'elle prétendait corriger, et elle pouvait en créer une —
    // `didBecomeActive` part à chaque retour dans l'application, y compris au
    // lancement et au retour des Réglages, et relancer un annonceur peut lui
    // faire perdre l'invitation qu'il était en train de recevoir. Garder
    // l'écran allumé pendant le salon couvre le cas qu'elle visait.

    func ouvrir() {
        arreter()
        jHeberge = true
        demarrerSession()
        annoncer([Link.cleRole: Link.hote])
        // L'hôte cherche, lui aussi. Non pour trouver une table — il en tient
        // une — mais pour entendre les invités qui l'appellent quand leur
        // invitation ne passe pas. Voir `secourir`.
        chercherAutour()
        state = .ouvert
    }

    func chercher() {
        arreter()
        jHeberge = false
        demarrerSession()
        chercherAutour()
        state = .cherche
    }

    private func annoncer(_ info: [String: String]) {
        guard advertiser == nil else { return }
        advertiser = MCNearbyServiceAdvertiser(peer: moi, discoveryInfo: info,
                                               serviceType: Link.service)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    private func chercherAutour() {
        guard browser == nil else { return }
        browser = MCNearbyServiceBrowser(peer: moi, serviceType: Link.service)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func rejoindre(_ pair: MCPeerID, essai: Int = 1) {
        guard let session else { return }
        print("Riskelo — invitation envoyée à \(pair.displayName) (essai \(essai))")
        state = .invite(pair.displayName)
        // On s'annonce en nommant la table visée. Si notre invitation
        // n'aboutit pas, l'hôte pourra nous inviter à son tour — et lui seul :
        // aucune autre table ne verra son propre nom là-dedans.
        annoncer([Link.cleRole: Link.invite, Link.cleCible: pair.displayName])
        browser?.invitePeer(pair, to: session, withContext: nil, timeout: 20)
        // L'invitation expire sans que le système prévienne qui que ce soit :
        // l'écran serait resté sur « connexion… » pour toujours. On retente
        // une fois — une poignée de main manquée n'a rien d'exceptionnel — et
        // l'on conclut ensuite plutôt que d'attendre indéfiniment.
        attente?.cancel()
        attente = Task { [weak self] in
            // Plus long que l'invitation elle-même : relancer par-dessus une
            // invitation encore vivante en enverrait deux à la fois, et
            // l'annonceur d'en face en verrait deux du même appareil.
            try? await Task.sleep(for: .seconds(23))
            guard let self, !Task.isCancelled, case .invite = self.state else { return }
            if essai < 2 {
                self.rejoindre(pair, essai: essai + 1)
            } else {
                self.state = .refuse(pair.displayName)
            }
        }
    }

    /// Cesse d'accueillir : la table est complète.
    func fermerLaTable() {
        advertiser?.stopAdvertisingPeer(); advertiser = nil
        browser?.stopBrowsingForPeers(); browser = nil
    }

    func arreter() {
        attente?.cancel(); attente = nil
        secours.values.forEach { $0.cancel() }; secours = [:]
        fermerLaTable()
        session?.disconnect(); session = nil
        sessionPartagee = nil
        trouves = []
        relies = []
        state = .aLArret
    }

    private func demarrerSession() {
        // `.optional` et non `.required`.
        //
        // C'est le seul réglage de tout ce fichier qui puisse faire échouer
        // une liaison sans rien dire : deux appareils qui ne s'entendent pas
        // sur le chiffrement passent en « non relié » sans erreur, sans
        // message, et sans que rien distingue ce cas d'un appareil absent.
        // Apple emploie `.optional` dans ses propres exemples, et la liaison
        // reste chiffrée dès que les deux côtés le peuvent — ce qui est le cas
        // de tout appareil récent. On ne perd donc rien, et l'on retire une
        // cause d'échec muette.
        let s = MCSession(peer: moi, securityIdentity: nil, encryptionPreference: .optional)
        s.delegate = self
        session = s
        sessionPartagee = s
    }

    // MARK: - Envoyer

    /// En mode fiable : un coup perdu désynchroniserait les parties, et il n'y
    /// a pas assez de trafic pour que l'ordre coûte quoi que ce soit.
    func envoyer(_ data: Data) {
        guard let session, !session.connectedPeers.isEmpty else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    /// À un seul appareil : chacun doit apprendre son rang, et lui seul.
    func envoyer(_ data: Data, a pair: MCPeerID) {
        guard let session, session.connectedPeers.contains(pair) else { return }
        try? session.send(data, toPeers: [pair], with: .reliable)
    }

    /// À tous sauf un : c'est ainsi que l'hôte relaie le coup d'un joueur aux
    /// autres, sans le lui renvoyer.
    func envoyer(_ data: Data, saufA pair: MCPeerID) {
        guard let session else { return }
        let cibles = session.connectedPeers.filter { $0 != pair }
        guard !cibles.isEmpty else { return }
        try? session.send(data, toPeers: cibles, with: .reliable)
    }
}

// MARK: - Les rappels du système

extension Link: MCSessionDelegate {

    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID,
                             didChange state: MCSessionState) {
        let nom = peerID.displayName
        // Tracé dans la console de Xcode. C'est la seule fenêtre qui reste
        // quand la liaison échoue sur un appareil qu'on n'a pas sous la main :
        // la suite des états dit à quel moment exact elle renonce.
        let quoi = switch state {
        case .notConnected: "non relié"
        case .connecting:   "en cours"
        case .connected:    "relié"
        @unknown default:   "inconnu"
        }
        print("Riskelo — \(nom) : \(quoi)")
        Task { @MainActor in
            switch state {
            case .connected:
                self.attente?.cancel(); self.attente = nil
                self.secours[peerID]?.cancel(); self.secours[peerID] = nil
                if !self.relies.contains(peerID) { self.relies.append(peerID) }
                self.state = .relie(nom)
                // Qui rejoint a fini de chercher. Qui héberge accueille
                // jusqu'à ce que la table soit pleine — et **s'arrête là**,
                // au lieu de s'annoncer jusqu'au lancement.
                if !self.jHeberge || self.relies.count >= self.attendus {
                    self.fermerLaTable()
                }
                self.onConnected?(self.jHeberge, peerID)
            case .notConnected:
                self.relies.removeAll { $0 == peerID }
                if case .relie = self.state { self.state = .perdu(nom) }
                // Et surtout : on ne conclut **pas** pendant une invitation.
                //
                // J'avais mis ici un passage direct à l'échec, en croyant que
                // « non relié » voulait dire « refusé ». C'est faux :
                // MultipeerConnectivity annonce cet état au fil de la
                // négociation, pour un pair qui n'a encore jamais été relié et
                // qui va l'être une seconde plus tard. Conclure ici tuait des
                // liaisons qui allaient aboutir. Seul le délai conclut.
            default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data,
                             fromPeer peerID: MCPeerID) {
        Task { @MainActor in self.onReceive?(data, peerID) }
    }

    nonisolated func session(_ s: MCSession, didReceive stream: InputStream,
                             withName: String, fromPeer: MCPeerID) {}
    nonisolated func session(_ s: MCSession, didStartReceivingResourceWithName: String,
                             fromPeer: MCPeerID, with: Progress) {}
    nonisolated func session(_ s: MCSession, didFinishReceivingResourceWithName: String,
                             fromPeer: MCPeerID, at: URL?, withError: Error?) {}
}

extension Link: MCNearbyServiceAdvertiserDelegate {

    /// Le système n'a pas voulu ouvrir la table. Sans ce rappel, il ne se
    /// passait rien et rien ne le disait.
    nonisolated func advertiser(_ a: MCNearbyServiceAdvertiser,
                                didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            print("Riskelo — table impossible : \(error)")
            self.state = .refuse("")
        }
    }

    nonisolated func advertiser(_ a: MCNearbyServiceAdvertiser,
                                didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext: Data?,
                                invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("Riskelo — invitation reçue de \(peerID.displayName)")
        // Tout de suite, et sur le fil du rappel : voir `sessionPartagee`.
        // Celui qui ouvre accepte le premier qui se présente — à deux, il n'y
        // a rien à arbitrer.
        if let ouverte = sessionPartagee {
            invitationHandler(true, ouverte)
            return
        }
        // Si la référence manque, on ne refuse **pas** : on répond par
        // l'ancien chemin, en différé. Répondre tard vaut mieux que dire non —
        // un refus ferme la porte, un retard la laisse ouverte.
        Task { @MainActor in invitationHandler(true, self.session) }
    }
}

extension Link: MCNearbyServiceBrowserDelegate {

    nonisolated func browser(_ b: MCNearbyServiceBrowser,
                             didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            print("Riskelo — recherche impossible : \(error)")
            self.state = .refuse("")
        }
    }

    nonisolated func browser(_ b: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                             withDiscoveryInfo info: [String: String]?) {
        let role = info?[Link.cleRole], cible = info?[Link.cleCible]
        Task { @MainActor in
            switch role {
            case Link.invite:
                // Un invité qui appelle. Il ne nous regarde que s'il **nous**
                // nomme : sans cette condition, une table happerait les
                // invités des tables voisines.
                guard self.jHeberge, cible == self.moi.displayName else { return }
                self.secourir(peerID)

            default:
                // Une table. Elle n'intéresse que celui qui en cherche une.
                // Le cas sans rôle tombe ici aussi : seules les tables
                // s'annonçaient, autrefois.
                guard !self.jHeberge else { return }
                if !self.trouves.contains(peerID) { self.trouves.append(peerID) }
            }
        }
    }

    nonisolated func browser(_ b: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.trouves.removeAll { $0 == peerID }
            // Il ne nous appelle plus : le secours n'a plus d'objet.
            self.secours[peerID]?.cancel()
            self.secours[peerID] = nil
        }
    }

    /// Inviter un invité qui nous appelle, quand sa propre invitation
    /// n'aboutit pas.
    ///
    /// On attend d'abord. Le chemin normal — c'est l'invité qui invite —
    /// marche dans la grande majorité des cas, et deux invitations croisées
    /// valent mieux d'être évitées. Six secondes quand celle d'en face en dure
    /// vingt : s'il est encore là à s'annoncer, c'est que rien n'a abouti, et
    /// il reste largement le temps d'essayer l'autre sens avant que l'écran
    /// ne conclue à l'échec.
    private func secourir(_ pair: MCPeerID) {
        guard secours[pair] == nil, !relies.contains(pair) else { return }
        secours[pair] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard let self, !Task.isCancelled else { return }
            self.secours[pair] = nil
            guard let session = self.session, let browser = self.browser,
                  !self.relies.contains(pair), self.relies.count < self.attendus
            else { return }
            print("Riskelo — secours : invitation envoyée à \(pair.displayName)")
            browser.invitePeer(pair, to: session, withContext: nil, timeout: 20)
        }
    }
}

#if os(iOS)
import UIKit
#endif
