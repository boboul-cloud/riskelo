//
//  AccueilView.swift
//  Riskelo
//
//  La porte d'entrée.
//
//  L'application s'ouvrait sur ses réglages : une page de curseurs et
//  d'interrupteurs avant d'avoir vu la moindre case. C'est demander de
//  choisir un plateau, un dosage de questions et la culture de la machine à
//  quelqu'un qui ne sait pas encore ce qu'est une question dans ce jeu.
//  L'accueil renverse l'ordre — une partie prête, et les réglages pour qui
//  les veut.
//

import SwiftUI

// MARK: - La partie qu'on lance sans rien régler

/// Ce sont exactement les valeurs par lesquelles l'écran des réglages
/// s'ouvre : « Partie rapide » ne propose pas une autre partie, il saute
/// l'écran. Les deux les prennent ici, donc ils ne peuvent pas diverger.
enum PartieRapide {
    static let plateau: Boards = .anneau
    static let camps = 2
    static let humains = 1
    static let niveau = 0.65
    static let manoeuvre: Bot.Style = .moyenne
    /// Zéro retire la règle ; sinon, une bonne réponse sur tant vaut un homme.
    static let erudition = 5
    static let dosage: Rules.Dosage = .melees
    static let cartes = false
    static let guerreTotale = false
    static let mode: Rules.Mode = .classique

    /// Les règles, assemblées à partir de ce que l'écran des réglages propose.
    /// Appelée sans rien, elle rend la partie par défaut.
    static func regles(erudition: Int = PartieRapide.erudition,
                       dosage: Rules.Dosage = PartieRapide.dosage,
                       cartes: Bool = PartieRapide.cartes,
                       mode: Rules.Mode = PartieRapide.mode,
                       guerreTotale: Bool = PartieRapide.guerreTotale) -> Rules {
        var r = Rules()
        r.answersPerBonusMan = erudition == 0 ? nil : erudition
        r.difficultyWeights = dosage.poids
        r.territoryCards = cartes
        r.mode = mode
        if guerreTotale { r.dominationOverride = 0 }
        return r
    }

    static func joueurs(nombre: Int = PartieRapide.camps,
                        humains: Int = PartieRapide.humains,
                        niveau: Double = PartieRapide.niveau,
                        manoeuvre: Bot.Style = PartieRapide.manoeuvre) -> [Player] {
        (0..<nombre).map { i in
            Player(id: i, name: Boards.nomDeCamp(i),
                   kind: i < humains ? .humain : .machine(niveau: niveau, style: manoeuvre))
        }
    }

    /// Le mot qui dit ce que vaut la machine. Le même barème sert à l'accueil,
    /// qui annonce la partie rapide, et aux réglages, qui la font varier.
    static func niveauDit(_ n: Double) -> String {
        switch n {
        case ..<0.45: "Distraite"
        case ..<0.60: "Honnête"
        case ..<0.75: "Cultivée"
        default:      "Redoutable"
        }
    }

    /// Ce qu'on obtient en appuyant, dit en une phrase. Écrite à partir des
    /// valeurs ci-dessus : elle ne peut donc pas promettre autre chose que ce
    /// qui se lance.
    static var enUnePhrase: String {
        // « sur L'Anneau » au milieu d'une phrase sonne comme un titre : le
        // nom du plateau y perd sa majuscule, mais pas son article.
        let ou = plateau.label.prefix(1).lowercased() + plateau.label.dropFirst()
        return "\(camps) camps sur \(ou), contre une machine "
            + niveauDit(niveau).lowercased() + "."
    }
}

// MARK: - L'icône, en mouvement

/// Une moitié d'hexagone, coupée par l'axe qui joint les deux pointes. C'est
/// la seule coupe qui laisse les deux camps identiques — celle de l'icône.
struct DemiHexagone: Shape {
    let gauche: Bool

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: gauche ? r.minX : r.maxX, y: r.minY + r.height * 0.25))
        p.addLine(to: CGPoint(x: gauche ? r.minX : r.maxX, y: r.minY + r.height * 0.75))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// L'icône de l'application, redessinée en vues plutôt qu'en image : c'est ce
/// qui permet de l'ouvrir en deux. Une image aurait fallu être découpée en
/// deux fichiers, et les deux morceaux auraient cessé de suivre la palette.
struct LogoRiskelo: View {
    /// De 0 — les deux camps au large — à 1, joints.
    var jonction: Double = 1
    var cote: CGFloat = 132

    /// Un hexagone pointe en haut est plus haut que large, dans ce rapport.
    private var largeur: CGFloat { cote * 0.866 }

    /// Le « ? » ne vient qu'une fois la case refermée : c'est lui qui tranche
    /// entre les deux camps, il n'aurait rien à trancher avant.
    private var apparition: Double { max(0, min(1, (jonction - 0.62) / 0.38)) }

    var body: some View {
        let ecart = (1 - jonction) * cote * 0.8
        ZStack {
            DemiHexagone(gauche: true).fill(Palette.camp(0))
                .frame(width: largeur, height: cote)
                .offset(x: -ecart)
            DemiHexagone(gauche: false).fill(Palette.camp(1))
                .frame(width: largeur, height: cote)
                .offset(x: ecart)
            // Le liseré : ce qui fait de l'hexagone une pièce de jeu et non
            // une tache. Il ne se referme qu'avec elle.
            Hexagon()
                .strokeBorder(Palette.ink.opacity(0.34), lineWidth: max(1.5, cote * 0.014))
                .frame(width: largeur, height: cote)
                .opacity(apparition)
            Text("?")
                .font(.system(size: cote * 0.46, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .opacity(apparition)
                .scaleEffect(0.75 + 0.25 * apparition)
        }
        .frame(width: largeur, height: cote)
        .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
        .accessibilityHidden(true)
    }
}

// MARK: - L'accueil

struct AccueilView: View {

    /// La partie par défaut, sans passer par les réglages.
    var onPartieRapide: () -> Void
    var onReglages: () -> Void
    /// Proposé seulement s'il y a une partie en attente : un bouton qui ne
    /// mène nulle part vaut mieux absent.
    var onResume: (() -> Void)?
    var onManuel: () -> Void
    /// Proposé seulement s'il y a quelque chose sur les rayons.
    var onArchives: (() -> Void)?
    /// L'ouverture ne se joue qu'une fois par lancement. La revoir à chaque
    /// retour de partie serait un péage.
    var anime = false

    @Environment(\.accessibilityReduceMotion) private var mouvementReduit
    @State private var jonction: Double = 0
    @State private var texte: Double = 0

    /// Tant que l'ouverture n'a pas lieu, tout est déjà en place : c'est ce
    /// qui évite l'image où l'écran apparaît vide avant de se remplir.
    private var ouvre: Bool { anime && !mouvementReduit }

    var body: some View {
        ZStack {
            Palette.sea.ignoresSafeArea()
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 24)
                        LogoRiskelo(jonction: ouvre ? jonction : 1)
                        titre
                            .padding(.top, 22)
                            .opacity(ouvre ? texte : 1)
                        Spacer(minLength: 32)
                        boutons
                            .opacity(ouvre ? texte : 1)
                        Spacer(minLength: 24)
                        // Les textes légaux se veulent là où l'on se demande à
                        // quoi l'on s'engage : avant de commencer, donc ici.
                        piedDeMentions
                            .opacity(ouvre ? texte : 1)
                            .padding(.bottom, 26)
                    }
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
            }
        }
        .onAppear {
            guard ouvre else { return }
            // Les deux camps se rejoignent, puis le reste de l'écran vient.
            // Le ressort dépasse un peu et revient : les deux moitiés se
            // referment comme une pièce qu'on repose, non comme une porte
            // qu'on tire.
            // Un demi-temps d'attente, et non un dixième : sur un Mac, la
            // vue paraît bien avant que sa fenêtre ne soit à l'écran, et
            // l'ouverture se jouait dans le vide — on ouvrait l'application
            // sur une icône déjà refermée.
            withAnimation(.spring(response: 0.72, dampingFraction: 0.68).delay(0.45)) {
                jonction = 1
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.9)) { texte = 1 }
        }
        // Le son part au même instant que le mouvement, et se tait avec lui :
        // ses deux voix se rejoignent sur l'accord qui tombe quand les deux
        // moitiés se touchent. Posé en `task` et non en `onAppear` pour que
        // quitter l'accueil pendant l'attente l'annule.
        .task {
            guard anime else { return }
            try? await Task.sleep(for: .seconds(ouvre ? 0.45 : 0.15))
            Sons.shared.jouer(.ouverture)
        }
        .preferredColorScheme(.dark)
    }

    private var titre: some View {
        VStack(spacing: 7) {
            Text("Riskelo")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
            Text("Le dé est remplacé par une question.")
                .font(.subheadline).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder private var boutons: some View {
        VStack(spacing: 12) {
            if let onResume {
                Button(action: onResume) {
                    Label("Reprendre la partie en cours", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent).tint(Palette.held)
            }

            VStack(spacing: 6) {
                Button(action: onPartieRapide) {
                    Label("Partie rapide", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent).tint(Palette.camp(0))
                // Dire ce qu'on lance avant de le lancer : sans cette ligne,
                // « rapide » ne veut rien dire de précis.
                Text(PartieRapide.enUnePhrase)
                    .font(.caption).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
            }

            Button(action: onReglages) {
                Label("Réglages de la partie", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
            }
            .buttonStyle(.bordered).tint(Palette.dim)

            // Deux portes de service, en retrait : elles ne servent pas à
            // jouer, mais les enterrer sous « Réglages » aurait été mentir sur
            // ce qu'on y trouve.
            HStack(spacing: 10) {
                petitBouton("Mode d'emploi", "book", onManuel)
                if let onArchives {
                    separateur
                    petitBouton("Parties enregistrées", "books.vertical", onArchives)
                }
            }
            .padding(.top, 4)
        }
    }

    private func petitBouton(_ titre: String, _ icone: String,
                             _ geste: @escaping () -> Void) -> some View {
        Button(action: geste) {
            Label(titre, systemImage: icone)
                .font(.caption.weight(.medium))
                .foregroundStyle(Palette.dim)
        }
        .buttonStyle(.plain)
    }

    /// Confidentialité, conditions, site : les trois adresses publiques. Elles
    /// sortent de l'application — le système ouvre le navigateur — et sont
    /// donc en gris, comme tout ce qui n'est pas un coup à jouer.
    private var piedDeMentions: some View {
        HStack(spacing: 9) {
            lien("Confidentialité", Manuel.confidentialiteURL)
            separateur
            lien("Conditions", Manuel.conditionsURL)
            separateur
            lien("Site", Manuel.siteURL)
        }
        .font(.caption)
        .frame(maxWidth: .infinity)
    }

    private var separateur: some View {
        Text("·").font(.caption).foregroundStyle(Palette.dim.opacity(0.45))
    }

    /// `SwiftUI.Link` en toutes lettres : dans ce module, `Link` tout court
    /// désigne le fil entre deux appareils, et c'est lui qui gagne.
    @ViewBuilder private func lien(_ titre: String, _ adresse: String) -> some View {
        if let url = URL(string: adresse) {
            SwiftUI.Link(titre, destination: url)
                .foregroundStyle(Palette.dim)
        }
    }
}

#Preview("Accueil") {
    AccueilView(onPartieRapide: {}, onReglages: {}, onResume: {},
                onManuel: {}, onArchives: {}, anime: true)
}
