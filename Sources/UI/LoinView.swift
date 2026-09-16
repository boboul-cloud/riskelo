//
//  LoinView.swift
//  Riskelo
//
//  Se trouver quand on n'est pas dans la même pièce.
//
//  Six lettres, et rien d'autre. Pas de compte à créer, pas de mot de passe
//  à retenir, pas de liste d'amis à constituer avant de pouvoir jouer une
//  fois : celui qui ouvre reçoit un code, il l'envoie comme il envoie tout le
//  reste — WhatsApp, SMS, Messages — et l'autre le tape.
//
//  Le code se **dicte** autant qu'il se colle : consonne, voyelle, consonne,
//  voyelle, consonne, voyelle. « MARENO » se répète au téléphone à une
//  grand-mère qui ne trouve pas le lien ; « X7KQ2V » se fait répéter trois
//  fois et se tape de travers.
//
//  Et le lien, quand il passe, dispense même de le taper : la page ouvre le
//  jeu sur le bon salon. C'est le chemin ordinaire ; le code écrit en gros
//  est ce qui reste quand le chemin ordinaire échoue — et il échoue, chez
//  quelqu'un, un jour.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct LoinView: View {

    let plateau: Boards
    let regles: Rules
    /// Un code arrivé par un lien : on n'a alors rien à choisir ni à taper.
    var codeRecu: String?
    var onReady: (GameSession) -> Void
    var onCancel: () -> Void
    var onReglages: () -> Void = { }

    @State private var relais = Relais()
    @State private var noms: [Pair: String] = [:]
    @State private var joueurs = 2
    @State private var saisie = ""
    @State private var lancee = false
    @State private var desaccord = false
    @State private var silence = false
    @State private var copie = false

    private var attendus: Int { joueurs - 1 }
    private var manquants: Int { max(0, attendus - relais.relies.count) }

    var body: some View {
        ZStack {
            Palette.sea.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "globe.europe.africa.fill")
                        .font(.system(size: 40)).foregroundStyle(Palette.camp(2))
                    Text("Jouer au loin")
                        .font(.title3.weight(.semibold)).foregroundStyle(Palette.ink)

                    contenu

                    Button("Annuler") { relais.arreter(); onCancel() }
                        .buttonStyle(.bordered).tint(Palette.dim)
                }
                .frame(maxWidth: 420)
                .padding(26)
            }
        }
        .preferredColorScheme(.dark)
        #if os(iOS)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        #endif
        .onAppear {
            // Arrivé par un lien : il n'y a rien à demander à personne.
            if let codeRecu, case .aLArret = relais.etat {
                preparer()
                relais.rejoindre(code: codeRecu)
            }
        }
        .onDisappear { if !lancee { relais.arreter() } }
    }

    // MARK: - Ce que l'écran montre

    @ViewBuilder private var contenu: some View {
        switch relais.etat {
        case .aLArret, .refuse:
            if case let .refuse(panne) = relais.etat { leRefus(panne) }
            ouvrirOuRejoindre

        case .ouvre:
            ProgressView().tint(Palette.dim)
            Text("On prépare le salon…").font(.subheadline).foregroundStyle(Palette.dim)

        case let .entre(code):
            ProgressView().tint(Palette.camp(1))
            Text("On entre dans la partie \(code)…")
                .font(.headline).foregroundStyle(Palette.ink)

        case let .ouvert(code):
            laTable(code)

        case .relie:
            if relais.jeSuisLHote {
                laTable(relais.code ?? "")
            } else {
                enAttente
            }

        case .rompue:
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34)).foregroundStyle(Palette.camp(3))
            Text("La liaison est tombée").font(.headline).foregroundStyle(Palette.ink)
            ProgressView().tint(Palette.dim)
            Text("""
                 On y retourne. Si c'est un tunnel ou un ascenseur, cela se \
                 rétablit tout seul — gardez l'écran allumé.
                 """)
                .font(.caption).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Ouvrir, ou rejoindre

    @ViewBuilder private var ouvrirOuRejoindre: some View {
        Text("""
             Chacun chez soi, sur son propre réseau. Un code à six lettres \
             suffit — ni compte, ni inscription.
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

        bouton("Ouvrir une partie", "plus.circle.fill", Palette.camp(0)) {
            // Rien à dire au serveur du nombre de joueurs attendus : il en
            // accepte quatre et c'est l'hôte qui décide quand lancer. Le fil
            // de la même pièce, lui, doit le savoir — il cesse de s'annoncer
            // quand la table est pleine.
            preparer()
            relais.ouvrir()
        }

        VStack(spacing: 10) {
            Text("OU REJOINDRE AVEC UN CODE").font(.caption.weight(.semibold))
                .foregroundStyle(Palette.dim).kerning(0.6)
            champDuCode
            bouton("Rejoindre", "arrow.right.circle.fill", Palette.camp(1)) {
                preparer()
                relais.rejoindre(code: saisie)
            }
            .disabled(!Relais.estUnCode(saisie))
            .opacity(Relais.estUnCode(saisie) ? 1 : 0.4)
        }
        .padding(.top, 6)

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
            Text("Celui qui ouvre la partie choisit pour tout le monde.")
                .font(.caption2).foregroundStyle(Palette.dim.opacity(0.8))
        }
        .padding(.top, 4)
    }

    private var champDuCode: some View {
        TextField("", text: $saisie, prompt: Text("CODE").foregroundStyle(Palette.dim))
            .font(.system(size: 26, weight: .bold, design: .monospaced))
            .kerning(6)
            .multilineTextAlignment(.center)
            .foregroundStyle(Palette.campVif(0))
            .padding(.vertical, 14)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.characters)
            #endif
            // Nettoyé à la frappe, et non à la validation : celui qui colle
            // « code : mareno » depuis WhatsApp doit voir MARENO apparaître,
            // pas se faire dire que ce n'en est pas un.
            .onChange(of: saisie) { _, brut in
                let propre = Relais.normaliser(brut)
                if propre != brut { saisie = propre }
            }
    }

    // MARK: - La table de celui qui a ouvert

    @ViewBuilder private func laTable(_ code: String) -> some View {
        Text("VOTRE CODE").font(.caption.weight(.semibold))
            .foregroundStyle(Palette.dim).kerning(0.6)
        Text(code)
            .font(.system(size: 34, weight: .bold, design: .monospaced))
            .kerning(8)
            .foregroundStyle(Palette.campVif(0))
            .padding(.vertical, 18).frame(maxWidth: .infinity)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
            // Un code se dicte aussi, et pas seulement au clavier : il faut
            // que l'écran le lise pour quelqu'un qui n'y voit pas.
            .accessibilityLabel(Text(code.map(String.init).joined(separator: " ")))

        if let lien = Relais.lien(pour: code) {
            ShareLink(item: lien,
                      subject: Text("Une partie de Riskelo"),
                      message: Text("Rejoignez-moi : le code est \(code).")) {
                Label("Envoyer l'invitation", systemImage: "square.and.arrow.up")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(Palette.camp(0))

            Button {
                copierLeCode(code)
            } label: {
                Label(copie ? "Code copié" : "Copier le code",
                      systemImage: copie ? "checkmark" : "doc.on.doc")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
            }
            .buttonStyle(.bordered).tint(copie ? Palette.held : Palette.dim)

            Text("""
                 WhatsApp, SMS, Messages — le lien ouvre le jeu directement. \
                 Le code écrit au-dessus marche aussi, s'il faut le dicter.
                 """)
                .font(.caption2).foregroundStyle(Palette.dim.opacity(0.85))
                .multilineTextAlignment(.center)
        }

        Divider().overlay(Palette.dim.opacity(0.3)).padding(.vertical, 4)

        Text(manquants > 0
             ? "En attente de \(manquants) joueur\(manquants > 1 ? "s" : "")…"
             : "Tout le monde est là.")
            .font(.headline).foregroundStyle(manquants > 0 ? Palette.ink : Palette.held)
        if manquants > 0 { ProgressView().tint(Palette.dim) }

        VStack(spacing: 6) {
            ligne(Pseudo.actuel ?? "Vous", camp: 0)
            ForEach(Array(relais.relies.enumerated()), id: \.element) { i, pair in
                ligne(noms[pair] ?? pair.nom, camp: i + 1)
            }
        }

        if manquants == 0 {
            bouton("Commencer", "flag.fill", Palette.held) { lancer() }
        }
    }

    // MARK: - Ce que voit celui qui a rejoint

    @ViewBuilder private var enAttente: some View {
        if desaccord {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34)).foregroundStyle(Palette.lostVif)
            Text("Versions différentes").font(.headline).foregroundStyle(Palette.lostVif)
            Text("""
                 L'autre appareil a envoyé une partie que celui-ci ne sait pas \
                 lire. Installez la même version de Riskelo des deux côtés.
                 """)
                .font(.footnote).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)
        } else {
            ProgressView().tint(Palette.held)
            Text("Vous êtes dans la partie").font(.headline).foregroundStyle(Palette.held)
            VStack(spacing: 6) {
                ForEach(Array(relais.relies.enumerated()), id: \.element) { _, pair in
                    ligne(noms[pair] ?? pair.nom, camp: 0)
                }
            }
            if silence {
                Text("Rien n'est venu.").font(.subheadline).foregroundStyle(Palette.lostVif)
                Text("""
                     La liaison est bonne : c'est le lancement qui n'arrive pas. \
                     Celui qui a ouvert la partie doit toucher « Commencer ».
                     """)
                    .font(.caption).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
            } else {
                Text("En attente du lancement…")
                    .font(.caption).foregroundStyle(Palette.dim)
                    .task {
                        try? await Task.sleep(for: .seconds(20))
                        silence = true
                    }
            }
        }
    }

    // MARK: - Quand cela n'a pas marché

    @ViewBuilder private func leRefus(_ panne: Relais.Panne) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icone(panne))
                .font(.system(size: 32)).foregroundStyle(Palette.lostVif)
            Text(titre(panne)).font(.headline).foregroundStyle(Palette.lostVif)
            Text(.init(remede(panne)))
                .font(.footnote).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 6)
    }

    private func icone(_ panne: Relais.Panne) -> String {
        switch panne {
        case .codeInconnu:    return "questionmark.circle.fill"
        case .salonPlein:     return "person.3.fill"
        case .dejaCommencee:  return "flag.fill"
        case .sansReponse:    return "wifi.slash"
        case .serveur:        return "exclamationmark.triangle.fill"
        }
    }

    private func titre(_ panne: Relais.Panne) -> String {
        switch panne {
        case .codeInconnu:    return "Ce code ne mène à rien"
        case .salonPlein:     return "La partie est complète"
        case .dejaCommencee:  return "La partie a déjà commencé"
        case .sansReponse:    return "Rien n'a répondu"
        case .serveur:        return "Le serveur a refusé"
        }
    }

    /// Ce qu'il faut faire, et non ce qui s'est passé.
    ///
    /// C'est la règle de tous les écrans de panne du jeu : « erreur réseau »
    /// n'a jamais fait revenir personne. Chaque cause a son geste, et chaque
    /// geste est dit à la place de la cause.
    private func remede(_ panne: Relais.Panne) -> String {
        switch panne {
        case .codeInconnu:
            return "Un code vit le temps d'une partie. Vérifiez les six lettres, "
                 + "ou demandez-en un nouveau à celui qui a ouvert."
        case .salonPlein:
            return "Quatre joueurs au plus, un appareil chacun. Il faudra attendre "
                 + "la partie suivante."
        case .dejaCommencee:
            return "On ne se glisse pas dans une partie en cours. Demandez qu'on "
                 + "en rouvre une."
        case .sansReponse:
            return "Vérifiez votre connexion — Wi-Fi ou données mobiles. "
                 + "Si tout va bien de votre côté, c'est le serveur des parties "
                 + "qui ne répond pas : la même pièce, elle, ne dépend de personne."
        case let .serveur(dit):
            let quoi = dit == "dialecte"
                ? "Les deux appareils n'ont pas la même version de Riskelo. "
                + "Mettez-les à jour tous les deux."
                : "Le serveur a répondu « \(dit) »."
            return quoi
        }
    }

    // MARK: - Petites pièces

    private var laPartieQuOnOuvre: String {
        var dits = [plateau.label, regles.mode.label]
        if regles.territoryCards { dits.append("cartes") }
        if regles.objectifs { dits.append("conquêtes personnelles") }
        if regles.dominationOverride == 0 { dits.append("guerre totale") }
        return dits.joined(separator: " · ")
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

    private func bouton(_ titre: LocalizedStringKey, _ icone: String, _ teinte: Color,
                        _ geste: @escaping () -> Void) -> some View {
        Button(action: geste) {
            Label(titre, systemImage: icone)
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent).tint(teinte)
    }

    private func copierLeCode(_ code: String) {
        #if os(iOS)
        UIPasteboard.general.string = code
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #endif
        copie = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copie = false
        }
    }

    // MARK: - Le salon

    private func preparer() {
        MiseEnPlace.preparer(
            relais,
            nomVu: { pair, nom in noms[pair] = nom },
            partieRecue: { etat, rang, numero in
                lancee = true
                onReady(GameSession(fil: relais, heberge: false, game: etat,
                                    monRang: rang, compteur: numero))
            },
            desaccord: { desaccord = true })
    }

    private func lancer() {
        lancee = true
        onReady(MiseEnPlace.lancer(relais, joueurs: joueurs, plateau: plateau,
                                   regles: regles, noms: noms))
    }
}
