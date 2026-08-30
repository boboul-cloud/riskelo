//
//  LobbyView.swift
//  Riskelo
//
//  Se trouver, jusqu'à quatre appareils.
//
//  Un joueur ouvre la table, les autres la rejoignent. Rien à saisir, aucun
//  compte, aucun réseau à configurer : les appareils se voient s'ils sont dans
//  la même pièce.
//
//  Celui qui ouvre choisit le plateau, les règles et le nombre de joueurs, et
//  les envoie avec la partie. Les autres n'ont rien à régler — ce serait
//  autant d'occasions de ne pas être d'accord. C'est lui aussi qui donne son
//  rang à chacun, dans l'ordre d'arrivée.
//

import MultipeerConnectivity
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct LobbyView: View {

    let plateau: Boards
    let regles: Rules
    var onReady: (GameSession) -> Void
    var onCancel: () -> Void

    @State private var link = Link()
    /// Le nom que chaque appareil relié s'est donné. Vide tant qu'il n'a pas
    /// dit bonjour — ou qu'il n'a pas de nom, ce qui revient au même ici.
    @State private var noms: [MCPeerID: String] = [:]
    @State private var joueurs = 2
    @State private var lancee = false
    /// La partie est arrivée, mais dans une langue qu'on ne parle pas.
    @State private var desaccord = false
    /// Relié, et rien n'est venu. Ce n'est pas une panne de réseau — la
    /// liaison est bonne — et il faut le dire, sinon on attend sans fin.
    @State private var silence = false
    /// On cherche, et l'on ne trouve rien. Encore un écran qui tournait sans
    /// fin en laissant croire que c'était normal.
    @State private var rienEnVue = false

    private var attendus: Int { joueurs - 1 }
    private var manquants: Int { max(0, attendus - link.relies.count) }

    var body: some View {
        ZStack {
            Palette.sea.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 42)).foregroundStyle(Palette.camp(0))
                Text("Jouer à plusieurs appareils")
                    .font(.title3.weight(.semibold)).foregroundStyle(Palette.ink)

                contenu
                Spacer()
                Button("Annuler") { link.arreter(); onCancel() }
                    .buttonStyle(.bordered).tint(Palette.dim)
            }
            .frame(maxWidth: 420)
            .padding(26)
        }
        .preferredColorScheme(.dark)
        // L'écran ne doit pas s'éteindre pendant qu'on va chercher l'autre
        // appareil : une application endormie n'annonce plus sa table.
        #if os(iOS)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        #endif
        .onDisappear { if !lancee { link.arreter() } }
    }

    @ViewBuilder private var contenu: some View {
        switch link.state {
        case .aLArret:
            Text("Les appareils doivent être proches. Ni compte ni réseau : "
                 + "le Bluetooth ou le Wi-Fi suffisent.")
                .font(.footnote).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("COMBIEN DE JOUEURS").font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.dim).kerning(0.6)
                Picker("", selection: $joueurs) {
                    ForEach(2...4, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Un appareil par joueur.")
                    .font(.caption2).foregroundStyle(Palette.dim)
            }

            bouton("Ouvrir la table", "plus.circle.fill", Palette.camp(0)) {
                preparer()
                link.attendus = attendus
                link.ouvrir()
            }
            bouton("Rejoindre une table", "magnifyingglass", Palette.camp(1)) {
                preparer(); link.chercher()
            }

        case .ouvert:
            tableDeLHote

                case .cherche:
            if link.trouves.isEmpty {
                ProgressView().tint(Palette.dim)
                Text("Recherche des tables ouvertes…")
                    .font(.subheadline).foregroundStyle(Palette.dim)
                if rienEnVue {
                    Text("Aucune table en vue.")
                        .font(.headline).foregroundStyle(Palette.lostVif)
                    VStack(alignment: .leading, spacing: 6) {
                        cause("Le **Wi-Fi doit rester actif**. Coupez-le depuis le "
                              + "centre de contrôle si besoin — jamais depuis les "
                              + "Réglages, qui éteignent la radio et suppriment "
                              + "toute découverte.")
                        cause("Sur l'autre appareil : « Ouvrir la table », et laissez "
                              + "son écran allumé.")
                        cause("Réglages → Confidentialité et sécurité → Réseau local : "
                              + "Riskelo activé, sur les deux.")
                    }
                    .font(.caption).foregroundStyle(Palette.dim)
                } else {
                    Color.clear.frame(height: 1).task {
                        try? await Task.sleep(for: .seconds(20))
                        rienEnVue = true
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(link.trouves, id: \.self) { pair in
                        Button { link.rejoindre(pair) } label: {
                            Label(pair.displayName, systemImage: "iphone")
                                .font(.headline)
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                        }
                        .buttonStyle(.borderedProminent).tint(Palette.camp(1))
                    }
                }
            }

        case .invite(let nom):
            ProgressView().tint(Palette.camp(1))
            Text("Connexion à \(nom)…").font(.headline).foregroundStyle(Palette.ink)
            Text("Si un appareil demande l'autorisation d'utiliser le réseau local, "
                 + "acceptez-la : sans elle, la liaison ne peut pas s'établir.")
                .font(.caption).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)

        case .refuse(let nom):
            // La panne la plus fréquente, et la plus muette : l'autorisation
            // « réseau local » se refuse une fois et ne se redemande jamais.
            // Le système ne dit rien, l'invitation expire sans bruit, et l'on
            // reste sur la liste des appareils à se demander si l'appui a été
            // pris. Il faut donc nommer la cause et dire où la corriger.
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34)).foregroundStyle(Palette.lostVif)
            Text("La liaison n'a pas pu s'établir")
                .font(.headline).foregroundStyle(Palette.lostVif)
            Text(nom.isEmpty
                 ? "Le système a refusé d'ouvrir le réseau local."
                 : "\(nom) n'a pas répondu.")
                .font(.subheadline).foregroundStyle(Palette.ink)
            VStack(alignment: .leading, spacing: 7) {
                cause("**Coupez le Wi-Fi depuis le centre de contrôle** (le bouton, "
                      + "pas les Réglages) sur les deux appareils. Ils se relient "
                      + "alors directement, sans passer par la box — et beaucoup de "
                      + "box interdisent à deux appareils de se parler entre eux.")
                cause("Riskelo doit être **à l'écran** sur l'autre appareil. En "
                      + "arrière-plan, ou l'écran verrouillé, il cesse de répondre.")
                cause("Réglages → Confidentialité et sécurité → Réseau local : "
                      + "Riskelo activé, sur les deux.")
                cause("Un VPN ou le relais privé iCloud coupe la liaison directe : "
                      + "désactivez-les le temps de la partie.")
            }
            .font(.caption).foregroundStyle(Palette.dim)
            bouton("Réessayer", "arrow.clockwise", Palette.camp(0)) { link.arreter() }

        case .relie(let nom):
            // `case .ouvert, .relie where ...` ne veut pas dire ce qu'il a
            // l'air de dire : le `where` ne s'applique qu'au second motif.
            // On sépare, pour que le code se lise comme il se comporte.
            if link.jeSuisLHote {
                tableDeLHote
            } else {
                enAttente(de: nom)
            }

        case .perdu(let nom):
            Image(systemName: "wifi.slash")
                .font(.system(size: 34)).foregroundStyle(Palette.lostVif)
            Text("Liaison perdue avec \(nom).")
                .font(.subheadline).foregroundStyle(Palette.lostVif)
            bouton("Réessayer", "arrow.clockwise", Palette.camp(0)) { link.arreter() }
        }
    }

    /// Ce que voit celui qui a rejoint, entre la liaison et le lancement.
    ///
    /// Deux pannes se cachaient derrière le tourniquet : la partie arrive mais
    /// ne se lit pas — les deux appareils n'ont pas la même version du jeu —
    /// ou rien n'arrive du tout. Dans les deux cas on attendait indéfiniment,
    /// devant un écran qui disait « en attente du lancement » et qui avait
    /// tort : il n'y avait plus rien à attendre.
    @ViewBuilder private func enAttente(de nom: String) -> some View {
        if desaccord {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34)).foregroundStyle(Palette.lostVif)
            Text("Versions différentes").font(.headline).foregroundStyle(Palette.lostVif)
            Text("\(nom) a envoyé une partie que cet appareil ne sait pas lire. "
                 + "Installez la même version de Riskelo sur les deux, puis "
                 + "recommencez.")
                .font(.footnote).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)
        } else {
            ProgressView().tint(Palette.held)
            Text("Relié à \(nom)").font(.headline).foregroundStyle(Palette.held)
            if silence {
                Text("Rien n'est venu de \(nom).")
                    .font(.subheadline).foregroundStyle(Palette.lostVif)
                Text("La liaison est bonne : c'est le lancement qui n'arrive pas. "
                     + "Vérifiez que \(nom) a bien touché « Commencer », et que les "
                     + "deux appareils ont la même version de Riskelo.")
                    .font(.caption).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
            } else {
                Text("En attente du lancement…")
                    .font(.caption).foregroundStyle(Palette.dim)
                    .task {
                        try? await Task.sleep(for: .seconds(15))
                        silence = true
                    }
            }
        }
    }

    /// Ce que voit celui qui a ouvert la table, tant qu'il attend ou qu'il
    /// n'a pas lancé.
    @ViewBuilder private var tableDeLHote: some View {
        VStack(spacing: 12) {
            Text(manquants > 0
                 ? "En attente de \(manquants) joueur\(manquants > 1 ? "s" : "")…"
                 : "Tout le monde est là.")
                .font(.headline).foregroundStyle(manquants > 0 ? Palette.ink : Palette.held)
            if manquants > 0 {
                ProgressView().tint(Palette.dim)
                if rienEnVue {
                    Text("Personne ne s'est présenté. Le Wi-Fi doit être allumé des "
                         + "deux côtés — c'est lui qui porte la liaison, même sans "
                         + "réseau commun — et Riskelo autorisé au réseau local.")
                        .font(.caption).foregroundStyle(Palette.dim)
                        .multilineTextAlignment(.center)
                } else {
                    Color.clear.frame(height: 1).task {
                        try? await Task.sleep(for: .seconds(25))
                        rienEnVue = true
                    }
                }
            }

            VStack(spacing: 6) {
                ligne(Pseudo.actuel ?? "Vous", camp: 0)
                ForEach(Array(link.relies.enumerated()), id: \.element) { i, pair in
                    ligne(noms[pair] ?? pair.displayName, camp: i + 1)
                }
            }
            Text("Sur les autres appareils : « Rejoindre une table ».\n"
                 + "Laissez cet écran allumé jusqu'au lancement.")
                .font(.caption).foregroundStyle(Palette.dim.opacity(0.85))
                .multilineTextAlignment(.center)

            if manquants == 0 {
                bouton("Commencer", "flag.fill", Palette.held) { lancer() }
            }
        }
    }

    /// Une cause possible, dans l'ordre où il vaut mieux les essayer.
    private func cause(_ texte: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Text("•")
            Text(.init(texte)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ligne(_ nom: String, camp: PlayerID) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Palette.camp(camp)).frame(width: 10, height: 10)
            Text(nom).font(.subheadline).foregroundStyle(Palette.ink)
            Spacer()
            Text(Boards.nomDeCamp(camp)).font(.caption).foregroundStyle(Palette.dim)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 10))
    }

    private func bouton(_ titre: String, _ icone: String, _ teinte: Color,
                        _ geste: @escaping () -> Void) -> some View {
        Button(action: geste) {
            Label(titre, systemImage: icone)
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent).tint(teinte)
    }

    /// Qui rejoint attend la partie avant d'afficher quoi que ce soit — sans
    /// cela il verrait une partie factice le temps d'un battement.
    private func preparer() {
        // Chacun dit son nom en arrivant, sans attendre qu'on le lui demande :
        // à quatre appareils, une demande par appareil serait quatre fois
        // l'occasion de se perdre.
        link.onConnected = { _, pair in
            if let data = Message.bonjour(nom: Pseudo.actuel ?? "").data {
                link.envoyer(data, a: pair)
            }
        }
        link.onReceive = { data, pair in
            switch Message.lire(data) {
            case let .message(.bonjour(nom)):
                noms[pair] = nom.isEmpty ? nil : nom

            case let .message(.partie(etat, rang, numero)):
                lancee = true
                onReady(GameSession(link: link, heberge: false, game: etat,
                                    monRang: rang, compteur: numero))

            case .message:
                // Un coup, avant même d'avoir la partie : il n'y a rien à en
                // faire, et surtout ce n'est pas un désaccord. Tout ce qui
                // n'était pas la partie était compté comme tel, et un paquet
                // arrivé une fraction de seconde trop tôt affichait donc
                // « Versions différentes » à deux appareils parfaitement
                // d'accord.
                break

            case .autreDialecte, .illisible:
                desaccord = true
            }
        }
    }

    /// L'hôte crée la partie et donne son rang à chacun, dans l'ordre
    /// d'arrivée. Chaque appareil reçoit le sien, et lui seul.
    private func lancer() {
        link.fermerLaTable()
        // Chaque camp porte le nom de qui le tient, quand il s'en est donné
        // un : « Rouge · Marie ». Le nom part avec l'état, et les quatre
        // appareils voient donc les mêmes joueurs — c'est le seul endroit où
        // cette composition se fait, et le seul moment où l'hôte les connaît
        // tous.
        let camps = (0..<joueurs).map { rang -> Player in
            let camp = Boards.nomDeCamp(rang)
            let choisi = rang == 0 ? Pseudo.actuel
                                   : link.relies.indices.contains(rang - 1)
                                     ? noms[link.relies[rang - 1]] : nil
            return Player(id: rang, name: choisi.map { "\(camp) · \($0)" } ?? camp)
        }
        let partie = GameState.start(board: plateau, players: camps, rules: regles)

        var rangs: [MCPeerID: PlayerID] = [:]
        for (i, pair) in link.relies.enumerated() {
            let rang = i + 1
            rangs[pair] = rang
            if let data = Message.partie(partie, votreRang: rang, numero: 0).data {
                link.envoyer(data, a: pair)
            }
        }
        lancee = true
        onReady(GameSession(link: link, heberge: true, game: partie,
                            monRang: 0, rangs: rangs, compteur: 0))
    }
}
