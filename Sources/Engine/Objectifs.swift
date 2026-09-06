//
//  Objectifs.swift
//  Riskelo
//
//  La conquête personnelle : ce que chacun cherche, et que lui seul sait.
//
//  Sans elle, une partie n'a qu'une fin — tenir le nombre de territoires du
//  seuil — et tout le monde la voit venir : il suffit de compter les cases de
//  la barre du haut pour savoir où en est l'autre. La conquête personnelle
//  rend le compte trompeur. Celui qui paraît en retard tient peut-être ses
//  deux continents, et celui qui mène ne sait pas ce qu'on lui veut.
//
//  Trois familles, comme dans la boîte :
//
//      des continents entiers   — deux gros, ou trois petits
//      des territoires tenus    — tant de places, avec tant d'hommes sur chacune
//      un camp à faire tomber   — et il faut que ce soit vous qui le fassiez
//
//  Les nombres du Risk d'origine sont des parts du monde et non des comptes
//  absolus : 24 territoires sur 42, c'est 57 % ; 18 avec deux hommes, 43 %.
//  Les plateaux d'ici n'ont pas tous quarante-deux places, et ce sont donc les
//  parts qui se transposent.
//
//  Le seuil de domination reste en jeu par-dessus : une conquête personnelle
//  est une porte de plus, jamais la seule. Sans quoi une partie dont les
//  objectifs deviennent tous impossibles ne finirait pas.
//

import Foundation

enum Objectif: Equatable, Hashable, Codable {

    /// Tenir ces continents en entier, en même temps.
    case continents([ContinentID])

    /// Tenir tant de territoires, avec au moins tant d'hommes sur chacun.
    case territoires(nombre: Int, hommes: Int)

    /// Faire disparaître un camp — de votre main. S'il tombe sous les coups
    /// d'un autre, ou si c'est le vôtre qu'on vous a désigné, la carte se
    /// retourne et devient une conquête de territoires : c'est la règle du
    /// Risk, et elle empêche qu'un objectif devienne impossible sans qu'on y
    /// puisse rien.
    case eliminer(PlayerID)

    // MARK: - Le paquet, taillé pour le plateau

    /// Les parts du monde héritées du Risk, et l'exigence qui va avec.
    private static let parts: [(part: Double, hommes: Int)] = [
        (0.57, 1),   // 24 territoires sur 42
        (0.43, 2),   // 18 avec deux hommes
        (0.29, 3),   // 12 avec trois
    ]

    /// Ce qu'une conquête personnelle ne doit pas dépasser : au-delà, elle
    /// serait plus dure que le seuil de domination, et ne servirait plus de
    /// raccourci.
    private static let partMaximale = 0.60

    /// Le repli : ce que devient une carte « faites tomber tel camp » quand
    /// ce camp n'est plus à prendre.
    static func repli(_ board: Board) -> Objectif {
        .territoires(nombre: nombre(0.57, of: board), hommes: 1)
    }

    private static func nombre(_ part: Double, of board: Board) -> Int {
        max(2, Int((Double(board.map.order.count) * part).rounded()))
    }

    /// Tout ce qu'on peut demander sur ce plateau, dans un ordre stable.
    ///
    /// Les continents sont pris par leur taille et non par leur nom : « deux
    /// gros » et « trois petits » n'ont de sens que relativement au plateau,
    /// et l'Anneau n'a pas d'Australie.
    static func paquet(pour board: Board, joueurs: Int) -> [Objectif] {
        let map = board.map
        let total = map.order.count
        let tries = map.continentsInOrder.sorted {
            ($0.territories.count, $0.id) > ($1.territories.count, $1.id)
        }
        func taille(_ ids: [ContinentID]) -> Int {
            ids.reduce(0) { $0 + (map.continents[$1]?.territories.count ?? 0) }
        }
        func tenable(_ ids: [ContinentID]) -> Bool {
            Double(taille(ids)) / Double(total) <= partMaximale
        }

        var paquet: [Objectif] = []

        // Deux gros continents. La moitié haute du plateau, deux à deux.
        let gros = Array(tries.prefix(max(2, (tries.count + 1) / 2)))
        for i in gros.indices {
            for j in gros.indices where j > i {
                let couple = [gros[i].id, gros[j].id]
                if tenable(couple) { paquet.append(.continents(couple)) }
            }
        }

        // Trois petits. Les quatre plus maigres, trois à trois.
        let petits = Array(tries.suffix(min(4, max(3, tries.count - 1))))
        for i in petits.indices {
            for j in petits.indices where j > i {
                for k in petits.indices where k > j {
                    let trio = [petits[i].id, petits[j].id, petits[k].id]
                    if tenable(trio) { paquet.append(.continents(trio)) }
                }
            }
        }

        // Des territoires tenus, en trois exigences.
        for (part, hommes) in parts {
            paquet.append(.territoires(nombre: nombre(part, of: board), hommes: hommes))
        }

        // Faire tomber un camp. À deux, cela reviendrait à gagner la partie
        // ordinaire — la carte n'entre au paquet qu'à trois joueurs et plus.
        if joueurs >= 3 {
            for rang in 0 ..< joueurs { paquet.append(.eliminer(rang)) }
        }
        return paquet
    }

    /// Une carte pour chacun, et jamais deux fois la même.
    ///
    /// Le tirage passe par le tirage de la partie : deux appareils qui
    /// rejouent les mêmes coups doivent distribuer les mêmes objectifs, sans
    /// quoi ils ne joueraient pas à la même partie.
    static func distribuer<G: RandomNumberGenerator>(pour board: Board, joueurs: Int,
                                                     using rng: inout G) -> [PlayerID: Objectif] {
        var pioche = paquet(pour: board, joueurs: joueurs)
        pioche.shuffle(using: &rng)
        var donnes: [PlayerID: Objectif] = [:]
        for rang in 0 ..< joueurs {
            // Personne ne reçoit sa propre disparition.
            if let i = pioche.firstIndex(where: { $0 != .eliminer(rang) }) {
                donnes[rang] = pioche.remove(at: i)
            } else {
                donnes[rang] = repli(board)
            }
        }
        return donnes
    }
}

// MARK: - Ce que l'objectif demande, et où l'on en est

extension GameState {

    /// L'objectif de ce joueur, tel qu'il compte **maintenant** : la carte
    /// tirée, ou son repli si elle est devenue impossible.
    func objectif(de joueur: PlayerID) -> Objectif? {
        guard let carte = objectifs[joueur] else { return nil }
        guard case let .eliminer(cible) = carte else { return carte }
        if cible == joueur { return Objectif.repli(board) }
        // Éliminé par un autre : la carte se retourne. Éliminé par vous : elle
        // est gagnée, et reste ce qu'elle est.
        if let bourreau = elimines[cible], bourreau != joueur { return Objectif.repli(board) }
        return carte
    }

    /// L'objectif est-il rempli ?
    func objectifAccompli(_ joueur: PlayerID) -> Bool {
        guard rules.objectifs, let carte = objectif(de: joueur) else { return false }
        switch carte {
        case .continents(let ids):
            return ids.allSatisfy { tientLeContinent($0, joueur) }
        case let .territoires(nombre, hommes):
            return territoires(de: joueur, dAuMoins: hommes) >= nombre
        case .eliminer(let cible):
            return elimines[cible] == joueur
        }
    }

    /// Ce joueur tient-il ce continent en entier ?
    func tientLeContinent(_ id: ContinentID, _ joueur: PlayerID) -> Bool {
        guard let continent = map.continents[id] else { return false }
        return continent.territories.allSatisfy { owner[$0] == joueur }
    }

    /// Combien de places ce joueur tient avec au moins tant d'hommes.
    func territoires(de joueur: PlayerID, dAuMoins hommes: Int) -> Int {
        territories(of: joueur).filter { armies($0) >= hommes }.count
    }

    /// L'objectif dit en toutes lettres, pour celui qui le lit.
    func texte(_ carte: Objectif) -> String {
        carte.texte(board, nomDuCamp: playerName)
    }

    /// Où l'on en est de son objectif, en une ligne. Elle ne dit jamais rien
    /// des autres : c'est le sien qu'on regarde.
    func avancement(_ carte: Objectif, pour joueur: PlayerID) -> String {
        switch carte {
        case .continents(let ids):
            let tenus = ids.filter { tientLeContinent($0, joueur) }.count
            let detail = ids.compactMap { id -> String? in
                guard let c = map.continents[id] else { return nil }
                let a_moi = c.territories.filter { owner[$0] == joueur }.count
                return "\(c.name) \(a_moi)/\(c.territories.count)"
            }
            return "\(tenus) sur \(ids.count) — " + detail.joined(separator: " · ")
        case let .territoires(nombre, hommes):
            return "\(territoires(de: joueur, dAuMoins: hommes)) sur \(nombre)"
        case .eliminer(let cible):
            let reste = territories(of: cible).count
            return reste == 0 ? "Le camp est tombé"
                              : "Il lui reste \(reste) territoire\(reste > 1 ? "s" : "")"
        }
    }

    /// Ce qu'on écrit au journal quand la partie se gagne ainsi.
    func recitDeLObjectif(_ joueur: PlayerID) -> String {
        guard let carte = objectif(de: joueur) else { return "" }
        switch carte {
        case .continents(let ids):
            let noms = ids.compactMap { map.continents[$0]?.name }
            return "\(playerName(joueur)) tenait " + Objectif.liste(noms)
                + " — c'était sa conquête."
        case let .territoires(nombre, hommes):
            return hommes > 1
                ? "\(playerName(joueur)) tient \(nombre) places à "
                    + "\(Objectif.enLettres(hommes)) hommes — c'était sa conquête."
                : "\(playerName(joueur)) tient \(nombre) territoires — c'était sa conquête."
        case .eliminer(let cible):
            return "\(playerName(joueur)) a fait tomber \(playerName(cible)) — c'était sa conquête."
        }
    }
}

extension Objectif {

    /// L'objectif dit en toutes lettres, à partir du seul plateau.
    ///
    /// Le mode d'emploi liste les conquêtes possibles avant qu'aucune partie
    /// n'existe : il lui faut la même phrase, et il ne doit surtout pas la
    /// recopier. Une liste écrite à la main mentirait le jour où un continent
    /// change de taille, ou le jour où un plateau s'ajoute.
    func texte(_ board: Board, nomDuCamp: (PlayerID) -> String = Boards.nomDeCamp) -> String {
        switch self {
        case .continents(let ids):
            let noms = ids.compactMap { board.map.continents[$0]?.name }
            return "Tenir en entier " + Objectif.liste(noms) + "."
        case let .territoires(nombre, hommes):
            guard hommes > 1 else { return "Tenir \(nombre) territoires." }
            return "Tenir \(nombre) territoires avec au moins "
                + "\(Objectif.enLettres(hommes)) hommes sur chacun."
        case .eliminer(let cible):
            return "Faire disparaître le camp de \(nomDuCamp(cible)) — de votre main."
        }
    }

    /// « A », « A et B », « A, B et C » — la liste française, qui n'a pas de
    /// virgule avant son dernier terme.
    static func liste(_ mots: [String]) -> String {
        guard let dernier = mots.last else { return "" }
        guard mots.count > 1 else { return dernier }
        return mots.dropLast().joined(separator: ", ") + " et " + dernier
    }

    static func enLettres(_ n: Int) -> String {
        switch n {
        case 1: "un"
        case 2: "deux"
        case 3: "trois"
        case 4: "quatre"
        default: "\(n)"
        }
    }
}
