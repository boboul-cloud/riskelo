//
//  BoardView.swift
//  Riskelo
//
//  Le plateau.
//
//  Rien n'y est écrit en points : les centres viennent du moteur en unités
//  relatives, et tout se multiplie par le côté disponible. Le même plateau
//  tient donc sur un iPhone en portrait et sur un écran de Mac, sans une
//  ligne de conditionnel.
//

import SwiftUI

struct BoardView: View {

    let session: GameSession
    /// Où commence le panneau qui couvre le bas de l'écran, mesuré par
    /// l'écran de jeu. Absent — rien ne couvre, ou la mesure n'est pas encore
    /// venue — on s'en tient à l'estimation de la session.
    var hautCouvert: CGFloat?

    /// Le plateau se déplace et se rapproche. C'est ce qui permet d'en avoir
    /// de plus grands que l'écran : une carte du monde ne tient pas sur un
    /// téléphone à une taille où les noms se lisent, mais elle tient très bien
    /// si on peut la promener sous le doigt.
    @State private var zoom: CGFloat = 1
    @State private var ajuste = false
    @State private var decalage: CGSize = .zero
    @GestureState private var pince: CGFloat = 1
    @GestureState private var glisse: CGSize = .zero
    /// De combien le plateau a été remonté pour laisser la place au panneau.
    /// Il redescend d'autant quand le panneau s'en va : sans cela la carte
    /// restait perchée en haut, une bande vide sous elle, jusqu'au recadrage
    /// suivant — et d'autant plus haut que le panneau était grand.
    @State private var remonteAppliquee: CGFloat = 0

    private var echelle: CGFloat { min(4, max(0.9, zoom * pince)) }
    private var deplace: Bool { echelle != 1 || decalage != .zero }

    var body: some View {
        GeometryReader { geo in
            let layout = session.game.board.layout
            let side = min(geo.size.width, geo.size.height / layout.aspect)
            let radius = layout.cellRadius * side
            let couvert = partCouverte(geo.frame(in: .named(Espace.ecran)))
            let repere = Repere(couvert: couvert, stage: session.stage, cible: session.target)
            ZStack {
                ForEach(session.game.map.order, id: \.self) { id in
                    tile(id, side: side, radius: radius,
                         center: layout.centers[id] ?? Point(x: 0, y: 0))
                }
                traversees(side: side, radius: radius)
                fleche(side: side, radius: radius)
            }
            .frame(width: side, height: side * layout.aspect)
            .scaleEffect(echelle)
            .offset(x: decalage.width + glisse.width, y: decalage.height + glisse.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            // Le déplacement et le rapprochement cohabitent avec les touches
            // sur les cases : un doigt qui ne bouge pas reste une touche.
            .gesture(
                DragGesture(minimumDistance: 8)
                    .updating($glisse) { valeur, etat, _ in etat = valeur.translation }
                    .onEnded { valeur in
                        decalage.width += valeur.translation.width
                        decalage.height += valeur.translation.height
                        borner(dans: geo.size, side: side, aspect: layout.aspect,
                               couvert: couvert)
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($pince) { valeur, etat, _ in etat = valeur.magnification }
                    .onEnded { valeur in
                        zoom = min(4, max(0.9, zoom * valeur.magnification))
                        borner(dans: geo.size, side: side, aspect: layout.aspect,
                               couvert: couvert)
                    }
            )
            // Il y avait ici un double-appui pour recentrer la carte. Il
            // coûtait cher et ne rapportait rien : un appui **simple** sur une
            // case devait attendre que la fenêtre du double se referme avant
            // d'être reconnu comme simple — un quart de seconde de retard sur
            // chaque touche du jeu. Le bouton de recentrage, en bas à droite,
            // fait déjà la même chose sans rien retarder.
            .clipped()
            // Un grand plateau arrive à une taille où les noms ne se lisent
            // pas. On le rapproche d'emblée juste assez pour qu'ils
            // apparaissent — le reste se promène sous le doigt.
            .onAppear {
                guard !ajuste else { return }
                ajuste = true
                zoom = min(2.2, max(1, 54 / max(radius * 1.7, 1)))
            }
            // Trois choses appellent un recadrage, et toutes passent par ici.
            // L'étape du duel, parce que la feuille qui monte prend le bas de
            // l'écran et que le combat doit rester visible au-dessus d'elle.
            // La cible qu'on désigne, parce que le panneau d'assaut cache
            // justement le bas du plateau, où les deux places se trouvaient
            // peut-être. Et la hauteur du panneau, parce que celui qui
            // demande combien d'hommes avancent est plus haut que le bilan
            // qu'il remplace.
            //
            // Toutes attendent un battement. Un panneau qui monte change de
            // hauteur à chaque image : sans cette attente, le plateau se
            // recadrait sur une couverture déjà périmée, et jugeait « déjà
            // visible » un décalage encore en mouvement — les deux places
            // finissaient à cheval sur le bord du panneau.
            .task(id: repere) {
                try? await Task.sleep(for: .milliseconds(260))
                guard !Task.isCancelled else { return }
                if couvert == 0 {
                    redescendre(dans: geo.size, side: side, aspect: layout.aspect)
                } else {
                    cadrerSurLAssaut(dans: geo.size, side: side, aspect: layout.aspect,
                                     couvert: couvert)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if deplace {
                    Button {
                        withAnimation(.snappy) { zoom = 1; decalage = .zero; remonteAppliquee = 0 }
                    } label: {
                        Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(9)
                            .background(Palette.panel.opacity(0.92), in: Circle())
                            .foregroundStyle(Palette.dim)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .transition(.opacity)
                }
            }
        }
    }

    /// Ce qui appelle un recadrage : la part couverte, l'étape du duel, la
    /// cible visée. Réunies en une seule valeur, elles ne déclenchent qu'une
    /// attente — et donc qu'un seul recadrage — quand elles changent ensemble,
    /// ce qui est le cas ordinaire.
    private struct Repere: Equatable {
        let couvert: CGFloat
        let stage: GameSession.Stage?
        let cible: TerritoryID?
    }

    /// La part du plateau que le panneau mange — mesurée quand on la connaît,
    /// estimée sinon.
    ///
    /// Arrondie au centième : un panneau qui respire d'un point ne doit pas
    /// relancer le recadrage.
    private func partCouverte(_ cadre: CGRect) -> CGFloat {
        guard let hautCouvert, cadre.height > 0 else { return CGFloat(session.partCouverte) }
        let part = (cadre.maxY - hautCouvert) / cadre.height
        return min(0.9, max(0, (part * 100).rounded() / 100))
    }

    /// Amène le milieu des deux places au centre de ce qui reste visible.
    ///
    /// Sans effet si elles s'y trouvent déjà : rien ne serait plus agaçant
    /// qu'une carte qui se met à glisser toute seule sans qu'on y gagne rien.
    private func cadrerSurLAssaut(dans taille: CGSize, side: CGFloat, aspect: Double,
                                  couvert: CGFloat) {
        guard let (de, vers) = placesEnJeu,
              let depart = session.game.board.layout.centers[de],
              let arrivee = session.game.board.layout.centers[vers] else { return }
        // Rien à faire si les deux places tiennent déjà dans ce qui reste
        // visible : une carte qui glisse sans raison gêne plus que le
        // recadrage ne rend service. Un plateau entier à l'écran, et rien
        // par-dessus, tombe de lui-même dans ce cas — c'est l'ancienne règle,
        // mais dite en termes de ce qu'on voit et non de ce qui existe.
        let rayon = CGFloat(session.game.board.layout.cellRadius) * side * echelle
        if enVue(depart, dans: taille, side: side, aspect: aspect, marge: rayon,
                 couvert: couvert),
           enVue(arrivee, dans: taille, side: side, aspect: aspect, marge: rayon,
                 couvert: couvert) { return }

        let milieu = CGPoint(x: (depart.x + arrivee.x) / 2 * side,
                             y: (depart.y + arrivee.y) / 2 * side)
        // La feuille du duel — ou le panneau de préparation — mange le bas :
        // le centre de ce qu'on voit remonte d'autant, et les deux places
        // doivent s'y poser.
        let remonte = taille.height * couvert / 2
        withAnimation(.easeInOut(duration: 0.45)) {
            decalage = CGSize(width: -echelle * (milieu.x - side / 2),
                              height: -echelle * (milieu.y - side * CGFloat(aspect) / 2) - remonte)
            borner(dans: taille, side: side, aspect: aspect, couvert: couvert)
            remonteAppliquee = remonte
        }
    }

    /// Le panneau s'en va : le plateau reprend la place qu'il lui avait
    /// laissée. Rien d'autre ne bouge — ni le rapprochement, ni ce que le
    /// joueur a promené sous son doigt entre-temps.
    private func redescendre(dans taille: CGSize, side: CGFloat, aspect: Double) {
        guard remonteAppliquee != 0 else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            decalage.height += remonteAppliquee
            remonteAppliquee = 0
            borner(dans: taille, side: side, aspect: aspect, couvert: 0)
        }
    }

    /// Les deux places que la vue doit garder à l'œil : celles de l'assaut en
    /// cours, ou, tant qu'il n'est pas déclaré, celles qu'on est en train de
    /// choisir. Un départ sans cible ne compte pas : la carte n'a pas à
    /// glisser au premier appui, seulement quand un panneau vient la couvrir.
    private var placesEnJeu: (TerritoryID, TerritoryID)? {
        if let a = session.assault { return (a.from, a.to) }
        if let base = session.selected, let cible = session.target { return (base, cible) }
        return nil
    }

    /// Une place est-elle là où on peut la voir : dans l'écran, et au-dessus
    /// du panneau qui en mange le bas ?
    private func enVue(_ p: Point, dans taille: CGSize, side: CGFloat, aspect: Double,
                       marge: CGFloat, couvert: CGFloat) -> Bool {
        let x = taille.width / 2 + decalage.width
            + echelle * (CGFloat(p.x) * side - side / 2)
        let y = taille.height / 2 + decalage.height
            + echelle * (CGFloat(p.y) * side - side * CGFloat(aspect) / 2)
        let bas = taille.height * (1 - couvert)
        return x > marge && x < taille.width - marge
            && y > marge && y < bas - marge
    }

    /// Empêche le plateau de partir hors de l'écran : on garde toujours de
    /// quoi le rattraper.
    private func borner(dans taille: CGSize, side: CGFloat, aspect: Double,
                        couvert: CGFloat) {
        let large = side * echelle, haut = side * CGFloat(aspect) * echelle
        let maxX = Cadrage.borneHorizontale(largeurVue: taille.width, largeurPlateau: large)
        decalage.width = min(maxX, max(-maxX, decalage.width))
        let bornes = Cadrage.bornesVerticales(hauteurVue: taille.height,
                                              hauteurPlateau: haut, couvert: couvert)
        decalage.height = min(bornes.upperBound, max(bornes.lowerBound, decalage.height))
    }

    /// Les traversées, en pointillé. Sans elles, un joueur qui voit deux
    /// cases séparées par la mer n'a aucune raison de croire qu'il peut passer
    /// de l'une à l'autre — et il ne l'essaiera jamais.
    private func traversees(side: CGFloat, radius: CGFloat) -> some View {
        let layout = session.game.board.layout
        return ForEach(layout.seaRoutes, id: \.self) { route in
            if let a = layout.centers[route.from], let b = layout.centers[route.to] {
                let depart = CGPoint(x: a.x * side, y: a.y * side)
                let arrivee = CGPoint(x: b.x * side, y: b.y * side)
                let chemin = SeaLink(from: depart, to: arrivee, recul: radius * 0.80,
                                     controle: courbure(depart, arrivee,
                                                        side: side, aspect: layout.aspect,
                                                        radius: radius))
                // Deux traits superposés : un large et sombre en dessous, qui
                // détache la route de la mer, et le pointillé clair par-dessus.
                // Un seul trait pâle se perdait sur le fond, et l'on ne
                // devinait pas qu'on pouvait passer.
                ZStack {
                    chemin.stroke(Palette.sea.opacity(0.9),
                                  style: StrokeStyle(lineWidth: max(5, radius * 0.30),
                                                     lineCap: .round))
                    chemin.stroke(Palette.ink.opacity(0.72),
                                  style: StrokeStyle(lineWidth: max(2.5, radius * 0.15),
                                                     lineCap: .round,
                                                     dash: [radius * 0.30, radius * 0.26]))
                }
                .allowsHitTesting(false)
            }
        }
    }

    /// Une traversée courte va tout droit. Une longue s'arque, et s'écarte du
    /// centre du plateau — ce qui la fait passer par-dessus la carte plutôt
    /// qu'au travers.
    private func courbure(_ a: CGPoint, _ b: CGPoint,
                          side: CGFloat, aspect: Double, radius: CGFloat) -> CGPoint? {
        let dx = b.x - a.x, dy = b.y - a.y
        let d = (dx * dx + dy * dy).squareRoot()
        guard d > radius * 4 else { return nil }

        let milieu = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let centre = CGPoint(x: side / 2, y: side * CGFloat(aspect) / 2)
        // Des deux perpendiculaires, on prend celle qui s'éloigne du centre.
        var nx = -dy / d, ny = dx / d
        if (milieu.x - centre.x) * nx + (milieu.y - centre.y) * ny < 0 { nx = -nx; ny = -ny }
        let creux = d * 0.34
        return CGPoint(x: milieu.x + nx * creux, y: milieu.y + ny * creux)
    }

    /// D'où part l'assaut et où il tombe. Le trait ne se voit que pendant un
    /// assaut : le reste du temps, le plateau n'a rien à raconter.
    @ViewBuilder
    private func fleche(side: CGFloat, radius: CGFloat) -> some View {
        if let a = session.assault,
           let depart = session.game.board.layout.centers[a.from],
           let arrivee = session.game.board.layout.centers[a.to] {
            AttackArrow(from: CGPoint(x: depart.x * side, y: depart.y * side),
                        to: CGPoint(x: arrivee.x * side, y: arrivee.y * side),
                        // Deux cases voisines n'ont qu'un rayon et demi entre
                        // leurs centres : reculer d'un rayon de chaque côté ne
                        // laissait plus rien à tracer. La flèche part donc de
                        // l'intérieur de la case et franchit la frontière.
                        recul: radius * 0.44, tete: radius * 0.40)
                .stroke(Palette.camp(a.attacker),
                        style: StrokeStyle(lineWidth: max(3, radius * 0.19),
                                           lineCap: .round, lineJoin: .round))
                .shadow(color: .black.opacity(0.5), radius: 2)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    // MARK: - Une case

    private func tile(_ id: TerritoryID, side: CGFloat, radius: CGFloat, center: Point) -> some View {
        let largeur: CGFloat = radius * 1.732 * 0.97
        let hauteur: CGFloat = radius * 2 * 0.97
        return Hexagon()
            .fill(fill(id))
            .overlay(Hexagon().strokeBorder(border(id), lineWidth: borderWidth(id)))
            .overlay(frontiere(id, radius: radius))
            .overlay(legende(id, radius: radius, echelle: echelle))
            .frame(width: largeur, height: hauteur)
            .contentShape(Hexagon())
            .position(x: center.x * side, y: center.y * side)
            .onTapGesture { withAnimation(.snappy(duration: 0.11)) { session.tap(id) } }
            .animation(.easeInOut(duration: 0.16), value: session.game.armies(id))
    }

    /// Le trait de frontière du continent, du côté de cette case.
    private func frontiere(_ id: TerritoryID, radius: CGFloat) -> some View {
        let bords = session.game.board.layout.frontierEdges[id] ?? []
        let teinte = Palette.continent(rang: session.game.map.tint(of: id))
        // Deux fois plus fin qu'avant : c'est ce qui permet à la teinte d'être
        // vive sans se battre avec la couleur du camp qui remplit la case.
        return BorderEdges(edges: bords)
            .stroke(teinte, style: StrokeStyle(lineWidth: max(1.5, radius * 0.075),
                                               lineCap: .round, lineJoin: .round))
    }

    /// Le nombre d'hommes, et le nom si la case est assez large pour le lire.
    private func legende(_ id: TerritoryID, radius: CGFloat, echelle: CGFloat) -> some View {
        let nombre: Int = session.game.armies(id)
        let nom: String = session.game.name(id)
        // C'est la taille réellement vue qui décide : une case trop petite
        // pour son nom le retrouve dès qu'on rapproche la carte.
        let large: Bool = radius * echelle * 1.7 > 52
        return VStack(spacing: 0) {
            Text("\(nombre)")
                .font(.system(size: max(11, radius * 0.62), weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 1, y: 1)
                // Le chiffre roule au lieu de sauter : c'est ce qui rend
                // visible qu'un homme vient de tomber, pendant qu'on répond.
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: nombre)
            if large {
                Text(nom)
                    .font(.system(size: radius * 0.27, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Ce que la couleur raconte

    private func fill(_ id: TerritoryID) -> some ShapeStyle {
        let g = session.game
        let base = Palette.camp(g.owner[id] ?? 0)
        // Sous les projecteurs : les deux places d'un assaut, puis ce qui est
        // jouable.
        if session.assault?.to == id || session.assault?.from == id {
            return AnyShapeStyle(base.opacity(1))
        }
        if isTarget(id) || session.selected == id { return AnyShapeStyle(base.opacity(0.95)) }
        return AnyShapeStyle(base.opacity(playable(id) ? 0.72 : 0.45))
    }

    private func border(_ id: TerritoryID) -> Color {
        if session.assault?.to == id { return Palette.lost }
        if let a = session.assault, a.from == id { return Palette.camp(a.attacker) }
        if session.selected == id { return .white }
        if isTarget(id) { return Palette.lost.opacity(0.9) }
        // Le contour d'une case n'a plus à porter le continent : les traits de
        // frontière s'en chargent. Il ne fait que détacher les cases entre
        // elles, et se tient donc en retrait.
        return Palette.sea.opacity(0.7)
    }

    private func borderWidth(_ id: TerritoryID) -> CGFloat {
        if session.assault?.to == id || session.assault?.from == id { return 3.5 }
        return session.selected == id || isTarget(id) ? 3 : 1.5
    }

    /// Une case sur laquelle le joueur peut agir maintenant.
    private func playable(_ id: TerritoryID) -> Bool {
        let g = session.game
        guard !g.currentPlayer.isBot else { return true }
        switch g.phase {
        case .reinforcement: return g.owner[id] == g.currentPlayer.id
        case .attack: return g.canLaunch(from: id)
        case .fortify: return g.owner[id] == g.currentPlayer.id
        default: return true
        }
    }

    /// Une cible atteignable depuis la case retenue.
    private func isTarget(_ id: TerritoryID) -> Bool {
        guard let base = session.selected else { return false }
        let g = session.game
        switch g.phase {
        case .attack:
            return g.map.areAdjacent(base, id) && g.owner[id] != g.currentPlayer.id
        case .fortify:
            return id != base && g.owner[id] == g.currentPlayer.id
                && g.areLinked(base, id, for: g.currentPlayer.id)
        default:
            return false
        }
    }
}

// MARK: - Les bornes du déplacement

/// Jusqu'où le plateau peut se déplacer sous le doigt — ou sous le recadrage.
///
/// C'est de l'arithmétique, et elle est sortie de la vue parce qu'elle se
/// vérifie : c'est elle, et non le recadrage, qui laissait les deux places
/// sous le panneau. Le recadrage visait juste ; la borne l'arrêtait en
/// chemin, sans rien dire.
enum Cadrage {

    /// Ce qu'on garde toujours de plateau à l'écran, en points. Une marge
    /// franche : moins, et l'on ne saurait plus où rattraper la carte.
    static let marge: CGFloat = 90

    static func borneHorizontale(largeurVue: CGFloat, largeurPlateau: CGFloat) -> CGFloat {
        max(0, (largeurPlateau - largeurVue) / 2 + marge)
    }

    /// Le décalage vertical admissible, dit en termes de **ce qu'on voit**.
    ///
    /// Il valait « la moitié de ce qui déborde, plus une marge » — une règle
    /// qui ne connaît que l'écran. Or un panneau qui mange les trois quarts
    /// du bas ne laisse qu'une bande étroite en haut, et amener deux places
    /// du bas de la carte dans cette bande demande de remonter le plateau de
    /// bien plus que la moitié de son débord. La borne s'y opposait : les
    /// places restaient sous le panneau, ce que le recadrage avait justement
    /// pour objet d'éviter.
    ///
    /// La règle est donc dite autrement, et sans mentionner l'écran : le
    /// plateau peut monter tant qu'il en reste une marge sous le haut, et
    /// descendre tant qu'il en reste une dans la bande libre. Elle n'est pas
    /// symétrique, et elle n'a pas à l'être — c'est le bas qui est mangé.
    static func bornesVerticales(hauteurVue: CGFloat, hauteurPlateau: CGFloat,
                                 couvert: CGFloat) -> ClosedRange<CGFloat> {
        let bande = hauteurVue * (1 - min(max(couvert, 0), 0.95))
        // Le bas du plateau reste sous le haut de l'écran…
        let leplusHaut = marge - (hauteurVue + hauteurPlateau) / 2
        // …et son haut reste dans la bande qu'aucun panneau ne couvre.
        let leplusBas = bande - marge - (hauteurVue - hauteurPlateau) / 2
        return min(leplusHaut, leplusBas) ... max(leplusHaut, leplusBas)
    }
}
