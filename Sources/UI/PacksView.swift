//
//  PacksView.swift
//  Riskelo
//
//  Les packs : ce qu'on joue, et ce qu'on achète.
//
//  Le choix des thèmes vivait dans « Réglages de la partie », et il n'y
//  marchait qu'à moitié — pour une raison de fond. Cet écran-là ne règle pas
//  l'application : il met en place **une** partie, et son bouton de départ est
//  le seul à lire ce qu'on y a coché. Une partie rapide lancée depuis
//  l'accueil, une partie reprise, une table ouverte en réseau partaient toutes
//  des valeurs d'usine. On décochait un thème, et il revenait.
//
//  Un pack n'est pas un réglage de partie. C'est quelque chose qu'on possède,
//  qui se garde, et qui vaut pour toutes les parties tant qu'on n'en décide
//  pas autrement. D'où cette page à part, et son accès depuis l'accueil.
//
//  Ce qu'on y choisit part malgré tout **avec** la partie, dans ses règles :
//  celui qui rejoint une table joue les thèmes de l'hôte, sans quoi les deux
//  appareils ne poseraient pas les mêmes questions.
//

import SwiftUI
import StoreKit

// MARK: - Ce que l'appareil garde

/// Le choix des packs, gardé d'une partie à l'autre.
///
/// Dans les préférences du système et non dans une vue : il vaut pour
/// l'application entière, comme le son et le pseudonyme, et non pour la
/// partie qu'on est en train de mettre en place.
enum Packs {

    static let cleChoisis = "riskelo.packs.choisis"
    static let cleAvecBase = "riskelo.packs.base"

    /// Les packs cochés, par identifiant de thème.
    static var choisis: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: cleChoisis) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: cleChoisis) }
    }

    /// Joue-t-on aussi les six thèmes de culture générale ?
    static var avecBase: Bool {
        get { UserDefaults.standard.object(forKey: cleAvecBase) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: cleAvecBase) }
    }

    /// Les thèmes que les parties doivent utiliser.
    ///
    /// Jamais vide : tout décocher rendrait le jeu injouable, et une partie
    /// sans question ne se distingue pas d'une panne. À défaut de tout, le
    /// jeu de base — celui que tout le monde possède.
    static var enJeu: Set<String> {
        var ids = avecBase ? Set(Themes.base.map(\.id)) : []
        ids.formUnion(choisis)
        return ids.isEmpty ? Set(Themes.base.map(\.id)) : ids
    }

    /// Écarte ce qui n'est plus possédé — un remboursement, un appareil neuf.
    static func oublierCeQuOnNaPlus(_ possedes: Set<String>) {
        let valides = choisis.filter { id in
            guard let produit = Themes.connu(Category(id))?.produit else { return false }
            return possedes.contains(produit)
        }
        if valides != choisis { choisis = Set(valides) }
    }
}

// MARK: - L'écran

struct PacksView: View {

    var onClose: () -> Void

    @State private var boutique = Boutique.shared
    @State private var choisis = Packs.choisis
    @State private var avecBase = Packs.avecBase

    var body: some View {
        VStack(spacing: 0) {
            entete
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    presentation
                    jeuDeBase
                    ForEach(Themes.packs) { pack in ligne(pack) }
                    restauration
                    resume
                }
                .padding(18)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Palette.sea)
        .preferredColorScheme(.dark)
        .task {
            await boutique.ouvrir()
            Packs.oublierCeQuOnNaPlus(boutique.possedes)
            choisis = Packs.choisis
        }
    }

    private var entete: some View {
        HStack {
            Button(action: onClose) {
                Label("Accueil", systemImage: "chevron.left").font(.subheadline)
            }
            .buttonStyle(.plain).foregroundStyle(Palette.dim)
            Spacer()
            Text("Packs").font(.headline).foregroundStyle(Palette.ink)
            Spacer()
            // Un vide de la largeur du bouton, pour que le titre soit centré
            // sur l'écran et non sur ce qui reste.
            Label("Accueil", systemImage: "chevron.left").font(.subheadline).hidden()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Palette.panel)
    }

    private var presentation: some View {
        Text("Un pack est un jeu de questions qui s'ajoute au vôtre. Cochez ceux "
             + "que vous voulez jouer — un seul, ou plusieurs mêlés. Le choix vaut "
             + "pour toutes vos parties, et c'est celui qui ouvre la table qui "
             + "décide pour tout le monde.")
            .font(.caption).foregroundStyle(Palette.dim)
    }

    // MARK: - Le jeu de base

    private var jeuDeBase: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                // On ne peut pas tout retirer : sans thème, pas de question.
                guard !avecBase || !choisis.isEmpty else { return }
                avecBase.toggle()
                Packs.avecBase = avecBase
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "globe.europe.africa")
                        .font(.system(size: 17)).frame(width: 24)
                        .foregroundStyle(avecBase ? Palette.camp(0) : Palette.dim)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Culture générale").font(.subheadline.weight(.semibold))
                            .foregroundStyle(avecBase ? Palette.ink : Palette.dim)
                        Text("Les six thèmes du jeu — \(compte(Themes.base)) questions.")
                            .font(.caption2).foregroundStyle(Palette.dim)
                    }
                    Spacer()
                    coche(avecBase, teinte: Palette.camp(0))
                }
                .padding(14).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Un pack

    @ViewBuilder private func ligne(_ pack: Category) -> some View {
        let possede = boutique.possede(pack)
        let coche = possede && choisis.contains(pack.id)
        let teinte = Palette.category(pack)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: pack.symbol)
                    .font(.system(size: 17)).frame(width: 24)
                    .foregroundStyle(coche ? teinte : Palette.dim)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.label).font(.subheadline.weight(.semibold))
                        .foregroundStyle(coche ? Palette.ink : Palette.dim)
                    Text(Themes.connu(pack)?.detail ?? "")
                        .font(.caption2).foregroundStyle(Palette.dim)
                    Text("\(compte([pack])) questions")
                        .font(.caption2.monospacedDigit()).foregroundStyle(Palette.dim)
                }
                Spacer()
                if possede {
                    Button {
                        // Le dernier thème coché ne se décoche pas.
                        if coche {
                            guard avecBase || choisis.count > 1 else { return }
                            choisis.remove(pack.id)
                        } else {
                            choisis.insert(pack.id)
                        }
                        Packs.choisis = choisis
                    } label: {
                        self.coche(coche, teinte: teinte)
                    }
                    .buttonStyle(.plain)
                } else {
                    boutonDAchat(pack, teinte: teinte)
                }
            }
        }
        .padding(14)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(coche ? teinte.opacity(0.45) : .clear, lineWidth: 1))
    }

    @ViewBuilder private func boutonDAchat(_ pack: Category, teinte: Color) -> some View {
        if boutique.enCours == pack.produit {
            ProgressView().controlSize(.small)
        } else if let prix = boutique.prix(pack) {
            Button(prix) { Task { await boutique.acheter(pack) } }
                .buttonStyle(.borderedProminent).tint(teinte)
                .font(.subheadline.weight(.semibold))
        } else if boutique.ouverte {
            // L'article existe dans le jeu mais pas dans l'App Store : c'est
            // une faute de configuration, et mieux vaut la dire que d'afficher
            // un bouton qui ne fait rien.
            Text("indisponible").font(.caption2).foregroundStyle(Palette.dim)
        } else {
            ProgressView().controlSize(.small)
        }
    }

    // MARK: - Le bas de page

    private var restauration: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let panne = boutique.panne {
                Text(panne).font(.caption).foregroundStyle(Palette.lostVif)
            }
            Button("Restaurer mes achats") { Task { await boutique.restaurer() } }
                .buttonStyle(.bordered).tint(Palette.dim)
                .font(.subheadline)
            Text("Un pack acheté vous suit sur vos appareils. Celui qui rejoint votre "
                 + "table joue vos packs sans avoir à les acheter.")
                .font(.caption2).foregroundStyle(Palette.dim)
        }
    }

    private var resume: some View {
        let enJeu = Themes.tous.filter { Packs.enJeu.contains($0.id) }
        return Text("\(enJeu.count) thème\(enJeu.count > 1 ? "s" : "") en jeu — "
                    + "\(compte(enJeu)) questions.")
            .font(.caption.weight(.medium)).foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Le détail

    private func coche(_ actif: Bool, teinte: Color) -> some View {
        Image(systemName: actif ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 20))
            .foregroundStyle(actif ? teinte : Palette.dim.opacity(0.5))
    }

    private func compte(_ themes: [Category]) -> Int {
        let ids = Set(themes.map(\.id))
        return QuestionBank.francaises.filter { ids.contains($0.category.id) }.count
    }
}
