//
//  Archives.swift
//  Riskelo
//
//  La bibliothèque des parties : y revenir, et pas seulement les finir.
//
//  Il y avait déjà une sauvegarde — celle qui rend la partie en cours d'un
//  lancement sur l'autre. Elle ne garde qu'un état, le dernier, et l'écrase à
//  chaque coup. C'est ce qu'il faut pour reprendre, et c'est exactement ce
//  qu'il ne faut pas pour revenir : au moment où l'on se dit « c'est là que
//  j'ai tout perdu », l'instant en question a été effacé depuis longtemps.
//
//  D'où trois choix de fabrication :
//
//  On enregistre **à chaque tour**, sans qu'on le demande. Un instant
//  stratégique ne se reconnaît qu'après coup : demander au joueur de penser à
//  sauvegarder avant de commettre l'erreur, c'est ne rien lui offrir du tout.
//  Le bouton « marquer » existe aussi, mais il n'est qu'un supplément.
//
//  Un fichier par instant, et non un gros fichier par partie. Une partie de
//  vingt tours réécrite vingt fois coûte vingt fois plus qu'écrite une fois
//  par tour, et une écriture interrompue n'emporterait pas les dix-neuf
//  autres avec elle.
//
//  Un index séparé, léger, pour la liste. Ouvrir vingt parties entières pour
//  afficher vingt lignes serait absurde : l'index porte les noms, les dates
//  et le compte des territoires, et les états dorment jusqu'à ce qu'on les
//  demande.
//

import Foundation

/// Une partie rangée, telle que la liste la montre.
struct PartieArchivee: Codable, Identifiable, Equatable {

    /// Un instant de cette partie, auquel on peut revenir.
    struct Moment: Codable, Identifiable, Equatable {
        var id = UUID()
        var tour: Int
        /// Le rang dont c'était le tour. `tour` compte les tours de **table**,
        /// pas les tours de joueur : sans le camp, une partie à deux ne
        /// garderait qu'un instant sur deux, et à quatre un sur quatre.
        var camp: Int
        var date: Date
        var etiquette: String
        /// Le nombre de territoires par rang, au moment même. Il est ici et
        /// non dans l'état pour que la liste sache dessiner le rapport de
        /// forces sans ouvrir un seul fichier.
        var territoires: [Int]
        var fichier: String
        /// Marqué à la main par le joueur, ou posé par le tour qui passe.
        var marque = false
    }

    var id = UUID()
    var debut: Date
    var derniere: Date
    var plateau: Boards
    var mode: Rules.Mode
    var joueurs: [String]
    /// Les rangs tenus par la machine : de quoi dire contre qui l'on jouait.
    var machines: [Int]
    var moments: [Moment] = []
    /// Le rang du vainqueur, si la partie est allée à son terme.
    var vainqueur: Int?

    var estTerminee: Bool { vainqueur != nil }
}

/// Le rayonnage.
///
/// Toutes les écritures sont atomiques et aucune n'interrompt la partie : une
/// archive qu'on ne peut pas écrire est une archive qu'on n'aura pas, ce n'est
/// pas une raison pour arrêter de jouer.
struct Archives {

    static let shared = Archives()

    /// Combien de parties on garde. Au-delà, la plus ancienne s'en va.
    static let partiesGardees = 12
    /// Combien d'instants par partie. Les parties mesurées en font quatre à
    /// vingt-trois ; quatre-vingts est une digue, pas un plafond utile.
    static let momentsGardes = 80

    private let dossier: URL

    /// Le rayon se laisse déplacer : les tests écrivent dans un dossier à eux
    /// plutôt que dans les parties du joueur.
    init(dossier: URL? = nil) {
        let d = dossier ?? {
            let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil, create: true))
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            return base.appendingPathComponent("Riskelo/Parties", isDirectory: true)
        }()
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        self.dossier = d
    }

    private var indexURL: URL { dossier.appendingPathComponent("index.json") }

    // MARK: - Lire

    func liste() -> [PartieArchivee] {
        guard let data = try? Data(contentsOf: indexURL),
              let l = try? JSONDecoder().decode([PartieArchivee].self, from: data)
        else { return [] }
        return l.sorted { $0.derniere > $1.derniere }
    }

    func charger(_ moment: PartieArchivee.Moment) -> GameState? {
        let url = dossier.appendingPathComponent(moment.fichier)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(GameState.self, from: data)
        } catch {
            // Un plan de plateau retouché depuis : mieux vaut refuser que
            // restaurer une partie de travers.
            print("Riskelo — instant illisible : \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Écrire

    /// Range un instant de la partie. Sans effet si le tour est déjà rangé et
    /// que ce n'est pas une marque du joueur : on garde un instant par tour,
    /// et non un par coup.
    func ranger(_ g: GameState, partie: UUID, etiquette: String, marque: Bool = false) {
        var toutes = liste()
        var p: PartieArchivee
        if let i = toutes.firstIndex(where: { $0.id == partie }) {
            p = toutes.remove(at: i)
        } else {
            p = PartieArchivee(id: partie, debut: Date(), derniere: Date(),
                               plateau: g.boardKind, mode: g.rules.mode,
                               joueurs: g.players.map(\.name),
                               machines: g.players.filter(\.isBot).map(\.id))
        }
        if !marque, p.moments.contains(where: {
            $0.tour == g.turn && $0.camp == g.current && !$0.marque
        }) {
            toutes.append(p)
            ecrire(toutes)
            return
        }
        guard marque || p.moments.count < Archives.momentsGardes else {
            toutes.append(p); ecrire(toutes); return
        }

        let compte = g.players.map { j in g.owner.values.filter { $0 == j.id }.count }
        let nom = "\(partie.uuidString)-\(p.moments.count).json"
        do {
            let data = try JSONEncoder().encode(g)
            try data.write(to: dossier.appendingPathComponent(nom), options: .atomic)
        } catch {
            print("Riskelo — instant non rangé : \(error)")
            toutes.append(p); ecrire(toutes); return
        }

        p.moments.append(.init(tour: g.turn, camp: g.current, date: Date(),
                               etiquette: etiquette, territoires: compte,
                               fichier: nom, marque: marque))
        p.derniere = Date()
        if case let .finished(w) = g.phase { p.vainqueur = w }
        toutes.append(p)
        ecrire(toutes)
    }

    func supprimer(_ id: UUID) {
        var toutes = liste()
        guard let i = toutes.firstIndex(where: { $0.id == id }) else { return }
        for m in toutes[i].moments {
            try? FileManager.default.removeItem(at: dossier.appendingPathComponent(m.fichier))
        }
        toutes.remove(at: i)
        ecrire(toutes)
    }

    /// Écrit l'index, et fait le ménage : les parties en trop s'en vont avec
    /// leurs fichiers, sans quoi le dossier grossirait sans fin.
    private func ecrire(_ liste: [PartieArchivee]) {
        var l = liste.sorted { $0.derniere > $1.derniere }
        // Une partie sans aucun instant n'a rien à faire dans la liste.
        l.removeAll { $0.moments.isEmpty }
        while l.count > Archives.partiesGardees {
            let vieille = l.removeLast()
            for m in vieille.moments {
                try? FileManager.default.removeItem(at: dossier.appendingPathComponent(m.fichier))
            }
        }
        guard let data = try? JSONEncoder().encode(l) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
