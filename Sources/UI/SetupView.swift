//
//  SetupView.swift
//  Riskelo
//
//  Qui joue, et contre qui.
//
//  Le niveau de la machine n'est pas une difficulté abstraite : c'est sa part
//  de bonnes réponses sur une question moyenne, dans le temps plein. On sait
//  donc exactement ce qu'on affronte — et la simulation a montré que cinq
//  points d'écart de culture suffisent à faire pencher deux parties sur trois.
//

import SwiftUI

struct SetupView: View {

    // Cet écran s'ouvre sur la partie rapide : « Réglages » n'est pas un
    // autre jeu, c'est le même, ouvert. Les valeurs sont donc prises là où
    // l'accueil les prend, et non recopiées ici.
    @State private var count = PartieRapide.camps
    @State private var humains = PartieRapide.humains
    @State private var niveau = PartieRapide.niveau
    @State private var manoeuvre: Bot.Style = PartieRapide.manoeuvre
    /// Zéro retire la règle ; sinon, une bonne réponse sur tant vaut un homme.
    @State private var erudition = PartieRapide.erudition
    @State private var dosage: Rules.Dosage = PartieRapide.dosage
    @State private var plateau: Boards = PartieRapide.plateau
    @State private var cartes = PartieRapide.cartes
    @State private var guerreTotale = PartieRapide.guerreTotale
    @State private var mode: Rules.Mode = PartieRapide.mode
    /// Le son n'est pas une règle du jeu : il vaut pour l'application et se
    /// garde d'une partie à l'autre. D'où les préférences du système plutôt
    /// qu'un état de cette vue.
    @AppStorage(Sons.cle) private var sons = true
    /// Le nom de celui qui tient l'appareil. Comme le son, il vaut pour
    /// l'application et non pour une partie.
    @AppStorage(Pseudo.cle) private var pseudo = ""
    var onStart: ([Player], Rules, Boards) -> Void
    var onNetwork: (Rules, Boards) -> Void = { _, _ in }
    /// Le mode d'emploi complet — il s'ouvre aussi depuis la partie.
    var onManuel: () -> Void = { }
    /// Proposé seulement s'il y a quelque chose sur les rayons.
    var onArchives: (() -> Void)?
    /// Le retour à l'accueil. La reprise d'une partie en cours s'y trouve
    /// désormais : elle n'a rien à faire au milieu des curseurs.
    var onRetour: () -> Void = { }

    var body: some View {
        ZStack {
            Palette.sea.ignoresSafeArea()
            // Le contenu se centre dans la hauteur disponible plutôt que de
            // coller en haut : sur un iPad ou un Mac, il flottait au sommet
            // d'un écran vide. Le défilement ne sert que si l'écran est trop
            // court — un iPhone en paysage.
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 26) {
                        Text(mode == .classique
                             ? "Le dé est remplacé par une question.\nL'attaquant choisit le terrain, le défenseur répond."
                             : "Le dé est remplacé par une question.\nLes deux la reçoivent : le plus sûr, ou le plus vif, l'emporte.")
                            .font(.subheadline).foregroundStyle(Palette.dim)
                            .multilineTextAlignment(.center)
                            .padding(.top, 22)

                        reglage("Mode de jeu") {
                            Picker("", selection: $mode) {
                                ForEach(Rules.Mode.allCases) { m in Text(m.label).tag(m) }
                            }
                            .pickerStyle(.segmented)
                            Text(mode.detail)
                                .font(.caption2).foregroundStyle(Palette.dim)
                            if mode == .faceAFace {
                                Text("Les deux savent : le sablier tranche. Aucun des deux : la "
                                     + "place tient, comme sur une égalité de dés.")
                                    .font(.caption2).foregroundStyle(Palette.dim.opacity(0.8))
                            }
                        }

                        reglage("Plateau") {
                            Picker("", selection: $plateau) {
                                ForEach(Boards.allCases) { p in Text(p.label).tag(p) }
                            }
                            .pickerStyle(.segmented)
                            Text(plateau.detail)
                                .font(.caption2).foregroundStyle(Palette.dim)
                        }

                        reglage("Joueurs") {
                            Picker("", selection: $count) {
                                ForEach(2...4, id: \.self) { Text("\($0)").tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: count) { _, n in humains = min(humains, n) }
                        }

                        reglage("Sur cet appareil") {
                            Picker("", selection: $humains) {
                                ForEach(1...count, id: \.self) {
                                    Text($0 == 1 ? "1 humain" : "\($0) humains").tag($0)
                                }
                            }
                            .pickerStyle(.segmented)
                            if humains > 1 {
                                Text("Chacun son tour : l'appareil se passe avant chaque question.")
                                    .font(.caption2).foregroundStyle(Palette.dim)
                            }
                        }

                        if humains < count {
                            reglage("Stratégie de la machine") {
                                Picker("", selection: $manoeuvre) {
                                    ForEach(Bot.Style.allCases, id: \.self) { st in
                                        Text(st.label).tag(st)
                                    }
                                }
                                .pickerStyle(.segmented)
                                Text(manoeuvre.detail)
                                    .font(.caption2).foregroundStyle(Palette.dim)
                            }

                            reglage("Culture de la machine") {
                                HStack {
                                    Text(libelleNiveau).font(.subheadline.weight(.medium))
                                        .foregroundStyle(Palette.ink)
                                    Spacer()
                                    Text("\(Int(niveau * 100)) % de bonnes réponses")
                                        .font(.caption.monospacedDigit()).foregroundStyle(Palette.dim)
                                }
                                Slider(value: $niveau, in: 0.35...0.90, step: 0.05)
                                    .tint(Palette.camp(1))
                            }
                        }

                        reglage("Questions") {
                            Picker("", selection: $dosage) {
                                ForEach(Rules.Dosage.allCases) { d in
                                    Text(d.label).tag(d)
                                }
                            }
                            .pickerStyle(.segmented)
                            Text(dosage.detail)
                                .font(.caption2).foregroundStyle(Palette.dim)
                        }

                        reglage("Renfort d'érudition") {
                            HStack {
                                Text(erudition == 0 ? "Retiré" : "Un homme de plus")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Palette.ink)
                                Spacer()
                                Text(erudition == 0 ? "—" : "toutes les \(erudition) bonnes réponses")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Palette.dim)
                            }
                            Slider(value: Binding(get: { Double(erudition) },
                                                  set: { erudition = Int($0.rounded()) }),
                                   in: 0...10, step: 1)
                                .tint(Palette.held)
                            Text(mode == .classique
                                 ? "Seul le défenseur répond : ce renfort revient à qui tient sa "
                                   + "place en sachant. Mesuré, il creuse un peu l'écart entre deux "
                                   + "cultures inégales — nettement en dessous de quatre."
                                 : "Les deux répondent : le renfort revient à qui sait, qu'il "
                                   + "attaque ou qu'il défende.")
                                .font(.caption2).foregroundStyle(Palette.dim)
                        }

                        reglage("Règles du jeu") {
                            Toggle(isOn: $cartes) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Cartes de territoire")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Palette.ink)
                                    Text("Une carte par tour où l'on prend une place. "
                                         + "Trois assorties valent des hommes, et le barème monte.")
                                        .font(.caption2).foregroundStyle(Palette.dim)
                                }
                            }
                            .tint(Palette.held)

                            Toggle(isOn: $guerreTotale) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Guerre totale")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Palette.ink)
                                    Text("Il faut tous les territoires, sans exception. "
                                         + "Compter environ deux fois plus de questions.")
                                        .font(.caption2).foregroundStyle(Palette.dim)
                                }
                            }
                            .tint(Palette.lost)
                        }

                        reglage("Vous") {
                            TextField("Sans nom", text: $pseudo)
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .font(.subheadline)
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(Color.white.opacity(0.06), in: Capsule())
                                .overlay(Capsule().stroke(Palette.dim.opacity(0.3), lineWidth: 1))
                                // Borné à la saisie et non à l'affichage : la
                                // bande des camps tient sur une seule ligne, et
                                // un nom à rallonge la ferait défiler pour rien.
                                .onChange(of: pseudo) { _, saisi in
                                    let court = String(saisi.prefix(Pseudo.maximum))
                                    if court != saisi { pseudo = court }
                                }
                            Text("Facultatif. Votre camp se lira « Bleu · "
                                 + "\(Pseudo.actuel ?? "Robert") · moi » — la couleur, votre "
                                 + "nom, et « moi » pour dire que c'est le vôtre. En réseau, "
                                 + "il fait le voyage : les autres vous verront ainsi, et "
                                 + "vous les verrez de même.")
                                .font(.caption2).foregroundStyle(Palette.dim)
                        }

                        reglage("Son") {
                            Toggle(isOn: $sons) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sons du jeu")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Palette.ink)
                                    Text("Une note brève à chaque homme posé, une autre à "
                                         + "l'issue de chaque échange — montante quand il "
                                         + "tourne pour vous, descendante sinon — et "
                                         + "l'ouverture au lancement. Vaut pour toutes les "
                                         + "parties, et non pour celle-ci seule.")
                                        .font(.caption2).foregroundStyle(Palette.dim)
                                }
                            }
                            .tint(Palette.held)
                        }

                        VStack(spacing: 4) {
                            Text(guerreTotale
                                 ? "Victoire à la conquête intégrale des \(plateau.board.map.order.count) territoires"
                                 : "Victoire à \(seuil) territoires sur \(plateau.board.map.order.count)")
                                .font(.footnote).foregroundStyle(Palette.dim)
                            if compensation > 0 {
                                Text("Celui qui ouvre part avec \(compensation) hommes de moins : "
                                     + "ici, la défense l'emporte, et ouvrir se paie.")
                                    .font(.caption2).foregroundStyle(Palette.dim)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        Button { onStart(joueurs, regles, plateau) } label: {
                            Text("Commencer").font(.headline)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent).tint(Palette.camp(0))

                        if let onArchives {
                            Button(action: onArchives) {
                                Label("Parties enregistrées", systemImage: "books.vertical")
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered).tint(Palette.dim)
                        }

                        Button { onNetwork(regles, plateau) } label: {
                            Label("Jouer à plusieurs appareils",
                                  systemImage: "iphone.gen3.radiowaves.left.and.right")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered).tint(Palette.dim)

                        Button(action: onManuel) {
                            Label("Mode d'emploi", systemImage: "book")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered).tint(Palette.dim)

                        // Les textes légaux sont aussi dans le mode d'emploi,
                        // mais personne ne cherche ses conditions d'utilisation
                        // au chapitre quatorze d'un manuel : elles se veulent
                        // là où l'on se demande à quoi l'on s'engage, avant de
                        // commencer. Trois liens, en petit, sous tout le reste.
                        piedDeMentions
                            .padding(.bottom, 30)
                    }
                    .frame(maxWidth: 460)
                    .padding(.horizontal, 22)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
            }
        }
        // La barre est posée en marge de sécurité plutôt qu'en tête du
        // défilement : la page est longue, et un retour qui s'en va dès qu'on
        // descend n'est plus un retour.
        .safeAreaInset(edge: .top, spacing: 0) { entete }
        .preferredColorScheme(.dark)
    }

    private var entete: some View {
        HStack {
            Button(action: onRetour) {
                Label("Accueil", systemImage: "chevron.left")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.plain).foregroundStyle(Palette.dim)
            Spacer(minLength: 12)
        }
        // Le titre par-dessus plutôt qu'entre deux ressorts : il reste centré
        // sur la barre quelle que soit la longueur du bouton de gauche.
        .overlay {
            Text("Réglages").font(.headline).foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Palette.panel)
    }

    /// Confidentialité, conditions, site : les trois adresses publiques, en
    /// bas de l'accueil. Elles sortent de l'application — le système ouvre le
    /// navigateur — et sont donc écrites en gris, comme tout ce qui n'est pas
    /// un coup à jouer.
    private var piedDeMentions: some View {
        HStack(spacing: 9) {
            lien("Confidentialité", Manuel.confidentialiteURL)
            separateur
            lien("Conditions", Manuel.conditionsURL)
            separateur
            lien("Site", Manuel.siteURL)
        }
        .font(.caption)
        .frame(maxWidth: .infinity)
    }

    private var separateur: some View {
        Text("·").font(.caption).foregroundStyle(Palette.dim.opacity(0.45))
    }

    /// `SwiftUI.Link` en toutes lettres : dans ce module, `Link` tout court
    /// désigne le fil entre deux appareils, et c'est lui qui gagne.
    @ViewBuilder private func lien(_ titre: String, _ adresse: String) -> some View {
        if let url = URL(string: adresse) {
            SwiftUI.Link(titre, destination: url)
                .foregroundStyle(Palette.dim)
        }
    }

    private func reglage<C: View>(_ titre: String, @ViewBuilder _ contenu: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(titre.uppercased()).font(.caption.weight(.semibold))
                .foregroundStyle(Palette.dim).kerning(0.6)
            contenu()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var libelleNiveau: String { PartieRapide.niveauDit(niveau) }

    private var seuil: Int {
        Rules().dominationThreshold(territories: plateau.board.map.order.count,
                                    playerCount: count)
    }

    private var compensation: Int { Rules().compensation(playerCount: count) }

    private var regles: Rules {
        PartieRapide.regles(erudition: erudition, dosage: dosage, cartes: cartes,
                            mode: mode, guerreTotale: guerreTotale)
    }

    private var joueurs: [Player] {
        PartieRapide.joueurs(nombre: count, humains: humains,
                             niveau: niveau, manoeuvre: manoeuvre)
    }
}
