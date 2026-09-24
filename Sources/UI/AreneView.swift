//
//  AreneView.swift
//  Riskelo
//
//  Jouer par Game Center.
//
//  Cet écran est court, et c'est normal : presque tout y est fait par Apple.
//  On lui demande une partie à deux, trois ou quatre, il montre sa propre
//  fenêtre — vos amis, l'invitation, l'attente — et il rend une partie
//  lorsqu'elle est pleine. Il n'y a ni code à donner, ni table à ouvrir, ni
//  « Commencer » à toucher : quand Apple rend la partie, elle est faite.
//
//  Ce que l'écran doit dire, en revanche, c'est ce qu'Apple ne dit pas :
//  qu'il faut un compte, et qu'une partie coupée ne se reprend pas. Les deux
//  se découvrent autrement au pire moment.
//

import SwiftUI
#if canImport(GameKit)
import GameKit
#endif
#if os(iOS)
import UIKit
#else
import AppKit
#endif

#if canImport(GameKit)

struct AreneView: View {

    let plateau: Boards
    let regles: Rules
    var onReady: (GameSession) -> Void
    var onCancel: () -> Void
    var onReglages: () -> Void = { }

    @State private var arene = Arene()
    @State private var noms: [Pair: String] = [:]
    @State private var joueurs = 2
    @State private var lancee = false
    @State private var desaccord = false
    /// La partie est là ; on laisse aux noms le temps d'arriver avant de
    /// distribuer les camps. Voir `attendreLesNoms`.
    @State private var onRassemble = false

    var body: some View {
        ZStack {
            Palette.sea.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 40)).foregroundStyle(Palette.camp(3))
                Text("Par Game Center")
                    .font(.title3.weight(.semibold)).foregroundStyle(Palette.ink)

                contenu

                Spacer()
                Button("Annuler") { arene.arreter(); onCancel() }
                    .buttonStyle(.bordered).tint(Palette.dim)
            }
            .frame(maxWidth: 420)
            .padding(26)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            preparer()
            arene.identifier()
        }
        .onDisappear { if !lancee { arene.arreter() } }
        // Les deux fenêtres d'Apple : celle qui connecte le joueur, et celle
        // qui compose la partie. Toutes deux sont des contrôleurs de vue
        // qu'on ne peut que présenter tels quels.
        .sheet(isPresented: Binding(
            get: { arene.ecranDeConnexion != nil },
            set: { if !$0 { arene.connexionRefermee() } })) {
            if let ecran = arene.ecranDeConnexion as? Controleur {
                PontVersApple(controleur: ecran)
            }
        }
        .sheet(isPresented: Binding(
            get: { arene.ecranAPresenter != nil },
            set: { if !$0 { arene.ecranReferme() } })) {
            if let ecran = arene.ecranAPresenter {
                PontVersApple(controleur: ecran)
            }
        }
    }

    @ViewBuilder private var contenu: some View {
        switch arene.etat {
        case .identification:
            ProgressView().tint(Palette.dim)
            Text("Connexion à Game Center…")
                .font(.subheadline).foregroundStyle(Palette.dim)

        case .sansCompte:
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 32)).foregroundStyle(Palette.lostVif)
            Text("Pas connecté à Game Center")
                .font(.headline).foregroundStyle(Palette.lostVif)
            Text("""
                 Game Center est le service de jeu d'Apple, et il demande un \
                 compte. Vous pouvez vous y connecter dans les Réglages — ou \
                 revenir en arrière et **jouer au loin avec un code**, qui ne \
                 demande rien à personne.
                 """)
                .font(.footnote).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)
            #if os(iOS)
            bouton("Ouvrir les Réglages", "arrow.up.forward.app", Palette.camp(0)) {
                if let ou = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(ou)
                }
            }
            #endif
            Button("Réessayer") { arene.identifier() }
                .buttonStyle(.bordered).tint(Palette.dim)

        case .aLArret:
            if let invite = arene.invitation {
                // Un ami a invité pendant qu'on était ailleurs.
                Text("\(invite.sender.displayName) vous invite")
                    .font(.headline).foregroundStyle(Palette.held)
                bouton("Accepter", "checkmark.circle.fill", Palette.held) {
                    arene.accepter(invite)
                }
            }

            Text("""
                 Vos amis Game Center, ou quelqu'un au hasard. \
                 Apple s'occupe de vous mettre en présence.
                 """)
                .font(.footnote).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("COMBIEN DE JOUEURS").font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.dim).kerning(0.6)
                Picker("", selection: $joueurs) {
                    ForEach(2...4, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
            }

            bouton("Chercher des joueurs", "magnifyingglass", Palette.camp(0)) {
                arene.joueurs = joueurs
                arene.chercher()
            }

            // Ce qu'Apple ne dira pas, et qu'il vaut mieux savoir avant.
            Text("""
                 Une partie Game Center ne se reprend pas : si quelqu'un perd \
                 le réseau, elle s'arrête. Le code, lui, laisse revenir.
                 """)
                .font(.caption2).foregroundStyle(Palette.dim.opacity(0.85))
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                Text(laPartieQuOnOuvre)
                    .font(.caption).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
                Button(action: onReglages) {
                    Label("Réglages de la partie", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.bordered).tint(Palette.dim)
            }
            .padding(.top, 4)

        case .cherche:
            ProgressView().tint(Palette.camp(0))
            Text("Recherche…").font(.subheadline).foregroundStyle(Palette.dim)

        case .relie:
            if desaccord {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34)).foregroundStyle(Palette.lostVif)
                Text("Versions différentes").font(.headline).foregroundStyle(Palette.lostVif)
                Text("Les deux appareils n'ont pas la même version de Riskelo.")
                    .font(.footnote).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView().tint(Palette.held)
                Text(arene.jeSuisLHote ? "On distribue les camps…"
                                       : "En attente du lancement…")
                    .font(.headline).foregroundStyle(Palette.held)
                VStack(spacing: 6) {
                    ForEach(Array(arene.relies.enumerated()), id: \.element) { i, pair in
                        HStack(spacing: 8) {
                            Circle().fill(Palette.camp(i + 1)).frame(width: 10, height: 10)
                            Text(noms[pair] ?? pair.nom)
                                .font(.subheadline).foregroundStyle(Palette.ink)
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

        case let .refuse(dit):
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32)).foregroundStyle(Palette.lostVif)
            Text("Game Center n'a pas pu")
                .font(.headline).foregroundStyle(Palette.lostVif)
            Text(dit).font(.footnote).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)
            Button("Réessayer") { arene.chercher() }
                .buttonStyle(.bordered).tint(Palette.dim)
        }
    }

    private var laPartieQuOnOuvre: String {
        var dits = [plateau.label, regles.mode.label]
        if regles.territoryCards { dits.append(dit("cartes")) }
        if regles.objectifs { dits.append(dit("conquêtes personnelles")) }
        if regles.dominationOverride == 0 { dits.append(dit("guerre totale")) }
        return dits.joined(separator: " · ")
    }

    private func bouton(_ titre: LocalizedStringKey, _ icone: String, _ teinte: Color,
                        _ geste: @escaping () -> Void) -> some View {
        Button(action: geste) {
            Label(titre, systemImage: icone)
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent).tint(teinte)
    }

    // MARK: - La mise en place

    private func preparer() {
        MiseEnPlace.preparer(
            arene,
            nomVu: { pair, nom in noms[pair] = nom },
            partieRecue: { etat, rang, numero in
                lancee = true
                onReady(GameSession(fil: arene, heberge: false, game: etat,
                                    monRang: rang, compteur: numero))
            },
            desaccord: { desaccord = true })

        // Chez Apple, personne ne touche « Commencer » : la partie est pleine
        // au moment où elle est rendue. C'est donc celui qui héberge — le
        // plus petit identifiant, voir `Arene` — qui lance, et lui seul.
        arene.onSalonPlein = {
            guard !lancee, arene.jeSuisLHote, !onRassemble else { return }
            onRassemble = true
            Task { await attendreLesNoms() }
        }
    }

    /// Laisser les `bonjour` arriver avant de distribuer les camps.
    ///
    /// Sans cette attente, l'hôte lançait la partie dans la seconde où Apple
    /// la rendait — c'est-à-dire avant que le nom des autres ait eu le temps
    /// de traverser. Les camps s'appelaient alors « Rouge » et « Vert » au
    /// lieu de « Rouge · Marie », sur les quatre appareils à la fois, et
    /// c'était irrattrapable : le nom part **avec** l'état.
    ///
    /// Deux secondes au plus. Un nom qui n'est pas là au bout de deux
    /// secondes ne viendra pas, et un camp sans nom reste parfaitement
    /// jouable — ce qui ne l'est pas, c'est d'attendre sans fin.
    private func attendreLesNoms() async {
        let limite = Date().addingTimeInterval(2)
        while Date() < limite,
              noms.count < arene.relies.count {
            try? await Task.sleep(for: .milliseconds(80))
        }
        guard !lancee, arene.jeSuisLHote else { return }
        lancee = true
        onReady(MiseEnPlace.lancer(arene, joueurs: arene.relies.count + 1,
                                   plateau: plateau, regles: regles, noms: noms))
    }
}

// MARK: - Le pont vers les fenêtres d'Apple

#if os(iOS)
typealias Controleur = UIViewController

/// GameKit ne sait montrer que des contrôleurs de vue. On les présente tels
/// quels : les habiller serait leur mentir dessus, et c'est justement l'écran
/// où le joueur doit reconnaître Apple plutôt que nous.
private struct PontVersApple: UIViewControllerRepresentable {
    let controleur: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { controleur }
    func updateUIViewController(_ controleur: UIViewController, context: Context) {}
}
#else
typealias Controleur = NSViewController

private struct PontVersApple: NSViewControllerRepresentable {
    let controleur: NSViewController
    func makeNSViewController(context: Context) -> NSViewController { controleur }
    func updateNSViewController(_ controleur: NSViewController, context: Context) {}
}
#endif

#endif
