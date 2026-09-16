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

    private static let devant = "localhost:8787"

    /// Le serveur de développement est-il devant ?
    private func serveurDebout() async -> Bool {
        var demande = URLRequest(url: URL(string: "http://\(SalonTests.devant)/sante")!)
        demande.timeoutInterval = 2
        guard let (data, _) = try? await URLSession.shared.data(for: demande) else {
            return false
        }
        return String(data: data, encoding: .utf8) == "ok"
    }

    /// Attendre qu'une chose devienne vraie, et rendre la main dès qu'elle
    /// l'est. Un délai fixe passerait sur une machine au repos et échouerait
    /// sur une machine occupée — l'essai accuserait alors l'innocent.
    private func jusqua(_ limite: TimeInterval = 8,
                        _ vrai: () -> Bool) async -> Bool {
        let fin = Date().addingTimeInterval(limite)
        while Date() < fin {
            if vrai() { return true }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return vrai()
    }

    @Test func leSalonDeBoutEnBout() async throws {
        guard await serveurDebout() else {
            print("Riskelo — essai du salon sauté : aucun serveur sur \(SalonTests.devant). "
                  + "Lancez « cd serveur && npm run dev » pour l'exécuter vraiment.")
            return
        }
        print("Riskelo — essai du salon : serveur trouvé, on y va.")

        let avant = Relais.serveur
        Relais.serveur = SalonTests.devant
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
}
