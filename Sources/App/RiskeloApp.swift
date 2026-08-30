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
    /// La mise en place d'une partie à deux appareils, quand elle est ouverte.
    var salon: (regles: Rules, plateau: Boards)?
    var bibliotheque = false
    /// Le mode d'emploi, ouvert depuis l'accueil.
    var manuel = false
    /// Les réglages, ouverts depuis l'accueil. Ils étaient l'accueil ; ils
    /// n'en sont plus qu'une porte.
    var reglages = false
    /// L'ouverture — les deux camps qui se rejoignent — ne se joue qu'une
    /// fois par lancement.
    var ouvertureJouee = false
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
                        model.reglages = false
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
                              withAnimation {
                                  model.salon = nil
                                  model.reglages = false
                                  model.session = partie
                              }
                          },
                          // Renoncer à la table rend les réglages tels qu'on
                          // les avait laissés, et non l'accueil : on venait
                          // d'y choisir un plateau et un mode.
                          onCancel: { withAnimation { model.salon = nil } })
            } else if model.reglages {
                SetupView(onStart: { joueurs, regles, plateau in
                    withAnimation {
                        model.reglages = false
                        model.session = GameSession(players: joueurs, rules: regles, board: plateau)
                    }
                }, onNetwork: { regles, plateau in
                    withAnimation { model.salon = (regles, plateau) }
                },
                onManuel: { withAnimation { model.manuel = true } },
                onArchives: Archives.shared.liste().isEmpty ? nil : {
                    withAnimation { model.bibliotheque = true }
                },
                onRetour: { withAnimation { model.reglages = false } })
            } else {
                AccueilView(
                    onPartieRapide: {
                        depuisAccueil {
                            model.session = GameSession(players: PartieRapide.joueurs(),
                                                        rules: PartieRapide.regles(),
                                                        board: PartieRapide.plateau)
                        }
                    },
                    onReglages: { depuisAccueil { model.reglages = true } },
                    // L'application reprenait la partie enregistrée d'elle-même
                    // au lancement. Elle ne le fait plus : un accueil qu'on ne
                    // voit jamais n'est pas un accueil. La reprise est le
                    // premier bouton, et le seul en vert.
                    onResume: GameStore.shared.hasSavedGame ? {
                        if let sauvee = GameStore.shared.load() {
                            depuisAccueil { model.session = GameSession(resuming: sauvee) }
                        }
                    } : nil,
                    onManuel: { depuisAccueil { model.manuel = true } },
                    onArchives: Archives.shared.liste().isEmpty ? nil : {
                        depuisAccueil { model.bibliotheque = true }
                    },
                    anime: !model.ouvertureJouee)
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Quitter l'accueil. On note au passage que l'ouverture a été vue : sans
    /// cela, les deux camps se rejoindraient à nouveau à chaque retour de
    /// partie, et ce qui charme au lancement devient un péage.
    private func depuisAccueil(_ geste: () -> Void) {
        model.ouvertureJouee = true
        withAnimation { geste() }
    }
}

#Preview("Plateau") {
    GameScreen(session: GameSession(players: [
        Player(id: 0, name: "Bleu"),
        Player(id: 1, name: "Rouge", kind: .machine(niveau: 0.65, style: .forte)),
    ], seed: 7), onQuit: {})
}
