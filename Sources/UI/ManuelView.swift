//
//  ManuelView.swift
//  Riskelo
//
//  Le mode d'emploi, dans l'application.
//
//  Un jeu de plateau se joue avec sa règle sur la table, et celle-ci ne tient
//  pas sur un écran d'accueil. Elle est donc rangée ici, en quatorze
//  chapitres, et elle s'ouvre aussi bien avant la partie que pendant : le
//  point d'interrogation de la barre du haut la pose par-dessus le plateau
//  sans rien interrompre — le tour attend, la partie est intacte.
//
//  Deux niveaux, comme la bibliothèque : un sommaire qui se lit d'un coup
//  d'œil, puis un chapitre à la fois. Tout à plat aurait fait deux mille mots
//  d'un seul tenant, c'est-à-dire un texte que personne n'ouvre deux fois.
//
//  Le texte est écrit ici et nulle part ailleurs : les chiffres qu'il cite —
//  quinze secondes, le barème des cartes, le seuil de victoire — sont ceux de
//  `Rules`, et un réglage qui bouge là-bas se corrige ici.
//

import SwiftUI

// MARK: - L'écran

struct ManuelView: View {

    /// Posé par-dessus une partie, le mode d'emploi se ferme ; ouvert depuis
    /// l'accueil, il se ferme aussi. C'est le même geste.
    var onClose: () -> Void

    @State private var chapitre: Chapitre?

    var body: some View {
        contenu
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .top, spacing: 0) { entete }
            .background(Palette.sea)
            .preferredColorScheme(.dark)
    }

    @ViewBuilder private var contenu: some View {
        if let chapitre {
            page(chapitre)
        } else {
            sommaire
        }
    }

    // MARK: En-tête

    private var entete: some View {
        HStack {
            Button {
                if chapitre != nil { withAnimation { chapitre = nil } } else { onClose() }
            } label: {
                Label(chapitre == nil ? "Fermer" : "Sommaire", systemImage: "chevron.left")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.plain).foregroundStyle(Palette.dim)
            Spacer(minLength: 12)
        }
        // Le titre par-dessus plutôt qu'entre deux ressorts : il reste centré
        // quelle que soit la longueur du bouton de gauche.
        .overlay {
            Text(chapitre?.titre ?? "Mode d'emploi")
                .font(.headline).foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 90)
        }
        .frame(maxWidth: 620)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Palette.panel)
    }

    // MARK: Le sommaire

    private var sommaire: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Riskelo")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text("Un jeu de conquête où le lancer de dés est remplacé par une "
                         + "question de culture générale. Tout ce que fait l'application "
                         + "est écrit ici.")
                        .font(.footnote).foregroundStyle(Palette.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 6)

                ForEach(Manuel.chapitres) { c in
                    Button { withAnimation { chapitre = c } } label: { ligne(c) }
                        .buttonStyle(.plain)
                }

                Text("Riskelo \(Manuel.version) — \(Manuel.site)")
                    .font(.caption2).foregroundStyle(Palette.dim.opacity(0.7))
                    .padding(.top, 10)
            }
            .padding(18)
        }
    }

    private func ligne(_ c: Chapitre) -> some View {
        HStack(spacing: 13) {
            Image(systemName: c.icone)
                .font(.system(size: 16))
                .frame(width: 30, height: 30)
                .background(c.teinte.opacity(0.22), in: RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(c.teinte)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.titre).font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(c.resume).font(.caption).foregroundStyle(Palette.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold)).foregroundStyle(Palette.dim.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Un chapitre

    private func page(_ c: Chapitre) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: c.icone).font(.system(size: 15))
                        .foregroundStyle(c.teinte)
                    Text(c.resume).font(.caption).foregroundStyle(Palette.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 2)

                ForEach(Array(c.blocs.enumerated()), id: \.offset) { _, bloc in
                    BlocView(bloc: bloc, teinte: c.teinte)
                }

                if let suivant = Manuel.apres(c) {
                    Button { withAnimation { chapitre = suivant } } label: {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Chapitre suivant").font(.caption2)
                                    .foregroundStyle(Palette.dim)
                                Text(suivant.titre).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Palette.ink)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.dim)
                        }
                        .padding(13)
                        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .padding(18)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Les briques d'un chapitre

/// Un chapitre est une suite de blocs, et chaque bloc a une forme et une
/// seule. Écrire le manuel revient donc à écrire des données, jamais des vues,
/// et une correction de texte ne touche pas à la mise en page.
enum Bloc {
    /// Un paragraphe.
    case p(String)
    /// Un intertitre.
    case h(String)
    /// Une liste à puces.
    case puces([String])
    /// Un terme et ce qu'il fait — la forme des réglages.
    case termes([(String, String)])
    /// Un tableau à colonnes égales, en-tête compris.
    case tableau([String], [[String]])
    /// Un bloc à chasse fixe : un barème, une échelle.
    case code(String)
    /// Ce qu'il ne faut pas manquer.
    case note(String)
    /// Des liens qui sortent de l'application : un titre, ce qu'on y trouve,
    /// et l'adresse. Le seul endroit du manuel qui mène dehors.
    case liens([(String, String, String)])
}

private struct BlocView: View {
    let bloc: Bloc
    let teinte: Color

    var body: some View {
        switch bloc {
        case let .p(texte):
            Text(texte)
                .font(.subheadline).foregroundStyle(Palette.ink.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

        case let .h(texte):
            Text(texte.uppercased())
                .font(.caption.weight(.semibold)).kerning(0.6)
                .foregroundStyle(teinte)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

        case let .puces(items):
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(teinte.opacity(0.8))
                            .frame(width: 5, height: 5).padding(.top, 7)
                        Text(item).font(.subheadline)
                            .foregroundStyle(Palette.ink.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case let .termes(items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.0).font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Text(item.1).font(.caption).foregroundStyle(Palette.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(13)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))

        case let .tableau(entetes, lignes):
            VStack(spacing: 0) {
                rangee(entetes, entete: true)
                ForEach(Array(lignes.enumerated()), id: \.offset) { i, ligne in
                    Divider().overlay(Palette.dim.opacity(0.25))
                    rangee(ligne, entete: false, pair: i.isMultiple(of: 2))
                }
            }
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Palette.dim.opacity(0.18), lineWidth: 1))

        case let .code(texte):
            Text(texte)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Palette.ink.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))

        case let .liens(items):
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    if i > 0 { Divider().overlay(Palette.dim.opacity(0.25)) }
                    // Une adresse mal formée ne donne pas une ligne morte :
                    // elle ne donne pas de ligne du tout.
                    // `SwiftUI.Link` en toutes lettres : dans ce module,
                    // `Link` tout court désigne le fil entre deux appareils.
                    if let url = URL(string: item.2) {
                        SwiftUI.Link(destination: url) {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.0).font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Palette.ink)
                                    Text(item.1).font(.caption).foregroundStyle(Palette.dim)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: item.2.hasPrefix("mailto:")
                                      ? "envelope" : "arrow.up.right.square")
                                    .font(.footnote).foregroundStyle(teinte)
                            }
                            .padding(.horizontal, 13).padding(.vertical, 12)
                            // Toute la ligne répond, pas seulement le texte.
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))

        case let .note(texte):
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "lightbulb.fill").font(.caption)
                    .foregroundStyle(teinte).padding(.top, 2)
                Text(texte).font(.footnote)
                    .foregroundStyle(Palette.ink.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(teinte.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(teinte.opacity(0.4), lineWidth: 1))
        }
    }

    private func rangee(_ cellules: [String], entete: Bool, pair: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(Array(cellules.enumerated()), id: \.offset) { i, c in
                Text(c)
                    .font(entete ? .caption.weight(.semibold) : .caption)
                    .foregroundStyle(entete ? teinte
                                     : (i == 0 ? Palette.ink : Palette.ink.opacity(0.85)))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .background(entete ? Color.white.opacity(0.05)
                    : (pair ? Color.clear : Color.white.opacity(0.02)))
    }
}

// MARK: - Le texte

struct Chapitre: Identifiable, Equatable {
    let id: String
    let titre: String
    let resume: String
    let icone: String
    let teinte: Color
    let blocs: [Bloc]

    static func == (a: Chapitre, b: Chapitre) -> Bool { a.id == b.id }
}

enum Manuel {

    static let version = "version 1.0"
    static let site = "boboul-cloud.github.io/riskelo"
    static let contact = "bob.oulhen@gmail.com"

    /// Les quatre adresses de l'application, écrites ici et nulle part
    /// ailleurs : l'écran d'accueil y puise les siennes. Un site qui
    /// déménage se corrige donc en un seul endroit.
    static let siteURL = "https://boboul-cloud.github.io/riskelo/"
    static let confidentialiteURL = "https://boboul-cloud.github.io/riskelo/confidentialite.html"
    static let conditionsURL = "https://boboul-cloud.github.io/riskelo/conditions.html"
    static let contactURL = "mailto:bob.oulhen@gmail.com"

    static func apres(_ c: Chapitre) -> Chapitre? {
        guard let i = chapitres.firstIndex(of: c), i + 1 < chapitres.count else { return nil }
        return chapitres[i + 1]
    }

    static let chapitres: [Chapitre] = [
        premierePartie, duel, faceAFace, tour, victoire, miseEnPlace, ecran,
        cartes, dossier, memoire, reseau, banque, conseils, mentions,
    ]

    // MARK: 1

    private static let premierePartie = Chapitre(
        id: "debut", titre: "En deux minutes",
        resume: "Ce qu'il faut savoir pour jouer le premier tour.",
        icone: "bolt.fill", teinte: Palette.camp(0),
        blocs: [
            .p("Riskelo est un jeu de conquête : des territoires, des hommes, "
               + "et un adversaire à déloger. Il n'y a pas de dés. Quand vous "
               + "attaquez, une question de culture générale décide de l'issue."),
            .h("Le premier tour"),
            .puces([
                "Touchez « Commencer » : deux joueurs, le plateau de l'Anneau, une "
                + "machine de culture moyenne. Les réglages viennent après.",
                "Vos territoires portent votre couleur et le nombre d'hommes qui les "
                + "tiennent. Ceux qui ne sont pas jouables restent dans l'ombre.",
                "Renforts : touchez vos territoires pour y poser les hommes annoncés "
                + "par la consigne, un par appui.",
                "Attaque : touchez un de vos territoires d'au moins deux hommes, puis "
                + "un voisin ennemi. Un panneau s'ouvre — choisissez le thème de la "
                + "question et le nombre de questions, puis « Lancer l'assaut ».",
                "Déplacement : un seul, vers un territoire à vous relié au départ. "
                + "Puis « Fin du tour ».",
            ]),
            .note("La barre du bas dit toujours ce qu'on attend de vous, et le fil des "
                  + "trois étapes dit où vous en êtes du tour. En cas de doute, c'est là "
                  + "qu'il faut regarder."),
            .h("Ce que décide la question"),
            .p("C'est le défenseur qui répond, dans le temps du sablier. S'il répond "
               + "juste, c'est vous qui perdez un homme ; s'il se trompe ou laisse "
               + "passer le temps, c'est lui. Une question vaut exactement une paire de "
               + "dés au Risk : elle coûte un homme à l'un des deux camps."),
            .p("Le second mode, « face à face », fait répondre les deux joueurs à la "
               + "même question — c'est le chapitre qui lui est consacré."),
        ])

    // MARK: 2

    private static let duel = Chapitre(
        id: "duel", titre: "Le duel",
        resume: "La question tient lieu de dé — qui la pose, qui y répond, en combien de temps.",
        icone: "questionmark.circle.fill", teinte: Palette.category(.geographie),
        blocs: [
            .p("L'attaquant choisit deux choses : le thème de la question, et le "
               + "nombre de questions — une ou deux. Ce sont ses dés. Le défenseur, "
               + "lui, répond."),
            .tableau(["Ce que fait le défenseur", "L'équivalent au dé", "Qui perd un homme"],
                     [["Bonne réponse", "Dé supérieur", "L'attaquant"],
                      ["Mauvaise réponse", "Dé inférieur", "Le défenseur"],
                      ["Temps écoulé", "Le dé le plus bas", "Le défenseur"]]),
            .h("Une ou deux questions"),
            .p("Deux questions, c'est deux chances de prendre la place — et deux "
               + "pertes possibles de votre côté. Le pari est celui du Risk. Vous ne "
               + "pouvez lancer que le nombre de questions que votre pile peut payer : "
               + "un territoire de deux hommes n'en pose qu'une."),
            .h("Le thème ne déborde jamais"),
            .p("Le thème demandé est tenu : la banque ne sort jamais de la catégorie "
               + "choisie. Épuisée, elle recommence plutôt que de glisser vers un autre "
               + "sujet. C'est ce qui rend le choix du terrain fiable — et c'est là "
               + "qu'est votre adresse."),
            .h("Le sablier, et l'usure du siège"),
            .p("Quinze secondes à la première question. Un joueur qui sait ne perdrait "
               + "jamais sa place : ce qui remplace la statistique du dé, c'est le "
               + "temps qui se resserre. Chaque question subie par un même territoire, "
               + "dans le même tour, raccourcit le sablier."),
            .code("1re question   15,0 s\n2e             11,7 s\n3e              9,1 s\n"
                  + "4e              7,1 s\n5e et suivantes 6,0 s"),
            .p("Le sablier se remet à zéro entre deux tours. Presser une place finit "
               + "donc par payer — mais c'est le souffle du défenseur qui cède, pas le "
               + "sort."),
            .h("Prendre la place"),
            .p("Quand la dernière garnison tombe, vous choisissez combien d'hommes "
               + "avancent : au moins autant que de questions posées, et jamais votre "
               + "dernier homme — un territoire garde toujours un homme."),
            .note("La machine répond toujours quelque chose : le temps écoulé est le "
                  + "fait d'un humain, et de lui seul."),
        ])

    // MARK: 3

    private static let faceAFace = Chapitre(
        id: "face", titre: "Face à face",
        resume: "Le second mode : les deux joueurs répondent à la même question.",
        icone: "person.2.fill", teinte: Palette.camp(1),
        blocs: [
            .p("En classique, une seule main lance les dés : le défenseur répond, et "
               + "la culture de l'attaquant ne lui sert à rien quand il attaque. Elle "
               + "est une armure, jamais une arme. En face à face, les deux reçoivent "
               + "la même question."),
            .tableau(["Ce qui arrive", "Ce qu'il advient"],
                     [["Un seul des deux sait", "Il emporte l'échange"],
                      ["Les deux savent", "Le sablier tranche ; l'égalité stricte au défenseur"],
                      ["Aucun des deux ne sait", "La place tient — l'égalité du Risk"]]),
            .p("Le départage au sablier n'est pas un ornement : sans lui, plus personne "
               + "ne prendrait jamais une place et la partie se figerait. Il tranche "
               + "environ quatre échanges sur dix."),
            .note("La vitesse ne départage jamais deux réponses inégales : un ignorant "
                  + "rapide ne bat pas un savant lent. Elle ne décide que ce que le Risk "
                  + "décidait par le chiffre du dé."),
            .h("La feuille du verdict"),
            .p("Les deux réponses s'affichent côte à côte, chacune avec son temps, et "
               + "une couronne sur celle qui l'emporte. C'est nécessaire : sans elle, "
               + "on répond juste, on perd une place, et l'on croit à une erreur du jeu."),
            .h("La relance — doubler l'enjeu"),
            .p("Avant de répondre, le défenseur peut doubler : l'échange vaudra deux "
               + "hommes au lieu d'un, dans le sens où il tombera. Le bouton n'apparaît "
               + "que pour lui, et seulement avant sa réponse."),
            .p("Doubler n'est pas un coup de force, c'est un coup de hasard : quand les "
               + "deux savent, l'échange se joue au sablier, donc à pile ou face — pour "
               + "deux hommes. Le hasard sert celui qui est derrière et coûte à celui "
               + "qui mène."),
            .note("Une mise de deux ne rapporte jamais plus que ce que la pile d'en face "
                  + "peut payer : on ne prend pas à l'assaillant sa dernière garnison. "
                  + "Doubler contre une pile de deux hommes ne rapporte donc qu'un homme."),
            .h("Sur un appareil partagé"),
            .p("Chacun répond à son tour, l'appareil se passe entre les deux, et l'écran "
               + "attend un « je suis prêt » avant de lancer le sablier — personne ne "
               + "voit la question avant son tour."),
        ])

    // MARK: 4

    private static let tour = Chapitre(
        id: "tour", titre: "Le tour",
        resume: "Renforts, attaques, un déplacement — puis le tour passe.",
        icone: "arrow.triangle.2.circlepath", teinte: Palette.camp(2),
        blocs: [
            .h("1 — Les renforts"),
            .p("Un homme par tranche de trois territoires tenus, avec un plancher de "
               + "trois hommes, plus le bonus de chaque continent que vous tenez "
               + "entièrement. Touchez vos territoires pour les poser, un par appui. "
               + "Tant qu'il en reste, le tour ne passe pas."),
            .h("2 — Les attaques"),
            .p("Autant d'assauts que vous voulez, tant qu'il vous reste des piles d'au "
               + "moins deux hommes. Touchez le territoire de départ, puis un voisin "
               + "ennemi : le panneau d'assaut s'ouvre. Il montre le rapport de forces, "
               + "les six thèmes avec ce que le défenseur y a montré savoir, et le "
               + "choix d'une ou deux questions."),
            .p("Une place prise se garnit aussitôt : vous choisissez combien d'hommes "
               + "avancent, au moins autant que de questions posées."),
            .h("3 — Le déplacement"),
            .p("Un seul, à la fin du tour : d'un de vos territoires vers un autre "
               + "territoire à vous, relié au premier par une chaîne ininterrompue de "
               + "territoires amis. Vous pouvez aussi terminer sans rien déplacer."),
            .note("Un territoire ne reste jamais vide : un homme y demeure toujours, "
                  + "au départ comme à l'arrivée."),
            .h("Ce que le tour rapporte en passant"),
            .puces([
                "Le renfort d'érudition : un homme de plus toutes les N bonnes réponses "
                + "dans un même thème, si la règle est en jeu.",
                "Une carte de territoire, si la règle est en jeu et que vous avez pris "
                + "au moins une place dans le tour.",
            ]),
        ])

    // MARK: 5

    private static let victoire = Chapitre(
        id: "victoire", titre: "Gagner la partie",
        resume: "Le seuil de domination, la guerre totale, l'élimination.",
        icone: "flag.checkered", teinte: Palette.held,
        blocs: [
            .p("La victoire ne demande pas de tout prendre : il faut tenir sa part de "
               + "départ, plus sept territoires. C'est un écart, et non une part fixe "
               + "du monde — un joueur sur quatre part de 25 % et non de 50 %."),
            .tableau(["Plateau", "À 2", "À 3", "À 4"],
                     [["L'Anneau — 28 territoires", "21", "17", "14"],
                      ["Europe — 38 territoires", "26", "20", "17"],
                      ["Monde — 42 territoires", "28", "21", "18"]]),
            .p("La barre du haut porte ce compte en permanence : vos territoires sur le "
               + "seuil à franchir."),
            .h("La guerre totale"),
            .p("L'option retire le seuil : il faut tous les territoires, sans exception. "
               + "Comptez environ deux fois plus de questions — 112 au lieu de 71 à deux "
               + "joueurs. C'est une partie de soirée entière, et c'est le but."),
            .h("L'élimination"),
            .p("Un joueur qui perd son dernier territoire est éliminé ; son nom reste "
               + "barré dans la barre des camps. Si les cartes de territoire sont en "
               + "jeu, celui qui l'achève prend sa main."),
            .h("Ouvrir se paie"),
            .p("À deux joueurs, celui qui commence part avec deux hommes de moins : "
               + "sans cela, il gagnerait six parties sur dix. Au-delà de deux joueurs "
               + "l'avantage se dilue de lui-même — qui frappe le premier s'expose à "
               + "deux voisins au lieu d'un."),
        ])

    // MARK: 6

    private static let miseEnPlace = Chapitre(
        id: "reglages", titre: "La mise en place",
        resume: "Tous les réglages de l'écran d'accueil, un par un.",
        icone: "slider.horizontal.3", teinte: Palette.category(.sciences),
        blocs: [
            .h("Mode de jeu"),
            .termes([
                ("Classique", "L'attaquant choisit le thème, le défenseur seul répond."),
                ("Face à face", "Les deux répondent à la même question ; le défenseur "
                 + "peut doubler l'enjeu."),
            ]),
            .h("Plateau"),
            .termes([
                ("L'Anneau", "Un monde inventé, cinq terres en cercle. 28 territoires. "
                 + "Le plus court."),
                ("Europe", "De l'Atlantique à la mer Noire. 38 territoires, six régions."),
                ("Monde", "Les six continents, 42 territoires — comme la boîte."),
            ]),
            .h("Joueurs, et humains sur cet appareil"),
            .p("De deux à quatre joueurs. Le second réglage dit combien sont assis "
               + "devant cet écran : le reste est tenu par la machine. À plusieurs "
               + "humains sur un même appareil, il se passe avant chaque question, et "
               + "l'écran attend un « je suis prêt »."),
            .h("Stratégie de la machine"),
            .termes([
                ("Facile", "Elle avance au hasard et sème des garnisons d'un homme."),
                ("Moyenne", "Elle tient ce qu'elle prend et cherche vos points faibles."),
                ("Forte", "Elle concentre ses renforts sur une seule pointe, vise le "
                 + "continent le plus proche d'être complet, achève une place déjà "
                 + "pressée dont le sablier s'est raccourci, et n'attaque plus quand sa "
                 + "pile descend à deux hommes."),
            ]),
            .h("Culture de la machine"),
            .p("Ce n'est pas une difficulté abstraite : c'est sa part de bonnes réponses "
               + "sur une question moyenne, de 35 à 90 %. On sait donc exactement ce "
               + "qu'on affronte. Distraite, honnête, cultivée, redoutable — cinq points "
               + "d'écart suffisent à faire pencher deux parties sur trois."),
            .p("Sa culture et sa manœuvre sont deux réglages distincts : on peut être "
               + "savant et jouer mal."),
            .h("Questions"),
            .termes([
                ("Faciles", "De quoi jouer avec des enfants."),
                ("Mêlées", "Les trois niveaux, comme dans une boîte de jeu."),
                ("Corsées", "Pour ceux qui trouvent le reste trop facile."),
            ]),
            .h("Renfort d'érudition"),
            .p("Un homme de plus toutes les N bonnes réponses dans un même thème. Le "
               + "curseur va de 0 à 10 ; à zéro, la règle est retirée. Cinq est le "
               + "réglage d'origine ; trois fait peser la culture davantage."),
            .p("En classique, seul le défenseur répond : ce renfort revient donc à qui "
               + "tient sa place en sachant. En face à face, il revient à qui sait, "
               + "qu'il attaque ou qu'il défende."),
            .h("Règles du jeu"),
            .termes([
                ("Cartes de territoire", "Une carte par tour où l'on prend une place ; "
                 + "trois assorties valent des hommes, et le barème monte."),
                ("Guerre totale", "Il faut tous les territoires, sans exception. "
                 + "Environ deux fois plus de questions."),
            ]),
            .h("Les trois boutons du bas"),
            .termes([
                ("Reprendre la partie en cours", "N'apparaît que s'il y en a une. Elle "
                 + "est retrouvée exactement où vous l'avez laissée."),
                ("Parties enregistrées", "La bibliothèque des instants — voir le chapitre "
                 + "« Reprendre, marquer, revenir »."),
                ("Jouer à plusieurs appareils", "Un appareil par joueur, jusqu'à quatre, "
                 + "dans la même pièce."),
            ]),
        ])

    // MARK: 7

    private static let ecran = Chapitre(
        id: "ecran", titre: "L'écran de jeu",
        resume: "Ce que porte chaque barre, et ce qui répond au doigt.",
        icone: "rectangle.3.group.fill", teinte: Palette.category(.arts),
        blocs: [
            .h("La barre du haut"),
            .termes([
                ("Le chevron", "Quitte la partie. Elle est enregistrée avant de sortir : "
                 + "rien ne se perd."),
                ("La pastille et le nom", "Le camp qui a la main. En réseau, le vôtre "
                 + "porte « (vous) »."),
                ("Tour, et le compte", "Le numéro du tour de table, et vos territoires "
                 + "sur le seuil de victoire."),
                ("Le paquet de cartes", "Votre main, quand la règle est en jeu. La "
                 + "pastille passe au rouge quand l'échange devient obligatoire."),
                ("Le signet", "Marque l'instant présent dans la bibliothèque."),
                ("La fiche", "Le dossier : ce que chacun a montré savoir, thème par thème."),
                ("La liste", "Le journal de la partie, coup par coup."),
                ("Le point d'interrogation", "Ce mode d'emploi, sans quitter la partie."),
            ]),
            .h("Le plateau"),
            .puces([
                "Un appui simple sur un territoire : c'est le seul geste du jeu, et ce "
                + "qu'il fait dépend de l'étape en cours.",
                "Deux doigts pour agrandir, un doigt qui glisse pour déplacer la carte. "
                + "Le bouton en bas à droite la recentre.",
                "Les territoires jouables sont les seuls qui ne soient pas dans l'ombre.",
                "Un liseré vif marque les frontières de continent ; un trait fin, les "
                + "liaisons maritimes.",
            ]),
            .h("La barre des camps"),
            .p("Sous la carte : chaque joueur, ses territoires, ses hommes, et un "
               + "drapeau à sa couleur sur celui qui a la main. Un joueur éliminé est "
               + "barré."),
            .p("En dessous, une bande nomme les continents avec leur bonus. Celui qui "
               + "est tenu entièrement prend la couleur de son maître : c'est ainsi "
               + "qu'on voit d'un coup d'œil qui touche au bonus."),
            .h("La barre du bas"),
            .termes([
                ("La consigne", "Ce qu'on attend de vous. Elle a la forme d'un bouton "
                 + "mais pas son habit : fond voilé, texte ordinaire. Trois tons — la "
                 + "couleur du camp quand elle attend quelque chose, le rouge quand "
                 + "quelque chose vous bloque, la couleur d'en face quand ce n'est pas "
                 + "à vous de jouer."),
                ("Le fil du tour", "Les trois temps — renforts, attaque, déplacement — "
                 + "et où l'on en est. Quand c'est à la machine de jouer, il montre où "
                 + "elle en est du sien."),
                ("Le bouton", "« À l'attaque », « Au déplacement », « Fin du tour ». Il "
                 + "reste éteint tant qu'une obligation n'est pas levée — des renforts "
                 + "non posés, un assaut en cours, cinq cartes en main."),
            ]),
            .h("Suivre la machine"),
            .p("Quand elle attaque, la partie passe par la carte avant le duel : les "
               + "deux places s'allument, une flèche part de l'une vers l'autre, et la "
               + "barre du bas dit qui attaque quoi, avec combien de questions et sur "
               + "quel terrain. Une touche écourte l'annonce — comme partout ailleurs."),
            .h("Le duel"),
            .p("La question monte du bas sans cacher le plateau : on voit les hommes "
               + "tomber pendant qu'on répond. La barre de temps est en couleur quand "
               + "c'est votre sablier, grise quand c'est le temps de lecture de l'autre. "
               + "Après la réponse, la bonne proposition passe au vert et la vôtre au "
               + "rouge si vous vous êtes trompé ; le verdict nomme toujours celui qui a "
               + "répondu."),
        ])

    // MARK: 8

    private static let cartes = Chapitre(
        id: "cartes", titre: "Les cartes de territoire",
        resume: "L'option qui change l'économie des renforts.",
        icone: "rectangle.stack.fill", teinte: Palette.category(.histoire),
        blocs: [
            .p("Comme dans la boîte : une carte par territoire, plus deux jokers. Chaque "
               + "carte porte un symbole — infanterie, cavalerie, artillerie."),
            .h("Comment on en gagne"),
            .p("Une carte à la fin d'un tour où vous avez pris au moins une place. "
               + "L'attente ne rapporte rien : c'est l'audace qui tire."),
            .h("L'échange"),
            .p("Trois cartes assorties — trois symboles identiques ou trois différents, "
               + "le joker remplaçant n'importe lequel — s'échangent contre des hommes, "
               + "pendant la phase de renforts. Ouvrez votre main par le paquet de la "
               + "barre du haut, choisissez trois cartes, échangez."),
            .h("Le barème monte à chaque échange de la partie"),
            .code("1er échange    4 hommes\n2e             6\n3e             8\n"
                  + "4e            10\n5e            12\n6e            15\n"
                  + "puis          +5 à chaque fois"),
            .p("Deux hommes de plus si l'une des trois cartes porte un territoire que "
               + "vous tenez. C'est le barème qui empêche une partie de s'enliser — et "
               + "garder ses cartes ne les fait pas prendre de la valeur, cela laisse "
               + "seulement la valeur monter pour l'adversaire."),
            .note("Cinq cartes en main : l'échange devient obligatoire. Vous ne pouvez "
                  + "pas quitter la phase de renforts sans en avoir soldé trois."),
            .h("Les cartes du vaincu"),
            .p("Celui qui achève un joueur prend sa main. Sans cette règle, les cartes "
               + "du vaincu sortiraient du jeu pour de bon et le paquet s'appauvrirait à "
               + "chaque élimination."),
            .p("Mesuré : l'équilibre ne bouge pas, la partie s'allonge de deux ou trois "
               + "questions, et la culture pèse un peu plus."),
        ])

    // MARK: 9

    private static let dossier = Chapitre(
        id: "dossier", titre: "Le dossier et le journal",
        resume: "Ce que chacun a montré savoir, et tout ce qui s'est passé.",
        icone: "person.text.rectangle.fill", teinte: Palette.category(.spectacle),
        blocs: [
            .h("Le dossier"),
            .p("Il se remplit tout seul, question après question : pour chaque joueur et "
               + "chaque thème, les bonnes réponses sur les questions subies. C'est lui "
               + "qu'on consulte avant de choisir son terrain."),
            .p("Une convention, une seule : un score appartient à celui qui l'a fait, et "
               + "sa couleur dit son niveau à lui — vert, il y répond bien ; rouge, il y "
               + "trébuche. Partout, dans le dossier comme dans le panneau d'assaut."),
            .p("Où frapper se dit autrement : une lunette marque le point faible du "
               + "défenseur, et seulement s'il en est un — c'est-à-dire moins d'une bonne "
               + "réponse sur deux."),
            .note("En face à face, un thème où l'adversaire trébuche ne vous sert que si "
                  + "vous, vous y tenez debout : vous répondez aussi."),
            .h("Le journal"),
            .p("Tout ce qui s'est passé, du plus récent au plus ancien : les tours, les "
               + "renforts, les duels, les conquêtes, les échanges de cartes, les "
               + "éliminations. Les têtes de tour sont en clair, le reste en gris."),
            .h("Ce que la machine sait de vous"),
            .p("Quand elle attaque, elle tire son terrain au sort pondéré par vos "
               + "faiblesses connues, sans jamais s'y verrouiller : viser à chaque fois "
               + "votre point faible exact serait le coup optimal et le plus ennuyeux de "
               + "tous."),
        ])

    // MARK: 10

    private static let memoire = Chapitre(
        id: "memoire", titre: "Reprendre, marquer, revenir",
        resume: "La partie en cours, le signet, et la bibliothèque des instants.",
        icone: "books.vertical.fill", teinte: Palette.camp(3),
        blocs: [
            .h("La partie se garde toute seule"),
            .p("Elle survit à la fermeture de l'application : on la retrouve où on l'a "
               + "laissée, sans rien avoir à faire. Le bouton « Reprendre la partie en "
               + "cours » apparaît alors sur l'écran d'accueil. Un duel en attente "
               + "repasse par « je suis prêt » — le sablier ne court pas pendant que "
               + "vous rallumez l'appareil."),
            .h("La bibliothèque"),
            .p("La sauvegarde ci-dessus ne garde qu'un état, le dernier, et l'écrase à "
               + "chaque coup : c'est ce qu'il faut pour reprendre, et exactement ce "
               + "qu'il ne faut pas pour revenir. La bibliothèque, elle, garde un instant "
               + "par tour et par camp, sans qu'on le demande — un moment décisif ne se "
               + "reconnaît qu'après coup."),
            .p("Chaque partie s'y lit comme un rayon : le plateau, le mode, la date, "
               + "contre qui. Ses instants montrent le rapport de forces qu'ils avaient, "
               + "en couleurs de camp — c'est ce qui permet de retrouver le moment où "
               + "tout a basculé sans les ouvrir un à un."),
            .h("Le signet"),
            .p("Le marque-page de la barre du haut range l'instant présent à la main. "
               + "Il n'est qu'un supplément : l'enregistrement automatique fait déjà le "
               + "travail."),
            .h("Revenir à un instant"),
            .p("Choisir un instant reprend la partie à partir de là — et ouvre une "
               + "branche neuve : la partie d'origine reste entière. Rejouer une fin "
               + "n'efface pas la fin que vous vouliez garder."),
            .note("Un instant enregistré sur un plateau qui a changé de dessin depuis ne "
                  + "se relit plus. L'application le dit plutôt que de restaurer une "
                  + "partie de travers."),
        ])

    // MARK: 11

    private static let reseau = Chapitre(
        id: "reseau", titre: "Jouer à plusieurs appareils",
        resume: "Jusqu'à quatre appareils, sans compte ni configuration.",
        icone: "iphone.gen3.radiowaves.left.and.right", teinte: Palette.camp(0),
        blocs: [
            .p("Un appareil par joueur, jusqu'à quatre. Rien à saisir, aucun compte, "
               + "aucun réseau à configurer : les appareils se trouvent par Bluetooth ou "
               + "par Wi-Fi direct, et cela fonctionne dans un train."),
            .h("Ouvrir et rejoindre"),
            .puces([
                "Un joueur touche « Jouer à plusieurs appareils », choisit le nombre de "
                + "joueurs, puis « Ouvrir la table ».",
                "Les autres touchent « Rejoindre une table » et choisissent son nom dans "
                + "la liste.",
                "Celui qui ouvre choisit le plateau et les règles, et les envoie avec la "
                + "partie : les autres n'ont rien à régler. C'est lui aussi qui donne "
                + "son rang à chacun, dans l'ordre d'arrivée.",
                "Quand tout le monde est là, il lance la partie.",
            ]),
            .p("Sur chaque appareil, seul le joueur dont c'est le tour peut agir — et "
               + "seul le défenseur peut répondre, où qu'il soit."),
            .note("Pas de machine dans une partie en réseau : un adversaire artificiel "
                  + "devrait être joué par tous les appareils à la fois."),
            .h("Ce qu'il faut, et rien de plus"),
            .puces([
                "Les appareils dans la même pièce.",
                "Le Wi-Fi allumé des deux côtés, même sans réseau auquel se connecter — "
                + "c'est lui qui porte la liaison directe.",
                "L'autorisation « réseau local », que le système demande une fois. "
                + "Refusée, les appareils ne se voient jamais : elle se rétablit dans "
                + "Réglages ▸ Riskelo.",
                "La même version de Riskelo des deux côtés.",
            ]),
            .h("Quand cela ne marche pas"),
            .termes([
                ("Aucune table en vue", "Vérifiez que l'autre appareil a bien ouvert la "
                 + "table, que le Wi-Fi est allumé des deux côtés, et que les appareils "
                 + "sont proches."),
                ("La liaison n'a pas pu s'établir", "L'invitation a expiré au bout de "
                 + "vingt secondes. Recommencez — et si une autorisation réseau est "
                 + "demandée, acceptez-la tout de suite."),
                ("Relié, mais rien ne vient", "La liaison est bonne : c'est le lancement "
                 + "qui n'arrive pas. C'est à celui qui a ouvert la table de lancer la "
                 + "partie."),
                ("Versions différentes", "Un appareil a envoyé une partie que l'autre ne "
                 + "sait pas lire. Mettez les deux à jour."),
                ("Rien ne se passe malgré tout", "Inversez les rôles : que celui qui "
                 + "cherchait ouvre la table. Une liaison peut ne passer que dans un sens."),
            ]),
        ])

    // MARK: 12

    private static let banque = Chapitre(
        id: "questions", titre: "Les questions",
        resume: "Six thèmes, mille deux cents questions, trois niveaux.",
        icone: "text.book.closed.fill", teinte: Palette.category(.sports),
        blocs: [
            .p("Mille deux cents questions à choix multiple, deux cents par thème, "
               + "toutes en français. Elles sont dans l'application : aucune connexion "
               + "n'est nécessaire pour jouer."),
            .tableau(["Thème", "Ce qu'on y trouve"],
                     [["Géographie", "Pays, capitales, fleuves, reliefs, mers"],
                      ["Histoire", "Dates, règnes, batailles, civilisations"],
                      ["Sciences & Nature", "Corps, animaux, physique, chimie, ciel"],
                      ["Arts & Lettres", "Livres, peinture, architecture, langue"],
                      ["Sports & Loisirs", "Disciplines, records, règles, jeux"],
                      ["Écrans & Musique", "Cinéma, séries, chanson, télévision"]]),
            .h("Les trois niveaux"),
            .p("Chaque question porte un niveau — facile, moyen, difficile — et le "
               + "dosage choisi à la mise en place décide de leur proportion. Le tirage "
               + "ne sort jamais du thème demandé : épuisé, il recommence plutôt que de "
               + "déborder."),
            .p("Une partie pose de cinquante à cent soixante questions, et un seul thème "
               + "peut en brûler vingt-cinq. Deux cents par thème, c'est la banque qui "
               + "tient des mois sans se répéter."),
            .note("Une coquille dans une question ? Écrivez-la à \(contact) : elle sera "
                  + "corrigée dans la version suivante."),
        ])

    // MARK: 13

    private static let conseils = Chapitre(
        id: "conseils", titre: "Conseils",
        resume: "Ce que la mesure a montré des bons et des mauvais coups.",
        icone: "lightbulb.fill", teinte: Palette.held,
        blocs: [
            .puces([
                "Une grosse pile bat cinq petites. Verser ses renforts sur une seule "
                + "pointe vaut mieux que colmater tout le front.",
                "Ne prenez pas une place avec votre dernière paire d'hommes : la machine "
                + "forte s'interdit ce coup-là, et cette seule ligne vaut vingt points "
                + "de parties gagnées.",
                "Pressez la même place : le sablier du défenseur se resserre à chaque "
                + "question du tour, et une place déjà entamée s'achève mieux qu'une "
                + "autre ne s'ouvre.",
                "Consultez le dossier avant de choisir le thème. La lunette marque le "
                + "point faible ; frapper là revient à lancer un dé de plus.",
                "Un continent entier vaut son bonus à chaque tour : c'est le seul revenu "
                + "qui ne dépend pas du nombre de territoires.",
                "Avec les cartes, l'attente ne rapporte rien — la carte se tire en "
                + "prenant. Et le barème monte pour tout le monde, donc garder sa main "
                + "n'enrichit que l'adversaire.",
                "En face à face, ne doublez pas quand vous menez : le hasard sert celui "
                + "qui est derrière.",
            ]),
        ])

    // MARK: 14

    private static let mentions = Chapitre(
        id: "mentions", titre: "Confidentialité et contact",
        resume: "Ce que l'application fait de vos données — c'est-à-dire rien.",
        icone: "hand.raised.fill", teinte: Palette.dim,
        blocs: [
            .h("Aucune donnée ne quitte l'appareil"),
            .puces([
                "Pas de compte, pas d'inscription, pas de courriel demandé.",
                "Aucune mesure d'audience, aucun traceur, aucune publicité.",
                "Vos parties sont enregistrées sur l'appareil seul, et disparaissent avec "
                + "l'application si vous la supprimez.",
                "Le jeu à plusieurs appareils ne passe par aucun serveur : les coups "
                + "voyagent directement d'un appareil à l'autre, par Bluetooth ou Wi-Fi "
                + "direct, et rien n'en est conservé.",
                "Aucune connexion à Internet n'est nécessaire pour jouer.",
            ]),
            .h("Les textes complets"),
            .liens([
                ("Politique de confidentialité",
                 "Ce qui est enregistré, où, et ce qui ne quitte jamais l'appareil.",
                 confidentialiteURL),
                ("Conditions d'utilisation",
                 "Licence, propriété, garanties, droit applicable.",
                 conditionsURL),
                ("Le site de Riskelo",
                 site,
                 siteURL),
            ]),
            .h("Contact"),
            .p("Une question, une coquille dans une question, une panne : écrivez, "
               + "on vous répondra."),
            .liens([
                ("Écrire à l'auteur", contact, contactURL),
            ]),
            .h("Mentions"),
            .p("Riskelo est un jeu indépendant, inspiré des jeux de conquête "
               + "traditionnels. Il n'est affilié à aucun éditeur de jeu de société ni "
               + "à aucune de leurs marques."),
            .p("Riskelo \(Manuel.version) — © 2026 Robert Oulhen. Tous droits réservés."),
        ])
}

#Preview("Mode d'emploi") {
    ManuelView(onClose: {})
}
