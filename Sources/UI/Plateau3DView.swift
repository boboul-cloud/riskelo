//
//  Plateau3DView.swift
//  Riskelo
//
//  Le plateau en relief, tel qu'on le touche.
//
//  Il fait tout ce que fait le plateau à plat, et de la même façon : un doigt
//  qui ne bouge pas joue, un doigt qui glisse promène la carte, deux doigts la
//  rapprochent. Il y ajoute un geste : deux doigts qui tournent font tourner
//  la table — on regarde l'Asie depuis le Pacifique si l'on veut.
//
//  Les règles du jeu n'en savent rien. La vue lit la partie comme le fait le
//  plateau à plat, et elle touche les terres par la même porte, `tap`.
//

import RealityKit
import SwiftUI

@available(iOS 18.0, macOS 15.0, *)
struct Plateau3DView: View {

    let session: GameSession
    /// Où commence le panneau qui couvre le bas de l'écran — voir `BoardView`.
    var hautCouvert: CGFloat?

    @State private var scene = Scene3D()
    @State private var camera = Camera3D()
    /// Le cadrage du plateau entier, pour la taille de vue du moment.
    @State private var ensemble = Camera3D()
    /// Le premier regard : l'ensemble, rapproché s'il le faut pour lire.
    @State private var depart = Camera3D()
    /// La durée de la prochaine pose de la caméra : nulle sous le doigt, qui
    /// doit suivre sans retard ; un battement pour un recadrage, qui doit se
    /// voir glisser.
    @State private var duree: Double = 0
    @State private var taille: CGSize = .zero
    /// Ce que les gestes en cours ont déjà appliqué. Chaque geste ne verse
    /// que ce qui s'est ajouté depuis son dernier appel : le glisser et le
    /// pincer se mêlent alors sans se marcher dessus.
    @State private var dejaGlisse: CGSize = .zero
    @State private var dejaPince: CGFloat = 1
    @State private var dejaTourne: Double = 0
    /// La caméra telle qu'elle était avant qu'un panneau ne la fasse glisser.
    /// Le panneau parti, elle y revient — sauf si le joueur l'a promenée
    /// entre-temps : c'est alors son choix qui compte.
    @State private var avantCadrage: Camera3D?
    /// La part de la vue que le panneau du bas mange en ce moment.
    @State private var couvertVu: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let instantane = Instantane3D(partie: session.plateau, choisi: session.selected,
                                          assaut: session.assautAffiche)
            let couvert = partCouverte(geo.frame(in: .named(Espace.ecran)))
            let repere = Repere(couvert: couvert, stage: session.stage, cible: session.target)
            // La scène ne se retouche que lorsque quelque chose change — l'état
            // du plateau, l'œil, la taille de la vue —, et `montrer` relit
            // alors la partie au moment même plutôt qu'une copie faite à
            // l'ouverture.
            RealityView { content in
                let partie = session.plateau
                await scene.construire(board: partie.board, nom: { partie.name($0) })
                content.add(scene.racine)
                montrer()
            }
            .onChange(of: instantane) { montrer() }
            .onChange(of: camera) { montrer() }
            .onChange(of: taille) { montrer() }
            .onChange(of: couvert, initial: true) { _, nouveau in
                couvertVu = nouveau
                montrer()
            }
            .gesture(
                SpatialTapGesture()
                    .onEnded { valeur in toucher(valeur.location, taille: geo.size) }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { valeur in
                        let d = CGSize(width: valeur.translation.width - dejaGlisse.width,
                                       height: valeur.translation.height - dejaGlisse.height)
                        dejaGlisse = valeur.translation
                        bouger { $0.glisser(d, taille: geo.size) }
                    }
                    .onEnded { _ in dejaGlisse = .zero }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { valeur in
                        let f = valeur.magnification / max(0.01, dejaPince)
                        dejaPince = valeur.magnification
                        bouger { $0.pincer(f) }
                    }
                    .onEnded { _ in dejaPince = 1 }
            )
            .simultaneousGesture(
                RotateGesture()
                    .onChanged { valeur in
                        let a = valeur.rotation.radians - dejaTourne
                        dejaTourne = valeur.rotation.radians
                        bouger { $0.tourner(a) }
                    }
                    .onEnded { _ in dejaTourne = 0 }
            )
            .onAppear { mesurer(geo.size, premiereFois: true) }
            .onChange(of: geo.size) { _, nouvelle in mesurer(nouvelle, premiereFois: false) }
            // Les mêmes raisons de recadrer que le plateau à plat, et la même
            // attente : un panneau qui monte change de hauteur à chaque image.
            .task(id: repere) {
                try? await Task.sleep(for: .milliseconds(260))
                guard !Task.isCancelled else { return }
                if couvert == 0 { revenir() } else { cadrerSurLAssaut(couvert: couvert) }
            }
            .overlay(alignment: .bottomTrailing) {
                // Pas sous un panneau : il se voyait au travers, sans qu'on
                // puisse l'atteindre.
                if camera != ensemble, couvert == 0 {
                    Button {
                        avantCadrage = nil
                        duree = 0.45
                        camera = ensemble
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
                    .accessibilityLabel(Text("Recentrer le plateau"))
                }
            }
        }
    }

    /// Montre la partie telle qu'elle est maintenant, de l'œil du moment.
    private func montrer() {
        let etat = Instantane3D(partie: session.plateau, choisi: session.selected,
                                assaut: session.assautAffiche)
        scene.appliquer(etat, camera: camera, duree: duree, taille: taille, couvert: couvertVu)
    }

    private struct Repere: Equatable {
        let couvert: CGFloat
        let stage: GameSession.Stage?
        let cible: TerritoryID?
    }

    /// Un geste du joueur : la caméra suit sans retard, et ce qu'un panneau
    /// avait décidé n'a plus lieu d'être rétabli.
    private func bouger(_ changement: (inout Camera3D) -> Void) {
        var c = camera
        changement(&c)
        c.borner(repere: scene.repere, ensemble: ensemble.distance)
        duree = 0
        avantCadrage = nil
        camera = c
    }

    /// La taille de la vue a changé — rotation de l'appareil, fenêtre du Mac
    /// redimensionnée. Le cadrage d'ensemble suit ; la caméra aussi, si le
    /// joueur ne l'avait pas déplacée.
    private func mesurer(_ nouvelle: CGSize, premiereFois: Bool) {
        guard nouvelle.width > 0, nouvelle.height > 0 else { return }
        let intacte = premiereFois || camera == depart || camera == ensemble
        taille = nouvelle
        let layout = session.plateau.board.layout
        let repere = Repere3D(aspect: layout.aspect)
        ensemble = Camera3D.ensemble(repere: repere, taille: nouvelle)
        depart = ensemble.rapprochee(pourLire: repere.fanion(nil, layout: layout),
                                     repere: repere, taille: nouvelle)
        if intacte {
            duree = 0
            camera = depart
        }
    }

    /// La part du plateau que le panneau mange — la même mesure que le
    /// plateau à plat.
    private func partCouverte(_ cadre: CGRect) -> CGFloat {
        guard let hautCouvert, cadre.height > 0 else { return CGFloat(session.partCouverte) }
        let part = (cadre.maxY - hautCouvert) / cadre.height
        return min(0.9, max(0, (part * 100).rounded() / 100))
    }

    /// Les deux places que la vue doit garder à l'œil.
    private var placesEnJeu: (TerritoryID, TerritoryID)? {
        if let a = session.assautAffiche { return (a.from, a.to) }
        if let base = session.selected, let cible = session.target { return (base, cible) }
        return nil
    }

    private func cadrerSurLAssaut(couvert: CGFloat) {
        let layout = session.plateau.board.layout
        guard let (de, vers) = placesEnJeu, let a = layout.centers[de], let b = layout.centers[vers],
              taille.width > 0 else { return }
        let r = Repere3D(aspect: layout.aspect)
        let marge = camera.points(pour: r.longueur(layout.typicalRadius), taille: taille)
        guard let cadre = camera.cadrage(de: r.monde(a, hauteur: scene.epaisseur),
                                         vers: r.monde(b, hauteur: scene.epaisseur),
                                         taille: taille, couvert: couvert,
                                         marge: min(60, max(16, marge))) else { return }
        if avantCadrage == nil { avantCadrage = camera }
        duree = 0.45
        camera = cadre
    }

    /// Le panneau s'en va : la caméra retourne où elle était.
    private func revenir() {
        guard let avant = avantCadrage else { return }
        avantCadrage = nil
        duree = 0.45
        camera = avant
    }

    /// Le doigt est tombé là : quelle terre ?
    ///
    /// Une terre en jeu est soulevée, et le rayon qui la touche la rencontre
    /// plus haut que les autres. On la cherche donc d'abord à sa hauteur ;
    /// sans quoi le doigt posé sur le bord d'une place soulevée tombait sur
    /// sa voisine, qu'on voit derrière elle.
    private func toucher(_ point: CGPoint, taille: CGSize) {
        let partie = session.plateau
        let layout = partie.board.layout
        let repere = scene.repere
        func terre(a hauteur: Float) -> TerritoryID? {
            guard let m = camera.sol(point, taille: taille, hauteur: hauteur) else { return nil }
            return Touche3D.territoire(en: repere.plateau(m), layout: layout, ordre: partie.map.order)
        }
        let enJeu = Instantane3D(partie: partie, choisi: session.selected,
                                 assaut: session.assautAffiche)
        func soulevee(_ id: TerritoryID) -> Bool {
            enJeu.choisi == id || enJeu.cibles.contains(id)
                || enJeu.assaut?.de == id || enJeu.assaut?.vers == id
        }
        let haute = terre(a: scene.epaisseur + scene.levee)
        let choix = haute.flatMap { soulevee($0) ? $0 : nil } ?? terre(a: scene.epaisseur)
        guard let id = choix else { return }
        withAnimation(.snappy(duration: 0.11)) { session.tap(id) }
    }
}
