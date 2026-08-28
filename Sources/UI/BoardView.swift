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

    /// Le plateau se déplace et se rapproche. C'est ce qui permet d'en avoir
    /// de plus grands que l'écran : une carte du monde ne tient pas sur un
    /// téléphone à une taille où les noms se lisent, mais elle tient très bien
    /// si on peut la promener sous le doigt.
    @State private var zoom: CGFloat = 1
    @State private var ajuste = false
    @State private var decalage: CGSize = .zero
    @GestureState private var pince: CGFloat = 1
    @GestureState private var glisse: CGSize = .zero

    private var echelle: CGFloat { min(4, max(0.9, zoom * pince)) }
    private var deplace: Bool { echelle != 1 || decalage != .zero }

    var body: some View {
        GeometryReader { geo in
            let layout = session.game.board.layout
            let side = min(geo.size.width, geo.size.height / layout.aspect)
            let radius = layout.cellRadius * side
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
                        borner(dans: geo.size, side: side, aspect: layout.aspect)
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($pince) { valeur, etat, _ in etat = valeur.magnification }
                    .onEnded { valeur in
                        zoom = min(4, max(0.9, zoom * valeur.magnification))
                        borner(dans: geo.size, side: side, aspect: layout.aspect)
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
            // Quand la machine annonce un assaut, la vue va le chercher :
            // rapprochée, la carte n'en montre qu'un morceau, et le combat
            // pouvait se dérouler entièrement hors de l'écran.
            // À chaque étape du duel : la feuille qui monte prend le bas de
            // l'écran, et le combat doit rester visible au-dessus d'elle.
            .onChange(of: session.stage) { _, _ in
                cadrerSurLAssaut(dans: geo.size, side: side, aspect: layout.aspect)
            }
            .overlay(alignment: .bottomTrailing) {
                if deplace {
                    Button {
                        withAnimation(.snappy) { zoom = 1; decalage = .zero }
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

    /// Amène le milieu des deux places au centre de l'écran.
    ///
    /// Sans effet si tout le plateau tient déjà : rien ne serait plus agaçant
    /// qu'une carte entièrement visible qui se met à glisser toute seule.
    private func cadrerSurLAssaut(dans taille: CGSize, side: CGFloat, aspect: Double) {
        guard let a = session.assault,
              let depart = session.game.board.layout.centers[a.from],
              let arrivee = session.game.board.layout.centers[a.to] else { return }
        let large = side * echelle, haut = side * CGFloat(aspect) * echelle
        guard large > taille.width + 1 || haut > taille.height + 1 else { return }

        let milieu = CGPoint(x: (depart.x + arrivee.x) / 2 * side,
                             y: (depart.y + arrivee.y) / 2 * side)
        // La feuille du duel mange le bas : le centre de ce qu'on voit remonte
        // d'autant, et le combat doit s'y poser.
        let remonte = taille.height * CGFloat(session.partCouverte) / 2
        withAnimation(.easeInOut(duration: 0.45)) {
            decalage = CGSize(width: -echelle * (milieu.x - side / 2),
                              height: -echelle * (milieu.y - side * CGFloat(aspect) / 2) - remonte)
            borner(dans: taille, side: side, aspect: aspect)
        }
    }

    /// Empêche le plateau de partir hors de l'écran : on garde toujours de
    /// quoi le rattraper.
    private func borner(dans taille: CGSize, side: CGFloat, aspect: Double) {
        let large = side * echelle, haut = side * CGFloat(aspect) * echelle
        let marge: CGFloat = 60 + taille.height * CGFloat(session.partCouverte) / 2
        let maxX = max(0, (large - taille.width) / 2 + marge)
        let maxY = max(0, (haut - taille.height) / 2 + marge)
        decalage.width = min(maxX, max(-maxX, decalage.width))
        decalage.height = min(maxY, max(-maxY, decalage.height))
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
