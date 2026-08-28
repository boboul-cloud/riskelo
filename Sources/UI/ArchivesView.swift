//
//  ArchivesView.swift
//  Riskelo
//
//  La bibliothèque : les parties passées, et les instants où l'on peut y
//  revenir.
//
//  Deux niveaux, et non un seul. La liste des parties se lit comme un rayon —
//  le plateau, le mode, la date, contre qui — et l'on n'ouvre les instants
//  d'une partie que lorsqu'on a choisi laquelle. Tout tenir à plat aurait
//  donné cinq cents lignes indiscernables.
//
//  Chaque instant montre le rapport de forces qu'il avait, en couleurs de
//  camp. C'est ce qui permet de retrouver « le moment où j'ai basculé » sans
//  ouvrir les positions une à une.
//

import SwiftUI

struct ArchivesView: View {

    var onOpen: (GameState) -> Void
    var onClose: () -> Void

    @State private var parties: [PartieArchivee] = []
    @State private var ouverte: PartieArchivee?
    @State private var illisible = false

    var body: some View {
        // La barre est posée en marge de sécurité plutôt qu'empilée : c'est
        // ce qu'attend le système, et le contenu défile dessous proprement.
        //
        // Le contenu se borne en largeur — sinon il s'étalerait sur un Mac —
        // quand la barre, elle, tient tout l'écran.
        contenu
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .top, spacing: 0) { entete }
            .background(Palette.sea)
        .onAppear { parties = Archives.shared.liste() }
        .alert("Cet instant ne se relit plus",
               isPresented: $illisible) {
            Button("Bien") { }
        } message: {
            Text("Il a été enregistré sur un plateau qui a changé de dessin depuis.")
        }
    }

    @ViewBuilder private var contenu: some View {
        if parties.isEmpty {
            vide
        } else if let p = ouverte {
            moments(de: p)
        } else {
            rayon
        }
    }

    // MARK: - En-tête

    private var entete: some View {
        HStack {
            Button {
                if ouverte != nil { withAnimation { ouverte = nil } } else { onClose() }
            } label: {
                Label(ouverte == nil ? "Fermer" : "Toutes les parties",
                      systemImage: "chevron.left")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.plain).foregroundStyle(Palette.dim)
            Spacer(minLength: 12)
        }
        // Le titre par-dessus plutôt qu'entre deux ressorts : il reste centré
        // sur la barre quelle que soit la longueur du bouton de gauche.
        .overlay {
            Text(ouverte == nil ? "Parties enregistrées" : "Revenir à un instant")
                .font(.headline).foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Palette.panel)
    }

    private var vide: some View {
        VStack(spacing: 10) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40)).foregroundStyle(Palette.dim)
            Text("Aucune partie rangée pour l'instant.")
                .font(.headline).foregroundStyle(Palette.ink)
            Text("Chaque tour joué dépose un instant ici, tout seul.")
                .font(.footnote).foregroundStyle(Palette.dim)
        }
        .multilineTextAlignment(.center)
        .frame(maxHeight: .infinity)
        .padding(30)
    }

    // MARK: - Le rayon

    private var rayon: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(parties) { p in
                    Button { withAnimation { ouverte = p } } label: { ligne(p) }
                        .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    private func ligne(_ p: PartieArchivee) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(p.plateau.label).font(.headline).foregroundStyle(Palette.ink)
                    Text("· \(p.mode.label)").font(.caption).foregroundStyle(Palette.dim)
                }
                HStack(spacing: 6) {
                    ForEach(Array(p.joueurs.enumerated()), id: \.offset) { i, nom in
                        Text(nom + (p.machines.contains(i) ? " ⌘" : ""))
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Palette.camp(i).opacity(0.28), in: Capsule())
                            .foregroundStyle(Palette.camp(i))
                    }
                }
                Text(etat(p)).font(.caption).foregroundStyle(Palette.dim)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 8) {
                Text(p.derniere.formatted(.dateTime.day().month(.abbreviated)
                                              .hour().minute()))
                    .font(.caption2).foregroundStyle(Palette.dim)
                Button {
                    Archives.shared.supprimer(p.id)
                    withAnimation { parties = Archives.shared.liste() }
                } label: {
                    Image(systemName: "trash").font(.caption)
                }
                .buttonStyle(.plain).foregroundStyle(Palette.dim.opacity(0.7))
            }
        }
        .padding(14)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
    }

    private func etat(_ p: PartieArchivee) -> String {
        let n = p.moments.count
        let instants = "\(n) instant\(n > 1 ? "s" : "")"
        if let v = p.vainqueur, v < p.joueurs.count {
            return "\(p.joueurs[v]) l'a emporté · \(instants)"
        }
        return "Interrompue au tour \(p.moments.last?.tour ?? 1) · \(instants)"
    }

    // MARK: - Les instants d'une partie

    private func moments(de p: PartieArchivee) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Choisir un instant reprend la partie à partir de là, sans "
                     + "effacer celle-ci : la suite que vous jouerez sera rangée à part.")
                    .font(.caption).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 6)

                ForEach(p.moments.reversed()) { m in
                    Button {
                        if let g = Archives.shared.charger(m) { onOpen(g) } else { illisible = true }
                    } label: { instant(m, de: p) }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    private func instant(_ m: PartieArchivee.Moment, de p: PartieArchivee) -> some View {
        let total = max(1, m.territoires.reduce(0, +))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if m.marque {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2).foregroundStyle(Palette.held)
                } else {
                    Circle().fill(Palette.camp(m.camp)).frame(width: 8, height: 8)
                }
                Text(m.etiquette).font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(m.date.formatted(.dateTime.hour().minute()))
                    .font(.caption2).foregroundStyle(Palette.dim)
            }
            // Le rapport de forces, en une barre : c'est lui qui fait
            // reconnaître le moment qu'on cherche.
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(Array(m.territoires.enumerated()), id: \.offset) { i, n in
                        if n > 0 {
                            Capsule().fill(Palette.camp(i))
                                .frame(width: max(3, g.size.width * Double(n) / Double(total)))
                        }
                    }
                }
            }
            .frame(height: 6)
            HStack(spacing: 8) {
                ForEach(Array(m.territoires.enumerated()), id: \.offset) { i, n in
                    Text("\(p.joueurs.indices.contains(i) ? p.joueurs[i] : "?") \(n)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Palette.camp(i))
                }
            }
        }
        .padding(13)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
    }
}


