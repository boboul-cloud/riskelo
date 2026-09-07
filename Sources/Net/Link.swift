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
        /// abouti. Presque toujours l'autorisation « réseau local », qui se
        /// refuse une fois et ne se redemande jamais.
        case refuse(String)
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

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var jHeberge = false

    /// Les canaux ouverts, par appareil.
    private var canaux: [Pair: Canal] = [:]
    /// Les canaux qui n'ont pas encore dit qui ils sont. Un invité qui arrive
    /// est d'abord un inconnu : c'est son salut qui le nomme.
    private var anonymes: [Canal] = []
    /// Où joindre chaque table trouvée.
    private var adresses: [Pair: NWEndpoint] = [:]
    /// Le délai d'une connexion en cours.
    private var attente: Task<Void, Never>?

    /// Les réglages du transport, les mêmes des deux côtés.
    ///
    /// `includePeerToPeer` laisse le Wi-Fi direct disponible quand il marche —
    /// c'est lui qui permet de jouer sans box du tout. La différence avec
    /// MultipeerConnectivity tient en un mot : ici il est *permis*, là il
    /// était *exigé*.
    private static func reglages() -> NWParameters {
        let p = NWParameters.tcp
        p.includePeerToPeer = true
        // Une partie ne supporte pas qu'un coup attende : sans cela, TCP
        // regroupe les petits envois et retarde les plus pressés.
        if let tcp = p.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcp.noDelay = true
            // Une liaison morte doit se voir, sinon l'écran attend un joueur
            // qui est parti depuis longtemps.
            tcp.enableKeepalive = true
            tcp.keepaliveIdle = 5
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
        do {
            let ecoute = try NWListener(using: Link.reglages())
            var txt = NWTXTRecord()
            txt[Link.cleRole] = Link.hote
            txt[Link.cleNom] = moi.nom
            txt[Link.cleId] = moi.id
            // Le nom d'instance Bonjour doit être unique sur le réseau ; celui
            // de l'appareil ne l'est pas (tous les iPhone s'appellent
            // « iPhone »). On y joint donc un fragment de notre identité.
            let instance = "\(moi.nom) \(moi.id.prefix(4))"
            ecoute.service = NWListener.Service(name: instance,
                                                type: "_\(Link.service)._tcp",
                                                txtRecord: txt)
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
        let cherche = NWBrowser(for: .bonjourWithTXTRecord(type: "_\(Link.service)._tcp",
                                                           domain: nil),
                                using: Link.reglages())
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
    func rejoindre(_ pair: Pair) {
        guard let ou = adresses[pair] else { return }
        print("Riskelo — connexion vers \(pair.nom)")
        state = .invite(pair.nom)
        let connexion = NWConnection(to: ou, using: Link.reglages())
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

    /// Cesse d'accueillir : la table est complète.
    ///
    /// Les connexions déjà ouvertes n'en souffrent pas — arrêter d'écouter ne
    /// coupe rien de ce qui est établi.
    func fermerLaTable() {
        listener?.cancel(); listener = nil
        browser?.cancel(); browser = nil
    }

    func arreter() {
        attente?.cancel(); attente = nil
        fermerLaTable()
        canaux.values.forEach { $0.fermer() }
        canaux = [:]
        anonymes.forEach { $0.fermer() }
        anonymes = []
        adresses = [:]
        trouves = []
        relies = []
        state = .aLArret
    }

    // MARK: - Ce que le système nous dit

    private func listenerAChange(_ etat: NWListener.State) {
        switch etat {
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
            if !vues.contains(pair) { vues.append(pair) }
            ou[pair] = t.endpoint
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
        if !jHeberge || relies.count >= attendus { fermerLaTable() }
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
