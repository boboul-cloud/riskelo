//
//  Bot.swift
//  Riskelo
//
//  L'adversaire de la machine.
//
//  Il sert à deux choses : jouer seul, et surtout faire tourner mille parties
//  en une seconde pour voir si la règle tient. Ses décisions sont donc des
//  fonctions pures de l'état — aucune mémoire cachée, rien qui ne se rejoue.
//
//  Sa « culture » est un nombre : la part de bonnes réponses qu'il donne sur
//  une question moyenne, dans le temps plein. Le siège le presse comme il
//  presserait un humain — moins de temps, moins de bonnes réponses.
//

import Foundation

enum Bot {

    /// Comment la machine manœuvre. Rien à voir avec sa culture : on peut être
    /// savant et jouer mal.
    ///
    /// Les trois niveaux se cumulent, chacun ajoutant un acquis au précédent —
    /// et chacun a été mesuré contre celui d'en dessous, sans quoi ce ne
    /// seraient que trois noms.
    enum Style: String, Equatable, Codable, CaseIterable {
        /// Gourmande. Elle avance d'un pas sur toute cible où elle a un homme
        /// de plus, et laisse le minimum derrière elle — d'où les garnisons
        /// d'un homme semées en terre ennemie.
        case facile
        /// Elle tient ce qu'elle prend : après une conquête, elle laisse à sa
        /// base ce qu'il lui faut et fait avancer tout le reste. Pour le
        /// reste elle garde l'allant de la facile — et c'est voulu : la
        /// prudence sans la concentration est **pire que rien**. Mesurée, une
        /// machine qui retenait ses piles sans savoir où les porter perdait
        /// quatre parties sur cinq contre la gourmande.
        case moyenne
        /// Elle joue au Risk : elle concentre ses renforts sur une seule
        /// pointe, vise le continent le plus proche d'être complet, cherche à
        /// briser celui de l'adversaire — et elle exploite le sablier, qui est
        /// la particularité de ce jeu-ci : une place déjà pressée dans le tour
        /// répond dans un temps plus court, donc on l'achève plutôt que d'en
        /// ouvrir une autre.
        case forte

        var label: String {
            switch self {
            case .facile:  "Facile"
            case .moyenne: "Moyenne"
            case .forte:   "Forte"
            }
        }

        var detail: String {
            switch self {
            case .facile:
                "Elle avance au hasard et sème des garnisons d'un homme."
            case .moyenne:
                "Elle tient ce qu'elle prend et cherche vos points faibles."
            case .forte:
                "Elle concentre, vise un continent, et sait où vous frapper."
            }
        }

        /// Laisse-t-elle à sa base de quoi tenir, au lieu du strict minimum ?
        var garnisonne: Bool { self != .facile }
        /// Retient-elle ses piles épuisées ? Cette discipline ne paie qu'avec
        /// la concentration : seule, elle rend la machine passive.
        var retientSesPiles: Bool { self == .forte }
        /// Verse-t-elle ses renforts sur une seule pointe ?
        var concentre: Bool { self == .forte }
        /// Vise-t-elle un continent, et cherche-t-elle à briser celui d'en face ?
        var viseUnContinent: Bool { self == .forte }
        /// Achève-t-elle une place déjà entamée plutôt que d'en ouvrir une
        /// autre ? C'est la stratégie propre à ce jeu : le sablier du
        /// défenseur se resserre à chaque question subie dans le tour.
        var exploiteLeSablier: Bool { self == .forte }

        /// Combien elle vise les faiblesses de l'adversaire en choisissant le
        /// terrain de la question.
        ///
        /// C'est le levier décisif, et il a fallu le mesurer pour le voir : la
        /// manœuvre ne départage les machines que sur un grand plateau, parce
        /// qu'ailleurs la partie se règle en sept tours et que **c'est le quiz
        /// qui décide**. Choisir le terrain est la seule adresse de
        /// l'attaquant dans cette variante, et elle pèse sur chaque duel.
        /// Zéro : elle tire au hasard sans regarder le dossier.
        var flair: Double {
            switch self {
            case .facile:  0
            case .moyenne: 1.2
            case .forte:   3.0
            }
        }
    }

    // MARK: - Ce que la machine regarde

    /// Ce qui presse une place : les hommes ennemis qui la touchent.
    static func menace(_ g: GameState, _ id: TerritoryID) -> Int {
        g.map.neighbors(of: id)
            .filter { g.owner[$0] != g.owner[id] }
            .reduce(0) { $0 + g.armies($1) }
    }

    /// Ce qu'une place permet : le meilleur surnombre disponible depuis elle.
    /// C'est la mesure d'une pointe d'attaque.
    static func potentiel(_ g: GameState, _ id: TerritoryID) -> Int {
        g.targets(from: id).map { g.armies(id) - 1 - g.armies($0) }.max() ?? -99
    }

    /// Le continent visé : le plus proche d'être complet, à bonus égal le plus
    /// gros. Un continent déjà tenu reste l'objectif — le défendre vaut ce
    /// qu'il rapporte.
    static func continentVise(_ g: GameState, _ joueur: PlayerID) -> Continent? {
        var meilleur: Continent?
        var manquantsMin = Int.max
        for c in g.map.continentsInOrder {
            var manquants = 0
            for id in c.territories where g.owner[id] != joueur { manquants += 1 }
            if manquants < manquantsMin
                || (manquants == manquantsMin && c.bonus > (meilleur?.bonus ?? 0)) {
                manquantsMin = manquants
                meilleur = c
            }
        }
        return meilleur
    }

    /// La garnison qu'une place doit garder pour n'être pas reprise au
    /// premier assaut. C'est tout le défaut de l'adversaire gourmand : il
    /// laissait un homme et perdait la place au tour suivant.
    static func garnison(_ g: GameState, _ id: TerritoryID) -> Int {
        let m = menace(g, id)
        if m == 0 { return 1 }
        return max(2, min(m / 2 + 1, 5))
    }

    // MARK: - Répondre

    /// Deux facteurs, et non un : savoir, et avoir le temps de le dire.
    ///
    /// Le second n'est pas une décoration de simulation — c'est lui qui porte
    /// tout l'équilibre du jeu. Trois secondes s'en vont à lire l'énoncé et
    /// les quatre propositions ; au-delà d'une douzaine de secondes utiles,
    /// savoir davantage ne se traduit plus en réponses. En dessous, la
    /// mémoire n'a plus le temps de remonter, et il reste le réflexe.
    /// Ce qu'un joueur sait mieux, et moins bien.
    ///
    /// Personne n'est également fort partout, et c'est tout l'objet du choix
    /// du terrain par l'attaquant. Sans ce relief, une machine simulée répond
    /// aussi bien en géographie qu'en sport, le dossier de l'adversaire ne
    /// contient que du bruit — et l'on ne peut pas mesurer si viser les
    /// faiblesses sert à quelque chose. Le profil est déterministe : chacun
    /// garde ses forces d'un bout à l'autre de la partie.
    static func aptitude(_ joueur: PlayerID, _ categorie: Category) -> Double {
        let relief = [0.16, 0.09, 0.0, -0.09, -0.16, 0.0]
        let rang = Category.allCases.firstIndex(of: categorie) ?? 0
        return relief[(rang + joueur * 2) % relief.count]
    }

    static func probability(level: Double, difficulty: Difficulty,
                            allowance: TimeInterval, rules: Rules) -> Double {
        let knowledge: Double
        switch difficulty {
        case .facile:    knowledge = level + 0.15
        case .moyen:     knowledge = level
        case .difficile: knowledge = level - 0.20
        }
        let time = min(1, max(0.35, (allowance - 3) / 12))
        return min(0.98, max(0.02, knowledge * time))
    }

    /// La machine répond toujours quelque chose — bien ou mal, jamais rien.
    ///
    /// Elle laissait auparavant passer le temps une fois sur sept quand elle
    /// se trompait. Trois raisons de l'avoir retiré. Une machine qui manque de
    /// temps n'est pas crédible. Surtout, l'écran n'avait rien à montrer : un
    /// temps écoulé ne marque aucune proposition en rouge, on ne voyait donc
    /// que la bonne réponse en vert pendant que le verdict annonçait un
    /// silence — et l'on croyait l'application en train de compter une bonne
    /// réponse comme une mauvaise. Enfin, cela ne servait à rien : pour le
    /// moteur, un silence et une erreur ont la même conséquence exactement.
    ///
    /// Le temps écoulé reste ce qu'il doit être : le fait d'un humain qui n'a
    /// pas répondu, et qui sait très bien pourquoi.
    static func answer(to duel: Duel, level: Double, rules: Rules,
                       joueur: PlayerID = 0,
                       using rng: inout SeededRandom) -> Answer {
        let p = probability(level: level + aptitude(joueur, duel.question.category),
                            difficulty: duel.question.difficulty,
                            allowance: duel.allowance, rules: rules)
        let elapsed = Double.random(in: 0.25 ... 0.85, using: &rng) * duel.allowance
        if Double.random(in: 0 ... 1, using: &rng) < p {
            return .chosen(duel.question.answer, elapsed: elapsed)
        }
        let wrong = (0 ..< duel.question.choices.count).filter { $0 != duel.question.answer }
        return .chosen(wrong.randomElement(using: &rng) ?? 0, elapsed: elapsed)
    }

    /// Faut-il doubler l'enjeu ? Le seul pari du défenseur, en face à face.
    ///
    /// Il ne se gagne pas en sachant, il se gagne en sachant **ce que l'autre
    /// ignore**. Doubler sur une question facile est un piège : l'attaquant la
    /// sait aussi, et l'échange se joue alors au sablier — deux hommes à pile
    /// ou face. La machine mise donc sur ce qu'elle tient *et* qui est rare.
    static func relance(_ g: GameState, duel: Duel, level: Double,
                        style: Style, joueur: PlayerID) -> Bool {
        guard style != .facile else { return false }
        let p = probability(level: level + aptitude(joueur, duel.question.category),
                            difficulty: duel.question.difficulty,
                            allowance: duel.allowance, rules: g.rules)
        let rare: Double
        switch duel.question.difficulty {
        case .facile:    rare = 0
        case .moyen:     rare = 0.12
        case .difficile: rare = 0.25
        }
        // Doubler n'est pas un coup de force, c'est un coup de hasard : cela
        // multiplie l'écart sans déplacer l'espérance quand les deux savent —
        // l'échange se joue alors au sablier, à pile ou face, pour deux
        // hommes. Or le hasard sert celui qui est derrière et coûte à celui
        // qui mène. Mesuré : à relancer dès qu'elle se sentait sûre, la forte
        // doublait une fois sur quatre et **perdait son rang** contre la
        // moyenne (39 à 49 % selon le plateau). Elle ne relance donc que
        // lorsqu'elle sait *et* qu'elle a quelque chose à rattraper.
        var mien = 0, meilleurAutre = 0
        for j in g.players {
            let n = g.owner.values.filter { $0 == j.id }.count
            if j.id == joueur { mien = n } else { meilleurAutre = max(meilleurAutre, n) }
        }
        let derriere = mien < meilleurAutre
        let seuil: Double
        switch (style, derriere) {
        case (.forte, true):    seuil = 0.70
        case (.forte, false):   seuil = 0.95
        case (_, true):         seuil = 0.80
        default:                seuil = 0.97
        }
        return p + rare > seuil
    }

    // MARK: - Renforts

    /// Où poser un homme.
    ///
    /// Le gourmand pose sur la case la plus pressée, et recommence pour chaque
    /// homme : il étale donc ses renforts sur tout le front. Le stratège fait
    /// l'inverse — il colmate d'abord ce qui tombe au premier coup, puis il
    /// verse tout le reste sur **une seule** pointe. C'est la première leçon du
    /// Risk : une grosse pile bat cinq petites.
    static func reinforcement(_ g: GameState) -> TerritoryID? {
        let moi = g.currentPlayer.id
        let mine = g.territories(of: moi)
        guard !mine.isEmpty else { return nil }
        guard g.currentPlayer.style.concentre else {
            return mine.max { a, b in pression(g, a) < pression(g, b) }
        }

        // 1. Une place à un homme que l'ennemi peut prendre d'un coup tombera :
        //    elle vaut un renfort avant tout le reste.
        let fragiles = mine.filter { g.armies($0) == 1 && menace(g, $0) >= 3 }
        if let pire = fragiles.max(by: { menace(g, $0) < menace(g, $1) }) { return pire }

        // 2. Tout le reste sur la meilleure pointe.
        return pointe(g, moi) ?? mine.max { a, b in menace(g, a) < menace(g, b) }
    }

    /// La place d'où partira l'offensive : celle qui touche l'ennemi, qui
    /// promet le plus, et qui sert l'objectif.
    static func pointe(_ g: GameState, _ joueur: PlayerID) -> TerritoryID? {
        let vise = continentVise(g, joueur)
        return g.territories(of: joueur)
            .filter { !g.targets(from: $0).isEmpty }
            .max { a, b in valeurDePointe(g, a, vise) < valeurDePointe(g, b, vise) }
    }

    private static func valeurDePointe(_ g: GameState, _ id: TerritoryID,
                                       _ vise: Continent?) -> Double {
        var v = Double(g.armies(id)) * 0.6 + Double(potentiel(g, id)) * 0.8
        // Une pointe qui ouvre sur le continent visé vaut mieux qu'une autre.
        if let vise, g.targets(from: id).contains(where: {
            g.map[$0]?.continent == vise.id && g.owner[$0] != g.currentPlayer.id
        }) { v += 4 }
        return v
    }

    /// L'ancienne mesure du gourmand, gardée pour lui.
    private static func pression(_ g: GameState, _ id: TerritoryID) -> Double {
        let ennemis = menace(g, id)
        guard ennemis > 0 else { return -100 }
        let bonus = g.map.continentsInOrder.first { $0.id == g.map[id]?.continent }
            .map { c -> Double in
                let tenus = c.territories.filter { g.owner[$0] == g.owner[id] }.count
                return tenus >= c.territories.count - 1 ? 2 : 0
            } ?? 0
        return Double(ennemis) - Double(g.armies(id)) + bonus
    }

    // MARK: - Attaquer

    struct Plan: Equatable {
        let from: TerritoryID
        let to: TerritoryID
        let questions: Int
        let category: Category
    }

    /// Le meilleur assaut du moment, s'il en vaut la peine.
    ///
    /// `boldness` fixe le surnombre exigé : 1 demande un homme de plus que la
    /// place visée, 2 accepte le combat à forces égales. Le second n'est pas
    /// une folie — l'usure du siège fait que la cinquième question d'un tour
    /// se gagne trois fois sur quatre. C'est même indispensable : deux
    /// machines qui exigent toutes deux le surnombre s'enterrent face à face
    /// et la partie ne finit jamais.
    ///
    /// Le stratège ajoute deux choses au gourmand. Il ne descend pas sa pile
    /// au-dessous de trois hommes — une pile épuisée ne tient rien et ne prend
    /// plus rien. Et il pèse ce que la place vaut : achever un continent,
    /// briser celui de l'adversaire, ou n'être qu'une case de plus.
    static func assault<G: RandomNumberGenerator>(_ g: GameState, boldness: Double = 1.0,
                                                  using rng: inout G) -> Plan? {
        let moi = g.currentPlayer.id
        let style = g.currentPlayer.style
        let strategique = style.viseUnContinent
        let vise = strategique ? continentVise(g, moi) : nil
        var best: (score: Double, plan: Plan)?

        for from in g.territories(of: moi) where g.armies(from) >= 2 {
            // Une pile réduite à deux hommes n'attaque plus : elle tient.
            //
            // Cette ligne vaut cher, et je l'ai mesuré en la desserrant : la
            // laisser ramasser une place sans défense fait tomber le stratège
            // de 51 % à 32 % sur l'Europe. Prendre une case avec sa dernière
            // paire d'hommes, c'est exactement le défaut qu'on corrige.
            //
            // Et en face à face, exactement l'inverse. C'est la seule règle du
            // jeu qui change de signe d'un mode à l'autre : la retenir coûte à
            // la forte 14 points contre la moyenne (44 % au lieu de 58 % sur
            // l'Europe, 41 au lieu de 56 sur le Monde), là où le flair, la
            // pointe et le continent ne bougent pas de deux points. La raison
            // tient à ce que vaut un échange : en classique il coûte un homme
            // et n'en prend qu'un, si bien qu'une pile de deux ne finit
            // jamais rien ; en face à face, celui qui sait emporte l'échange
            // sec, et la relance peut en prendre deux d'un coup. La dernière
            // paire d'hommes peut donc achever une place — s'en priver, c'est
            // abandonner des conquêtes réelles.
            if style.retientSesPiles, g.rules.mode == .classique,
               g.armies(from) <= 2, menace(g, from) > 0 { continue }
            for to in g.targets(from: from) {
                let advantage = Double(g.armies(from) - 1 - g.armies(to))
                // Une place déjà pressée ce tour-ci répond dans un sablier plus
                // court : elle vaut mieux qu'une place fraîche à effectif égal.
                // Le sablier se resserre à chaque question subie par une même
                // place dans le tour : achever une place entamée coûte bien
                // moins cher que d'en ouvrir une autre. C'est la stratégie
                // propre à ce jeu, et la forte est la seule à s'en servir.
                //
                // En face à face, ce levier perd son tranchant sans changer de
                // sens. Le sablier raccourci s'applique aux deux, et quand
                // personne ne sait la place tient : presser fabrique donc des
                // égalités, qui appartiennent au défenseur — à p égal des deux
                // côtés, l'attaquant l'emporte dans `p − p²/2` des échanges,
                // soit 44 % à 0,65 mais 35 % à 0,45. J'ai voulu en tirer la
                // conclusion et faire fuir les places entamées : c'était une
                // faute. La machine cessait d'achever ce qu'elle avait ouvert,
                // les parties passaient de 13 à 23 tours, treize sur trois
                // cents ne finissaient plus. Une place fraîche n'est pas
                // meilleure — elle est seulement neuve, et les hommes déjà
                // dépensés sur l'autre sont perdus.
                let usure = Double(g.siege[to] ?? 0) * (style.exploiteLeSablier ? 1.6 : 0.7)
                guard advantage + usure >= 2 - boldness else { continue }

                var score = advantage + usure
                if let c = g.map.continentsInOrder.first(where: { $0.id == g.map[to]?.continent }) {
                    // Achever un continent vaut mieux que grignoter.
                    if c.territories.filter({ g.owner[$0] != moi }).count == 1 {
                        score += Double(c.bonus) * 1.5
                    }
                    if strategique {
                        // Avancer dans le continent visé, et briser celui que
                        // l'adversaire est sur le point de tenir.
                        if c.id == vise?.id { score += 3 }
                        let adverse = g.owner[to]
                        if let adverse, c.territories.allSatisfy({ g.owner[$0] == adverse }) {
                            score += Double(c.bonus)
                        }
                    }
                }
                if strategique {
                    // Ne pas se jeter sur une place qu'on ne pourra pas garder.
                    score -= Double(menace(g, to)) * 0.15
                }
                let plan = Plan(from: from, to: to,
                                questions: min(g.maxQuestions(from: from), advantage >= 2 ? 2 : 1),
                                category: category(g, against: g.owner[to] ?? -1, using: &rng))
                if best == nil || score > best!.score { best = (score, plan) }
            }
        }
        return best?.plan
    }

    /// Où frapper. C'est tout le métier de l'attaquant dans cette variante —
    /// et c'est aussi là qu'une machine devient insupportable si on la laisse
    /// faire au mieux.
    ///
    /// Viser à chaque fois la faiblesse exacte est le coup optimal, et le plus
    /// mauvais de tous : on reçoit dix fois de suite le même sujet, la
    /// catégorie s'épuise, et chaque duel ressemble au précédent. Un joueur
    /// réel sonde. Le tirage est donc pondéré — ce qui est raté pèse lourd, ce
    /// qui est réussi pèse peu, ce qu'on ignore encore garde sa chance — et le
    /// même sujet deux fois d'affilée devient improbable sans être exclu.
    static func category<G: RandomNumberGenerator>(_ g: GameState, against player: PlayerID,
                                                   using rng: inout G) -> Category {
        let style = g.currentPlayer.style
        // Sans flair, elle ne regarde même pas le dossier.
        guard style.flair > 0 else { return Category.allCases.randomElement(using: &rng)! }

        let precedente = style == .forte ? g.lastCategoryAgainst[player] : nil
        let poids: [(Category, Double)] = Category.allCases.map { c in
            let score = g.record(of: player, in: c)
            // Sans échantillon, on prête à l'adversaire une réussite moyenne :
            // ni redoutable ni offert, donc digne d'être sondé.
            let leur = score.asked == 0 ? 0.5 : score.rate
            var p: Double
            if g.rules.mode == .classique {
                let echec = 1 - leur
                p = 0.20 + echec * echec * style.flair
            } else {
                // En face à face, on répond aussi : ce qu'il faut chercher
                // n'est plus la faiblesse d'en face, c'est **l'écart**.
                // Choisir l'ignorance de l'autre en s'y jetant soi-même, c'est
                // se piéger avec lui — et l'échange se règle alors sur une
                // égalité, qui appartient au défenseur.
                let mien = g.record(of: g.currentPlayer.id, in: c)
                let ma = mien.asked == 0 ? 0.5 : mien.rate
                let ecart = max(0, ma - leur)
                p = 0.20 + ecart * ecart * style.flair
            }
            if c == precedente { p *= 0.22 }
            return (c, p)
        }
        let total = poids.reduce(0) { $0 + $1.1 }
        var tirage = Double.random(in: 0 ..< total, using: &rng)
        for (c, p) in poids {
            tirage -= p
            if tirage <= 0 { return c }
        }
        return poids.last!.0
    }

    // MARK: - Occuper, déplacer

    /// Combien d'hommes avancent dans la place conquise.
    ///
    /// C'est ici que le gourmand semait ses garnisons d'un homme : dès que sa
    /// base touchait encore un ennemi, il n'avançait que le minimum, et la
    /// place reprise retombait au tour suivant. Le stratège fait le compte
    /// inverse : il garde à la base ce qu'il lui faut pour tenir, et **tout le
    /// reste avance**. Une place prise est une place à défendre.
    static func occupation(_ g: GameState) -> Int {
        guard case let .occupation(from, _, minimum, maximum) = g.phase else { return 1 }
        guard g.currentPlayer.style.garnisonne else {
            let exposee = g.map.neighbors(of: from).contains { g.owner[$0] != g.owner[from] }
            return exposee ? minimum : maximum
        }
        // Ce qui reste derrière : de quoi tenir la base, pas davantage.
        let reste = garnison(g, from)
        let avance = g.armies(from) - reste
        return min(maximum, max(minimum, avance))
    }

    /// Ramener l'arrière vers le front.
    ///
    /// Le gourmand vise la case la plus pressée : il colmate. Le stratège
    /// vise sa pointe : il prépare le tour suivant. Colmater partout, c'est
    /// n'être fort nulle part.
    static func fortification(_ g: GameState) -> (from: TerritoryID, to: TerritoryID, count: Int)? {
        let me = g.currentPlayer.id
        let mine = g.territories(of: me)
        let front = mine.filter { id in g.map.neighbors(of: id).contains { g.owner[$0] != me } }
        let rear = mine.filter { !front.contains($0) && g.armies($0) >= 2 }
        guard let source = rear.max(by: { g.armies($0) < g.armies($1) }) else { return nil }

        let atteignables = front.filter { g.areLinked(source, $0, for: me) }
        guard !atteignables.isEmpty else { return nil }

        let cible: TerritoryID?
        if g.currentPlayer.style.concentre {
            let vise = continentVise(g, me)
            // Une place qui tombe au premier assaut passe avant la pointe :
            // perdre un territoire coûte un renfort à chaque tour suivant.
            let enPeril = atteignables.filter { g.armies($0) == 1 && menace(g, $0) >= 3 }
            cible = enPeril.max(by: { menace(g, $0) < menace(g, $1) })
                ?? atteignables.max(by: {
                    valeurDePointe(g, $0, vise) < valeurDePointe(g, $1, vise)
                })
        } else {
            cible = atteignables.max(by: { pression(g, $0) < pression(g, $1) })
        }
        guard let target = cible else { return nil }
        return (source, target, g.armies(source) - 1)
    }
}
