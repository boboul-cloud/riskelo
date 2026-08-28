//
//  Rules.swift
//  Riskelo
//
//  Toutes les manettes du jeu, au même endroit — et ce que la simulation a
//  répondu quand on les a tournées.
//
//  Le Risk tient son équilibre du hasard : l'attaquant lance plus de dés que
//  le défenseur et finit statistiquement par passer. Remplacer le dé par une
//  question supprime ce ressort. Deux conséquences, toutes deux mesurées sur
//  des milliers de parties jouées par la machine contre elle-même :
//
//  1. La part de duels gagnés par l'attaquant vaut exactement « un moins le
//     taux de bonnes réponses du défenseur ». Avec trente secondes par
//     question, le défenseur tenait sept fois sur dix : attaquer devenait une
//     mauvaise affaire, et il fallait près de deux cents questions pour finir
//     une partie. À quinze secondes, l'attaquant l'emporte dans 48 % des
//     duels — la fourchette du Risk d'origine, où il gagne 39 % des
//     comparaisons à deux dés contre deux, 42 % à un contre un.
//
//  2. Sans hasard, un joueur qui sait ne perd jamais sa place, quelle que
//     soit l'armée en face. Ce qui remplace la statistique, c'est l'usure :
//     le sablier se raccourcit à chaque question subie par un même territoire
//     dans le même tour. Presser une place finit par payer, comme au Risk —
//     mais c'est le souffle du défenseur qui cède, pas le sort.
//
//  Une seule manette pousse dans ce sens, volontairement : la difficulté des
//  questions ne monte pas avec le siège. Deux réglages qui tirent au même
//  endroit ne se règlent plus séparément.
//

import Foundation

struct Rules: Equatable, Codable {

    // MARK: - Le duel

    /// Le mode de jeu, choisi à la mise en place.
    ///
    /// En **classique**, l'attaquant choisit le terrain et le défenseur seul
    /// répond : la culture est une armure, jamais une arme, et l'attaquant
    /// passe son propre tour à regarder l'autre réfléchir.
    ///
    /// En **face à face**, les deux répondent à la même question. C'est le
    /// duel du Risk retrouvé — les deux lancent — et il a fallu pour cela
    /// emprunter deux règles telles quelles au dé :
    ///
    ///     les deux savent          → le sablier tranche, le plus vif l'emporte
    ///     aucun des deux ne sait   → la place tient, comme sur une égalité
    ///
    /// Le départage au sablier n'est pas un ornement, c'est ce qui tient
    /// l'équilibre. Sans lui, l'attaquant ne l'emporterait plus que dans
    /// `p × (1−p)` des échanges — 23 % à 65 % de bonnes réponses — et la
    /// partie se figerait, personne ne pouvant plus prendre une place. Avec
    /// lui on remonte à 44 %, la fourchette du dé contre dé du Risk (41,7 %).
    var mode: Mode = .classique

    enum Mode: String, CaseIterable, Identifiable, Codable {
        case classique
        case faceAFace

        var id: String { rawValue }

        var label: String {
            switch self {
            case .classique: "Classique"
            case .faceAFace: "Face à face"
            }
        }

        var detail: String {
            switch self {
            case .classique:
                "L'attaquant choisit le thème, le défenseur seul répond."
            case .faceAFace:
                "Les deux répondent à la même question. Le défenseur peut doubler l'enjeu."
            }
        }
    }

    /// Les « dés » de l'attaquant : une ou deux questions par assaut.
    var maxQuestions = 2

    /// Sablier de la première question d'un siège.
    ///
    /// Quinze secondes, et non trente : c'est le réglage qui décide de tout
    /// l'équilibre du jeu (voir l'en-tête). Le temps de lire l'énoncé, de
    /// savoir, et de répondre.
    var baseSeconds: TimeInterval = 15

    /// Ce qu'il reste du sablier à chaque question suivante sur le même
    /// territoire, dans le même tour : 15 s, 11,7 s, 9,1 s, 7,1 s, 6 s.
    var siegePressure: Double = 0.78

    /// En dessous, la question n'est plus une question mais un réflexe.
    var minSeconds: TimeInterval = 6

    /// Poids de tirage des trois niveaux de difficulté.
    var difficultyWeights: [Difficulty: Int] = Dosage.melees.poids

    /// Le dosage des questions, tel qu'on le choisit à la mise en place. C'est
    /// un réglage de jeu — on choisit à quel point la partie est corsée, comme
    /// on choisit la culture de la machine.
    enum Dosage: String, CaseIterable, Identifiable, Codable {
        case faciles, melees, corsees
        var id: String { rawValue }

        var label: String {
            switch self {
            case .faciles: "Faciles"
            case .melees:  "Mêlées"
            case .corsees: "Corsées"
            }
        }

        var detail: String {
            switch self {
            case .faciles: "De quoi jouer avec des enfants."
            case .melees:  "Les trois niveaux, comme dans une boîte de jeu."
            case .corsees: "Pour ceux qui trouvent le reste trop facile."
            }
        }

        var poids: [Difficulty: Int] {
            switch self {
            case .faciles: [.facile: 6, .moyen: 3, .difficile: 1]
            case .melees:  [.facile: 4, .moyen: 4, .difficile: 2]
            case .corsees: [.facile: 1, .moyen: 3, .difficile: 6]
            }
        }
    }

    // MARK: - Le tour

    /// Renfort minimal par tour, quoi qu'il arrive.
    var reinforcementFloor = 3

    /// Un renfort par tranche de tant de territoires. Passer à quatre allonge
    /// la partie de moitié sans rien changer à l'équilibre.
    var territoriesPerReinforcement = 3

    /// Armées de départ, avant répartition sur les territoires reçus.
    var startingArmies = 22

    /// Les cartes de territoire du Risk. Option : elles changent l'économie
    /// des renforts, et le plateau se joue très bien sans elles.
    var territoryCards = false

    /// Un homme de plus toutes les tant de bonnes réponses dans un même thème.
    /// `nil` retire la règle.
    ///
    /// Seul le défenseur répond : ce renfort récompense donc celui qui tient
    /// sa place en sachant, et il échoit surtout à qui se fait attaquer —
    /// c'est-à-dire, le plus souvent, à celui qui est en train de perdre. Reste
    /// à savoir si cela rattrape les écarts ou les creuse : c'est mesuré.
    var answersPerBonusMan: Int? = 5

    /// Le déplacement de fin de tour suit-il une chaîne de territoires amis
    /// (règle « moderne »), ou seulement un voisinage direct ?
    var fortifyAlongChain = true

    // MARK: - La fin

    /// Part du monde qui suffit à gagner, sans avoir à ramasser les miettes.
    /// `nil` prend la valeur mesurée ; `0` demande la **guerre totale** — tous
    /// les territoires, sans exception.
    ///
    /// La conquête intégrale fait traîner la fin : les derniers territoires
    /// sont tenus par un joueur qui n'a plus rien à perdre et se contente de
    /// répondre juste. À deux, elle coûte 177 questions là où le seuil de 65 %
    /// en demande 90 — et le vainqueur est le même.
    var dominationOverride: Double?

    /// Ce que reçoit en plus, au départ, chaque joueur qui passe après le
    /// premier. `nil` prend la valeur mesurée.
    ///
    /// Ouvrir vaut cher : à deux joueurs, sans compensation, celui qui
    /// commence gagne 61 % des parties. Deux hommes rétablissent le partage
    /// (51/48 sur six cents parties).
    var compensationOverride: Int?

    // MARK: - Ce qui en découle

    func answerTime(siege: Int) -> TimeInterval {
        max(minSeconds, baseSeconds * pow(siegePressure, Double(max(0, siege))))
    }

    func reinforcements(territories: Int, continentBonus: Int) -> Int {
        max(reinforcementFloor, territories / territoriesPerReinforcement) + continentBonus
    }

    func drawDifficulty<G: RandomNumberGenerator>(using rng: inout G) -> Difficulty {
        let table = Difficulty.allCases.flatMap { d in
            Array(repeating: d, count: difficultyWeights[d] ?? 1)
        }
        return table.randomElement(using: &rng) ?? .moyen
    }

    /// Le seuil de victoire : sa part de départ, plus trois territoires et
    /// demi. Ce n'est pas une part fixe du monde — 65 % ne veut pas dire la
    /// même chose à deux et à quatre, où l'on part de 25 %. C'est un écart, et
    /// c'est lui qui fixe la durée : quel que soit le nombre de joueurs, il
    /// faut une douzaine de tours pour le franchir.
    func dominationThreshold(territories: Int, playerCount: Int) -> Int {
        if let dominationOverride {
            return dominationOverride <= 0 ? territories
                : Int((Double(territories) * dominationOverride).rounded(.up))
        }
        let depart = Double(territories) / Double(max(2, playerCount))
        return min(territories, Int((depart + victoryGap).rounded(.up)))
    }

    /// L'écart à prendre, en territoires, sur sa part de départ. Sept donne
    /// des parties de 65 questions à deux, 120 à trois, 160 à quatre — une
    /// vingtaine de minutes à une heure. Chaque point ajoute une dizaine de
    /// questions.
    var victoryGap: Double = 7

    /// La compensation de rang, telle que la simulation l'a réglée : deux
    /// hommes à deux joueurs, rien au-delà. À trois et plus, l'avantage
    /// d'ouvrir se dilue de lui-même — celui qui frappe le premier s'expose
    /// à deux voisins au lieu d'un.
    func compensation(playerCount: Int) -> Int {
        if let compensationOverride { return compensationOverride }
        return playerCount <= 2 ? 2 : 0
    }
}
