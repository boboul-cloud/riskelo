//
//  Link.swift
//  Riskelo
//
//  Le fil entre deux appareils.
//
//  Bonjour pour se trouver, TCP pour se parler — par le framework Network.
//
//  C'était MultipeerConnectivity, et cela paraissait le choix évident : il
//  prend le Bluetooth et le Wi-Fi direct sans qu'on ait à choisir, ne demande
//  ni compte ni réseau, et marche dans un train.
//
//  Il avait un défaut qu'aucun réglage ne corrige. Sa session de jeu n'accepte
//  QUE le Wi-Fi direct — le journal du système le dit mot pour mot :
//  « use awdl, prohibit fallback ». Or le Wi-Fi direct est interdit sur les
//  canaux 5 GHz dits « radar » (52 à 140), que les box choisissent toutes
//  seules et changent sans prévenir. Sur un tel canal, la découverte marche,
//  l'invitation passe, et la partie ne démarre jamais : « Sendmsg failed with
//  error No route to host », dix fois, puis l'abandon. Mesuré ici, sur le
//  canal 104, entre un Mac et un iPhone qui se pinguaient parfaitement.
//
//  Un joueur n'a ni les journaux, ni la main sur sa box. Faire dépendre le jeu
//  d'une condition qu'il ne peut ni voir ni corriger n'était pas tenable.
//
//  D'où ce fil-ci. La découverte reste Bonjour, exactement la même ; les
//  données passent par une connexion TCP ordinaire. `includePeerToPeer` reste
//  allumé, donc le Wi-Fi direct sert encore quand il est là — dans un train,
//  sans aucune box. Mais il devient un bonus au lieu d'être une exigence.
//
//  Et toute la danse des invitations disparaît avec lui. Il n'y a plus
//  d'invitation à accepter, plus de secours à envoyer six secondes plus tard,
//  plus de rôles à rendre symétriques, plus de délai de quarante-six secondes
//  au bout duquel on renonce : celui qui rejoint ouvre une connexion, et elle
//  aboutit ou elle échoue. Une famille entière de pannes s'en va avec.
//
//  Ce fichier ne connaît rien au jeu : il transporte des paquets d'octets et
//  dit qui est là. Ce qui circule dedans est l'affaire de `Match`.
//

import Foundation
import Network
#if os(iOS)
import UIKit
#endif

/// Un appareil au bout du fil.
///
/// Deux appareils sont le même si leur identité est la même. Le nom, lui, ne
/// distingue rien : depuis iOS 16 tous les iPhone s'appellent « iPhone » pour
/// qui n'a pas l'autorisation d'en demander plus.
struct Pair: Hashable, Sendable {
    /// Gardée d'un lancement sur l'autre. Voir `Link.identite()`.
    let id: String
    /// Ce qu'on montre à l'écran.
    let nom: String

    static func == (a: Pair, b: Pair) -> Bool { a.id == b.id }
    func hash(into hacheur: inout Hasher) { hacheur.combine(id) }
}

@Observable
@MainActor
final class Link {

    /// Le nom du service. Quinze caractères au plus, minuscules et tirets :
    /// c'est une contrainte de Bonjour, pas un goût.
    nonisolated static let service = "riskelo-jeu"

    /// Ce que l'hôte dit de lui dans son annonce.
    ///
    /// Les clés sont courtes parce que tout ceci voyage dans un enregistrement
    /// Bonjour, qui est petit. Seul l'hôte s'annonce désormais : celui qui
    /// rejoint n'a plus rien à faire savoir à personne, il se connecte.
    nonisolated static let cleRole = "r", cleNom = "n", cleId = "i"
    /// Où joindre l'hôte, sans rien avoir à demander à personne.
    ///
    /// Laisser le système résoudre un service Bonjour paraissait naturel, et
    /// c'était le chemin le plus court sur le papier. Sur l'iPhone de Robert,
    /// il ne menait nulle part : la table se voyait, son adresse ne s'obtenait
    /// jamais, et la connexion restait « en préparation » jusqu'au délai —
    /// sans erreur, sans rien à quoi se raccrocher.
    ///
    /// Or le même iPhone atteignait le Mac en une seconde depuis Safari, et
    /// le journal du serveur l'a confirmé de l'autre bout : ses paquets
    /// arrivent, en IPv4 comme en IPv6. C'est la résolution du *service* qui
    /// ne passe pas, rien d'autre. On annonce donc où l'on est, et l'invité
    /// s'y rend sans avoir de question à poser.
    ///
    /// Une **adresse**, et non un nom d'hôte. J'ai essayé le nom, pris de
    /// `ProcessInfo.hostName` : sur le Mac il rend « macbook-air-de-robert
    /// .local », mais sur l'iPad il rend « customer.lndngbr1.isp.starlink.com »
    /// — le nom que le fournisseur d'accès attribue à la connexion. Y coller
    /// « .local » donnait une adresse qui ne désigne rien. Une adresse IP, au
    /// moins, ne se devine pas : elle se lit.
    nonisolated static let cleAdresse = "a", clePort = "p"
    nonisolated static let hote = "h"

    enum State: Equatable {
        case aLArret
        /// On tient une table et l'on attend qu'on vienne.
        case ouvert
        /// On cherche qui en tient une.
        case cherche
        /// La connexion est partie, on attend qu'elle aboutisse.
        case invite(String)
        case relie(String)
        case perdu(String)
        /// Le système a refusé d'ouvrir le réseau, ou la connexion n'a pas
        /// abouti.
        case refuse(String)
        /// Le système coupe l'accès au réseau local à cette application.
        ///
        /// Il le dit d'une seule façon, et de très loin : « Network is down »
        /// sur une adresse pourtant valide et joignable. Rien à l'écran, rien
        /// dans les réglages qui saute aux yeux — l'autorisation « réseau
        /// local » se refuse une fois et ne se redemande jamais. Sans ce cas,
        /// le joueur ne voyait que « n'a pas répondu » et cherchait du côté
        /// de son Wi-Fi, où il n'y avait rien à trouver.
        case sansAutorisation
    }

    private(set) var state: State = .aLArret
    /// Les tables trouvées autour, pour le joueur qui cherche.
    private(set) var trouves: [Pair] = []
    /// Les appareils reliés, dans l'ordre où ils sont arrivés : c'est cet
    /// ordre qui décide des rangs.
    private(set) var relies: [Pair] = []

    var jeSuisLHote: Bool { jHeberge }

    /// Ce qui arrive d'un autre appareil, et de qui.
    var onReceive: ((Data, Pair) -> Void)?
    /// Appelé à chaque appareil relié, avec `true` si c'est nous qui avons
    /// ouvert la partie. À quatre, il est appelé trois fois.
    var onConnected: ((Bool, Pair) -> Void)?

    /// Combien d'appareils l'hôte attend en tout, lui non compris.
    /// Il cesse d'annoncer dès que la table est pleine.
    var attendus = 1

    /// Notre identité sur le fil.
    let moi = Link.identite()

    /// Sommes-nous sur un réseau ?
    ///
    /// Toute la question du Wi-Fi direct tient là. Une écoute qui l'active
    /// s'annonce sous un nom d'hôte en forme d'identifiant — mesuré ici :
    /// « 49f8cb31-8eb0-….local » au lieu de « MacBook-Air-de-Robert.local »,
    /// et c'est `includePeerToPeer` seul qui en décide. Or ce nom-là ne se
    /// résout pas toujours par le réseau ordinaire : l'invité reste alors
    /// bloqué en préparation, sans erreur, jusqu'à ce que le délai tranche.
    /// Il trouve la table et n'atteint jamais son adresse.
    ///
    /// D'où la règle : **le direct ne sert que faute de réseau**. Dans un
    /// train il est le seul chemin ; sur un réseau il ne fait que nuire.
    @ObservationIgnored private let veilleur = NWPathMonitor()
    private var surUnReseau = true

    init() {
        veilleur.pathUpdateHandler = { [weak self] chemin in
            let dessus = chemin.status == .satisfied
                && (chemin.usesInterfaceType(.wifi)
                    || chemin.usesInterfaceType(.wiredEthernet))
            MainActor.assumeIsolated { self?.surUnReseau = dessus }
        }
        veilleur.start(queue: .main)
    }

    deinit { veilleur.cancel() }

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var jHeberge = false
    /// La table est tenue — même quand on a cessé d'accueillir parce qu'elle
    /// était pleine. Elle ne se referme pour de bon qu'au lancement.
    private var tableOuverte = false

    /// Les canaux ouverts, par appareil.
    private var canaux: [Pair: Canal] = [:]
    /// Les canaux qui n'ont pas encore dit qui ils sont. Un invité qui arrive
    /// est d'abord un inconnu : c'est son salut qui le nomme.
    private var anonymes: [Canal] = []
    /// Où joindre chaque table trouvée.
    private var adresses: [Pair: NWEndpoint] = [:]
    /// La même, en adresse IP nue — pour le témoin seulement. Voir `temoin`.
    private var adressesBrutes: [Pair: NWEndpoint] = [:]
    /// Le délai d'une connexion en cours.
    private var attente: Task<Void, Never>?

    /// Les réglages du transport.
    ///
    /// `includePeerToPeer` laisse le Wi-Fi direct disponible — c'est lui qui
    /// permet de jouer sans box du tout, dans un train. La différence avec
    /// MultipeerConnectivity tient en un mot : ici il est *permis*, là il
    /// était *exigé*.
    ///
    /// Mais permis ne suffit pas : quand les deux chemins existent, le système
    /// peut choisir le Wi-Fi direct — et celui-ci est interdit sur les canaux
    /// 5 GHz radar, où il échoue en silence. On ouvre donc la découverte aux
    /// deux, et l'on tente la connexion **par le réseau d'abord**, le Wi-Fi
    /// direct n'étant essayé qu'ensuite. Le cas courant passe par le chemin
    /// sûr ; le train reste possible.
    private static func reglages(direct: Bool = true) -> NWParameters {
        let p = NWParameters.tcp
        p.includePeerToPeer = direct
        // On n'interdit aucune interface.
        //
        // J'avais interdit la cellulaire, en me disant qu'une partie se joue
        // dans la même pièce et que ce chemin ne mène nulle part. C'était une
        // intuition, posée sans preuve, et elle a coûté cher : le système
        // répondait alors « Network is down » — il ne restait plus aucun
        // chemin qu'il s'autorise à prendre. Interdire un chemin inutile
        // revenait à les fermer tous. On laisse le système choisir : il sait
        // très bien qu'un nom en « .local » ne s'atteint pas par la cellulaire.
        // Une partie ne supporte pas qu'un coup attende : sans cela, TCP
        // regroupe les petits envois et retarde les plus pressés.
        if let tcp = p.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcp.noDelay = true
            // Une liaison morte doit se voir, sinon l'écran attend un joueur
            // qui est parti depuis longtemps.
            // Une liaison morte doit se voir, mais sans précipitation :
            // cinq secondes de silence, c'est un tour de jeu ordinaire.
            tcp.enableKeepalive = true
            tcp.keepaliveIdle = 20
        }
        return p
    }

    /// L'identité de cet appareil, **gardée d'un lancement sur l'autre**.
    ///
    /// Elle ne sert plus qu'à se reconnaître d'un bout à l'autre du fil, mais
    /// elle doit rester stable : deux appareils qui changeraient d'identité en
    /// cours de route se compteraient deux fois.
    static func identite() -> Pair {
        let reglages = UserDefaults.standard
        let cle = "riskelo.identite"
        let id: String
        if let gardee = reglages.string(forKey: cle), !gardee.isEmpty {
            id = gardee
        } else {
            id = UUID().uuidString
            reglages.set(id, forKey: cle)
        }
        return Pair(id: id, nom: Link.nomDeLAppareil)
    }

    /// L'adresse de cette machine sur le réseau local, s'il y en a une.
    ///
    /// La première adresse IPv4 d'une interface « en… » — le Wi-Fi ou
    /// l'Ethernet. Rien à deviner : on la lit dans le système.
    ///
    /// `nil` quand il n'y a pas de réseau. C'est exactement le cas où le
    /// Wi-Fi direct prend le relais, et où l'invité doit repasser par la
    /// résolution du service : là, aucune adresse fixe n'aurait de sens.
    static var adresseLocale: String? {
        var liste: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&liste) == 0, let debut = liste else { return nil }
        defer { freeifaddrs(liste) }
        var courante: UnsafeMutablePointer<ifaddrs>? = debut
        while let ptr = courante {
            let carte = ptr.pointee
            courante = carte.ifa_next
            let nom = String(cString: carte.ifa_name)
            let drapeaux = Int32(carte.ifa_flags)
            guard let adresse = carte.ifa_addr,
                  drapeaux & IFF_UP != 0,
                  drapeaux & IFF_LOOPBACK == 0,
                  adresse.pointee.sa_family == UInt8(AF_INET),
                  nom.hasPrefix("en")
            else { continue }
            var tampon = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(adresse, socklen_t(adresse.pointee.sa_len),
                              &tampon, socklen_t(tampon.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            return String(cString: tampon)
        }
        return nil
    }

    /// Le nom que porte l'appareil.
    ///
    /// Il n'est plus `nonisolated`. Il l'était du temps de
    /// MultipeerConnectivity, dont les rappels arrivaient sur leur propre fil
    /// et devaient pouvoir le lire. Plus rien ne le lit désormais hors de
    /// l'acteur principal — et `UIDevice.current` y est justement tenu.
    static var nomDeLAppareil: String {
        #if os(iOS)
        String(UIDevice.current.name.prefix(30))
        #else
        String((Host.current().localizedName ?? "Mac").prefix(30))
        #endif
    }

    // MARK: - Ouvrir, chercher, raccrocher

    /// Tenir une table : on écoute, et l'on s'annonce.
    func ouvrir() {
        arreter()
        jHeberge = true
        tableOuverte = true
        demarrerEcoute()
    }

    /// Écouter, et s'annoncer. Refait tel quel si la table rouvre.
    private func demarrerEcoute() {
        guard listener == nil else { return }
        do {
            // Le direct seulement s'il n'y a pas de réseau : voir
            // `surUnReseau`. C'est ce choix qui décide du nom annoncé, et donc
            // de la capacité de l'invité à nous atteindre.
            let direct = !surUnReseau
            print("Riskelo — table ouverte " + (direct ? "en Wi-Fi direct" : "sur le réseau"))
            let ecoute = try NWListener(using: Link.reglages(direct: direct))
            ecoute.service = annonce(port: nil)
            ecoute.stateUpdateHandler = { [weak self] etat in
                MainActor.assumeIsolated { self?.listenerAChange(etat) }
            }
            ecoute.newConnectionHandler = { [weak self] connexion in
                MainActor.assumeIsolated { self?.accueillir(connexion) }
            }
            listener = ecoute
            ecoute.start(queue: .main)
            state = .ouvert
        } catch {
            print("Riskelo — table impossible : \(error)")
            state = .refuse("")
        }
    }

    /// Chercher une table.
    func chercher() {
        arreter()
        jHeberge = false
        direCeQuOnVoit()
        // La même règle que pour l'écoute, et pour la même raison : chercher
        // en mode Wi-Fi direct rapporte des adresses taillées pour ce
        // chemin-là. Sur un réseau, c'est le réseau qu'il faut interroger.
        let cherche = NWBrowser(for: .bonjourWithTXTRecord(type: "_\(Link.service)._tcp",
                                                           domain: nil),
                                using: Link.reglages(direct: !surUnReseau))
        cherche.stateUpdateHandler = { [weak self] etat in
            MainActor.assumeIsolated { self?.browserAChange(etat) }
        }
        cherche.browseResultsChangedHandler = { [weak self] trouvailles, _ in
            MainActor.assumeIsolated { self?.tablesVues(trouvailles) }
        }
        browser = cherche
        cherche.start(queue: .main)
        state = .cherche
    }

    /// Rejoindre une table : on ouvre une connexion, et c'est tout.
    ///
    /// Il n'y a plus d'invitation à faire accepter, donc plus rien qui puisse
    /// rester sans réponse. Ou la connexion aboutit, ou elle échoue et le dit.
    /// Rejoindre une table : on ouvre une connexion, et c'est tout.
    ///
    /// Un seul essai, par le même chemin que l'hôte a choisi — le réseau s'il
    /// y en a un, le Wi-Fi direct sinon. Il y en avait deux : le réseau
    /// d'abord, le direct six secondes plus tard. Cette seconde tentative
    /// partait par-dessus la première au moment précis où celle-ci aboutissait,
    /// et la fermait. L'hôte voyait sa liaison coupée net — « Connection reset
    /// by peer » — juste après l'avoir acceptée. Une course que rien
    /// n'obligeait à courir : les deux côtés appliquent déjà la même règle.
    func rejoindre(_ pair: Pair) {
        guard let ou = adresses[pair] else { return }
        let direct = !surUnReseau
        print("Riskelo — connexion vers \(pair.nom) "
              + (direct ? "en Wi-Fi direct" : "sur le réseau") + " → \(ou)")
        state = .invite(pair.nom)
        if let brute = adressesBrutes[pair] { Link.temoin(vers: brute) }
        let connexion = NWConnection(to: ou, using: Link.reglages(direct: direct))
        ouvrirCanal(connexion, attendu: pair)
        // TCP peut mettre longtemps à renoncer, et l'écran serait resté sur
        // « connexion… » sans rien dire. On tranche nous-mêmes.
        attente?.cancel()
        attente = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard let self, !Task.isCancelled, case .invite = self.state else { return }
            print("Riskelo — \(pair.nom) n'a pas répondu")
            self.state = .refuse(pair.nom)
        }
    }

    /// Une connexion témoin, vers l'**adresse IP nue** de l'hôte.
    ///
    /// Elle ne sert qu'à vérifier une chose, à chaque tentative : qu'iOS
    /// refuse bien ce chemin-là alors qu'il accorde le service déclaré. Si un
    /// jour elle réussit, c'est que la règle a changé.
    ///
    /// Elle n'envoie rien et se ferme au bout de cinq secondes.
    static func temoin(vers ou: NWEndpoint) {
        let t = NWConnection(to: ou, using: .tcp)
        t.stateUpdateHandler = { etat in
            switch etat {
            case .ready:
                print("Riskelo — TÉMOIN (réglages d'Apple) : RELIÉ ✅")
                t.cancel()
            case .waiting(let e):
                let c = t.currentPath
                print("Riskelo — TÉMOIN en attente : \(e)"
                      + " | raison : \(String(describing: c?.unsatisfiedReason))")
            case .failed(let e):
                print("Riskelo — TÉMOIN échoué : \(e)")
            default:
                break
            }
        }
        t.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { t.cancel() }
    }

    /// Ce que cet appareil voit du réseau, en toutes lettres.
    ///
    /// À comparer d'un appareil à l'autre : c'est le seul endroit où un
    /// iPhone et un iPad peuvent différer alors qu'ils exécutent le même code.
    private func direCeQuOnVoit() {
        let c = veilleur.currentPath
        print("""
            Riskelo — état du réseau vu par \(moi.nom) :
              statut       : \(String(describing: c.status))
              raison       : \(String(describing: c.unsatisfiedReason))
              wifi         : \(c.usesInterfaceType(.wifi))
              ethernet     : \(c.usesInterfaceType(.wiredEthernet))
              cellulaire   : \(c.usesInterfaceType(.cellular))
              interfaces   : \(c.availableInterfaces.map { "\($0.name)(\($0.type))" }.joined(separator: ", "))
              sur un réseau: \(surUnReseau)
            """)
    }

    /// Cesse d'accueillir, sans renoncer à la table.
    ///
    /// Les connexions déjà ouvertes n'en souffrent pas — arrêter d'écouter ne
    /// coupe rien de ce qui est établi.
    private func cesserDAccueillir() {
        listener?.cancel(); listener = nil
        browser?.cancel(); browser = nil
    }

    /// Ferme la table pour de bon : la partie commence, on n'attend plus
    /// personne.
    func fermerLaTable() {
        tableOuverte = false
        cesserDAccueillir()
    }

    /// Rouvrir, parce qu'une place s'est libérée avant le lancement.
    ///
    /// Sans cela, un invité qui se relie puis repart — il quitte le salon, ou
    /// son application passe en arrière-plan — laissait l'hôte muré : il avait
    /// cessé d'écouter en se croyant complet, et ne recommençait jamais. La
    /// table restait pourtant annoncée, donc visible : on la voyait, on la
    /// touchait, et rien n'aboutissait plus jamais.
    private func rouvrirLaTable() {
        guard jHeberge, tableOuverte, relies.count < attendus else { return }
        print("Riskelo — une place s'est libérée, la table rouvre")
        demarrerEcoute()
    }

    func arreter() {
        attente?.cancel(); attente = nil
        tableOuverte = false
        cesserDAccueillir()
        canaux.values.forEach { $0.fermer() }
        canaux = [:]
        anonymes.forEach { $0.fermer() }
        anonymes = []
        adresses = [:]
        adressesBrutes = [:]
        trouves = []
        relies = []
        state = .aLArret
    }

    // MARK: - Ce que le système nous dit

    /// Ce que l'hôte dit de lui. Le port n'est connu qu'une fois l'écoute
    /// prête : l'annonce se refait alors, complète.
    private func annonce(port: NWEndpoint.Port?) -> NWListener.Service {
        var txt = NWTXTRecord()
        txt[Link.cleRole] = Link.hote
        txt[Link.cleNom] = moi.nom
        txt[Link.cleId] = moi.id
        if let port, let ou = Link.adresseLocale {
            txt[Link.cleAdresse] = ou
            txt[Link.clePort] = String(port.rawValue)
        }
        // Le nom d'instance Bonjour doit être unique sur le réseau ; celui de
        // l'appareil ne l'est pas (tous les iPhone s'appellent « iPhone »). On
        // y joint donc un fragment de notre identité.
        return NWListener.Service(name: "\(moi.nom) \(moi.id.prefix(4))",
                                  type: "_\(Link.service)._tcp",
                                  txtRecord: txt)
    }

    private func listenerAChange(_ etat: NWListener.State) {
        switch etat {
        case .ready:
            // Le port est connu : on redit qui l'on est, adresse comprise.
            if let ecoute = listener, let port = ecoute.port {
                print("Riskelo — table prête sur \(Link.adresseLocale ?? "sans adresse"):\(port)")
                ecoute.service = annonce(port: port)
            }
        case .failed(let erreur):
            // Presque toujours l'autorisation « réseau local ».
            print("Riskelo — table impossible : \(erreur)")
            state = .refuse("")
        case .cancelled:
            break
        default:
            break
        }
    }

    private func browserAChange(_ etat: NWBrowser.State) {
        if case .failed(let erreur) = etat {
            print("Riskelo — recherche impossible : \(erreur)")
            state = .refuse("")
        }
    }

    /// Les tables vues autour de nous.
    private func tablesVues(_ trouvailles: Set<NWBrowser.Result>) {
        var vues: [Pair] = []
        var ou: [Pair: NWEndpoint] = [:]
        for t in trouvailles {
            guard case let .bonjour(txt) = t.metadata,
                  txt[Link.cleRole] == Link.hote,
                  let id = txt[Link.cleId], !id.isEmpty
            else { continue }
            // Ne jamais se proposer à soi-même.
            guard id != moi.id else { continue }
            let pair = Pair(id: id, nom: txt[Link.cleNom] ?? "Appareil")
            print("Riskelo — table vue : \(t.endpoint)"
                  + " par [\(t.interfaces.map(\.name).joined(separator: ", "))]")
            if !vues.contains(pair) { vues.append(pair) }
            print("Riskelo — table vue : \(t.endpoint)"
                  + " par [\(t.interfaces.map(\.name).joined(separator: ", "))]")

            // **Le service, et non l'adresse.**
            //
            // iOS n'accorde pas à une application « le réseau local » en bloc :
            // il lui accorde les services qu'elle a déclarés dans
            // `NSBonjourServices`. Une adresse IP nue ne figure dans aucune
            // déclaration, et se fait refuser — `localNetworkDenied` — quand
            // bien même l'interrupteur des Réglages est vert.
            //
            // J'étais passé à l'adresse pour contourner une résolution qui
            // paraissait bloquée. Elle ne l'était pas : ce qui bloquait, c'était
            // un nom d'hôte inventé, des adresses clouées à la mauvaise
            // interface, et deux connexions qui se coupaient l'une l'autre —
            // trois défauts corrigés depuis. En passant à l'adresse IP, j'avais
            // troqué le chemin autorisé contre un chemin interdit.
            //
            // **Sans l'interface** : Bonjour trouve la même table une fois par
            // interface, et l'adresse qu'il rend est clouée à celle par
            // laquelle il l'a vue. Détachée, c'est au système de choisir.
            if case let .service(nom, type, domaine, _) = t.endpoint {
                ou[pair] = .service(name: nom, type: type, domain: domaine, interface: nil)
            } else {
                ou[pair] = t.endpoint
            }
            // L'adresse annoncée ne sert plus qu'au témoin, qui vérifie à
            // chaque tentative que ce chemin-là reste bien le mauvais.
            if let brute = txt[Link.cleAdresse], !brute.isEmpty,
               let n = txt[Link.clePort], let numero = UInt16(n),
               let port = NWEndpoint.Port(rawValue: numero) {
                adressesBrutes[pair] = .hostPort(host: NWEndpoint.Host(brute), port: port)
            }
        }
        adresses = ou
        trouves = vues
    }

    /// Un invité se présente à notre table.
    private func accueillir(_ connexion: NWConnection) {
        guard relies.count < attendus else {
            // La table est pleine : refuser franchement plutôt que de laisser
            // une connexion ouverte que personne ne lira.
            connexion.cancel()
            return
        }
        ouvrirCanal(connexion, attendu: nil)
    }

    // MARK: - Les canaux

    private func ouvrirCanal(_ connexion: NWConnection, attendu: Pair?) {
        let canal = Canal(connexion: connexion)
        anonymes.append(canal)
        canal.onPret = { [weak self, weak canal] in
            guard let self, let canal else { return }
            // Chacun dit qui il est dès que le fil est ouvert. Sans cela,
            // celui qui accepte une connexion ne saurait jamais qui vient
            // d'arriver : une adresse n'est pas une identité.
            canal.envoyer(self.salut())
        }
        canal.onPaquet = { [weak self, weak canal] data in
            guard let self, let canal else { return }
            self.recu(data, sur: canal, attendu: attendu)
        }
        canal.onInterdit = { [weak self] in
            guard let self else { return }
            self.attente?.cancel(); self.attente = nil
            self.state = .sansAutorisation
        }
        canal.onFerme = { [weak self, weak canal] in
            guard let self, let canal else { return }
            self.canalFerme(canal)
        }
        canal.demarrer()
    }

    /// Notre carte de visite : l'identité et le nom, rien d'autre.
    ///
    /// Elle voyage dans son propre paquet, devant tout le reste, et ne change
    /// jamais de forme — c'est le seul contrat que toutes les versions à venir
    /// doivent tenir sur ce fil-ci. Le dialecte du jeu, lui, est l'affaire de
    /// `Match`, et il se négocie après.
    private func salut() -> Data {
        let carte = ["id": moi.id, "nom": moi.nom]
        return (try? JSONSerialization.data(withJSONObject: carte)) ?? Data()
    }

    private func recu(_ data: Data, sur canal: Canal, attendu: Pair?) {
        // Tant qu'il ne s'est pas nommé, tout ce qui arrive est son salut.
        if canal.pair == nil {
            guard let carte = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let id = carte["id"], !id.isEmpty
            else {
                print("Riskelo — un appareil s'est présenté sans se nommer")
                canal.fermer()
                return
            }
            let pair = Pair(id: id, nom: carte["nom"] ?? "Appareil")
            // Si l'on visait quelqu'un, c'est bien lui qu'on doit trouver.
            if let attendu, attendu != pair {
                print("Riskelo — attendu \(attendu.nom), reçu \(pair.nom)")
                canal.fermer()
                return
            }
            nommer(canal, pair)
            return
        }
        guard let pair = canal.pair else { return }
        onReceive?(data, pair)
    }

    /// Un canal vient de dire qui il est : la liaison est faite.
    private func nommer(_ canal: Canal, _ pair: Pair) {
        anonymes.removeAll { $0 === canal }
        // Deux fils vers le même appareil : garder le premier.
        if canaux[pair] != nil {
            canal.fermer()
            return
        }
        canal.pair = pair
        canaux[pair] = canal
        if !relies.contains(pair) { relies.append(pair) }
        attente?.cancel(); attente = nil
        state = .relie(pair.nom)
        print("Riskelo — \(pair.nom) : relié")
        // Qui rejoint a fini de chercher. Qui héberge accueille jusqu'à ce que
        // la table soit pleine, et s'arrête là.
        if !jHeberge || relies.count >= attendus { cesserDAccueillir() }
        onConnected?(jHeberge, pair)
    }

    private func canalFerme(_ canal: Canal) {
        anonymes.removeAll { $0 === canal }
        guard let pair = canal.pair else {
            // Il n'a jamais dit son nom : c'est une connexion qui n'a pas
            // abouti. Seul le délai conclut, pour ne pas tuer une liaison qui
            // allait se faire.
            return
        }
        guard canaux[pair] === canal else { return }
        canaux[pair] = nil
        relies.removeAll { $0 == pair }
        print("Riskelo — \(pair.nom) : liaison perdue")
        if case .relie = state { state = .perdu(pair.nom) }
        rouvrirLaTable()
    }

    // MARK: - Envoyer

    /// À tous. Un coup perdu désynchroniserait les parties : TCP garantit
    /// l'ordre et la livraison, il n'y a rien à ajouter.
    func envoyer(_ data: Data) {
        canaux.values.forEach { $0.envoyer(data) }
    }

    /// À un seul appareil : chacun doit apprendre son rang, et lui seul.
    func envoyer(_ data: Data, a pair: Pair) {
        canaux[pair]?.envoyer(data)
    }

    /// À tous sauf un : c'est ainsi que l'hôte relaie le coup d'un joueur aux
    /// autres, sans le lui renvoyer.
    func envoyer(_ data: Data, saufA pair: Pair) {
        for (qui, canal) in canaux where qui != pair { canal.envoyer(data) }
    }
}

private extension NWError {
    /// « Network is down » sur une adresse du réseau local ne veut pas dire
    /// que le réseau est coupé — on vient de l'atteindre par ailleurs. Cela
    /// veut dire que le système le ferme **à cette application**.
    var estUnRefusDeReseauLocal: Bool {
        if case let .posix(code) = self { return code == .ENETDOWN }
        return false
    }
}

// MARK: - Un canal, et ses paquets

/// Une connexion TCP, et de quoi y faire passer des paquets entiers.
///
/// TCP est un flot d'octets : il ne connaît pas les messages. Deux envois
/// peuvent arriver collés, un seul peut arriver coupé en deux. Chaque paquet
/// part donc précédé de sa longueur sur quatre octets, et l'on ne remonte un
/// paquet que lorsqu'il est là tout entier. Sans cela, un message sur deux
/// serait illisible — et la panne ressemblerait à un désaccord de version.
@MainActor
private final class Canal {

    let connexion: NWConnection
    var pair: Pair?

    var onPret: (() -> Void)?
    /// Le système nous ferme le réseau local. Voir `State.sansAutorisation`.
    var onInterdit: (() -> Void)?
    var onPaquet: ((Data) -> Void)?
    var onFerme: (() -> Void)?

    /// Ce qui est arrivé mais pas encore complet.
    private var tampon = Data()
    private var ferme = false

    /// Au-delà, ce n'est plus un paquet du jeu : la partie entière tient très
    /// largement dans cette taille, et une longueur aberrante ne peut venir
    /// que d'un flot désaligné.
    private static let tailleMax = 8 * 1024 * 1024

    init(connexion: NWConnection) { self.connexion = connexion }

    func demarrer() {
        connexion.stateUpdateHandler = { [weak self] etat in
            MainActor.assumeIsolated {
                guard let self else { return }
                switch etat {
                case .ready:
                    self.onPret?()
                    self.lire()
                case .preparing:
                    print("Riskelo — canal en préparation")
                case .waiting(let erreur):
                    // L'état qui manquait au journal. Une connexion qui
                    // n'aboutit pas ne « échoue » pas : elle *attend*, en
                    // gardant sa raison pour elle.
                    //
                    // Et « Network is down » ne dit pas *laquelle* de ses
                    // raisons. Le système en tient pourtant le compte exact —
                    // autorisation refusée, Wi-Fi refusé, rien de disponible —
                    // dans `NWPath.unsatisfiedReason`. C'est le seul endroit
                    // où il nomme la cause, et c'est celui-là qu'il faut lire.
                    let chemin = self.connexion.currentPath
                    print("""
                        Riskelo — canal en attente : \(erreur)
                          état du chemin : \(String(describing: chemin?.status))
                          raison         : \(String(describing: chemin?.unsatisfiedReason))
                          interfaces     : \(chemin?.availableInterfaces.map(\.name).joined(separator: ", ") ?? "aucune")
                          coûteux/limité : \(String(describing: chemin?.isExpensive)) / \(String(describing: chemin?.isConstrained))
                        """)
                    if chemin?.unsatisfiedReason == .localNetworkDenied
                        || erreur.estUnRefusDeReseauLocal {
                        self.onInterdit?()
                    }
                case .failed(let erreur):
                    print("Riskelo — canal rompu : \(erreur)")
                    self.fermer()
                case .cancelled:
                    self.prevenirDeLaFermeture()
                default:
                    break
                }
            }
        }
        connexion.start(queue: .main)
    }

    func envoyer(_ data: Data) {
        guard !ferme else { return }
        var longueur = UInt32(data.count).bigEndian
        var paquet = Data(bytes: &longueur, count: 4)
        paquet.append(data)
        connexion.send(content: paquet, completion: .contentProcessed { erreur in
            if let erreur {
                print("Riskelo — paquet non envoyé : \(erreur)")
            }
        })
    }

    func fermer() {
        guard !ferme else { return }
        ferme = true
        connexion.cancel()
        onFerme?()
    }

    private func prevenirDeLaFermeture() {
        guard !ferme else { return }
        ferme = true
        onFerme?()
    }

    private func lire() {
        connexion.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) {
            [weak self] morceau, _, fini, erreur in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let morceau, !morceau.isEmpty {
                    self.tampon.append(morceau)
                    self.decouper()
                }
                if let erreur {
                    print("Riskelo — lecture interrompue : \(erreur)")
                    self.fermer()
                    return
                }
                if fini { self.fermer(); return }
                guard !self.ferme else { return }
                self.lire()
            }
        }
    }

    /// Remonte tous les paquets entiers présents dans le tampon.
    private func decouper() {
        while tampon.count >= 4 {
            let longueur = tampon.prefix(4).reduce(0) { Int($0) << 8 | Int($1) }
            guard longueur > 0, longueur <= Canal.tailleMax else {
                print("Riskelo — longueur de paquet aberrante (\(longueur))")
                fermer()
                return
            }
            guard tampon.count >= 4 + longueur else { return }
            let corps = tampon.subdata(in: 4 ..< (4 + longueur))
            tampon.removeSubrange(0 ..< (4 + longueur))
            onPaquet?(corps)
        }
    }
}
