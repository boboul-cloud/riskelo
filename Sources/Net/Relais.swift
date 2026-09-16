//
//  Relais.swift
//  Riskelo
//
//  Le fil du loin.
//
//  Dans la même pièce, deux appareils se trouvent parce qu'ils sont dans la
//  même pièce : ils crient leur nom, et l'autre l'entend. À deux cents
//  kilomètres, il n'y a personne pour entendre. Il faut un tiers qui les
//  mette en présence, et il n'y a pas moyen d'y couper — c'est vrai de tous
//  les jeux en ligne, sans exception.
//
//  Ce tiers-ci est aussi bête qu'on a pu le faire. Il ne connaît pas les
//  règles, ne tient pas la partie, ne sait pas qui gagne : il a des salons
//  désignés par un code de six lettres, et il recopie les paquets de l'un à
//  l'autre. Tout ce que le jeu envoie ici, il l'enverrait mot pour mot sur
//  le fil de la même pièce — c'est le même `Message`, la même partie, les
//  mêmes coups de quelques dizaines d'octets.
//
//  ## Le code plutôt qu'un compte
//
//  Riskelo n'a jamais demandé à personne de créer un compte, et ce n'est pas
//  le loin qui va l'y obliger. Celui qui ouvre reçoit six lettres, il les
//  envoie par WhatsApp ou par SMS, l'autre les tape. Le salon vit le temps
//  de la partie et disparaît — rien n'est gardé, ni les noms, ni les coups,
//  ni qui a joué avec qui.
//
//  ## La coupure est la règle, pas l'accident
//
//  Dans la même pièce, une liaison qui tombe est un appareil qu'on a éteint :
//  il n'y a rien à attendre. Au loin, c'est un tunnel, un ascenseur, un
//  appel qui arrive — et l'appareil revient trente secondes plus tard. Une
//  partie qui s'arrêterait là-dessus ne finirait jamais.
//
//  D'où la reprise, et la bonne surprise qu'elle a été : **elle n'a demandé
//  aucun message nouveau**. Celui qui revient dit « je ne suis plus à la même
//  partie que vous » — `Message.perdu`, qui existait déjà pour les
//  divergences — et celui qui la tient la renvoie entière, comme au premier
//  jour. Il suffisait que le salon garde la place au chaud, et que le fil
//  rappelle tout seul.
//

import Foundation

@Observable
@MainActor
final class Relais: Fil {

    // MARK: - Où l'on appelle

    /// Le serveur qui tient les salons.
    ///
    /// Une seule ligne à changer pour en changer, et une variable
    /// d'environnement pour l'essayer sur sa machine sans toucher au code :
    /// `RISKELO_SALON=localhost:8787` fait passer la partie par le serveur
    /// de développement, en clair et sans certificat.
    nonisolated static let serveurParDefaut = "riskelo-salon.boboul.workers.dev"

    /// Une variable et non une constante calculée : les essais de bout en
    /// bout la pointent sur le serveur de développement, et c'est la seule
    /// façon d'éprouver pour de vrai le dialogue entre l'application et le
    /// salon. Le reste du temps, elle ne bouge pas.
    nonisolated(unsafe) static var serveur: String =
        ProcessInfo.processInfo.environment["RISKELO_SALON"] ?? serveurParDefaut

    /// En clair sur sa machine, chiffré partout ailleurs. `wrangler dev` ne
    /// sert pas de certificat, et exiger `wss` rendrait l'essai impossible.
    private static var schema: String {
        serveur.hasPrefix("localhost") || serveur.hasPrefix("127.0.0.1") ? "ws" : "wss"
    }

    /// L'adresse qu'on partage par WhatsApp. Le serveur y répond par une page
    /// qui ouvre le jeu — et, s'il n'est pas installé, par où le prendre.
    nonisolated static func lien(pour code: String) -> URL? {
        URL(string: "https://\(serveurParDefaut)/p/\(code)")
    }

    // MARK: - Ce que l'écran regarde

    enum Etat: Equatable {
        case aLArret
        /// On demande un salon, on n'a pas encore son code.
        case ouvre
        /// On tient le salon, et voici le code à donner.
        case ouvert(String)
        /// On entre dans le salon d'un autre.
        case entre(String)
        /// On y est.
        case relie
        /// La liaison est tombée et l'on essaie de revenir.
        case rompue
        case refuse(Panne)
    }

    /// Pourquoi l'on n'est pas entré. Chacune demande autre chose au joueur,
    /// et c'est bien pour cela qu'elles sont nommées séparément : « ce code
    /// n'existe pas » et « le réseau ne répond pas » n'ont pas le même
    /// remède, et un message unique les enverrait chercher au mauvais
    /// endroit.
    enum Panne: Equatable {
        /// Le code ne désigne aucun salon — mal tapé, ou la partie est finie.
        case codeInconnu
        /// Le salon est au complet.
        case salonPlein
        /// La partie a déjà commencé sans nous.
        case dejaCommencee
        /// Rien n'a répondu.
        case sansReponse
        /// Le serveur a répondu, mais pas ce qu'on attendait.
        case serveur(String)
    }

    private(set) var etat: Etat = .aLArret
    private(set) var relies: [Pair] = []
    /// Le code du salon, dès qu'on le connaît. C'est ce qu'on partage.
    private(set) var code: String?

    var jeSuisLHote: Bool { jHeberge }

    let moi: Pair

    /// L'identité de l'appareil, sauf dans les essais.
    ///
    /// Deux salons dans le même processus se présenteraient sous la même
    /// identité, et le serveur prendrait le second pour le premier qui
    /// revient — il fermerait le premier. C'est le bon comportement en
    /// production, et il rend une partie à deux impossible à éprouver sans
    /// cette porte.
    /// `nil` plutôt que `Link.identite()` en valeur par défaut : une valeur
    /// par défaut s'évalue **hors** de l'acteur principal, et l'identité de
    /// l'appareil y est justement tenue. Le compilateur le dit clairement ;
    /// il ne dit pas que la solution est de reculer l'appel d'une ligne.
    init(moi: Pair? = nil) {
        self.moi = moi ?? Link.identite()
    }

    var onReceive: ((Data, Pair) -> Void)?
    var onConnected: ((Bool, Pair) -> Void)?
    var onLiaison: ((Liaison) -> Void)?

    // MARK: - Dedans

    private var socket: URLSessionWebSocketTask?
    private var jHeberge = false
    /// Le salon visé, gardé pour pouvoir y revenir.
    private var codeVise: String?
    /// On a raccroché soi-même : il ne faut surtout pas rappeler.
    private var raccroche = false
    /// Quand la liaison est tombée. `nil` tant qu'elle tient.
    private var rompueDepuis: Date?
    private var rappel: Task<Void, Never>?
    /// Combien de fois on a rappelé d'affilée, pour espacer les essais.
    private var essais = 0

    /// Au-delà, on renonce.
    ///
    /// Deux minutes : c'est un tunnel, un ascenseur, un appel qui arrive et
    /// qu'on prend. Au-delà, ce n'est plus une coupure, c'est quelqu'un qui
    /// est parti — et laisser les autres devant un bandeau qui tourne sans
    /// fin ne rend service à personne.
    private static let dureeDeGrace: TimeInterval = 120

    /// `@ObservationIgnored` : une propriété paresseuse n'est pas une
    /// propriété stockée aux yeux du macro `@Observable`, et il refuse de la
    /// suivre. De toute façon, personne ne regarde la session — seul son état
    /// intéresse l'écran.
    @ObservationIgnored private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        // Une partie ne supporte pas qu'un coup attende derrière un cache.
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }()

    // MARK: - Ouvrir, rejoindre, raccrocher

    /// Ouvrir un salon. Le code vient du serveur — c'est lui qui sait
    /// lesquels sont libres.
    func ouvrir() {
        arreter()
        raccroche = false
        jHeberge = true
        codeVise = nil
        etat = .ouvre
        composer()
    }

    /// Entrer dans le salon d'un autre.
    ///
    /// Le code est normalisé ici et non à la saisie : on le reçoit aussi d'un
    /// lien WhatsApp, et personne ne garantit sa casse ni ses espaces.
    func rejoindre(code brut: String) {
        let propre = Relais.normaliser(brut)
        guard propre.count == Relais.longueurDuCode else {
            etat = .refuse(.codeInconnu)
            return
        }
        arreter()
        raccroche = false
        jHeberge = false
        codeVise = propre
        code = propre
        etat = .entre(propre)
        composer()
    }

    /// Raccrocher pour de bon. Aucun rappel ne suivra.
    func arreter() {
        raccroche = true
        rappel?.cancel(); rappel = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        relies = []
        rompueDepuis = nil
        essais = 0
        if case .aLArret = etat {} else { etat = .aLArret }
    }

    /// L'hôte cesse d'accueillir : la partie part. Ceux qui y étaient
    /// pourront toujours revenir après une coupure — c'est aux nouveaux que
    /// la porte se ferme.
    func fermerLaTable() {
        envoyerAuServeur(["t": "ferme"])
    }

    // MARK: - Composer le numéro

    private func composer() {
        var morceaux = URLComponents()
        morceaux.scheme = Relais.schema
        let coupe = Relais.serveur.split(separator: ":", maxSplits: 1)
        morceaux.host = String(coupe[0])
        if coupe.count == 2 { morceaux.port = Int(coupe[1]) }
        morceaux.path = "/salon"
        // Ni le nom de l'appareil, ni le pseudo du joueur.
        //
        // Ils y étaient, et c'était commode : le salon affichait « Marie »
        // avant même que son appareil ait dit bonjour. Mais un paramètre
        // d'adresse se retrouve dans les journaux du serveur, et il n'y a
        // aucune raison qu'un prénom y figure — le jeu envoie déjà son nom
        // dans un `bonjour`, sous la forme d'un paquet que le serveur ne sait
        // pas lire et qu'il ne fait que recopier. Le seul coût est un dixième
        // de seconde où la liste dit « Joueur ».
        //
        // Ce qui reste est un identifiant tiré au sort à l'installation et le
        // numéro de dialecte. Ni l'un ni l'autre ne désigne quelqu'un.
        morceaux.queryItems = [
            URLQueryItem(name: "id", value: moi.id),
            URLQueryItem(name: "dialecte", value: String(Message.dialecte)),
        ]
        if let codeVise {
            morceaux.queryItems?.append(URLQueryItem(name: "code", value: codeVise))
        }
        if jHeberge {
            morceaux.queryItems?.append(URLQueryItem(name: "hote", value: "1"))
        }
        guard let url = morceaux.url else {
            etat = .refuse(.serveur("adresse illisible"))
            return
        }

        let tache = session.webSocketTask(with: url)
        socket = tache
        tache.resume()
        ecouter(tache)
        battre(tache)
    }

    // MARK: - Écouter

    private func ecouter(_ tache: URLSessionWebSocketTask) {
        tache.receive { [weak self] resultat in
            Task { @MainActor [weak self] in
                guard let self, self.socket === tache else { return }
                switch resultat {
                case let .success(message):
                    switch message {
                    case let .string(texte):
                        self.recu(Data(texte.utf8))
                    case let .data(data):
                        self.recu(data)
                    @unknown default:
                        break
                    }
                    self.ecouter(tache)
                case let .failure(erreur):
                    print("Riskelo — salon : liaison interrompue (\(erreur))")
                    self.tombe()
                }
            }
        }
    }

    /// Un battement régulier.
    ///
    /// Sans lui, une liaison morte peut rester ouverte longtemps du côté de
    /// l'appareil : rien ne circule pendant qu'un joueur réfléchit, et
    /// personne ne s'aperçoit de rien. Le battement la fait tomber tout de
    /// suite, et la reprise part aussitôt.
    private func battre(_ tache: URLSessionWebSocketTask) {
        Task { @MainActor [weak self] in
            while let self, self.socket === tache, !self.raccroche {
                try? await Task.sleep(for: .seconds(20))
                guard self.socket === tache else { return }
                tache.sendPing { erreur in
                    guard let erreur else { return }
                    print("Riskelo — salon : battement sans écho (\(erreur))")
                    Task { @MainActor [weak self] in
                        guard let self, self.socket === tache else { return }
                        self.tombe()
                    }
                }
            }
        }
    }

    private func recu(_ data: Data) {
        guard let brut = try? JSONSerialization.jsonObject(with: data),
              let dit = brut as? [String: Any],
              let quoi = dit["t"] as? String
        else {
            print("Riskelo — salon : paquet illisible")
            return
        }

        switch quoi {
        case "salon":
            // Le premier mot du serveur : le code, qui tient le salon, et qui
            // s'y trouve déjà. Il arrive aussi au retour d'une coupure, et il
            // remet alors tout le monde en place d'un coup.
            if let donne = dit["code"] as? String {
                code = donne
                codeVise = donne
            }
            let revenu = rompueDepuis != nil
            rompueDepuis = nil
            essais = 0
            if let gens = dit["gens"] as? [[String: Any]] {
                for gars in gens { noter(gars, arrive: true) }
            }
            // Celui qui tient le salon reste sur `.ouvert` tant qu'il le
            // tient : son écran montre le code, et il doit le montrer même
            // quand quelqu'un est déjà entré. Seul celui qui a rejoint passe
            // à `.relie` — il n'a plus rien à donner à personne.
            etat = jHeberge ? .ouvert(code ?? "") : .relie
            if revenu { onLiaison?(.tenue) }

        case "arrivee":
            noter(dit, arrive: true)

        case "depart":
            guard let id = dit["id"] as? String else { return }
            relies.removeAll { $0.id == id }
            // Le départ d'un autre ne rompt pas *notre* liaison : elle est
            // parfaite, c'est lui qui n'est plus là. La partie le verra à sa
            // façon — un joueur qui ne joue plus — et le salon, lui, le
            // montre dans sa liste.

        case "paquet":
            guard let de = dit["de"] as? String,
                  let encode = dit["d"] as? String,
                  let charge = Data(base64Encoded: encode)
            else { return }
            let qui = relies.first { $0.id == de } ?? Pair(id: de, nom: de)
            onReceive?(charge, qui)

        case "refus":
            let pourquoi = dit["pourquoi"] as? String ?? ""
            raccroche = true
            rappel?.cancel(); rappel = nil
            socket?.cancel(with: .goingAway, reason: nil)
            socket = nil
            switch pourquoi {
            case "inconnu":  etat = .refuse(.codeInconnu)
            case "plein":    etat = .refuse(.salonPlein)
            case "commence": etat = .refuse(.dejaCommencee)
            default:         etat = .refuse(.serveur(pourquoi))
            }

        default:
            // Un serveur plus récent que l'application. Se taire vaut mieux
            // que de tomber : ce qu'on ne comprend pas ne nous concerne pas.
            break
        }
    }

    /// Un appareil est là — arrivé, ou revenu.
    ///
    /// Sans nom : le serveur n'en connaît aucun. « Joueur » tient la place le
    /// temps que le `bonjour` du jeu traverse, ce qui est l'affaire d'un
    /// dixième de seconde.
    private func noter(_ dit: [String: Any], arrive: Bool) {
        guard let id = dit["id"] as? String, id != moi.id else { return }
        let pair = Pair(id: id, nom: "Joueur")
        if !relies.contains(pair) { relies.append(pair) }
        if arrive { onConnected?(jHeberge, pair) }
    }

    // MARK: - Tomber, et revenir

    /// La liaison vient de tomber. On ne renonce pas : on rappelle.
    private func tombe() {
        guard !raccroche else { return }
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil

        // Tomber avant même d'être entré n'est pas une coupure : c'est que le
        // serveur n'est pas joignable, et rappeler deux minutes durant
        // n'apprendrait rien de plus au joueur.
        switch etat {
        case .ouvre, .entre:
            etat = .refuse(.sansReponse)
            return
        default:
            break
        }

        let debut = rompueDepuis ?? Date()
        rompueDepuis = debut
        etat = .rompue
        onLiaison?(.rompue(depuis: debut))

        guard Date().timeIntervalSince(debut) < Relais.dureeDeGrace else {
            renoncer()
            return
        }

        // On espace : une seconde, deux, quatre… jusqu'à cinq. Rappeler dix
        // fois par seconde ne ferait revenir la liaison ni plus tôt ni mieux,
        // et viderait la batterie de celui qui est dans le tunnel.
        let attente = min(pow(2.0, Double(essais)), 5.0)
        essais += 1
        rappel?.cancel()
        rappel = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(attente))
            guard let self, !self.raccroche, !Task.isCancelled else { return }
            guard let debut = self.rompueDepuis else { return }
            guard Date().timeIntervalSince(debut) < Relais.dureeDeGrace else {
                self.renoncer()
                return
            }
            self.composer()
        }
    }

    private func renoncer() {
        rappel?.cancel(); rappel = nil
        raccroche = true
        rompueDepuis = nil
        etat = .refuse(.sansReponse)
        onLiaison?(.perdue("la liaison"))
    }

    // MARK: - Envoyer

    func envoyer(_ data: Data) {
        envoyerAuServeur(["t": "vers", "d": data.base64EncodedString()])
    }

    func envoyer(_ data: Data, a pair: Pair) {
        envoyerAuServeur(["t": "vers", "a": pair.id, "d": data.base64EncodedString()])
    }

    func envoyer(_ data: Data, saufA pair: Pair) {
        envoyerAuServeur(["t": "vers", "sauf": pair.id, "d": data.base64EncodedString()])
    }

    private func envoyerAuServeur(_ dit: [String: Any]) {
        guard let socket else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: dit),
              let texte = String(data: data, encoding: .utf8)
        else {
            print("Riskelo — salon : paquet non formé")
            return
        }
        socket.send(.string(texte)) { [weak self] erreur in
            guard let erreur else { return }
            print("Riskelo — salon : paquet non envoyé (\(erreur))")
            Task { @MainActor [weak self] in self?.tombe() }
        }
    }

    // MARK: - Le code

    /// Six lettres, et jamais deux qui se ressemblent à l'oreille.
    ///
    /// Un code se dicte au téléphone autant qu'il se colle dans WhatsApp :
    /// consonne, voyelle, consonne, voyelle, consonne, voyelle. « MARENO » se
    /// lit, se répète et se retient ; « X7KQ2V » se fait répéter trois fois.
    ///
    /// Le serveur le tire — c'est lui qui sait quels salons sont libres — mais
    /// l'alphabet est écrit des deux côtés : l'application doit pouvoir dire
    /// « ce n'est pas un code » sans appeler personne.
    nonisolated static let consonnes = Array("BCDFGHJKLMNPRSTVZ")
    nonisolated static let voyelles = Array("AEIOU")
    nonisolated static let longueurDuCode = 6

    /// Nettoie ce qu'on a tapé, collé, ou reçu par un lien.
    ///
    /// Le zéro et la lettre O, le un et le I : personne ne les distingue à
    /// l'écrit, et les confondre renverrait « ce code n'existe pas » à
    /// quelqu'un qui a bien tapé ce qu'il voyait. On les redresse plutôt que
    /// de les refuser.
    nonisolated static func normaliser(_ brut: String) -> String {
        let redresse = brut.uppercased()
            .replacingOccurrences(of: "0", with: "O")
            .replacingOccurrences(of: "1", with: "I")
        return String(redresse.filter { $0.isLetter }.prefix(longueurDuCode))
    }

    /// Est-ce la forme d'un code ? Cela ne dit pas qu'un salon existe
    /// derrière — seul le serveur le sait.
    nonisolated static func estUnCode(_ brut: String) -> Bool {
        let propre = normaliser(brut)
        guard propre.count == longueurDuCode else { return false }
        for (rang, lettre) in propre.enumerated() {
            let attendu = rang % 2 == 0 ? consonnes : voyelles
            guard attendu.contains(lettre) else { return false }
        }
        return true
    }
}
