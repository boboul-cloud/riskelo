//
//  PlusieursView.swift
//  Riskelo
//
//  « Jouer à plusieurs » — mais où ?
//
//  Il y a trois façons de relier des appareils, et elles ne se valent pas :
//  elles ont chacune un prix et chacune une portée. Cet écran les pose côte à
//  côte avec ce qu'elles coûtent vraiment, au lieu de les cacher derrière un
//  mot unique où le joueur découvrirait la contrainte trop tard.
//
//  L'ordre n'est pas neutre. La même pièce d'abord : elle ne dépend de
//  personne, ni serveur ni compte, et c'est la seule dont on soit sûr qu'elle
//  marchera encore dans dix ans. Le code ensuite : il porte loin et ne
//  demande rien. Game Center en dernier : il donne des adversaires qu'on n'a
//  pas, et réclame un compte pour cela.
//

import SwiftUI

struct PlusieursView: View {

    let plateau: Boards
    let regles: Rules
    /// Un code arrivé par un lien. On saute alors le choix : quelqu'un
    /// attend, et lui demander par quel chemin serait une question de trop.
    var codeRecu: String?
    var onReady: (GameSession) -> Void
    var onCancel: () -> Void
    var onReglages: () -> Void = { }

    enum Chemin { case memePiece, auLoin, gameCenter }
    @State private var chemin: Chemin?

    var body: some View {
        Group {
            switch chemin {
            case .memePiece:
                LobbyView(plateau: plateau, regles: regles,
                          onReady: onReady,
                          onCancel: { chemin = nil },
                          onReglages: onReglages)

            case .auLoin:
                LoinView(plateau: plateau, regles: regles, codeRecu: codeRecu,
                         onReady: onReady,
                         onCancel: { chemin = nil },
                         onReglages: onReglages)

            case .gameCenter:
                #if canImport(GameKit)
                AreneView(plateau: plateau, regles: regles,
                          onReady: onReady,
                          onCancel: { chemin = nil },
                          onReglages: onReglages)
                #else
                choix
                #endif

            case nil:
                choix
            }
        }
        .onAppear {
            // Arrivé par un lien : droit au but.
            if codeRecu != nil, chemin == nil { chemin = .auLoin }
        }
    }

    // MARK: - Le choix

    private var choix: some View {
        ZStack {
            Palette.sea.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 40)).foregroundStyle(Palette.camp(4))
                    Text("Jouer à plusieurs")
                        .font(.title3.weight(.semibold)).foregroundStyle(Palette.ink)
                    Text("Jusqu'à quatre joueurs, un appareil chacun.")
                        .font(.footnote).foregroundStyle(Palette.dim)

                    porte("Dans la même pièce",
                          "iphone.gen3.radiowaves.left.and.right",
                          Palette.camp(0),
                          """
                          Les appareils se trouvent tout seuls. Ni compte, ni code, \
                          ni serveur — cela marche même dans un train.
                          """) {
                        chemin = .memePiece
                    }

                    porte("Au loin, avec un code",
                          "globe.europe.africa.fill",
                          Palette.camp(2),
                          """
                          Six lettres à envoyer par WhatsApp ou par SMS. \
                          Chacun chez soi, et rien à créer.
                          """) {
                        chemin = .auLoin
                    }

                    #if canImport(GameKit)
                    porte("Par Game Center",
                          "person.2.wave.2.fill",
                          Palette.camp(3),
                          """
                          Vos amis Game Center, ou un adversaire au hasard. \
                          Demande un compte Apple, et ne se reprend pas \
                          après une coupure.
                          """) {
                        chemin = .gameCenter
                    }
                    #endif

                    Button("Annuler", action: onCancel)
                        .buttonStyle(.bordered).tint(Palette.dim)
                        .padding(.top, 6)
                }
                .frame(maxWidth: 420)
                .padding(26)
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Une façon de jouer, et ce qu'elle coûte. Les deux ensemble, toujours :
    /// un bouton qui ne dit pas sa contrainte la fait découvrir au pire
    /// moment, quand deux personnes sont déjà installées pour jouer.
    // « dit » est un libellé, non une chaîne quelconque : en String, Text
    // choisissait la surcharge qui ne traduit pas, et les trois portes
    // restaient en français sur un appareil anglais.
    private func porte(_ titre: LocalizedStringKey, _ icone: String, _ teinte: Color,
                       _ dit: LocalizedStringKey, _ geste: @escaping () -> Void) -> some View {
        Button(action: geste) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icone)
                    .font(.system(size: 24)).foregroundStyle(teinte)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(titre).font(.headline).foregroundStyle(Palette.ink)
                    Text(dit).font(.caption).foregroundStyle(Palette.dim)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(teinte.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
