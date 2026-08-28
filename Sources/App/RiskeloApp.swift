//
//  RiskeloApp.swift
//  Riskelo
//
//  Un Risk où le dé est remplacé par une question de culture générale.
//
//  Une seule cible pour l'iPhone, l'iPad et le Mac : rien dans le jeu ne
//  dépend d'un écran. Le plateau est décrit en unités relatives, les panneaux
//  sont bornés en largeur, et tout ce qui se touche se clique.
//

import SwiftUI

@main
struct RiskeloApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var racine = RootModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: racine)
        }
        .onChange(of: scenePhase) { _, nouvelle in
            // L'application peut être arrêtée sans autre préavis que celui-ci.
            if nouvelle != .active { racine.session?.saveNow() }
        }
        #if os(macOS)
        .defaultSize(width: 980, height: 760)
        #endif
    }
}

/// Ce qui survit au-delà d'une vue : la partie en cours, et elle seule.
@Observable
@MainActor
final class RootModel {
    var session: GameSession?
    var repriseTentee = false
    /// La mise en place d'une partie à deux appareils, quand elle est ouverte.
    var salon: (regles: Rules, plateau: Boards)?
    var bibliotheque = false
    /// Le mode d'emploi, ouvert depuis l'accueil.
    var manuel = false
}

struct RootView: View {
    @Bindable var model: RootModel

    var body: some View {
        ZStack {
            // Le fond est posé d'emblée : sans lui, l'écran d'accueil
            // apparaîtrait le temps d'une image avant que la partie reprise
            // ne le remplace.
            Palette.sea.ignoresSafeArea()
            if let session = model.session {
                GameScreen(session: session) {
                    session.saveNow()
                    withAnimation { model.session = nil }
                }
            } else if model.bibliotheque {
                ArchivesView(onOpen: { etat in
                    withAnimation {
                        model.bibliotheque = false
                        // Une branche neuve : revenir sur une partie ne doit
                        // pas effacer la partie sur laquelle on revient.
                        model.session = GameSession(resuming: etat, partie: UUID())
                    }
                }, onClose: { withAnimation { model.bibliotheque = false } })
            } else if model.manuel {
                ManuelView(onClose: { withAnimation { model.manuel = false } })
            } else if let salon = model.salon {
                LobbyView(plateau: salon.plateau, regles: salon.regles,
                          onReady: { partie in
                              withAnimation { model.salon = nil; model.session = partie }
                          },
                          onCancel: { withAnimation { model.salon = nil } })
            } else if model.repriseTentee {
                SetupView(onStart: { joueurs, regles, plateau in
                    withAnimation {
                        model.session = GameSession(players: joueurs, rules: regles, board: plateau)
                    }
                }, onNetwork: { regles, plateau in
                    withAnimation { model.salon = (regles, plateau) }
                }, onResume: GameStore.shared.hasSavedGame ? {
                    if let sauvee = GameStore.shared.load() {
                        withAnimation { model.session = GameSession(resuming: sauvee) }
                    }
                } : nil,
                onManuel: { withAnimation { model.manuel = true } },
                onArchives: Archives.shared.liste().isEmpty ? nil : {
                    withAnimation { model.bibliotheque = true }
                })
            } else {
                // Le temps que la partie enregistrée soit relue.
                //
                // Ce cas manquait, et son absence donnait un écran **noir** :
                // aucune branche ne s'appliquait, il ne restait que le fond.
                // Un écran vide ne dit pas qu'il attend — il dit que
                // l'application est morte.
                ProgressView().tint(Palette.dim)
            }
        }
        .task {
            guard !model.repriseTentee else { return }
            // Posé par `defer` : quoi qu'il arrive à la lecture, on sort de
            // l'écran d'attente. Sans cela, une reprise qui n'aboutit pas
            // laisse l'application sur son fond, sans rien, pour toujours.
            defer { model.repriseTentee = true }
            if let sauvee = GameStore.shared.load() {
                model.session = GameSession(resuming: sauvee)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Plateau") {
    GameScreen(session: GameSession(players: [
        Player(id: 0, name: "Bleu"),
        Player(id: 1, name: "Rouge", kind: .machine(niveau: 0.65, style: .forte)),
    ], seed: 7), onQuit: {})
}
