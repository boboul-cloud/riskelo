//
//  Boutique.swift
//  Riskelo
//
//  Les packs qui s'achètent, et ce que l'appareil possède.
//
//  Un pack est un thème de questions vendu à part. Son fichier est dans
//  l'application, sur tous les appareils : ce qui s'achète n'est pas le
//  contenu, c'est le droit de le **choisir**. Deux raisons, et la seconde
//  compte plus que la première.
//
//  Il n'y a rien à télécharger — quatre cents questions pèsent cinquante
//  kilo-octets, moins qu'une photographie. Un serveur, un téléchargement et
//  une panne de réseau pour cela seraient trois ennuis pour rien.
//
//  Et surtout : celui qui rejoint une table joue les thèmes de l'hôte. Si le
//  pack n'était pas déjà là, il faudrait le lui envoyer au milieu de la
//  partie, ou lui refuser la table. Là, l'hôte achète et tout le monde joue —
//  ce qui est la meilleure publicité qu'un pack puisse avoir.
//
//  Pour l'essayer sans rien créer chez Apple : « Resources/Riskelo.storekit »
//  est un App Store de bureau, attaché au schéma. On y achète, on y restaure,
//  on y annule et on s'y fait rembourser, et rien n'est facturé. Les vrais
//  articles se créeront dans App Store Connect sous les mêmes identifiants.
//

import Foundation
import StoreKit

@MainActor
@Observable
final class Boutique {

    static let shared = Boutique()

    /// Les articles tels que l'App Store les décrit — nom et prix compris,
    /// dans la monnaie de qui regarde. Un prix ne s'écrit jamais dans le code.
    private(set) var articles: [String: Product] = [:]

    /// Ce que cet appareil a acheté.
    private(set) var possedes: Set<String> = []

    /// L'achat en cours, pour que le bouton sache qu'il attend.
    private(set) var enCours: String?

    /// Ce qui n'a pas marché, en une phrase montrable.
    private(set) var panne: String?

    /// La boutique a-t-elle répondu au moins une fois ?
    private(set) var ouverte = false

    private var veille: Task<Void, Never>?

    private init() {
        // Un achat peut arriver sans passer par nos boutons : restauration,
        // partage familial, achat commencé sur un autre appareil. Sans cette
        // veille, il faudrait relancer l'application pour le voir.
        veille = Task { [weak self] in
            for await resultat in Transaction.updates {
                guard case let .verified(t) = resultat else { continue }
                await t.finish()
                await self?.releverLesDroits()
            }
        }
    }

    // MARK: - Ce que l'écran demande

    func ouvrir() async {
        await charger()
        await releverLesDroits()
        ouverte = true
    }

    /// Ce thème est-il jouable ici ? Un thème sans prix appartient à tout le
    /// monde.
    func possede(_ c: Category) -> Bool {
        guard let produit = c.produit else { return true }
        return possedes.contains(produit)
    }

    func prix(_ c: Category) -> String? {
        guard let produit = c.produit else { return nil }
        return articles[produit]?.displayPrice
    }

    func acheter(_ c: Category) async {
        guard let id = c.produit, let article = articles[id] else {
            panne = "Cet article n'est pas disponible."
            return
        }
        enCours = id
        panne = nil
        defer { enCours = nil }
        do {
            switch try await article.purchase() {
            case let .success(verification):
                guard case let .verified(t) = verification else {
                    panne = "L'achat n'a pas pu être vérifié."
                    return
                }
                await t.finish()
                await releverLesDroits()
            case .userCancelled:
                break
            case .pending:
                // « Demander à acheter » : un parent doit approuver. Ce n'est
                // ni un échec ni un achat, et l'écran doit le dire.
                panne = "L'achat attend une autorisation."
            @unknown default:
                break
            }
        } catch {
            panne = "L'achat n'a pas abouti."
        }
    }

    /// Apple l'exige, et c'est utile : un appareil neuf, une réinstallation.
    func restaurer() async {
        panne = nil
        do {
            try await AppStore.sync()
            await releverLesDroits()
        } catch {
            panne = "La restauration n'a pas abouti."
        }
    }

    // MARK: - L'App Store

    private func charger() async {
        let ids = Themes.packs.compactMap(\.produit)
        guard !ids.isEmpty else { return }
        do {
            let trouves = try await Product.products(for: ids)
            articles = Dictionary(uniqueKeysWithValues: trouves.map { ($0.id, $0) })
            // Un article déclaré par un thème mais absent de l'App Store se
            // dit, et ne fait rien tomber.
            //
            // C'était une « assertionFailure », et elle a fait exactement ce
            // qu'il ne fallait pas : l'application lancée hors de Xcode n'a
            // pas le fichier de test StoreKit — il est attaché au schéma —
            // donc aucun article, donc l'arrêt brutal en ouvrant la page. Une
            // boutique qui ne répond pas est un incident ordinaire, au même
            // titre qu'un réseau coupé, et l'écran sait déjà le montrer.
            let manquants = Set(ids).subtracting(articles.keys)
            if !manquants.isEmpty {
                FileHandle.standardError.write(
                    Data("Riskelo — articles introuvables : \(manquants.sorted())\n".utf8))
            }
        } catch {
            panne = "La boutique n'a pas répondu."
        }
    }

    private func releverLesDroits() async {
        var acquis: Set<String> = []
        for await resultat in Transaction.currentEntitlements {
            guard case let .verified(t) = resultat else { continue }
            // Un achat remboursé se retire.
            if t.revocationDate == nil { acquis.insert(t.productID) }
        }
        possedes = acquis
    }
}
