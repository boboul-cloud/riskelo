//
//  GameScreen.swift
//  Riskelo
//
//  L'écran de jeu : une barre qui dit où l'on en est, le plateau, et une
//  barre qui dit ce qu'on peut faire.
//
//  La règle de composition est celle des jeux de plateau : on ne demande
//  jamais au joueur de deviner de quoi c'est le tour. La phase est écrite en
//  toutes lettres, ce qui reste à faire aussi, et les cases jouables sont les
//  seules qui ne soient pas dans l'ombre.
//

import SwiftUI

struct GameScreen: View {

    let session: GameSession
    var onQuit: () -> Void
    /// Le mode d'emploi se pose par-dessus la partie sans rien interrompre :
    /// on l'ouvre au milieu d'un tour pour vérifier une règle, on le referme,
    /// et le tour attend.
    @State private var manuelOuvert = false

    var body: some View {
        ZStack {
            Palette.sea.ignoresSafeArea()
            VStack(spacing: 0) {
                // L'état de la partie en haut, ce qu'on peut en faire en bas.
                // Les deux se suivaient sous la carte, et le bas de l'écran
                // portait quatre lignes : qui joue, les continents, la
                // consigne et le bouton. On lisait le compte des terres à
                // l'endroit même où l'on cherchait le prochain geste.
                StandingsBar(session: session)
                BoardView(session: session)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .overlay { AnnonceDePhase(session: session) }
                BottomBar(session: session)
            }
            if session.target != nil, case .attack = session.game.phase {
                AssaultPanel(session: session).transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if session.target != nil, case .fortify = session.game.phase {
                FortifyPanel(session: session).transition(.move(edge: .bottom).combined(with: .opacity))
            }
            DuelOverlay(session: session)
            if case let .finished(vainqueur) = session.game.phase {
                VictoryOverlay(session: session, winner: vainqueur, onQuit: onQuit)
            }
        }
        // La barre du haut est posée en marge de sécurité, et non dans la
        // pile : dans la pile, la feuille du duel passait par-dessus elle. Or
        // cette feuille porte le geste « touchez pour continuer » sur toute sa
        // surface — et elle avalait donc le bouton « quitter » pendant tout le
        // tour de la machine. En marge, la barre reste au-dessus de tout et
        // répond toujours.
        .safeAreaInset(edge: .top, spacing: 0) {
            TopBar(session: session, onQuit: onQuit, onManuel: { manuelOuvert = true })
        }
        // Resserré : ce ne sont pas des latences, mais elles s'ajoutaient au
        // retard du double-appui et le jeu paraissait mou. Le panneau d'assaut
        // suit le doigt de près ; seule la feuille du duel, qui vient de plus
        // loin, garde de quoi se voir monter.
        .animation(.snappy(duration: 0.15), value: session.target)
        .animation(.snappy(duration: 0.22), value: session.stage)
        .animation(.spring(response: 0.26, dampingFraction: 0.72), value: session.annonce)
        .sheet(isPresented: Binding(get: { session.journalOpen },
                                    set: { session.journalOpen = $0 })) {
            JournalSheet(session: session)
        }
        .sheet(isPresented: Binding(get: { session.dossierOpen },
                                    set: { session.dossierOpen = $0 })) {
            DossierSheet(session: session)
        }
        .sheet(isPresented: Binding(get: { session.cartesOpen },
                                    set: { session.cartesOpen = $0 })) {
            CartesSheet(session: session)
        }
        .sheet(isPresented: $manuelOuvert) {
            ManuelView(onClose: { manuelOuvert = false })
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Barre du haut

private struct TopBar: View {
    @State private var marque = false
    let session: GameSession
    var onQuit: () -> Void
    var onManuel: () -> Void

    var body: some View {
        let g = session.game
        HStack(spacing: 12) {
            Button(action: onQuit) {
                Image(systemName: "chevron.left").font(.headline)
            }
            .buttonStyle(.plain).foregroundStyle(Palette.dim)

            Circle().fill(Palette.camp(g.currentPlayer.id)).frame(width: 12, height: 12)
            // La phase était écrite ici en toutes lettres. Le fil du bas la
            // montre désormais, et en la situant dans les trois étapes du
            // tour : la dire deux fois à deux endroits n'apprenait rien.
            Text(session.nomAffiche(g.currentPlayer, avecMoi: false))
                .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                // Un nom long ne pousse ni le tour ni les cinq boutons qui
                // suivent : il se resserre, et se rogne s'il le faut.
                .lineLimit(1).minimumScaleFactor(0.75)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("Tour \(g.turn)").font(.caption).foregroundStyle(Palette.dim)
                Text("\(g.territories(of: g.currentPlayer.id).count)/\(g.dominationThreshold)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Palette.ink)
            }
            if g.rules.territoryCards, session.aMoiDeJouer {
                Button { session.cartesOpen = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "rectangle.stack")
                        let n = g.hand(of: g.currentPlayer.id).count
                        if n > 0 {
                            Text("\(n)")
                                .font(.system(size: 9, weight: .bold))
                                .padding(3)
                                .background(g.doitEchanger(g.currentPlayer.id)
                                            ? Palette.lost : Palette.camp(g.currentPlayer.id),
                                            in: Circle())
                                .offset(x: 8, y: -7)
                        }
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(g.doitEchanger(g.currentPlayer.id) ? Palette.lostVif : Palette.dim)
            }
            Button {
                session.marquer()
                marque = true
            } label: {
                Image(systemName: marque ? "bookmark.fill" : "bookmark")
            }
            .buttonStyle(.plain).foregroundStyle(marque ? Palette.held : Palette.dim)
            .task(id: marque) {
                guard marque else { return }
                try? await Task.sleep(for: .seconds(1.6))
                marque = false
            }
            Button { session.dossierOpen = true } label: {
                Image(systemName: "person.text.rectangle")
            }.buttonStyle(.plain).foregroundStyle(Palette.dim)
            Button { session.journalOpen = true } label: {
                Image(systemName: "list.bullet.rectangle")
            }.buttonStyle(.plain).foregroundStyle(Palette.dim)
            // La règle d'un jeu de plateau se consulte pendant la partie, pas
            // avant : c'est au moment où l'on hésite qu'on la cherche.
            Button(action: onManuel) {
                Image(systemName: "questionmark.circle")
            }.buttonStyle(.plain).foregroundStyle(Palette.dim)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Palette.panel)
    }
}

// MARK: - L'annonce d'une étape

/// « Bleu, c'est à vous ! », « À l'attaque ! » — le temps d'un battement, en
/// travers du plateau.
///
/// Elle ne décide de rien et ne se touche pas. Elle sert à ce qu'on sache
/// qu'on vient de changer d'étape sans avoir à lire la barre du haut : un jeu
/// se suit du coin de l'œil.
private struct AnnonceDePhase: View {
    let session: GameSession

    var body: some View {
        if let a = session.annonce {
            VStack(spacing: 4) {
                Text(a.titre)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: Palette.camp(a.camp).opacity(0.9), radius: 12)
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
                if let sous = a.sous {
                    Text(sous.uppercased())
                        .font(.caption.weight(.bold)).kerning(2)
                        .foregroundStyle(Palette.camp(a.camp))
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22).padding(.vertical, 14)
            .background(Palette.sea.opacity(0.72), in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.camp(a.camp).opacity(0.7), lineWidth: 2))
            .allowsHitTesting(false)
            .id(a.id)
            // Elle arrive en grand et se rétracte, elle repart en s'ouvrant :
            // c'est ce qui lui donne du claquant.
            .transition(.asymmetric(
                insertion: .scale(scale: 1.55).combined(with: .opacity),
                removal: .scale(scale: 1.25).combined(with: .opacity)))
        }
    }
}

// MARK: - État des forces

/// Qui tient quoi. Sur un plateau de Risk, cette information se lit d'un coup
/// d'œil aux couleurs ; sur un écran de téléphone, les cases sont trop petites
/// pour qu'on les compte. On l'écrit donc.
private struct StandingsBar: View {
    let session: GameSession

    var body: some View {
        let g = session.game
        VStack(spacing: 7) {
            // Chaque camp nommé, et un drapeau à celui qui a la main. La
            // pastille seule ne suffisait pas : elle disait la couleur, pas
            // qui c'était, et « qui joue » se lisait à une nuance d'opacité.
            //
            // C'était une grille, et elle se repliait en deux lignes dès trois
            // joueurs sur un téléphone : deux lignes prises au plateau, qui
            // est ce qu'on est venu regarder. Elle défile donc, comme la bande
            // des continents juste en dessous.
            //
            // L'objection à la bande qui défile tenait, et elle tient encore :
            // un joueur qu'on ne voit pas n'existe pas. Elle est levée non par
            // la grille mais par le défilement lui-même — celui qui a la main
            // est ramené sous les yeux à chaque changement de tour, et c'est
            // le seul qu'on ait vraiment besoin de voir à cet instant.
            camps(g)

            // Défilement horizontal : « Îles Britanniques » et « Europe
            // centrale » ne tiennent pas côte à côte sur un téléphone, et
            // repliés dans leur pastille ils devenaient illisibles.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(g.map.continentsInOrder) { c in
                        let maitre = tenu(c)
                        HStack(spacing: 3) {
                            Text(c.name).font(.system(size: 10, weight: .medium))
                            Text("+\(c.bonus)").font(.system(size: 10, weight: .bold))
                        }
                        .fixedSize()
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(maitre.map { Palette.camp($0).opacity(0.85) }
                                    ?? Palette.continent(rang: c.tint).opacity(0.16),
                                    in: Capsule())
                        .foregroundStyle(maitre != nil ? Color.white : Palette.continent(rang: c.tint))
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    /// Les camps sur une seule ligne, ramenée sur celui qui joue.
    ///
    /// `ScrollViewReader` plutôt qu'un ordre figé : les camps gardent leur
    /// rang de table — on les cherche toujours à la même place — et c'est la
    /// vue qui se déplace, non eux.
    private func camps(_ g: GameState) -> some View {
        ScrollViewReader { lecteur in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(g.players) { j in camp(j).fixedSize().id(j.id) }
                }
                .padding(.vertical, 1)
                // De quoi respirer aux deux bouts : sans cela, la dernière
                // pastille colle au bord et l'on ne sait plus si la bande est
                // finie ou seulement coupée.
                .padding(.horizontal, 2)
            }
            .onChange(of: g.currentPlayer.id) { _, qui in
                withAnimation(.snappy(duration: 0.35)) {
                    lecteur.scrollTo(qui, anchor: .center)
                }
            }
            .onAppear { lecteur.scrollTo(g.currentPlayer.id, anchor: .center) }
        }
    }

    private func camp(_ j: Player) -> some View {
        let g = session.game
        let aLaMain = j.id == g.currentPlayer.id && !g.isOver
        let terres = g.territories(of: j.id).count
        let hommes = g.territories(of: j.id).reduce(0) { $0 + g.armies($1) }
        return HStack(spacing: 4) {
            Image(systemName: aLaMain ? "flag.fill" : "circle.fill")
                .font(.system(size: aLaMain ? 11 : 8))
                .foregroundStyle(Palette.campVif(j.id))
            Text(session.nomAffiche(j))
                .font(.caption.weight(aLaMain ? .bold : .medium))
                .foregroundStyle(Palette.ink)
                .strikethrough(j.eliminated, color: Palette.dim)
                .fixedSize()
            Image(systemName: "hexagon.fill")
                .font(.system(size: 7)).foregroundStyle(Palette.dim)
            Text("\(terres)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Palette.ink)
            Image(systemName: "person.fill")
                .font(.system(size: 8)).foregroundStyle(Palette.dim)
            Text("\(hommes)")
                .font(.caption.monospacedDigit()).foregroundStyle(Palette.dim)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(aLaMain ? Palette.camp(j.id).opacity(0.22) : Color.white.opacity(0.04),
                    in: Capsule())
        .overlay(Capsule().strokeBorder(aLaMain ? Palette.campVif(j.id).opacity(0.9) : .clear,
                                        lineWidth: 1.3))
        .opacity(j.eliminated ? 0.4 : 1)
        .animation(.snappy(duration: 0.25), value: aLaMain)
    }

    private func tenu(_ c: Continent) -> PlayerID? {
        let g = session.game
        guard let premier = g.owner[c.territories[0]],
              c.territories.allSatisfy({ g.owner[$0] == premier }) else { return nil }
        return premier
    }
}

// MARK: - Barre du bas

private struct BottomBar: View {
    let session: GameSession

    /// Le déplacement ne se dédit pas : une fois l'attaque close, on n'y
    /// revient plus du tour. Le bouton se trouve pourtant sous le pouce, à
    /// l'endroit où l'on appuie sans lire — d'où cette question posée avant.
    @State private var quitterLAttaque = false

    var body: some View {
        let g = session.game
        VStack(spacing: 8) {
            if session.stage == .announcing, let a = session.assault {
                annonce(a)
            } else {
                consigneEnCapsule
            }

            HStack(spacing: 8) {
                if session.aMoiDeJouer {
                    FilDuTour(session: session)
                    Spacer(minLength: 6)
                    switch g.phase {
                    case .reinforcement(let reste):
                        action("À l'attaque", "arrow.right.circle.fill",
                               enabled: reste == 0
                                   && !g.doitEchanger(g.currentPlayer.id)) { session.endPhase() }
                    case .attack:
                        action("Au déplacement", "figure.walk",
                               enabled: session.assault == nil) { quitterLAttaque = true }
                    case .fortify:
                        action("Fin du tour", "checkmark.circle.fill") { session.endTurn() }
                    default:
                        EmptyView()
                    }
                } else if !g.isOver {
                    // Pas de bouton pendant le tour d'en face : le fil prend
                    // toute la place, et montre où la machine en est du sien.
                    FilDuTour(session: session).frame(maxWidth: .infinity)
                }
            }
        }
        // Serré à dix points plutôt que quatorze : chaque point gagné ici est
        // un point de plus pour le mot de l'étape en cours, qui sinon
        // disparaît sur un iPhone au profit des seuls jalons numérotés.
        .padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 12)
        .background(Palette.panel)
        // Une alerte et non une feuille de choix : sur un iPhone, la feuille se
        // rend en bulle accrochée au bouton, et n'y montre que « Oui » — on
        // annulait en touchant à côté, sans que rien ne le dise. Une alerte
        // porte ses deux réponses, sur les trois machines.
        .alert("Avez-vous fini d'attaquer ?", isPresented: $quitterLAttaque) {
            // « Oui » sans le rôle destructeur : ce n'est pas une perte,
            // seulement une porte qui se ferme. Le refus prend le rôle
            // d'annulation, donc la place du geste qui échappe.
            Button("Oui, au déplacement") {
                // La phase a pu tourner pendant que la question était posée.
                if case .attack = session.game.phase { session.endPhase() }
            }
            Button("Non, je continue d'attaquer", role: .cancel) { }
        } message: {
            Text(avertissementDeplacement)
        }
    }

    /// Ce qu'on risque en passant. La seconde phrase n'apparaît que si elle a
    /// lieu d'être : rien de conquis ce tour, donc pas de carte à la fin — et
    /// c'est précisément le regret qu'on veut éviter au joueur pressé.
    private var avertissementDeplacement: String {
        let g = session.game
        let base = "On ne revient pas à l'attaque une fois le déplacement commencé."
        guard g.rules.territoryCards, !g.conqueredThisTurn else { return base }
        return base + " Et sans une seule conquête ce tour, vous ne piochez pas de carte."
    }

    /// La consigne a la forme du bouton — même capsule, même largeur — mais
    /// pas son habit : fond mat, texte éteint, pas de couleur de camp. Elle
    /// gagne ainsi le poids qui lui manquait sans promettre un appui qu'elle
    /// ne tient pas. La nuance compte ici plus qu'ailleurs : cette même place
    /// **est** cliquable pendant l'annonce d'un assaut, et deux voisins qui se
    /// ressemblent, dont l'un seul répond, se paient cher.
    @ViewBuilder private var consigneEnCapsule: some View {
        let texte = consigne
        let (teinte, icone) = tonDeLaConsigne
        if !texte.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: icone)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(teinte)
                Text(texte)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                    // Sans cela, « Cinq cartes en main : il faut en échanger
                    // trois avant de poser » se fait rogner sur un iPhone.
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(teinte.opacity(0.13), in: Capsule())
            .overlay(Capsule().stroke(teinte.opacity(0.8), lineWidth: 1.2))
        }
    }

    /// La couleur et le signe de la consigne.
    ///
    /// Elle était grise sur fond mat — assez sobre pour ne pas passer pour un
    /// bouton, mais au point de ne plus se voir du tout. Elle reprend donc
    /// couleur, sans reprendre l'habit du bouton : celui-ci est plein et son
    /// texte est blanc et gras, celle-là est un voile teinté cerné d'un filet,
    /// et son texte reste de l'encre ordinaire.
    ///
    /// Trois tons, parce que la consigne dit trois choses différentes : ce
    /// qu'on attend de vous, ce qui vous bloque, et que ce n'est pas à vous
    /// de jouer.
    private var tonDeLaConsigne: (Color, String) {
        let g = session.game
        // La teinte vive, et non celle du plateau : ici elle ne remplit rien,
        // elle cerne d'un filet et dessine un signe de la taille d'un mot.
        if !session.aMoiDeJouer && !g.isOver {
            return (Palette.campVif(g.currentPlayer.id), "ellipsis.bubble.fill")
        }
        if g.doitEchanger(g.currentPlayer.id), case .reinforcement = g.phase {
            return (Palette.lostVif, "exclamationmark.triangle.fill")
        }
        return (Palette.campVif(g.currentPlayer.id), "hand.tap.fill")
    }

    /// Ce que la machine s'apprête à faire. Dit ici, sous la carte, et non
    /// par-dessus : les deux places concernées sont souvent celles du haut du
    /// plateau, et un bandeau flottant les aurait justement cachées.
    @ViewBuilder
    private func annonce(_ a: Assault) -> some View {
        let g = session.game
        Button { session.skipAhead() } label: {
            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    Circle().fill(Palette.campVif(a.attacker)).frame(width: 8, height: 8)
                    Text("\(session.player(a.attacker)?.name ?? "?") attaque")
                        .font(.caption).foregroundStyle(Palette.dim)
                }
                Text("\(g.name(a.from)) → \(g.name(a.to))")
                    .font(.headline).foregroundStyle(Palette.ink)
                Label("\(a.volley) question\(a.volley > 1 ? "s" : "") \(a.category.apresDe)",
                      systemImage: a.category.symbol)
                    .font(.caption2)
                    .foregroundStyle(Palette.category(a.category))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .transition(.opacity)
    }

    /// Le bouton ne tient plus toute la largeur — il laisse la place au fil
    /// du tour. Sa **hauteur**, elle, ne bouge pas : quarante-quatre points,
    /// le plancher de ce qui se touche sans rater, et c'est le bouton le plus
    /// tapé de la partie.
    private func action(_ titre: String, _ icone: String, enabled: Bool = true,
                        _ geste: @escaping () -> Void) -> some View {
        Button(action: geste) {
            Label(titre, systemImage: icone)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.camp(session.game.currentPlayer.id))
        .disabled(!enabled)
        // Le bouton se sert le premier et ne se comprime pas : « Passer au
        // déplace… » s'affichait sur un iPhone. C'est au fil de se replier
        // quand la ligne est courte, jamais au bouton de se faire rogner.
        .fixedSize()
        .layoutPriority(1)
    }

    private var consigne: String {
        let g = session.game
        if !session.aMoiDeJouer && !g.isOver {
            return session.enReseau ? "À \(g.currentPlayer.name) de jouer, sur l'autre appareil…"
                                    : "\(g.currentPlayer.name) joue…"
        }
        switch g.phase {
        case .reinforcement(let n):
            if g.doitEchanger(g.currentPlayer.id) {
                return "Cinq cartes en main : il faut en échanger trois avant de poser."
            }
            return n > 0 ? "Touchez vos territoires pour y poser vos \(n) renforts."
                         : "Tous les renforts sont posés."
        case .attack:
            if let base = session.selected {
                return "Depuis \(g.name(base)) — touchez un voisin ennemi à attaquer."
            }
            return "Touchez un de vos territoires d'au moins deux hommes pour partir de là."
        case .occupation:
            return "Choisissez combien d'hommes avancent."
        case .fortify:
            if let base = session.selected {
                return "Depuis \(g.name(base)) — touchez un de vos territoires reliés."
            }
            return "Un seul déplacement, puis le tour passe. Ou terminez directement."
        case .finished:
            return ""
        }
    }
}

// MARK: - Le fil du tour

/// Les trois temps d'un tour, et où l'on en est.
///
/// Un tour se joue en trois étapes — poser ses renforts, attaquer, déplacer —
/// et rien ne le disait. La barre du haut nommait la phase en cours, ce qui
/// répond à « où suis-je » mais jamais à « qu'est-ce qui vient après », qui
/// est la question de celui qui découvre le jeu. Elle ne la nomme plus : la
/// même chose dite à deux endroits n'apprenait rien de plus.
///
/// L'occupation d'une place conquise n'est pas une quatrième étape — c'est un
/// moment de l'attaque, et le jalon y reste.
///
/// Le fil sert aussi quand ce n'est pas votre tour : il n'y a alors pas de
/// bouton, et il montre où la machine en est du sien.
private struct FilDuTour: View {
    let session: GameSession

    private enum Etape: Int, CaseIterable {
        case renforts, attaque, deplacement

        var label: String {
            switch self {
            case .renforts:    "Renforts"
            case .attaque:     "Attaque"
            case .deplacement: "Déplacement"
            }
        }
    }

    private var courante: Etape? {
        switch session.game.phase {
        case .reinforcement:       .renforts
        case .attack, .occupation: .attaque
        case .fortify:             .deplacement
        case .finished:            nil
        }
    }

    var body: some View {
        if let courante {
            // Les trois mots si la ligne les porte, sinon celui de l'étape en
            // cours seul : sur un iPhone, trois libellés plus le bouton ne
            // tiennent pas côte à côte.
            // Trois replis, du plus disert au plus sobre. Le dernier — trois
            // jalons nus — tient sur n'importe quelle largeur : `ViewThatFits`
            // retient sa dernière proposition même si elle déborde, elle doit
            // donc être celle qui ne déborde jamais.
            ViewThatFits(in: .horizontal) {
                fil(courante, mots: .toutes)
                fil(courante, mots: .celleEnCours)
                fil(courante, mots: .aucune)
            }
        }
    }

    private enum Mots { case toutes, celleEnCours, aucune }

    private func fil(_ courante: Etape, mots: Mots) -> some View {
        let camp = Palette.camp(session.game.currentPlayer.id)
        // Le fil n'est fait que de traits de deux points et de cercles de
        // dix-huit : c'est le vif qu'il lui faut. Seul le jalon en cours reste
        // plein de la couleur sombre — il porte un chiffre blanc.
        let vif = Palette.campVif(session.game.currentPlayer.id)
        return HStack(spacing: 5) {
            ForEach(Array(Etape.allCases.enumerated()), id: \.element) { rang, etape in
                if rang > 0 {
                    Capsule()
                        .fill(etape.rawValue <= courante.rawValue
                              ? vif.opacity(0.8) : Palette.dim.opacity(0.3))
                        .frame(width: 9, height: 2)
                }
                jalon(etape, courante: courante, camp: camp, vif: vif,
                      mot: mots == .toutes || (mots == .celleEnCours && etape == courante))
            }
        }
        // Sans cela, le mot se faisait rogner en « … » au lieu de laisser le
        // repli suivant prendre la main.
        .fixedSize()
    }

    private func jalon(_ etape: Etape, courante: Etape, camp: Color, vif: Color,
                       mot: Bool) -> some View {
        let passee = etape.rawValue < courante.rawValue
        let ici = etape == courante
        return HStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(ici ? camp : Color.clear)
                    // L'étape en cours porte un anneau vif par-dessus son
                    // fond sombre : elle s'allume sans que son chiffre blanc
                    // ait à perdre en lisibilité.
                    .overlay(
                        Circle().stroke(ici ? vif
                                             : (passee ? vif.opacity(0.8)
                                                       : Palette.dim.opacity(0.45)),
                                        lineWidth: 1.5)
                    )
                    .frame(width: 18, height: 18)
                if passee {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(vif)
                } else {
                    Text("\(etape.rawValue + 1)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ici ? Palette.ink : Palette.dim)
                }
            }
            if mot {
                Text(etape.label)
                    .font(.caption2.weight(ici ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(ici ? Palette.ink
                                         : Palette.dim.opacity(passee ? 0.85 : 0.6))
            }
        }
    }
}

// MARK: - Déclaration d'assaut

private struct AssaultPanel: View {
    let session: GameSession

    var body: some View {
        let g = session.game
        if let base = session.selected, let cible = session.target,
           let defenseur = g.owner[cible] {
            let attaquant = g.owner[base] ?? g.currentPlayer.id
            VStack(spacing: 0) {
                Spacer()
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(g.name(base)) → \(g.name(cible))")
                                .font(.headline).foregroundStyle(Palette.ink)
                            Text("\(g.armies(base)) hommes contre \(g.armies(cible))")
                                .font(.caption).foregroundStyle(Palette.dim)
                        }
                        Spacer()
                        Button { session.cancelDraft() } label: {
                            Image(systemName: "xmark.circle.fill").font(.title3)
                        }.buttonStyle(.plain).foregroundStyle(Palette.dim)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text(g.rules.mode == .classique
                             ? "Vous posez la question — choisissez le terrain"
                             : "Vous choisissez le terrain — mais vous y répondez aussi")
                            .font(.caption.weight(.medium)).foregroundStyle(Palette.dim)
                        Text(g.rules.mode == .classique
                             ? "Le score est le sien : vert, il y répond bien ; rouge, il y "
                               + "trébuche. La lunette marque son point faible."
                             : "Le score est le sien : vert, il y répond bien ; rouge, il y "
                               + "trébuche. Attention — un thème où il trébuche ne vous sert "
                               + "que si vous, vous tenez debout.")
                            .font(.system(size: 10)).foregroundStyle(Palette.dim.opacity(0.8))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7),
                                                 count: 3), spacing: 7) {
                            ForEach(Category.allCases) { c in
                                categorie(c, contre: defenseur)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Combien de questions — vos dés")
                            .font(.caption.weight(.medium)).foregroundStyle(Palette.dim)
                        Picker("", selection: Binding(get: { session.draftQuestions },
                                                      set: { session.draftQuestions = $0 })) {
                            ForEach(1...max(1, g.maxQuestions(from: base)), id: \.self) { n in
                                Text(n == 1 ? "Une question" : "Deux questions").tag(n)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text(legendeDesDes(g))
                            .font(.caption2).foregroundStyle(Palette.dim)
                    }

                    Button { withAnimation { session.declare() } } label: {
                        Label("Lancer l'assaut", systemImage: "flame.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.lost)
                }
                .padding(18)
                .background(Palette.panel, in: RoundedRectangle(cornerRadius: 20))
                // Le panneau prend la couleur de celui qui attaque, en liseré
                // seulement : le fond reste mat, sinon les six camemberts
                // posés dessus deviendraient illisibles. Assez pour rappeler,
                // à deux sur le même écran, qui tient le doigt sur le bouton.
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Palette.campVif(attaquant).opacity(0.7), lineWidth: 3))
                .padding(10)
                .frame(maxWidth: 560)
            }
        }
    }

    /// Chaque camembert porte ce que l'adversaire y a montré : c'est toute
    /// l'adresse de l'attaquant dans cette variante.
    ///
    /// La couleur dit le niveau **de celui à qui appartient le score**, ici
    /// comme dans son dossier : vert, il y répond bien ; rouge, il y trébuche.
    /// Elle disait auparavant l'intérêt de l'attaquant — donc vert sur « 2/2 »
    /// parce qu'il fallait éviter ce terrain — et le même chiffre paraissait
    /// vert d'un côté, rouge de l'autre. On croyait l'application confuse sur
    /// ce qui est juste et ce qui ne l'est pas.
    ///
    /// Où frapper se dit autrement : la lunette marque le point faible.
    /// Ce que coûte la salve annoncée. Quatre cas : une ou deux questions, en
    /// classique ou en face à face — où le défenseur peut encore doubler.
    private func legendeDesDes(_ g: GameState) -> String {
        let une = session.draftQuestions == 1
        if g.rules.mode == .classique {
            return une
                ? "Un duel : au plus un homme perdu de chaque côté."
                : "Deux duels de suite. Le sablier se resserre au second — mais deux bonnes "
                    + "réponses vous coûtent deux hommes."
        }
        return une
            ? "Un duel, la même question pour vous deux. S'il double la mise, il vaudra "
                + "deux hommes."
            : "Deux duels de suite, la même question à chaque fois pour vous deux. Le sablier "
                + "se resserre au second, et il peut doubler la mise sur chacun."
    }

    private func categorie(_ c: Category, contre defenseur: PlayerID) -> some View {
        let score = session.game.record(of: defenseur, in: c)
        let choisie = session.draftCategory == c
        let pointFaible = session.game.weakness(of: defenseur) == c
        return Button { session.chooseCategory(c) } label: {
            VStack(spacing: 3) {
                Image(systemName: c.symbol).font(.system(size: 15))
                Text(c.label).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 3) {
                    if pointFaible {
                        Image(systemName: "scope").font(.system(size: 9))
                            .foregroundStyle(Palette.lostVif)
                    }
                    Text(score.asked == 0 ? "—" : "\(score.correct)/\(score.asked)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(score.asked == 0 ? Palette.dim
                                         : (score.rate < 0.5 ? Palette.lostVif : Palette.held))
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 9)
            .background(choisie ? Palette.category(c).opacity(0.32) : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(choisie ? Palette.category(c) : .clear, lineWidth: 1.5))
            .foregroundStyle(choisie ? Palette.category(c) : Palette.ink.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Déplacement

private struct FortifyPanel: View {
    let session: GameSession
    @State private var count = 1

    var body: some View {
        let g = session.game
        if let base = session.selected, let cible = session.target {
            let maximum = max(1, g.armies(base) - 1)
            VStack {
                Spacer()
                VStack(spacing: 14) {
                    Text("\(g.name(base)) → \(g.name(cible))")
                        .font(.headline).foregroundStyle(Palette.ink)
                    Stepper(value: $count, in: 1...maximum) {
                        Text("\(count) homme\(count > 1 ? "s" : "") sur \(maximum)")
                            .font(.subheadline.monospacedDigit()).foregroundStyle(Palette.ink)
                    }
                    HStack(spacing: 10) {
                        Button("Annuler") { session.cancelDraft() }
                            .buttonStyle(.bordered)
                        Button { session.fortify(count) } label: {
                            Text("Déplacer et finir le tour").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.camp(g.currentPlayer.id))
                    }
                }
                .padding(18)
                .background(Palette.panel, in: RoundedRectangle(cornerRadius: 20))
                .padding(10)
                .frame(maxWidth: 460)
            }
            .onAppear { count = 1 }
        }
    }
}

// MARK: - Victoire

private struct VictoryOverlay: View {
    let session: GameSession
    let winner: PlayerID
    var onQuit: () -> Void

    var body: some View {
        ZStack {
            Palette.sea.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 54)).foregroundStyle(Palette.camp(winner))
                Text("\(session.player(winner)?.name ?? "?") l'emporte")
                    .font(.title2.weight(.bold)).foregroundStyle(Palette.ink)
                Text("\(session.game.territories(of: winner).count) territoires sur \(session.game.map.order.count), en \(session.game.turn) tours.")
                    .font(.subheadline).foregroundStyle(Palette.dim)
                Button(action: onQuit) {
                    Text("Nouvelle partie").font(.headline)
                        .frame(maxWidth: 260).padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent).tint(Palette.camp(winner))
            }
        }
    }
}

// MARK: - Journal et dossier

private struct JournalSheet: View {
    let session: GameSession
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(session.game.journal.reversed()) { e in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(e.player.map { Palette.camp($0) } ?? Palette.dim)
                            .frame(width: 7, height: 7).padding(.top, 6)
                        Text(e.text).font(.footnote)
                            .foregroundStyle(e.kind == .tour ? Palette.ink : Palette.dim)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
        .background(Palette.sea)
        .preferredColorScheme(.dark)
    }
}

/// La main de cartes, et l'échange.
///
/// Trois cartes assorties — trois symboles identiques ou trois différents, le
/// joker remplaçant n'importe lequel — valent des hommes. Le barème monte à
/// chaque échange de la partie : garder ses cartes ne les fait pas prendre de
/// la valeur, cela laisse seulement la valeur monter pour l'adversaire.
private struct CartesSheet: View {
    let session: GameSession

    var body: some View {
        let g = session.game
        let main = g.hand(of: g.currentPlayer.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vos cartes").font(.headline).foregroundStyle(Palette.ink)
                    Text(main.isEmpty
                         ? "Une carte se gagne en prenant au moins une place dans le tour."
                         : "Trois symboles identiques, ou trois différents. "
                           + "Le prochain échange vaut \(g.prochainEchange) hommes.")
                        .font(.caption).foregroundStyle(Palette.dim)
                    if g.doitEchanger(g.currentPlayer.id) {
                        Text("Cinq cartes en main : l'échange est obligatoire.")
                            .font(.caption.weight(.semibold)).foregroundStyle(Palette.lostVif)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                    ForEach(main) { carte in carteVue(carte) }
                }

                Button { session.echanger(); session.cartesOpen = false } label: {
                    Label("Échanger contre \(g.prochainEchange) hommes", systemImage: "arrow.2.squarepath")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent).tint(Palette.held)
                .disabled(!session.combinaisonPrete)
            }
            .padding(18)
        }
        .background(Palette.sea)
        .preferredColorScheme(.dark)
    }

    private func carteVue(_ carte: Card) -> some View {
        let retenue = session.cartesChoisies.contains(carte.id)
        let nom = carte.territory.map { session.game.name($0) } ?? "Joker"
        return Button { session.basculerCarte(carte.id) } label: {
            VStack(spacing: 6) {
                Image(systemName: carte.estJoker ? "star.fill" : carte.symbol.icone)
                    .font(.system(size: 20))
                Text(nom).font(.caption2).lineLimit(2)
                    .multilineTextAlignment(.center).minimumScaleFactor(0.7)
                Text(carte.estJoker ? "tous symboles" : carte.symbol.label)
                    .font(.system(size: 9)).foregroundStyle(Palette.dim)
            }
            .frame(maxWidth: .infinity).frame(height: 92)
            .background(retenue ? Palette.held.opacity(0.25) : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(retenue ? Palette.held : .clear, lineWidth: 2))
            .foregroundStyle(Palette.ink)
        }
        .buttonStyle(.plain)
    }
}

/// Ce que chacun a montré savoir. Le tableau se remplit tout seul, question
/// après question — et c'est lui qu'on consulte avant de choisir son terrain.
private struct DossierSheet: View {
    let session: GameSession
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Ce que chacun a montré savoir")
                    .font(.headline).foregroundStyle(Palette.ink)
                ForEach(session.game.players) { j in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Circle().fill(Palette.camp(j.id)).frame(width: 9, height: 9)
                            Text(session.nomAffiche(j)).font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            if j.eliminated {
                                Text("éliminé").font(.caption).foregroundStyle(Palette.dim)
                            }
                        }
                        ForEach(Category.allCases) { c in
                            let s = session.game.record(of: j.id, in: c)
                            HStack {
                                Label(c.label, systemImage: c.symbol)
                                    .font(.caption).foregroundStyle(Palette.dim)
                                Spacer()
                                Text(s.asked == 0 ? "—" : "\(s.correct)/\(s.asked)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(s.asked == 0 ? Palette.dim
                                                     : (s.rate < 0.5 ? Palette.lostVif : Palette.held))
                            }
                        }
                    }
                    .padding(12)
                    .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(18)
        }
        .background(Palette.sea)
        .preferredColorScheme(.dark)
    }
}
