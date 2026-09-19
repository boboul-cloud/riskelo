//
//  SalonTests.swift
//  RiskeloTests
//
//  L'application face au vrai serveur.
//
//  C'est la couture la plus risquée de tout le jeu au loin, et la seule qu'un
//  essai en mémoire ne peut pas tenir : le nom des clés. Le serveur envoie
//  `{"t":"salon","gens":[…]}` et l'application lit « gens » — s'il envoie
//  « monde » et qu'elle lit « gens », tout compile, tout se connecte, et
//  personne n'apparaît jamais dans la liste. Aucun des deux côtés n'a tort
//  isolément ; c'est leur accord qui manque.
//
//  ## Il ne s'exécute que si le serveur tourne
//
//  Sans serveur devant, cet essai ne dit rien et passe. C'est un compromis
//  assumé et il a un défaut qu'il faut connaître : un essai qu'on saute en
//  silence est un essai qui peut cesser de vérifier quoi que ce soit sans que
//  personne s'en aperçoive. La ligne qu'il écrit dans la console est là pour
//  cela — elle dit laquelle des deux choses s'est passée.
//
//  Pour l'exécuter vraiment :
//
//      cd serveur && npm run dev        (dans une fenêtre)
//      xcodebuild … test                (dans une autre)
//

import Foundation
import Testing
@testable import Riskelo

@MainActor
struct SalonTests {

    /// Le serveur que cet essai va éprouver.
    ///
    /// Le local d'abord, quand `npm run dev` tourne : c'est le plus rapide, et
    /// c'est celui qu'on est en train de modifier. À défaut, **le serveur
    /// déployé** — l'essai éprouve alors ce que les joueurs utilisent
    /// vraiment, ce qui vaut infiniment mieux que de ne rien éprouver.
    ///
    /// Passer par une variable d'environnement paraissait plus propre. Elle
    /// n'arrive pas : `xcodebuild` ne transmet pas l'environnement du shell au
    /// processus qui porte les essais, et la suite disait « sauté » en croyant
    /// viser le serveur déployé. C'est la panne exacte que ce fichier existe
    /// pour éviter — croire qu'on vérifie quelque chose.
    private static var devant: String?

    private static func enClair(_ hote: String) -> Bool {
        hote.hasPrefix("localhost") || hote.hasPrefix("127.0.0.1")
    }

    /// Le premier des deux qui répond, ou `nil` s'il n'y a ni l'un ni l'autre
    /// — machine hors ligne, serveur arrêté.
    private func trouverLeServeur() async -> String? {
        for hote in ["localhost:8787", Relais.serveurParDefaut] {
            let schema = SalonTests.enClair(hote) ? "http" : "https"
            guard let url = URL(string: "\(schema)://\(hote)/sante") else { continue }
            var demande = URLRequest(url: url)
            demande.timeoutInterval = 6
            guard let (data, _) = try? await URLSession.shared.data(for: demande),
                  String(data: data, encoding: .utf8) == "ok"
            else { continue }
            return hote
        }
        return nil
    }

    /// Attendre qu'une chose devienne vraie, et rendre la main dès qu'elle
    /// l'est. Un délai fixe passerait sur une machine au repos et échouerait
    /// sur une machine occupée — l'essai accuserait alors l'innocent.
    private func jusqua(_ limite: TimeInterval = 10,
                        _ vrai: () -> Bool) async -> Bool {
        let fin = Date().addingTimeInterval(limite)
        while Date() < fin {
            if vrai() { return true }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return vrai()
    }

    @Test func leSalonDeBoutEnBout() async throws {
        guard let ou = await trouverLeServeur() else {
            print("Riskelo — essai du salon sauté : ni serveur local sur "
                  + "localhost:8787, ni \(Relais.serveurParDefaut) joignable. "
                  + "Lancez « cd serveur && npm run dev », ou rebranchez le réseau.")
            return
        }
        print("Riskelo — essai du salon : on éprouve \(ou).")

        let avant = Relais.serveur
        Relais.serveur = ou
        defer { Relais.serveur = avant }

        // Deux identités distinctes : dans un même processus, l'appareil n'en
        // a qu'une, et le serveur prendrait le second salon pour le premier
        // qui revient.
        let hote = Relais(moi: Pair(id: "essai-hote-\(UUID().uuidString)", nom: "Robert"))
        let invite = Relais(moi: Pair(id: "essai-invite-\(UUID().uuidString)", nom: "Marie"))
        defer { hote.arreter(); invite.arreter() }

        // --- Ouvrir -----------------------------------------------------
        hote.ouvrir()
        #expect(await jusqua { if case .ouvert = hote.etat { return true }; return false },
                "le serveur n'a pas rendu de code")
        guard case let .ouvert(code) = hote.etat else { return }
        #expect(Relais.estUnCode(code), "le code rendu n'a pas la forme attendue : \(code)")

        // --- Un code qui n'existe pas -----------------------------------
        let egare = Relais(moi: Pair(id: "essai-egare-\(UUID().uuidString)", nom: "Égaré"))
        egare.rejoindre(code: "BABEBI")
        #expect(await jusqua { egare.etat == .refuse(.codeInconnu) },
                "un code inconnu doit être nommé, et non rester en attente")
        egare.arreter()

        // --- Entrer ------------------------------------------------------
        var venu: [Pair] = []
        hote.onConnected = { _, pair in venu.append(pair) }
        invite.rejoindre(code: code)
        #expect(await jusqua { invite.etat == .relie }, "l'invité n'est pas entré")
        #expect(await jusqua { hote.relies.count == 1 },
                "l'hôte ne voit pas l'invité arriver")
        #expect(venu.count == 1)
        // Aucun nom ne vient du serveur : il n'en reçoit pas. La liste dit
        // « Joueur » le temps que le `bonjour` du jeu traverse.
        #expect(hote.relies.first?.nom == "Joueur")
        #expect(invite.relies.first?.nom == "Joueur")

        // --- Un paquet, dans les deux sens -------------------------------
        var chezLInvite: [Message] = []
        invite.onReceive = { data, _ in
            if case let .message(m) = Message.lire(data) { chezLInvite.append(m) }
        }
        hote.envoyer(Message.bonjour(nom: "Robert").data!)
        #expect(await jusqua { !chezLInvite.isEmpty }, "rien n'est arrivé chez l'invité")
        if case let .bonjour(nom)? = chezLInvite.first {
            #expect(nom == "Robert")
        } else {
            Issue.record("le paquet est arrivé déformé : \(String(describing: chezLInvite.first))")
        }

        // --- Et nominativement -------------------------------------------
        var chezLHote: [Message] = []
        hote.onReceive = { data, _ in
            if case let .message(m) = Message.lire(data) { chezLHote.append(m) }
        }
        guard let versLHote = invite.relies.first else {
            Issue.record("l'invité ne sait pas à qui parler"); return
        }
        invite.envoyer(Message.perdu.data!, a: versLHote)
        #expect(await jusqua { !chezLHote.isEmpty },
                "un envoi nominatif n'a pas trouvé son destinataire")

        // --- La partie part, la porte se ferme ---------------------------
        hote.fermerLaTable()
        let tard = Relais(moi: Pair(id: "essai-tard-\(UUID().uuidString)", nom: "Tard"))
        tard.rejoindre(code: code)
        #expect(await jusqua { tard.etat == .refuse(.dejaCommencee) },
                "une partie commencée ne doit plus accueillir")
        tard.arreter()
    }

    /// Se retrouver le lendemain.
    ///
    /// Tout le jeu au loin sur plusieurs soirées tient à ceci : celui qui a
    /// ouvert la partie doit pouvoir **rouvrir le même code**, et ceux qui y
    /// étaient doivent pouvoir y rentrer, même une fois la partie commencée.
    /// Rien de tout cela ne se voit d'un côté seulement — c'est l'accord entre
    /// l'application et le serveur, et il ne s'éprouve que de bout en bout.
    ///
    /// Contre le serveur **local** seulement. Cet essai porte sur ce que le
    /// serveur sait faire depuis cette version : le lancer contre celui qui est
    /// déployé n'apprendrait qu'une chose, c'est qu'il n'a pas encore été
    /// redéployé — et il le dirait sous la forme d'un essai rouge, ce qui
    /// désigne le mauvais coupable.
    @Test func onSeRetrouveLeLendemain() async throws {
        guard await trouverLeServeur() == "localhost:8787" else {
            print("Riskelo — essai de la reprise sauté : il demande le serveur de "
                  + "cette version. Lancez « cd serveur && npm run dev ».")
            return
        }
        let avant = Relais.serveur
        Relais.serveur = "localhost:8787"
        defer { Relais.serveur = avant }

        let hote = Relais(moi: Pair(id: "essai-hier-\(UUID().uuidString)", nom: "Robert"))
        let invite = Relais(moi: Pair(id: "essai-marie-\(UUID().uuidString)", nom: "Marie"))
        defer { hote.arreter(); invite.arreter() }

        // --- Le premier soir ---------------------------------------------
        hote.ouvrir()
        #expect(await jusqua { if case .ouvert = hote.etat { return true }; return false })
        guard case let .ouvert(code) = hote.etat else { return }

        invite.rejoindre(code: code)
        #expect(await jusqua { invite.etat == .relie })
        #expect(await jusqua { hote.relies.count == 1 })
        // La partie part : la porte se ferme aux nouveaux, pas à eux deux.
        hote.fermerLaTable()

        // --- On se quitte -------------------------------------------------
        hote.arreter()
        invite.arreter()

        // --- Le lendemain -------------------------------------------------
        // L'hôte rouvre son salon sous le même code. Un code neuf ne servirait
        // à rien : l'autre n'a que celui-là.
        hote.reprendreLeSalon(code: code)
        #expect(await jusqua { if case .ouvert = hote.etat { return true }; return false },
                "l'hôte n'a pas retrouvé son salon")
        guard case let .ouvert(retrouve) = hote.etat else { return }
        #expect(retrouve == code, "le salon rendu n'est pas le sien : \(retrouve) au lieu de \(code)")

        // Et l'invité y rentre, bien que la partie soit commencée : il y était.
        invite.rejoindre(code: code)
        #expect(await jusqua { invite.etat == .relie },
                "celui qui y était doit pouvoir revenir, même après le lancement")
        #expect(await jusqua { hote.relies.count == 1 })

        // --- Le code d'un autre -------------------------------------------
        // Un appareil qui prétendrait rouvrir ce salon-ci se fait renvoyer, et
        // on le lui dit : sans quoi il atterrirait dans la partie d'un inconnu.
        let usurpateur = Relais(moi: Pair(id: "essai-autre-\(UUID().uuidString)", nom: "Autre"))
        usurpateur.reprendreLeSalon(code: code)
        #expect(await jusqua { usurpateur.etat == .refuse(.salonRepris) },
                "un salon ne se reprend que par celui qui l'a ouvert")
        usurpateur.arreter()
    }
}
