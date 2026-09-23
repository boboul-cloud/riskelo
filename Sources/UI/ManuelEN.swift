//
//  ManuelEN.swift
//  Riskelo
//
//  Le mode d'emploi, en anglais.
//
//  Il n'est pas une traduction du français : il a été réécrit pour un lecteur
//  américain, à l'époque où l'application américaine devait vivre à part. Elle
//  n'a pas vu le jour — Apple refuse deux applications qui ne diffèrent que
//  par la langue de leur contenu — mais le texte, lui, reste bon.
//
//  Il tient dans un fichier de code plutôt que dans une ressource, et c'est un
//  choix. Un chapitre n'est pas de la prose : c'est une suite de blocs typés,
//  avec des couleurs et des symboles que le compilateur vérifie. Inventer un
//  format de fichier et son analyseur aurait remplacé cette vérification par
//  des fautes découvertes à l'exécution, pour le seul plaisir de sortir le
//  texte du binaire — où il retourne de toute façon.
//
//  Les banques de questions, elles, sont bien des fichiers : douze mille
//  lignes de données sans type ni couleur. La règle n'est pas « tout en
//  fichier », elle est « chaque chose là où on peut la vérifier ».
//

import SwiftUI

enum ManuelEN {

    /// A board's possible conquests, spelled out.
    ///
    /// Generated, not copied. The deck is cut to fit the board — two big
    /// continents, three small, shares of territory — and a list written by
    /// hand would start lying at the first continent that changes size. The
    /// elimination cards are left out: they take one sentence, and there is
    /// one per side.
    static func conquests(_ board: Boards) -> [String] {
        Objectif.paquet(pour: board.board, joueurs: 2).map { $0.texte(board.board) }
    }

    /// What the fallback costs, board by board — read from the engine. Three
    /// numbers written by hand would lie the day the share changes, and it
    /// would be the manual that was wrong.
    static var fallbacks: String {
        Objectif.liste(Boards.allCases.map { board in
            "\(Objectif.repli(board.board).nombreDemande ?? 0) on \(board.label)"
        })
    }

    /// The victory thresholds, board by board and by number of players — read
    /// from the rules rather than tabulated by hand, for the same reason.
    static var victoryRows: [[String]] {
        let rules = Rules()
        return Boards.allCases.map { board in
            let total = board.board.map.order.count
            return ["\(board.label) — \(total) territories"]
                + [2, 3, 4].map {
                    "\(rules.dominationThreshold(territories: total, playerCount: $0))"
                }
        }
    }

    /// The themes that ship with the game, named by the catalogue. Read from
    /// the question files, so that a theme added or renamed does not leave
    /// the manual behind.
    static var baseThemes: [String] { Themes.base.map(\.label) }

    /// How many questions the app carries, counted rather than claimed — and
    /// counted in this language only. The bundle holds both banks, twelve
    /// thousand questions; an English reader is offered six thousand of them,
    /// and it is that number the manual must give.
    static var questionCount: Int {
        let miennes = Set(Themes.tous.map(\.id))
        return QuestionBank().questions.filter { miennes.contains($0.category.id) }.count
    }




    static let chapitres: [Chapitre] = [
        firstGame, duel, showdown, dice, turn, victory, setup, screen,
        cards, file, memory, network, bank, tips, legal,
    ]

    // MARK: 1

    private static let firstGame = Chapitre(
        id: "debut", titre: "In two minutes",
        resume: "What you need to play your first turn.",
        icone: "bolt.fill", teinte: Palette.camp(0),
        blocs: [
            .p("Riskelo is a conquest game: territories, troops, and an opponent "
               + "to dislodge. When you attack, a trivia question decides the "
               + "outcome — it stands in for the die. If you would rather have the "
               + "die back, that is the third mode."),
            .h("Your first turn"),
            .puces([
                "Tap \"Quick game\": two players, the Ring board, a machine of medium "
                + "knowledge. The settings can wait.",
                "Your territories carry your color and the number of troops holding "
                + "them. The ones you cannot play stay in shadow.",
                "Reinforce: tap your territories to lay down the troops the hint "
                + "names, one per tap.",
                "Attack: tap one of your territories with at least two troops, then an "
                + "enemy neighbor. A panel opens — pick the theme of the question and "
                + "how many questions, then \"Launch the assault\".",
                "Move: one only, to a territory of yours linked to the one you start "
                + "from. Then \"End turn\".",
            ]),
            .note("The bottom bar always says what is expected of you, and the feed of "
                  + "three steps says how far along the turn you are. When in doubt, "
                  + "that is where to look."),
            .h("What the question decides"),
            .p("The defender answers, within the time on the clock. Answer right and "
               + "you lose a troop; answer wrong or let the time run out and they do. "
               + "One question is worth exactly one pair of dice in Risk: it costs one "
               + "side a troop."),
            .p("The second mode, \"showdown\", puts the same question to both players "
               + "— it has a chapter of its own."),
        ])

    // MARK: 2

    private static let duel = Chapitre(
        id: "duel", titre: "The duel",
        resume: "The question stands in for the die — who asks, who answers, how long they have.",
        icone: "questionmark.circle.fill", teinte: Palette.bleu,
        blocs: [
            .p("The attacker chooses two things: the theme of the question, and how "
               + "many questions — one or two. Those are their dice. The defender "
               + "answers."),
            .tableau(["What the defender does", "The dice equivalent", "Who loses a troop"],
                   [["Right answer", "Higher die", "The attacker"],
                    ["Wrong answer", "Lower die", "The defender"],
                    ["Time runs out", "The lowest die", "The defender"]]),
            .h("One question or two"),
            .p("Two questions means two chances to take the place — and two possible "
               + "losses on your side. The bet is Risk's. You can only launch as many "
               + "questions as your stack can pay for: a territory of two troops asks "
               + "one."),
            .h("The theme never wanders"),
            .p("The theme you ask for is honored: the bank never leaves the category "
               + "you chose. Once it runs dry it starts over rather than drifting to "
               + "another subject. That is what makes choosing the ground reliable — "
               + "and that is where your skill lies."),
            .h("Or the theme left to chance"),
            .p("Under the six theme tiles sits a seventh choice: \"at random\". The "
               + "question is then drawn from the whole bank, theme included. You give "
               + "up your only advantage — and in a showdown, where you answer too, "
               + "you give up a ground you were picking for yourself as much as for "
               + "your opponent."),
            .h("A question does not come back"),
            .p("Within a game, a theme serves all its questions before repeating one. "
               + "Between games too: the device remembers what has already come up, "
               + "and at equal difficulty a question never seen goes ahead of one "
               + "already asked. The count is in the settings, where you can also "
               + "clear it."),
            .h("The clock, and the wear of a siege"),
            .p("Fifteen seconds on the first question. A player who knows would never "
               + "lose their place: what replaces the statistics of the die is time "
               + "tightening. Every question the same territory faces, within the same "
               + "turn, shortens the clock."),
            .code("1st question    15.0 s\n2nd             11.7 s\n3rd              9.1 s\n"
                  + "4th              7.1 s\n5th and after    6.0 s"),
            .p("The clock resets between turns. Pressing a place therefore pays in the "
               + "end — but it is the defender's breath that gives out, not the luck of "
               + "a roll."),
            .h("Taking the place"),
            .p("When the last garrison falls, you choose how many troops advance: at "
               + "least as many as there were questions, and never your last troop — a "
               + "territory always keeps one."),
            .note("The machine always answers something: running out of time is a human "
                  + "act, and a human one only."),
        ])

    // MARK: 3

    private static let showdown = Chapitre(
        id: "face", titre: "Showdown",
        resume: "The second mode: both players answer the same question.",
        icone: "person.2.fill", teinte: Palette.camp(1),
        blocs: [
            .p("In classic play only one hand rolls the dice: the defender answers, and "
               + "the attacker's knowledge does them no good while attacking. It is "
               + "armor, never a weapon. In a showdown, both get the same question."),
            .tableau(["What happens", "What follows"],
                   [["Only one of them knows", "They win the exchange"],
                    ["Both know", "The clock settles it; a strict tie goes to the defender"],
                    ["Neither knows", "The place holds — Risk's tie"]]),
            .p("Settling it on the clock is not an ornament: without it nobody would "
               + "ever take a place again and the game would freeze. It settles about "
               + "four exchanges in ten."),
            .note("Speed never separates two unequal answers: a fast ignoramus does not "
                  + "beat a slow scholar. It only decides what Risk decided with the "
                  + "number on the die."),
            .h("The verdict sheet"),
            .p("Both answers appear side by side, each with its time, and a crown on "
               + "the one that wins. It is necessary: without it you answer correctly, "
               + "lose a place, and can only think the game got it wrong."),
            .h("The raise — doubling the stake"),
            .p("Before answering, the defender can double: the exchange will be worth "
               + "two troops instead of one, whichever way it falls. The button appears "
               + "only for them, and only before they answer."),
            .p("Doubling is not a show of strength, it is a throw of the dice: when "
               + "both players know, the exchange comes down to the clock, which is a "
               + "coin toss — for two troops. And chance serves whoever is behind and "
               + "costs whoever leads."),
            .note("A stake of two never pays more than the stack across the line can "
                  + "afford: you do not strip the attacker of their last garrison. "
                  + "Doubling against a stack of two troops therefore wins one troop."),
            .h("On a shared device"),
            .p("Each player answers in turn, the device passes between them, and the "
               + "screen waits for an \"I'm ready\" before starting the clock — nobody "
               + "sees the question before their turn."),
        ])

    // MARK: 4

    private static let dice = Chapitre(
        id: "des", titre: "Dice",
        resume: "The third mode: no questions at all, one die against one die.",
        icone: "dice.fill", teinte: Palette.camp(3),
        blocs: [
            .p("The first two modes replace the die with a question. This one goes "
               + "the other way: there is no question at all. You declare the "
               + "assault, the dice fall, and the place holds or gives."),
            .tableau(["What comes up", "What follows"],
                     [["The attacking die is higher", "The place loses a troop"],
                      ["The defending die is higher", "The attacker leaves a troop"],
                      ["The two are equal", "The place holds — ties go to the defender"]]),
            .p("This is the board game's rule, word for word, and the tie going to "
               + "the defender is the heart of it: you have to do better than them, "
               + "not as well. The attacker wins fifteen throws out of thirty-six."),
            .note("All three modes therefore run to the same length. A question on a "
                  + "fifteen-second timer gives the attacker 48 % of exchanges, the "
                  + "showdown 44 %, the dice 41.7 %: a game lasts no longer and no "
                  + "shorter for the mode you picked."),
            .h("What goes away"),
            .p("No subject to choose before an assault, no timer, no raise, and no "
               + "knowledge file to consult: there is nothing to know about anyone. "
               + "Setup drops the question mix and the scholar's reinforcement on its "
               + "own, since neither has anything left to act on."),
            .h("What stays"),
            .p("Everything else: reinforcements, continents, territory cards, private "
               + "objectives, the end-of-turn move, the victory threshold. One or two "
               + "dice per assault, just as one or two questions, and you never attack "
               + "with your garrison."),
            .h("Who it is for"),
            .puces([
                "Evenings when you would rather not think.",
                "Players too young for the questions — the map, the reinforcements and "
                + "the continents are enough to make a game.",
                "Anyone who wants to see where the rest comes from: play one with dice, "
                + "then the same one in classic, and the variant explains itself.",
            ]),
            .note("Across devices the dice fall on both sides with nothing sent: the "
                  + "two devices draw the same sequence from the same seed. It is the "
                  + "same mechanism that lets a game resume where it was left."),
        ])

    // MARK: 5

    private static let turn = Chapitre(
        id: "tour", titre: "The turn",
        resume: "Reinforce, attack, one move — then the turn passes.",
        icone: "arrow.triangle.2.circlepath", teinte: Palette.camp(2),
        blocs: [
            .h("1 — Reinforcements"),
            .p("One troop per three territories held, with a floor of three troops, "
               + "plus the bonus of every continent you hold whole. Tap your "
               + "territories to lay them down, one per tap. While any remain, the turn "
               + "does not pass."),
            .h("2 — Attacks"),
            .p("As many assaults as you like, as long as you have stacks of at least "
               + "two troops. Tap the territory you set out from, then an enemy "
               + "neighbor: the assault panel opens. It shows the balance of forces, "
               + "the six themes with what the defender has shown on each — or the "
               + "theme at random — and the choice of one or two questions."),
            .p("A place taken is garrisoned at once: you choose how many troops "
               + "advance, at least as many as there were questions."),
            .h("3 — The move"),
            .p("One only, at the end of the turn: from one of your territories to "
               + "another of yours, linked to the first by an unbroken chain of "
               + "friendly territories. You can also end without moving anything."),
            .note("A territory is never left empty: one troop always stays, at the "
                  + "start as at the finish."),
            .h("What the turn pays as it passes"),
            .puces([
                "The scholarship reinforcement: one extra troop for every N correct "
                + "answers within one theme, if the rule is in play.",
                "A territory card, if the rule is in play and you took at least one "
                + "place during the turn.",
            ]),
        ])

    // MARK: 6

    private static let victory = Chapitre(
        id: "victoire", titre: "Winning the game",
        resume: "The domination threshold, personal conquests, elimination.",
        icone: "flag.checkered", teinte: Palette.held,
        blocs: [
            .p("Winning does not require taking everything: you have to hold your "
               + "starting share plus seven territories. It is a gap, not a fixed share "
               + "of the world — one player in four starts from 25%, not 50%."),
            .tableau(["Board", "2 players", "3", "4"], ManuelEN.victoryRows),
            .p("The top bar carries that count at all times: your territories over the "
               + "threshold to cross. Personal conquests, further down, withdraw that "
               + "threshold: the bar then shows the whole board."),
            .h("Total war"),
            .p("The option removes the threshold: every territory, no exceptions. "
               + "Expect about twice as many questions — 112 instead of 71 with two "
               + "players. It is a whole evening's game, and that is the point."),
            .h("Personal conquests"),
            .p("The option deals everyone a secret objective at the start. Filling it "
               + "wins the game on the spot, and it is the only way to win: the "
               + "threshold in the table above withdraws. The count in the top bar then "
               + "says nothing about who is going to win — whoever looks behind may be "
               + "holding their two continents."),
            .puces([
                "Hold two big continents, or three small ones — taken from the size of "
                + "the board, since the Ring has no Australia.",
                "Hold so many territories: about half the board, or fewer if two or "
                + "three troops are required on each.",
                "Bring down a side, by your own hand — at three players and above.",
            ]),
            .p("Here they all are, board by board. They are dealt without replacement: "
               + "two players never have the same one."),
            .h("On the Ring"),
            .puces(ManuelEN.conquests(.anneau)),
            .h("On Europe"),
            .puces(ManuelEN.conquests(.europe)),
            .h("On the World"),
            .puces(ManuelEN.conquests(.monde)),
            .p("At three players and above, one card per side is added: \"wipe out "
               + "Red's side\", or Green's, Amber's or Purple's — and never your own."),
            .p("A target somebody else brings down before you does not count: your card "
               + "turns over and becomes a territory conquest, as in Risk. Otherwise "
               + "you would spend the rest of the game unable to win."),
            .p("That fallback asks for four places out of five on the board — "
               + "\(ManuelEN.fallbacks). It is the only threshold left in a game with "
               + "conquests, and it counts only for the player whose card has died: any "
               + "cheaper and bad luck would become a shortcut, and you would win faster "
               + "for having lost your prey than for having held your continents."),
            .p("The target button in the top bar shows yours and how far along you are. "
               + "It never shows anyone else's: across devices, each player sees only "
               + "their own; on a shared device, it shows the conquest of whoever is "
               + "playing — you do not look at your neighbor's card. They all turn over "
               + "at the end, on the victory screen."),
            .note("The machine is dealt a conquest like you, and can win by it. It does "
                  + "not chase it, though: it plays the way it has always played, and "
                  + "that is your advantage."),
            .h("Elimination"),
            .p("A player who loses their last territory is eliminated; their name stays "
               + "struck through in the strip of sides. If territory cards are in play, "
               + "whoever finishes them off takes their hand."),
            .h("Opening costs"),
            .p("With two players, whoever goes first starts two troops down: without "
               + "that they would win six games in ten. Beyond two players the advantage "
               + "dilutes on its own — whoever strikes first exposes themselves to two "
               + "neighbors instead of one."),
        ])

    // MARK: 7

    private static let setup = Chapitre(
        id: "reglages", titre: "Setting up",
        resume: "Every setting behind the \"Settings\" button, one by one.",
        icone: "slider.horizontal.3", teinte: Palette.vert,
        blocs: [
            .h("Mode of play"),
            .termes([
                ("Classic", "The attacker picks the theme, the defender alone answers."),
                ("Showdown", "Both answer the same question; the defender can double "
                 + "the stake."),
            ]),
            .h("Board"),
            .termes([
                ("The Ring", "An invented world, five lands in a circle. 28 territories. "
                 + "The shortest game."),
                ("Europe", "From the Atlantic to the Black Sea. 38 territories, six regions."),
                ("World", "The world map, drawn from real coastlines. 42 territories "
                 + "across six continents, twenty sea crossings."),
            ]),
            .h("Players, and humans on this device"),
            .p("Two to four players. The second setting says how many are sitting in "
               + "front of this screen: the rest are held by the machine. With several "
               + "humans on one device, it is passed before each question, and the "
               + "screen waits for an \"I'm ready\"."),
            .h("Machine strategy"),
            .termes([
                ("Easy", "It advances at random and scatters one-troop garrisons."),
                ("Medium", "It holds what it takes and looks for your weak spots."),
                ("Strong", "It concentrates its reinforcements on a single spearhead, "
                 + "aims at the continent closest to complete, finishes off a place "
                 + "already pressed whose clock has shortened, and stops attacking when "
                 + "its stack is down to two troops."),
            ]),
            .h("Machine knowledge"),
            .p("This is not an abstract difficulty: it is the machine's share of "
               + "correct answers on an average question, from 35% to 90%. So you know "
               + "exactly what you are up against. Distracted, fair, well-read, "
               + "formidable — five points of difference is enough to tip two games in "
               + "three."),
            .p("Its knowledge and its maneuvering are two separate settings: you can be "
               + "learned and play badly."),
            .h("Questions"),
            .termes([
                ("Easy", "Gentle enough to play with children."),
                ("Mixed", "All three levels, as in a boxed game."),
                ("Tough", "For anyone who finds the rest too easy."),
            ]),
            .h("Scholarship reinforcement"),
            .p("One extra troop for every N correct answers within one theme. The "
               + "slider runs from 0 to 10; at zero the rule is removed. Five is the "
               + "default; three makes knowledge weigh more."),
            .p("In classic play only the defender answers, so this reinforcement goes "
               + "to whoever holds their place by knowing. In a showdown it goes to "
               + "whoever knows, attacking or defending."),
            .h("Game rules"),
            .termes([
                ("Territory cards", "One card per turn in which you take a place; three "
                 + "matching are worth troops, and the scale climbs."),
                ("Total war", "Every territory, no exceptions. About twice as many "
                 + "questions."),
                ("Personal conquests", "A secret objective each; filling it wins, and "
                 + "the territory threshold withdraws."),
            ]),
            .h("You"),
            .p("A name, optional, for whoever is holding the device. It is added to the "
               + "side's color without replacing it — \"Blue · Alex\" — because the "
               + "board knows nothing but colors: a name that cannot be found there "
               + "would be no use. Fourteen characters at most, so the strip of sides "
               + "fits on one line."),
            .p("Over the network it travels: each device says its name on arriving in "
               + "the lobby, and all four screens show the same players. Yours carries "
               + "\"me\" at the end — otherwise, with everyone seeing the same thing, "
               + "nothing would say which one is yours."),
            .h("Sound"),
            .p("A short muted note for every troop you lay down — discreet enough to "
               + "repeat ten times running without wearing thin. Then a note at the "
               + "outcome of every exchange: rising when it goes your way, falling when "
               + "it goes against you. Two machines fighting each other stay silent — "
               + "you have no part in it. Plus the opening, when the app launches."),
            .p("It is the one setting on this screen that is not about the game: it "
               + "holds for the whole app and is kept from one game to the next. On an "
               + "iPhone the silent switch mutes it, and the music you were listening "
               + "to carries on."),
            .h("The buttons at the bottom"),
            .termes([
                ("Start", "Launches the game with what is set above. Resuming a game in "
                 + "progress is on the home screen instead."),
                ("Saved games", "The library of moments — see the chapter \"Resume, "
                 + "mark, go back\"."),
                ("Play across devices", "One device per player, up to four — in the "
                 + "same room, with a six-letter code, or through Game Center."),
            ]),
        ])

    // MARK: 8

    private static let screen = Chapitre(
        id: "ecran", titre: "The game screen",
        resume: "What each bar carries, and what answers to a finger.",
        icone: "rectangle.3.group.fill", teinte: Palette.bois,
        blocs: [
            .h("The top bar"),
            .termes([
                ("The chevron", "Leaves the game. It is saved before you go out: "
                 + "nothing is lost."),
                ("The dot and the name", "The side with the turn. Yours reads \"Red · "
                 + "Marie · me\": the color, the name you gave yourself in the "
                 + "settings, and \"me\" to say it is yours."),
                ("Turn, and the count", "The number of the round, and your territories "
                 + "over the victory threshold — over the whole board when personal "
                 + "conquests are in play, since there is no threshold then."),
                ("The deck of cards", "Your hand, when the rule is in play. The badge "
                 + "turns red when the trade becomes compulsory."),
                ("The bookmark", "Shelves the present moment in the library."),
                ("The file card", "The file: what each player has shown they know, "
                 + "theme by theme."),
                ("The list", "The game's log, move by move."),
                ("The question mark", "This manual, without leaving the game."),
            ]),
            .h("The board"),
            .puces([
                "A single tap on a territory: it is the only gesture in the game, and "
                + "what it does depends on the current step.",
                "Two fingers to zoom, one finger dragging to pan. The button at the "
                + "bottom right recenters it.",
                "The playable territories are the only ones not in shadow.",
                "A bright hairline marks continental borders; a thin dotted line, the "
                + "sea crossings.",
            ]),
            .h("The strip of sides"),
            .p("Under the map: each player, their territories, their troops, and a flag "
               + "in their color on whoever has the turn. An eliminated player is "
               + "struck through."),
            .p("Below that, a strip names the continents with their bonus. Each keeps "
               + "its own color — the color of its outline on the map, and that is what "
               + "ties the two together. A continent held whole also carries the dot "
               + "and outline of its owner: that is how you see at a glance who is "
               + "close to the bonus."),
            .h("The bottom bar"),
            .termes([
                ("The hint", "What is expected of you. It has the shape of a button but "
                 + "not its clothes: veiled ground, ordinary text. Three tones — the "
                 + "side's color when it is waiting for something, red when something "
                 + "is blocking you, the other side's color when it is not your turn."),
                ("The turn feed", "The three beats — reinforce, attack, move — and how "
                 + "far along you are. When it is the machine's turn, it shows how far "
                 + "along it is in theirs."),
                ("The button", "\"Attack\", \"Move\", \"End turn\". It stays dimmed "
                 + "while an obligation is unmet — reinforcements not laid down, an "
                 + "assault in progress, five cards in hand. \"Move\" asks for "
                 + "confirmation before closing the attack, which does not reopen that "
                 + "turn."),
            ]),
            .h("Following the machine"),
            .p("When it attacks, the game goes through the map before the duel: the two "
               + "places light up, an arrow runs from one to the other, and the bottom "
               + "bar says who is attacking what, with how many questions and on what "
               + "ground. A tap cuts the announcement short — as everywhere else."),
            .h("The duel"),
            .p("The question rises from the bottom without hiding the board: you see "
               + "the troops fall while you answer. The time bar is in color when it is "
               + "your clock, grey when it is the other player's reading time. After "
               + "the answer, the right choice turns green and yours turns red if you "
               + "got it wrong; the verdict always names whoever answered."),
        ])

    // MARK: 9

    private static let cards = Chapitre(
        id: "cartes", titre: "Territory cards",
        resume: "The option that changes the economics of reinforcement.",
        icone: "rectangle.stack.fill", teinte: Palette.or,
        blocs: [
            .p("As in the box: one card per territory, plus two wild cards. Each card "
               + "carries a symbol — infantry, cavalry, artillery."),
            .h("How you earn them"),
            .p("One card at the end of a turn in which you took at least one place. "
               + "Waiting pays nothing: nerve is what draws."),
            .h("The trade"),
            .p("Three matching cards — three identical symbols or three different ones, "
               + "the wild card standing in for any — trade for troops during the "
               + "reinforcement phase. Open your hand from the deck in the top bar, "
               + "pick three cards, trade."),
            .h("The scale climbs with every trade in the game"),
            .code("1st trade      4 troops\n2nd            6\n3rd            8\n"
                  + "4th           10\n5th           12\n6th           15\n"
                  + "then          +5 each time"),
            .p("Two extra troops if one of the three cards carries a territory you "
               + "hold. The climbing scale is what keeps a game from bogging down — and "
               + "holding your cards does not make them gain value, it only lets the "
               + "value climb for your opponent."),
            .note("Five cards in hand: the trade becomes compulsory. You cannot leave "
                  + "the reinforcement phase without having settled three."),
            .h("The loser's cards"),
            .p("Whoever finishes a player off takes their hand. Without that rule the "
               + "loser's cards would leave the game for good and the deck would grow "
               + "poorer with every elimination."),
            .p("Measured: the balance does not move, the game runs two or three "
               + "questions longer, and knowledge weighs slightly more."),
        ])

    // MARK: 10

    private static let file = Chapitre(
        id: "dossier", titre: "The file and the log",
        resume: "What each player has shown they know, and everything that has happened.",
        icone: "person.text.rectangle.fill", teinte: Palette.mauve,
        blocs: [
            .h("The file"),
            .p("It fills itself in, question after question: for each player and each "
               + "theme, correct answers over questions faced. It is what you consult "
               + "before choosing your ground."),
            .p("One convention, and one only: a score belongs to whoever made it, and "
               + "its color says their level — green, they answer it well; red, they "
               + "stumble on it. Everywhere, in the file as in the assault panel."),
            .p("Where to strike is said differently: a scope marks the defender's weak "
               + "spot, and only if there is one — that is, under one correct answer in "
               + "two."),
            .note("In a showdown, a theme your opponent stumbles on only helps you if "
                  + "you stay on your feet there: you answer too."),
            .h("The log"),
            .p("Everything that has happened, newest first: the turns, the "
               + "reinforcements, the duels, the conquests, the card trades, the "
               + "eliminations. Turn headings are in white, the rest in grey."),
            .h("What the machine knows about you"),
            .p("When it attacks, it draws its ground at random, weighted by the "
               + "weaknesses it knows about, without ever locking on: aiming every time "
               + "at your exact weak spot would be the optimal move and the dullest of "
               + "them all."),
        ])

    // MARK: 11

    private static let memory = Chapitre(
        id: "memoire", titre: "Resume, mark, go back",
        resume: "The game in progress, the bookmark, and the library of moments.",
        icone: "books.vertical.fill", teinte: Palette.camp(3),
        blocs: [
            .h("The game saves itself"),
            .p("It survives closing the app: you find it where you left it, with "
               + "nothing to do. The \"Resume game in progress\" button then appears on "
               + "the home screen. A duel left waiting goes back through \"I'm ready\" "
               + "— the clock does not run while you turn your device back on."),
            .p("A game played far away is saved in a drawer of its own: opening a game "
               + "here does not replace it, and it does not replace this one. It is not "
               + "picked back up with this button but from \"Play across devices\", "
               + "since the other player has to come as well."),
            .note("A game played in the same room, or through Game Center, is not kept "
                  + "that way: neither has anything to find its way back with. Handing "
                  + "it back without its link would put both sides on a single device, "
                  + "each of you playing the other."),
            .h("The library"),
            .p("The save above keeps a single state, the last one, and overwrites it at "
               + "every move: that is what resuming needs, and exactly what going back "
               + "must not have. The library keeps one moment per turn and per side, "
               + "unasked — a decisive moment is only recognized afterwards."),
            .p("Each game reads like a shelf: the board, the mode, the date, against "
               + "whom. Its moments show the balance of power they had, in side colors "
               + "— which is what lets you find the moment it all turned without "
               + "opening them one by one."),
            .h("The bookmark"),
            .p("The bookmark in the top bar shelves the present moment by hand. It is "
               + "only an extra: the automatic save already does the work."),
            .h("Going back to a moment"),
            .p("Choosing a moment resumes the game from there — and opens a fresh "
               + "branch: the original game stays whole. Replaying an ending does not "
               + "erase the ending you wanted to keep."),
            .note("A moment saved on a board whose drawing has changed since will no "
                  + "longer read back. The app says so rather than restoring a game "
                  + "that no longer lines up."),
        ])

    // MARK: 12

    private static let network = Chapitre(
        id: "reseau", titre: "Playing across devices",
        resume: "Up to four devices — in the same room, or a continent apart.",
        icone: "person.2.fill", teinte: Palette.camp(0),
        blocs: [
            .p("One device per player, up to four. Tap \"Play across devices\" on the "
               + "home screen, then choose how to link them."),
            .p("Whichever way you choose, whoever opens the game picks the board and the "
               + "rules and sends them along with the game: nobody else has anything to "
               + "set up. They also hand out the seats, in order of arrival. On each "
               + "device, only the player whose turn it is can act — and only the "
               + "defender can answer, wherever they are."),
            .note("No machine in a networked game: an artificial opponent would have to "
                  + "be played by every device at once."),

            .h("In the same room"),
            .p("Nothing to type, no account, no network to configure: the devices find "
               + "each other on their own, and it works on a train."),
            .puces([
                "One player picks the number of players, then \"Open the table\".",
                "The others tap \"Join a table\" and pick its name from the list.",
                "Wi-Fi switched on at both ends, even with no network to join — Wi-Fi is "
                + "what carries the direct link.",
                "The \"local network\" permission, which the system asks for once. "
                + "Refused, the devices never see each other: you can turn it back on in "
                + "Settings ▸ Riskelo.",
            ]),

            .h("Far away, with a code"),
            .p("Each of you at home, on your own network. Still no account to create."),
            .puces([
                "One player taps \"Open a game\". A six-letter code appears — MARENO, "
                + "say.",
                "They tap \"Send the invitation\" and pick WhatsApp, a text message, "
                + "Messages, an email. The other receives a link.",
                "The other taps the link: Riskelo opens on the right game. If nothing "
                + "opens, they type the six letters by hand.",
            ]),
            .p("The code is as easy to read out as it is to paste: it alternates "
               + "consonants and vowels on purpose, so that it survives being repeated "
               + "over the phone. Case and spaces do not matter, and the digit zero "
               + "counts as the letter O."),
            .note("A dropout does not lose the game. A tunnel, a lift, an incoming "
                  + "call: a banner appears, and the game picks itself back up as soon "
                  + "as the link returns. It waits two minutes — keep the screen on."),

            .h("Picking it up another evening"),
            .p("A game played far away does not have to fit into one evening. Stop "
               + "wherever you like: you find it again where you opened it — \"Play "
               + "across devices\", then \"Far away, with a code\". They wait at the "
               + "top of that page: who you are playing, which turn, and how long "
               + "ago."),
            .note("You can have several at once: one with your sister, one with a "
                  + "friend, each at its own pace. Opening a new one does not erase "
                  + "the others, and each keeps its own code. The cross gives up a "
                  + "game you no longer want."),
            .puces([
                "Whoever opened the game comes back first: their device is the one "
                + "holding it, and they are the only one who can reopen the code.",
                "The other taps \"Pick this game back up\" on their side, or types the "
                + "six letters again. The code has not changed.",
                "Once everyone is back, \"Resume the game\" starts again on the turn "
                + "you had reached.",
            ]),
            .note("The code stays good for a week after your last session. You do have "
                  + "to be there at the same time: a question is answered against the "
                  + "clock, so this is not play-by-mail."),

            .h("Through Game Center"),
            .p("Apple's gaming service: your Game Center friends, or a stranger. It "
               + "requires you to be signed in to it, and a game cut short there cannot "
               + "be picked up again, unlike one played with a code. That is why it "
               + "comes last."),

            .h("When it does not work"),
            .termes([
                ("No table in sight", "Check that the other device really did open the "
                 + "table, that Wi-Fi is on at both ends, and that the devices are close "
                 + "by."),
                ("Still nothing happens", "Swap the roles: let whoever was searching "
                 + "open the table. A link can go through in one direction only."),
                ("That code leads nowhere", "A code stays good for a week after your "
                 + "last session, then it is wiped. If you were picking a game back up, "
                 + "it may be that whoever opened it is not back yet: reopening the room "
                 + "is up to them, so tap \"Try again\" once they are there."),
                ("The game has already started", "You cannot slip into a game in "
                 + "progress. But anyone who was in it and got cut off is still "
                 + "expected."),
                ("Nothing answered", "Check your connection. If all is well at your end, "
                 + "it is the game server that is not answering: \"in the same room\" "
                 + "depends on nobody and is always available."),
                ("Linked, but nothing comes", "The link is good: it is the launch that "
                 + "is not arriving. It is up to whoever opened the game to start it."),
                ("Different versions", "One device sent a game the other cannot read. "
                 + "Update both."),
            ]),
        ])

    // MARK: 13

    private static let bank = Chapitre(
        id: "questions", titre: "The questions",
        resume: "The themes that ship with the game, and the three difficulty levels.",
        icone: "text.book.closed.fill", teinte: Palette.orange,
        blocs: [
            .p("\(ManuelEN.questionCount) multiple-choice questions ship with the app. "
               + "They are inside it: no connection is needed to play."),
            .h("The themes in the game"),
            .puces(ManuelEN.baseThemes),
            .p("Packs add more, and are bought separately — see the \"Packs\" page on "
               + "the home screen. Whoever opens a table plays their packs for "
               + "everyone: the others do not have to own them."),
            .h("The three levels"),
            .p("Every question carries a level — easy, medium, hard — and the mix "
               + "chosen at setup decides their proportion. The draw never leaves the "
               + "theme asked for: once it runs dry it starts over rather than "
               + "wandering."),
            .p("A game asks between fifty and a hundred and sixty questions, and a "
               + "single theme can burn through twenty-five of them. Four hundred per "
               + "theme is a bank that lasts months without repeating."),
            .note("Found a typo in a question? Write to \(Manuel.contact) and it will be "
                  + "fixed in the next version."),
        ])

    // MARK: 14

    private static let tips = Chapitre(
        id: "conseils", titre: "Tips",
        resume: "What measurement showed about the good moves and the bad ones.",
        icone: "lightbulb.fill", teinte: Palette.held,
        blocs: [
            .puces([
                "One big stack beats five small ones. Pouring your reinforcements onto "
                + "a single spearhead is better than plugging the whole front.",
                "Do not take a place with your last pair of troops: the strong machine "
                + "forbids itself that move, and that one line is worth twenty points "
                + "of games won.",
                "Press the same place: the defender's clock tightens with every "
                + "question in the turn, and a place already broken into is easier to "
                + "finish than another is to open.",
                "Check the file before choosing the theme. The scope marks the weak "
                + "spot; striking there amounts to rolling one more die.",
                "A whole continent is worth its bonus every turn: it is the only income "
                + "that does not depend on how many territories you hold.",
                "With cards, waiting pays nothing — the card is drawn by taking. And "
                + "the scale climbs for everyone, so holding your hand only enriches "
                + "your opponent.",
                "In a showdown, do not double while you are ahead: chance serves "
                + "whoever is behind.",
            ]),
        ])

    // MARK: 15

    private static let legal = Chapitre(
        id: "mentions", titre: "Privacy and contact",
        resume: "What the app does with your data — which is nothing.",
        icone: "hand.raised.fill", teinte: Palette.dim,
        blocs: [
            .h("No data leaves the device"),
            .puces([
                "No account, no sign-up, no email address asked for.",
                "No analytics, no trackers, no ads.",
                "Your games are saved on the device alone, and go with the app if you "
                + "delete it.",
                "Playing across devices goes through no server: the moves travel "
                + "directly from one device to the other over the local network, and "
                + "nothing is kept.",
                "No internet connection is needed to play.",
            ]),
            .h("The full texts"),
            .liens([
                ("Privacy policy",
                 "What is saved, where, and what never leaves the device.",
                 Manuel.confidentialiteURL),
                ("Terms of use",
                 "License, ownership, warranties, governing law.",
                 Manuel.conditionsURL),
                ("The Riskelo website",
                 Manuel.site,
                 Manuel.siteURL),
            ]),
            .h("Contact"),
            .p("A question, a typo in a question, something broken: write in and you "
               + "will get an answer."),
            .liens([
                ("Write to the author", Manuel.contact, Manuel.contactURL),
            ]),
            .h("Notices"),
            .p("Riskelo is an independent game, inspired by traditional conquest "
               + "games. It is not affiliated with any board game publisher or any of "
               + "their trademarks."),
            .p("Riskelo \(Manuel.version) — © 2026 Robert Oulhen. All rights "
               + "reserved."),
        ])
}
