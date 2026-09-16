//
//  BandeauDeLiaison.swift
//  Riskelo
//
//  Ce qui se dit quand le fil lâche au milieu d'une partie.
//
//  C'est un écran de trois lignes, et il compte plus que la plupart des
//  autres. Une liaison qui tombe sans rien dire est la panne la plus
//  désagréable du jeu en ligne : l'adversaire ne joue plus, et l'on ne sait
//  pas s'il réfléchit, s'il est parti, ou si c'est l'application qui est
//  bloquée. On reste devant, à attendre quelque chose qui n'arrivera peut-être
//  jamais, et l'on finit par tout quitter — y compris quand il restait dix
//  secondes avant que tout revienne.
//
//  D'où les deux bandeaux, et la différence entre les deux. L'ambre dit
//  « attendez » et montre le temps qui passe, parce qu'une attente sans durée
//  affichée paraît trois fois plus longue qu'elle n'est. Le rouge dit « c'est
//  fini », et il ne tourne pas : rien ne reviendra.
//

import SwiftUI

struct BandeauDeLiaison: View {

    let session: GameSession
    /// Le temps écoulé depuis la coupure, rafraîchi chaque seconde.
    @State private var depuis: Int = 0

    /// Au bout de combien de temps le fil du loin renonce. La même valeur que
    /// dans `Relais` et dans le serveur — les trois doivent s'accorder, sinon
    /// le bandeau promet un retour que plus personne n'attend.
    private static let grace = 120

    var body: some View {
        switch session.liaison {
        case .tenue:
            EmptyView()

        case let .rompue(debut):
            bandeau(Palette.camp(3), "wifi.exclamationmark") {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Liaison perdue — on y retourne")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text(restant > 0
                         ? "La partie reprendra toute seule. Encore \(restant) s."
                         : "Encore un instant…")
                        .font(.caption2).foregroundStyle(Palette.dim)
                }
                Spacer(minLength: 0)
                ProgressView().tint(Palette.camp(3)).scaleEffect(0.8)
            }
            // Un compteur qui n'avance pas laisse croire que rien ne se
            // passe. Celui-ci se remet en marche à chaque coupure : la date
            // de départ est dans l'état, il n'y a rien à garder ici.
            .task(id: debut) {
                depuis = 0
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    depuis = Int(Date().timeIntervalSince(debut))
                }
            }

        case let .perdue(qui):
            bandeau(Palette.lostVif, "wifi.slash") {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(qui.prefix(1).uppercased())\(qui.dropFirst()) n'est plus là")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text("La partie est rangée : vous la retrouverez à l'accueil.")
                        .font(.caption2).foregroundStyle(Palette.dim)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var restant: Int {
        max(0, BandeauDeLiaison.grace - depuis)
    }

    private func bandeau<Contenu: View>(_ teinte: Color, _ icone: String,
                                        @ViewBuilder _ contenu: () -> Contenu) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icone).font(.system(size: 17)).foregroundStyle(teinte)
            contenu()
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(teinte.opacity(0.8)).frame(height: 1.5)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
