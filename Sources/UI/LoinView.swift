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

    /// La partie au loin qu'on vient reprendre, une fois son bouton touché :
    /// le rendez-vous gardé sur cet appareil, et la partie qui dormait à côté.
    /// Il n'y a alors ni code à taper, ni réglages à choisir, ni camps à
    /// distribuer — tout cela a été décidé l'autre soir.
    ///
    /// C'est ici que la reprise vit, et non sur l'accueil. Le bouton vert de
    /// l'accueil rendait les deux parties — celle d'ici et celle du loin — sans
    /// dire laquelle, alors que l'une ouvre le plateau et que l'autre ouvre un
    /// salon où il faut attendre quelqu'un. Reprendre une partie au loin est
    /// une façon de jouer au loin : c'est sur cette page-ci qu'on vient la
    /// chercher.
    @State private var reprise: (rendezVous: RendezVous, partie: GameState)?
    /// Les parties au loin qui attendent, relues à l'ouverture de l'écran.
    /// La dernière jouée en tête.
    @State private var enCours: [RendezVous] = []
    /// Celle qu'on s'apprête à abandonner, le temps de le confirmer.
    @State private var aAbandonner: RendezVous?

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
                    Text(reprise == nil ? "Jouer au loin" : "Reprendre la partie")
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
            guard case .aLArret = relais.etat else { return }
            // Une partie au loin laissée en plan ? On le dit avant tout le
            // reste : c'est ce qu'on vient chercher ici neuf fois sur dix.
            enCours = GameStore.shared.partiesAuLoin()
            // On revient sur une partie commencée : celui qui l'héberge
            // rouvre son salon sous l'ancien code — ceux qui reviennent n'ont
            // que celui-là — et les autres y rentrent comme au premier soir.
            if reprise != nil {
                entrerAuRendezVous()
                return
            }
            // Arrivé par un lien : il n'y a rien à demander à personne.
            if let codeRecu {
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
            // Pas de « Ouvrir une partie » sous un rendez-vous manqué : on est
            // venu reprendre celle qui existe, et en ouvrir une neuve d'ici la
            // remplacerait dans le tiroir. Il reste « Réessayer », et
            // « Annuler » qui rend l'accueil.
            if reprise == nil { ouvrirOuRejoindre }

        case .ouvre:
            ProgressView().tint(Palette.dim)
            Text("On prépare le salon…").font(.subheadline).foregroundStyle(Palette.dim)

        case let .entre(code):
            ProgressView().tint(Palette.camp(1))
            Text("On entre dans la partie \(code)…")
                .font(.headline).foregroundStyle(Palette.ink)

        case let .ouvert(code):
            if reprise != nil { laReprise(code) } else { laTable(code) }

        case .relie:
            if relais.jeSuisLHote {
                if reprise != nil { laReprise(relais.code ?? "") } else { laTable(relais.code ?? "") }
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
        // Avant tout le reste : la partie qu'on a laissée en plan. En ouvrir
        // une neuve par-dessus serait le geste le plus coûteux de l'écran, et
        // c'était le premier proposé.
        if !enCours.isEmpty {
            lesPartiesQuiAttendent
            Divider().overlay(Palette.dim.opacity(0.3)).padding(.vertical, 2)
        }

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

    /// Les parties au loin en cours, et de quoi y retourner.
    ///
    /// Elles passent avant « Ouvrir une partie », et ce n'est pas un détail de
    /// mise en page : ouvrir une partie neuve est le geste le plus coûteux de
    /// l'écran quand on venait en reprendre une, et c'était le premier proposé.
    @ViewBuilder private var lesPartiesQuiAttendent: some View {
        VStack(spacing: 10) {
            Text(enCours.count > 1 ? "VOS PARTIES AU LOIN" : "VOTRE PARTIE AU LOIN")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.dim).kerning(0.6)

            ForEach(enCours, id: \.code) { rendezVous in
                laPartieQuiAttend(rendezVous)
            }
        }
        .padding(.vertical, 4)
        .alert("Abandonner cette partie ?", isPresented: Binding(
            get: { aAbandonner != nil },
            set: { if !$0 { aAbandonner = nil } }
        )) {
            Button("Abandonner", role: .destructive) {
                if let code = aAbandonner?.code {
                    GameStore.shared.discard(.auLoin(code: code))
                    enCours = GameStore.shared.partiesAuLoin()
                }
                aAbandonner = nil
            }
            Button("Non, la garder", role: .cancel) { aAbandonner = nil }
        } message: {
            Text("""
                 Elle ne sera plus proposée ici, et l'autre appareil vous \
                 attendra pour rien. La bibliothèque, elle, garde les instants \
                 de cette partie.
                 """)
        }
    }

    /// Une partie qui attend : contre qui, où l'on en est, et son code.
    ///
    /// Le nom d'abord, parce que c'est ce qu'on cherche — « celle avec
    /// Marie » — et le code en dernier : il ne sert qu'à le redonner à
    /// quelqu'un qui l'a perdu.
    @ViewBuilder private func laPartieQuiAttend(_ rendezVous: RendezVous) -> some View {
        HStack(spacing: 12) {
            Button {
                reprendre(rendezVous)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(rendezVous.contre.isEmpty
                             ? dit("Partie à plusieurs")
                             : rendezVous.contre.joined(separator: ", "))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text("tour \(rendezVous.tour)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Palette.dim)
                    }
                    HStack(spacing: 6) {
                        Text(rendezVous.code)
                            .font(.caption.monospaced().weight(.semibold))
                            .foregroundStyle(Palette.campVif(0))
                        Text("·").foregroundStyle(Palette.dim.opacity(0.6))
                        Text(rendezVous.quand, format: .relative(presentation: .named))
                            .font(.caption)
                            .foregroundStyle(Palette.dim)
                        if rendezVous.jHeberge {
                            Text("·").foregroundStyle(Palette.dim.opacity(0.6))
                            // Qui rouvre le salon n'est pas un détail : celui
                            // qui héberge doit venir le premier, et c'est la
                            // question qu'on se pose devant cette ligne.
                            Text("vous l'avez ouverte")
                                .font(.caption).foregroundStyle(Palette.dim)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                aAbandonner = rendezVous
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.dim)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Abandonner cette partie"))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
    }

    /// Retourner à une partie : on charge ce qui dormait, et l'on entre au
    /// rendez-vous.
    private func reprendre(_ rendezVous: RendezVous) {
        guard let partie = GameStore.shared.load(.auLoin(code: rendezVous.code)) else {
            // La partie a disparu sous son rendez-vous : mieux vaut retirer la
            // ligne que de tendre un bouton mort.
            enCours = GameStore.shared.partiesAuLoin()
            return
        }
        reprise = (rendezVous, partie)
        entrerAuRendezVous()
    }

    // MARK: - La table qu'on retrouve    // MARK: - La table qu'on retrouve

    /// Ceux qu'on attend : les appareils de l'autre soir, et eux seuls. Un
    /// curieux qui aurait tapé le code au hasard entre dans le salon sans
    /// entrer dans la partie — il ne compte pas, et ne retient personne.
    private var revenus: [Pair] {
        guard let attendus = reprise?.rendezVous.attendus else { return relais.relies }
        return relais.relies.filter { attendus.contains($0.id) }
    }

    private var manquantsALaReprise: Int {
        guard let rendezVous = reprise?.rendezVous else { return 0 }
        return max(0, rendezVous.rangs.count - revenus.count)
    }

    @ViewBuilder private func laReprise(_ code: String) -> some View {
        if let partie = reprise?.partie {
            Text("Tour \(partie.turn) — la partie vous attend")
                .font(.headline).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
        }

        Text("LE MÊME CODE QUE L'AUTRE SOIR").font(.caption.weight(.semibold))
            .foregroundStyle(Palette.dim).kerning(0.6)
        Text(code)
            .font(.system(size: 34, weight: .bold, design: .monospaced))
            .kerning(8)
            .foregroundStyle(Palette.campVif(0))
            .padding(.vertical, 18).frame(maxWidth: .infinity)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityLabel(Text(code.map(String.init).joined(separator: " ")))

        if manquantsALaReprise > 0, let lien = Relais.lien(pour: code) {
            // Le même lien qu'au premier soir : l'autre l'a peut-être perdu,
            // et c'est plus court que de lui dicter six lettres au téléphone.
            ShareLink(item: lien,
                      subject: Text("On reprend la partie ?"),
                      message: Text("Notre partie de Riskelo nous attend : le code est \(code).")) {
                Label("Le rappeler", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.bordered).tint(Palette.dim)
        }

        Divider().overlay(Palette.dim.opacity(0.3)).padding(.vertical, 4)

        Text(manquantsALaReprise > 0
             ? "En attente de \(manquantsALaReprise) joueur\(manquantsALaReprise > 1 ? "s" : "")…"
             : "Tout le monde est revenu.")
            .font(.headline)
            .foregroundStyle(manquantsALaReprise > 0 ? Palette.ink : Palette.held)
        if manquantsALaReprise > 0 {
            ProgressView().tint(Palette.dim)
            Text("""
                 Il faut être là tous les deux en même temps : une question se \
                 répond sablier en main. Le code, lui, reste bon une semaine.
                 """)
                .font(.caption).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)
        }

        if manquantsALaReprise == 0 {
            bouton("Reprendre la partie", "play.fill", Palette.held) { lancerLaReprise() }
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
            Text(reprise == nil ? "Vous êtes dans la partie" : "Vous y êtes")
                .font(.headline).foregroundStyle(Palette.held)
            VStack(spacing: 6) {
                ForEach(Array(relais.relies.enumerated()), id: \.element) { _, pair in
                    ligne(noms[pair] ?? pair.nom, camp: 0)
                }
            }
            if silence {
                Text("Rien n'est venu.").font(.subheadline).foregroundStyle(Palette.lostVif)
                Text(reprise == nil
                     ? """
                       La liaison est bonne : c'est le lancement qui n'arrive pas. \
                       Celui qui a ouvert la partie doit toucher « Commencer ».
                       """
                     : """
                       La liaison est bonne : c'est la partie qui n'arrive pas. \
                       Celui qui l'a ouverte doit être là lui aussi, et toucher \
                       « Reprendre la partie ».
                       """)
                    .font(.caption).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
            } else {
                Text(reprise == nil ? "En attente du lancement…"
                                    : "En attente de celui qui a ouvert la partie…")
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
        // Celui qui revient et trouve porte close n'a pas fait d'erreur :
        // l'autre n'est simplement pas encore là. Lui dire « vérifiez les six
        // lettres » l'enverrait chercher une faute qu'il n'a pas commise —
        // d'autant qu'il n'a rien tapé du tout.
        let enAvance = reprise != nil && panne == .codeInconnu
        VStack(spacing: 10) {
            Image(systemName: enAvance ? "clock.fill" : icone(panne))
                .font(.system(size: 32))
                .foregroundStyle(enAvance ? Palette.camp(3) : Palette.lostVif)
            Text(enAvance ? dit("La partie n'est pas encore rouverte") : titre(panne))
                .font(.headline)
                .foregroundStyle(enAvance ? Palette.ink : Palette.lostVif)
            Text(.init(enAvance
                       ? dit("""
                             Celui qui a ouvert la partie doit venir le premier : \
                             c'est son appareil qui la tient. Réessayez quand il \
                             sera là.
                             """)
                       : remede(panne)))
                .font(.footnote).foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 6)

        if reprise != nil, panne != .salonRepris {
            bouton("Réessayer", "arrow.clockwise", Palette.camp(1)) { entrerAuRendezVous() }
        }
    }

    private func icone(_ panne: Relais.Panne) -> String {
        switch panne {
        case .codeInconnu:    return "questionmark.circle.fill"
        case .salonPlein:     return "person.3.fill"
        case .dejaCommencee:  return "flag.fill"
        case .salonRepris:    return "person.crop.circle.badge.xmark"
        case .sansReponse:    return "wifi.slash"
        case .serveur:        return "exclamationmark.triangle.fill"
        }
    }

    private func titre(_ panne: Relais.Panne) -> String {
        switch panne {
        case .codeInconnu:    return dit("Ce code ne mène à rien")
        case .salonPlein:     return dit("La partie est complète")
        case .dejaCommencee:  return dit("La partie a déjà commencé")
        case .salonRepris:    return dit("Ce code n'est plus le vôtre")
        case .sansReponse:    return dit("Rien n'a répondu")
        case .serveur:        return dit("Le serveur a refusé")
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
            return """
                   Un code vit le temps d'une partie. Vérifiez les six lettres, \
                   ou demandez-en un nouveau à celui qui a ouvert.
                   """
        case .salonPlein:
            return """
                   Quatre joueurs au plus, un appareil chacun. Il faudra attendre \
                   la partie suivante.
                   """
        case .dejaCommencee:
            return """
                   On ne se glisse pas dans une partie en cours. Demandez qu'on \
                   en rouvre une.
                   """
        case .salonRepris:
            return """
                   Votre partie a attendu plus d'une semaine, et le code est \
                   reparti à quelqu'un d'autre. La partie, elle, est dans la \
                   bibliothèque : on peut la rouvrir, mais il faudra un \
                   nouveau code.
                   """
        case .sansReponse:
            return """
                   Vérifiez votre connexion — Wi-Fi ou données mobiles. \
                   Si tout va bien de votre côté, c'est le serveur des parties \
                   qui ne répond pas : la même pièce, elle, ne dépend de personne.
                   """
        case let .serveur(dit):
            if dit == "serveur trop ancien" {
                return """
                       Le serveur des parties n'a pas encore été mis à jour : il ne \
                       sait pas rendre à celui qui a ouvert la partie le code qu'il \
                       avait. C'est une chose à faire une fois, du côté du serveur, \
                       et non sur cet appareil.
                       """
            }
            let quoi = dit == "dialecte"
                ? """
                  Les deux appareils n'ont pas la même version de Riskelo. \
                  Mettez-les à jour tous les deux.
                  """
                : "Le serveur a répondu « \(dit) »."
            return quoi
        }
    }

    // MARK: - Petites pièces

    private var laPartieQuOnOuvre: String {
        var dits = [plateau.label, regles.mode.label]
        if regles.territoryCards { dits.append(dit("cartes")) }
        if regles.objectifs { dits.append(dit("conquêtes personnelles")) }
        if regles.dominationOverride == 0 { dits.append(dit("guerre totale")) }
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

    /// Revenir à la table de l'autre soir.
    ///
    /// Une fonction et non deux lignes dans `onAppear` : on y revient par le
    /// bouton « Réessayer », et c'est le cas le plus courant de tous. Celui
    /// qui héberge doit être là le premier — c'est lui qui rouvre le salon —
    /// et l'autre tombe donc sur une porte close s'il arrive en avance.
    private func entrerAuRendezVous() {
        guard let reprise else { return }
        preparer()
        if reprise.rendezVous.jHeberge {
            relais.reprendreLeSalon(code: reprise.rendezVous.code)
        } else {
            relais.rejoindre(code: reprise.rendezVous.code)
        }
    }

    /// L'hôte redonne la partie à chacun, et l'on repart d'où l'on en était.
    private func lancerLaReprise() {
        guard let reprise else { return }
        var rangs: [Pair: PlayerID] = [:]
        for pair in revenus {
            guard let rang = reprise.rendezVous.rangs[pair.id] else { continue }
            rangs[pair] = rang
        }
        lancee = true
        onReady(MiseEnPlace.reprendre(relais, partie: reprise.partie, rangs: rangs,
                                      compteur: reprise.rendezVous.compteur,
                                      partieID: reprise.rendezVous.partieID))
    }

    private func lancer() {
        lancee = true
        onReady(MiseEnPlace.lancer(relais, joueurs: joueurs, plateau: plateau,
                                   regles: regles, noms: noms))
    }
}
