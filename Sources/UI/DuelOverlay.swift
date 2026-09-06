//
//  DuelOverlay.swift
//  Riskelo
//
//  Le duel, en plein écran.
//
//  Il prend tout l'écran parce qu'il remplace le lancer de dés : c'est le
//  moment où la partie se décide, et rien d'autre ne doit être lisible à cet
//  instant. Le plateau réapparaît quand la question est réglée.
//

import SwiftUI

struct DuelOverlay: View {

    let session: GameSession

    var body: some View {
        if let stage = session.stage, stage != .announcing {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                contenu(stage)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    .frame(maxWidth: 620)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
                            .fill(Palette.panel)
                            .shadow(color: .black.opacity(0.5), radius: 14, y: -4)
                    )
                    .overlay(alignment: .top) {
                        // La poignée : elle dit que c'est une feuille posée
                        // sur le plateau, et non un écran qui l'a remplacé.
                        Capsule().fill(Palette.dim.opacity(0.5))
                            .frame(width: 34, height: 4).padding(.top, 7)
                    }
                    .frame(maxWidth: .infinity)
                    .couvreLeBas()
            }
            // Aucun voile sur le plateau : c'est tout l'objet de la feuille.
            // On doit voir les hommes tomber pendant qu'on répond.
            .contentShape(Rectangle())
            .onTapGesture { if session.canSkip { session.skipAhead() } }
            .transition(.move(edge: .bottom))
        }
    }

    @ViewBuilder
    private func contenu(_ stage: GameSession.Stage) -> some View {
        switch stage {
        case .announcing: EmptyView()
        case .handover: handover
        case .adversaireRepond: adversaire
        case .asking, .revealed: question
        case .summary: summary
        }
    }

    // MARK: - « Prêt ? »

    @ViewBuilder private var handover: some View {
        if let a = session.assault, let duel = session.duel,
           let attaquant = session.player(a.attacker), let defenseur = session.player(a.defender),
           let qui = session.repondeur, let repondeur = session.player(qui) {
            // En face à face, celui qui doit répondre n'est plus forcément le
            // défenseur : c'est lui qu'il faut nommer, et lui dont on prend la
            // couleur, sans quoi on tend l'appareil au mauvais joueur.
            let croise = session.game.rules.mode == .faceAFace
            VStack(spacing: 26) {
                Image(systemName: qui == a.defender ? "shield.lefthalf.filled" : "flag.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Palette.camp(repondeur.id))
                VStack(spacing: 8) {
                    Text("\(attaquant.name) attaque \(session.game.name(a.to))")
                        .font(.title3.weight(.semibold))
                    Text("Question \(duel.question.category.apresDe)"
                         + " — \(duel.question.difficulty.label.lowercased())")
                        .foregroundStyle(Palette.dim)
                    if croise, a.defenderAnswer != nil {
                        // On dit qu'il a répondu, jamais ce qu'il a répondu.
                        Text("\(defenseur.name) a répondu. À vous la même question.")
                            .font(.footnote)
                            .foregroundStyle(Palette.dim)
                    } else if croise {
                        Text("Vous répondez tous les deux à la même question.")
                            .font(.footnote)
                            .foregroundStyle(Palette.dim)
                    }
                    if a.mise > 1 {
                        Label("Enjeu doublé : deux hommes", systemImage: "arrow.up.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.lostVif)
                    }
                }
                .multilineTextAlignment(.center)

                sablier(duel.allowance, siege: duel.siege)

                Text("À \(repondeur.name) de répondre.")
                    .font(.headline)
                Button {
                    withAnimation { session.beginAnswering() }
                } label: {
                    Text("Je suis prêt")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.camp(repondeur.id))
            }
            .foregroundStyle(Palette.ink)
        }
    }

    /// Pendant que l'autre répond. On dit son nom, le thème, et ce qui va
    /// suivre — jamais l'énoncé, qui viendrait deux fois.
    @ViewBuilder private var adversaire: some View {
        if let duel = session.duel, let qui = session.repondeur,
           let repondeur = session.player(qui) {
            VStack(spacing: 14) {
                Image(systemName: "ellipsis.bubble")
                    .font(.system(size: 38))
                    .foregroundStyle(Palette.camp(repondeur.id))
                Text(session.assault?.defenderAnswer != nil
                     ? "Réponse prise. \(repondeur.name) répond…"
                     : "\(repondeur.name) répond…")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Label(duel.question.category.label, systemImage: duel.question.category.symbol)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Palette.category(duel.question.category).opacity(0.25),
                                in: Capsule())
                    .foregroundStyle(Palette.category(duel.question.category))
                Text(session.assault?.defenderAnswer != nil
                     ? "Votre réponse est prise. \(repondeur.name) répond maintenant à "
                       + "la même question : le plus sûr l'emporte, et si vous savez "
                       + "tous les deux, le plus rapide."
                     : "Vous recevrez la même question juste après : en face à face, "
                       + "l'attaquant répond aussi. Le plus sûr l'emporte, et si vous "
                       + "savez tous les deux, le plus rapide.")
                    .font(.footnote).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sablier(_ allowance: TimeInterval, siege: Int) -> some View {
        VStack(spacing: 4) {
            Label("\(Int(allowance.rounded())) secondes", systemImage: "hourglass")
                .font(.subheadline.weight(.medium))
            if siege > 0 {
                Text("\(siege + 1)ᵉ question sur cette place ce tour-ci — le temps se resserre")
                    .font(.caption)
                    .foregroundStyle(Palette.lostVif.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - La question

    /// La question que l'écran doit montrer.
    ///
    /// Ce n'est pas toujours celle que le moteur tient prête. Dès qu'une
    /// réponse lui parvient, il enchaîne : il compte la perte et tire aussitôt
    /// la question suivante de la salve. L'écran, lui, en est encore à
    /// dévoiler la précédente — et il affichait donc la suivante, sa bonne
    /// réponse déjà marquée en vert, avant que personne n'y ait répondu.
    ///
    /// Tant qu'un compte rendu est là, c'est sa question qui règne. Le moteur
    /// attendra.
    private var duelAffiche: Duel? {
        if let r = session.report {
            return Duel(question: r.question, allowance: r.allowance, siege: 0)
        }
        return session.duel
    }

    @ViewBuilder private var question: some View {
        if let duel = duelAffiche {
            VStack(spacing: 18) {
                entete(duel)
                compteARebours(duel.allowance)

                Text(duel.question.prompt)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 2)

                VStack(spacing: 8) {
                    ForEach(Array(duel.question.choices.enumerated()), id: \.offset) { i, choix in
                        proposition(i, choix, duel: duel)
                    }
                }

                if session.puisJeRelancer {
                    Button { withAnimation { session.relancer() } } label: {
                        Label("Doubler l'enjeu", systemImage: "arrow.up.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(Palette.lostVif)
                    .transition(.opacity)
                } else if let a = session.assault, a.mise > 1, session.report == nil {
                    Label("Enjeu doublé : deux hommes", systemImage: "arrow.up.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.lostVif)
                }

                if session.thinking {
                    Label(session.enReseau ? "L'adversaire répond…" : "L'adversaire réfléchit…",
                          systemImage: "ellipsis.bubble")
                        .font(.subheadline)
                        .foregroundStyle(Palette.dim)
                } else if let r = session.report {
                    verdict(r)
                }

                // L'invite ne paraît qu'une fois passé le premier instant :
                // affichée d'emblée, elle pousserait à écourter ce qu'on
                // vient tout juste d'ouvrir.
                if session.canSkip, session.waitPart < 0.8 {
                    Text("Touchez pour continuer")
                        .font(.caption2)
                        .foregroundStyle(Palette.dim.opacity(0.8))
                        .transition(.opacity)
                }
            }
        }
    }

    private func entete(_ duel: Duel) -> some View {
        HStack {
            Label(duel.question.category.label, systemImage: duel.question.category.symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Palette.category(duel.question.category).opacity(0.25), in: Capsule())
                .foregroundStyle(Palette.category(duel.question.category))
            Spacer()
            if let a = session.assault {
                Text("\(session.game.name(a.from)) → \(session.game.name(a.to))")
                    .font(.caption)
                    .foregroundStyle(Palette.dim)
                // Une fois la réponse donnée, le moteur a déjà compté la
                // question : le compteur affichait « 2/1 ». C'est celle qu'on
                // vient de régler qu'il faut montrer, pas la suivante.
                Text("· \(min(max(session.report == nil ? a.asked + 1 : a.asked, 1), a.volley))/\(a.volley)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.dim)
            }
        }
    }

    /// La barre du haut dit deux choses selon qui répond, et il faut qu'on les
    /// distingue : le sablier du défenseur, qui décide de l'issue, se tient en
    /// couleur ; le temps de lecture, qui ne décide de rien, reste gris.
    ///
    /// Dans les deux cas elle ne descend qu'une fois par question. Quand c'est
    /// un humain qui a répondu, elle se fige où elle en était — ce qui lui
    /// restait de temps est une information, pas un décompte à rejouer.
    private func compteARebours(_ allowance: TimeInterval) -> some View {
        let sablier = session.aMoiDeRepondre
        let part = sablier
            ? max(0, min(1, session.remaining / max(allowance, 0.001)))
            : session.waitPart
        let teinte: Color = sablier
            ? (part > 0.5 ? Palette.held : (part > 0.25 ? Color.orange : Palette.lost))
            : Palette.dim.opacity(0.45)
        return GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.panel)
                Capsule().fill(teinte).frame(width: g.size.width * part)
            }
        }
        .frame(height: 7)
        .animation(.linear(duration: 0.1), value: part)
    }

    private func proposition(_ index: Int, _ texte: String, duel: Duel) -> some View {
        let r = session.report
        let choisi: Int? = { if case let .chosen(i, _) = maReponse { return i } else { return nil } }()
        let estBonne = index == duel.question.answer
        let fond: Color = {
            guard r != nil else { return Palette.panel }
            if estBonne { return Palette.held.opacity(0.85) }
            if index == choisi { return Palette.lost.opacity(0.8) }
            return Palette.panel
        }()
        return Button {
            session.answer(index)
        } label: {
            HStack {
                Text(texte)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.leading)
                Spacer()
                if r != nil, estBonne { Image(systemName: "checkmark") }
                if r != nil, index == choisi, !estBonne { Image(systemName: "xmark") }
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14).padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fond, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        // Ne pas répondre n'est pas la même chose qu'être délavé. Un bouton
        // « disabled » perd son contraste, et l'attaquant — qui ne répond
        // pas — ne pouvait plus lire les propositions. Or les lire et y
        // répondre dans sa tête est tout son jeu pendant ce duel-là.
        .allowsHitTesting(session.stage == .asking && session.report == nil
                          && !session.thinking && session.aMoiDeRepondre)
        .animation(.easeOut(duration: 0.2), value: session.report)
    }

    /// Vert ou rouge selon ce qui vous arrive **à vous**, et non selon le camp
    /// qui tient. « Khanat tient bon » s'affichait en vert alors que la phrase
    /// vous coûtait un homme : la couleur disait le contraire du texte, et
    /// c'est elle qu'on lit en premier. À deux humains sur un appareil, il n'y
    /// a pas de « vous » : la phrase reste alors blanche.
    private func couleurDuVerdict(_ r: DuelReport) -> Color {
        guard let a = session.assault else { return Palette.ink }
        let attaquantEstMoi: Bool
        if session.enReseau {
            attaquantEstMoi = a.attacker == session.monRang
        } else {
            let attaquantHumain = !(session.player(a.attacker)?.isBot ?? true)
            let defenseurHumain = !(session.player(a.defender)?.isBot ?? true)
            guard attaquantHumain != defenseurHumain else { return Palette.ink }
            attaquantEstMoi = attaquantHumain
        }
        let jeLEmporte = attaquantEstMoi
            ? r.outcome == .attackerBreaks
            : r.outcome == .defenderHolds
        return jeLEmporte ? Palette.held : Palette.lostVif
    }

    /// Ce que la réponse valait, dit dans les termes du Risk.
    private func verdict(_ r: DuelReport) -> some View {
        VStack(spacing: 10) {
            if r.verdict == .reponse {
                HStack(spacing: 14) {
                    de(r.dice.attacker, legende: "assaut")
                    Image(systemName: r.outcome == .defenderHolds ? "lessthan" : "greaterthan")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Palette.dim)
                    de(r.dice.defender, legende: "défense")
                }
            } else {
                confrontation(r)
            }
            Text(verdictTexte(r))
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                // Sans cela, la phrase se fait tronquer sur une ligne : le
                // texte est le seul de l'écran qui n'ait pas de largeur
                // imposée, et SwiftUI le rogne plutôt que de le replier.
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(couleurDuVerdict(r))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    /// Qui a répondu, et ce que cela coûte.
    ///
    /// La phrase ne disait pas de qui elle parlait. Quand c'est vous qui
    /// attaquez, c'est l'adversaire qui répond : lire « bonne réponse » puis
    /// perdre un homme se prend alors pour une erreur de l'application. Nommer
    /// celui qui répond lève tout le doute, et la place nommée dit où l'homme
    /// tombe.
    private func verdictTexte(_ r: DuelReport) -> String {
        let nom = session.assault.flatMap { session.player($0.defender)?.name } ?? "Le défenseur"
        let att = session.assault.flatMap { session.player($0.attacker)?.name } ?? "L'assaillant"
        let lieu = session.assault.map { session.game.name($0.to) } ?? "La place"
        let cout = r.mise > 1 ? "deux hommes" : "un homme"

        switch r.verdict {
        case .reponse:
            let vous = session.aMoiDeRepondre
            if r.correct {
                return (vous ? "Vous avez répondu juste" : "\(nom) a répondu juste")
                    + " : \(lieu) tient, l'assaillant laisse \(cout)."
            }
            let faute = r.answer == .timeout
                ? (vous ? "Vous n'avez pas répondu à temps" : "\(nom) n'a pas répondu à temps")
                : (vous ? "Vous vous êtes trompé" : "\(nom) s'est trompé")
            return faute + " : \(lieu) perd \(cout)."

        case .seul:
            return r.correct
                ? "\(nom) savait, \(att) non : \(lieu) tient, l'assaillant laisse \(cout)."
                : "\(att) savait, \(nom) non : \(lieu) perd \(cout)."

        case .vitesse:
            return r.outcome == .defenderHolds
                ? "Les deux savaient. \(nom) a été le plus vif : \(lieu) tient, "
                    + "l'assaillant laisse \(cout)."
                : "Les deux savaient. \(att) a été le plus vif : \(lieu) perd \(cout)."

        case .egalite:
            return "Personne ne savait. Comme sur une égalité de dés, \(lieu) tient "
                + "et l'assaillant laisse \(cout)."
        }
    }

    /// Ma propre réponse, pour savoir où poser la croix. En face à face les
    /// deux joueurs ont coché une case : montrer celle du défenseur à
    /// l'attaquant lui ferait croire qu'il s'est trompé.
    private var maReponse: Answer? {
        guard let r = session.report else { return nil }
        guard r.verdict != .reponse, let a = session.assault else { return r.answer }
        let jeDefends = session.enReseau
            ? a.defender == session.monRang
            : !(session.player(a.defender)?.isBot ?? true)
        return jeDefends ? r.answer : r.attackerAnswer
    }

    /// Les deux réponses côte à côte, avec le temps de chacun.
    ///
    /// C'est la pièce qui manquait au face à face. Quatre échanges sur dix se
    /// décident au sablier : sans voir les deux temps, on perd une place en
    /// ayant répondu juste, et l'on ne peut que croire à une erreur du jeu.
    @ViewBuilder private func confrontation(_ r: DuelReport) -> some View {
        if let a = session.assault {
            VStack(spacing: 4) {
                camp(a.attacker, r.attackerAnswer, juste: r.attackerCorrect, de: r,
                     emporte: r.outcome == .attackerBreaks)
                camp(a.defender, r.answer, juste: r.correct, de: r,
                     emporte: r.outcome == .defenderHolds)
            }
        }
    }

    private func camp(_ joueur: PlayerID, _ reponse: Answer?, juste: Bool,
                      de r: DuelReport, emporte: Bool) -> some View {
        let nom = session.player(joueur)?.name ?? "?"
        var texte = "sans réponse"
        var temps: String?
        if case let .chosen(i, e)? = reponse {
            if r.question.choices.indices.contains(i) { texte = r.question.choices[i] }
            temps = String(format: "%.1f s", min(e, r.allowance))
        }
        return HStack(spacing: 7) {
            Circle().fill(Palette.camp(joueur)).frame(width: 7, height: 7)
            Text(nom).font(.caption.weight(.semibold))
                .foregroundStyle(Palette.camp(joueur))
            Image(systemName: juste ? "checkmark" : "xmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(juste ? Palette.held : Palette.lostVif)
            Text(texte).font(.caption).foregroundStyle(Palette.ink)
                .lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            if let temps {
                Text(temps).font(.caption2.monospacedDigit()).foregroundStyle(Palette.dim)
            }
            Image(systemName: "crown.fill")
                .font(.caption2)
                .foregroundStyle(emporte ? Palette.held : .clear)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(emporte ? Palette.held.opacity(0.14) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8))
    }

    private func de(_ face: Int, legende: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: "die.face.\(min(6, max(1, face)))")
                .font(.system(size: 34))
                .foregroundStyle(Palette.ink)
            Text(legende).font(.caption2).foregroundStyle(Palette.dim)
        }
    }

    // MARK: - Le bilan de l'assaut

    @ViewBuilder private var summary: some View {
        if let a = session.assault {
            VStack(spacing: 22) {
                Image(systemName: a.conquered ? "flag.fill" : "shield.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(a.conquered ? Palette.camp(a.attacker) : Palette.dim)
                Text(a.conquered
                     ? "\(session.game.name(a.to)) est prise."
                     : "\(session.game.name(a.to)) tient bon.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.ink)

                HStack(spacing: 28) {
                    bilan("Assaillant", a.attackerLosses, a.attacker)
                    bilan("Défenseur", a.defenderLosses, a.defender)
                }

                // Le bilan d'un assaut que l'on subit est en lecture seule.
                // Sans cette condition, une place prise par la machine vous
                // tendait **son** panneau d'occupation : vous auriez choisi
                // combien de ses hommes avancent chez vous.
                if !session.aMoiDeJouer {
                    Text("Touchez pour continuer")
                        .font(.caption2)
                        .foregroundStyle(Palette.dim.opacity(0.8))
                } else if case let .occupation(from, to, minimum, maximum) = session.game.phase {
                    OccupationPanel(session: session, from: from, to: to,
                                    minimum: minimum, maximum: maximum)
                } else {
                    Button { withAnimation { session.closeAssault() } } label: {
                        Text("Continuer").font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.camp(a.attacker))
                }
            }
        }
    }

    private func bilan(_ titre: String, _ pertes: Int, _ camp: PlayerID) -> some View {
        VStack(spacing: 5) {
            Text(titre).font(.caption).foregroundStyle(Palette.dim)
            Text("−\(pertes)")
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(pertes > 0 ? Palette.lostVif : Palette.dim)
            Circle().fill(Palette.camp(camp)).frame(width: 10, height: 10)
        }
    }
}

/// Combien d'hommes avancent dans la place conquise.
///
/// Le nombre passe devant le bouton, et non l'inverse. Le choix tenait dans
/// un `Stepper` — deux flèches grises de la taille d'un ongle — posé au-dessus
/// d'un bouton plein largeur, plein de la couleur du camp : on voyait le
/// bouton, on le touchait, et un seul homme avançait sur la place qu'on
/// venait de prendre. Le joueur ne s'en apercevait qu'au tour suivant, en
/// trouvant sa garnison restée derrière, et croyait que l'application avait
/// tranché à sa place.
///
/// D'où trois changements qui vont tous dans le même sens. Le chiffre est
/// gros et se règle par deux touches rondes de quarante-quatre points — le
/// plancher de ce qui se touche sans rater, et ici on les touche plusieurs
/// fois de suite. Trois raccourcis prennent les cas courants, car personne ne
/// tape onze fois sur « plus ». Et le bouton **porte le nombre choisi** : le
/// doigt pressé lit encore ce qu'il valide.
struct OccupationPanel: View {
    let session: GameSession
    let from: TerritoryID
    let to: TerritoryID
    let minimum: Int
    let maximum: Int
    @State private var count = 1

    /// Le haut de la plage. Le moteur donne toujours un maximum au moins égal
    /// au minimum, mais une plage qui s'inverse fait tomber l'écran : on ne
    /// s'y fie pas.
    private var haut: Int { max(minimum, maximum) }
    private var camp: PlayerID { session.game.currentPlayer.id }
    /// Ce qui reste à la place de départ. Les hommes n'ont pas encore bougé —
    /// le moteur ne les déplace qu'à la validation.
    private var reste: Int { max(1, session.game.armies(from) - count) }

    var body: some View {
        VStack(spacing: 12) {
            if haut > minimum {
                selecteur
            } else {
                // Rien à choisir : le dire, plutôt que de tendre un réglage
                // qui ne bouge pas.
                Text(minimum > 1
                     ? "\(minimum) hommes avancent — c'est tout ce que la place de départ peut céder."
                     : "Un homme avance — c'est tout ce que la place de départ peut céder.")
                    .font(.footnote).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
            }

            Button { withAnimation { session.occupy(count) } } label: {
                Text(count > 1 ? "Faire avancer \(count) hommes" : "Faire avancer 1 homme")
                    .font(.headline)
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.camp(camp))
        }
        .onAppear { count = minimum }
    }

    /// Le choix, dans son cadre. Le cadre n'est pas un ornement : il donne au
    /// réglage le poids que le bouton lui prenait, et la couleur du camp en
    /// liseré dit que c'est encore votre geste — le fond, lui, reste mat.
    private var selecteur: some View {
        VStack(spacing: 10) {
            Text("Combien d'hommes avancent ?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)

            HStack(spacing: 16) {
                pas(-1, "minus")
                VStack(spacing: 0) {
                    Text("\(count)")
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.campVif(camp))
                        .contentTransition(.numericText())
                    Text("sur \(haut)")
                        .font(.caption.monospacedDigit()).foregroundStyle(Palette.dim)
                }
                .frame(minWidth: 84)
                pas(+1, "plus")
            }

            HStack(spacing: 8) {
                raccourci("Le minimum", minimum)
                if let moitie { raccourci("La moitié", moitie) }
                raccourci("Tous", haut)
            }

            bilanDuMouvement
            if minimum > 1 {
                Text("Au moins \(minimum) : autant que de questions posées.")
                    .font(.caption).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(Palette.campVif(camp).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder(Palette.campVif(camp).opacity(0.65), lineWidth: 1.5))
    }

    /// Ce que le mouvement laisse de part et d'autre, à jour du chiffre
    /// choisi.
    ///
    /// La feuille couvre le bas de la carte au moment même où l'on décide, et
    /// l'on ne voyait donc plus **où** les hommes avancent — ni ce qu'il
    /// resterait derrière. Les deux places sont nommées ici, avec la garnison
    /// que chacune aura une fois le mouvement fait : c'est de cela qu'on
    /// décide, et cela ne dépend d'aucun recadrage.
    private var bilanDuMouvement: some View {
        HStack(spacing: 12) {
            place(session.game.name(from), reste, teinte: Palette.ink.opacity(0.85))
            Image(systemName: "arrow.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.dim)
            place(session.game.name(to), count, teinte: Palette.campVif(camp))
        }
    }

    private func place(_ nom: String, _ hommes: Int, teinte: Color) -> some View {
        VStack(spacing: 1) {
            Text(nom)
                .font(.caption2).foregroundStyle(Palette.dim)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text("\(hommes)")
                .font(.headline.monospacedDigit()).foregroundStyle(teinte)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: 120)
    }

    /// Un cran de plus ou de moins. La touche s'éteint quand elle est au bout
    /// de la plage, au lieu de disparaître : la paire reste symétrique, et le
    /// doigt ne cherche pas où est passé le « moins ».
    private func pas(_ delta: Int, _ icone: String) -> some View {
        let cible = min(max(count + delta, minimum), haut)
        let mort = cible == count
        return Button {
            withAnimation(.snappy(duration: 0.12)) { count = cible }
        } label: {
            Image(systemName: icone)
                .font(.title3.weight(.bold))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(mort ? 0.03 : 0.08)))
                .overlay(Circle().strokeBorder(mort ? Palette.dim.opacity(0.3)
                                                    : Palette.campVif(camp).opacity(0.8),
                                               lineWidth: 1.5))
                .foregroundStyle(mort ? Palette.dim.opacity(0.45) : Palette.campVif(camp))
        }
        .buttonStyle(.plain)
        .disabled(mort)
    }

    /// Les cas courants, en un appui.
    private func raccourci(_ titre: String, _ valeur: Int) -> some View {
        let choisi = count == valeur
        return Button {
            withAnimation(.snappy(duration: 0.12)) { count = valeur }
        } label: {
            Text(titre)
                .font(.caption.weight(.semibold)).lineLimit(1)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(choisi ? Palette.campVif(camp).opacity(0.28)
                                                  : Color.white.opacity(0.06)))
                .overlay(Capsule().strokeBorder(choisi ? Palette.campVif(camp)
                                                       : Palette.dim.opacity(0.45),
                                                lineWidth: 1))
                .foregroundStyle(choisi ? Palette.ink : Palette.dim)
        }
        .buttonStyle(.plain)
    }

    /// La moitié, et seulement quand elle dit autre chose que les deux bouts.
    private var moitie: Int? {
        let m = min(haut, max(minimum, (haut + 1) / 2))
        return m > minimum && m < haut ? m : nil
    }
}
