//
//  LoinTests.swift
//  RiskeloTests
//
//  Le fil du loin, et ce qui est commun aux trois.
//
//  Ces vérifications portent sur le seul endroit où une panne du jeu en ligne
//  ne dit rien du tout. Une partie qui diverge reste cohérente **de chaque
//  côté** : les deux écrans sont justes, les deux joueurs sont sûrs d'eux, et
//  ce sont deux parties différentes. Un rang mal distribué, un nom qui
//  n'arrive pas, une reprise qui ne redemande rien — tout cela se voit à
//  l'usage comme « le jeu bugue », sans jamais désigner un fichier.
//
//  Rien ici ne fait bouger une partie. C'est délibéré : `GameSession`
//  enregistre sur le disque dès que sa partie change, et sur le vrai disque —
//  `GameStore.shared` n'est pas déplaçable. Un test qui jouerait un coup
//  écraserait la partie en cours de celui qui lance les tests.
//

import Foundation
import Testing
@testable import Riskelo

// MARK: - Un fil qu'on peut couper

/// Deux appareils reliés par rien du tout.
///
/// Il tient la même promesse que `Link`, que `Relais` et que `Arene` — c'est
/// tout l'objet du protocole `Fil` — mais il passe par la mémoire, et l'on
/// peut le couper d'un booléen. C'est la seule façon d'éprouver une coupure
/// sans en provoquer une vraie.
@MainActor
final class FilFactice: Fil {

    let moi: Pair
    var relies: [Pair] = []
    var jeSuisLHote: Bool
    /// Un fil d'essai se retrouve par son nom : c'est ce qui permet
    /// d'éprouver le rangement d'une partie au loin sans vrai salon.
    var codeDeReprise: String?

    var onReceive: ((Data, Pair) -> Void)?
    var onConnected: ((Bool, Pair) -> Void)?
    var onLiaison: ((Liaison) -> Void)?

    /// L'autre bout du fil.
    weak var enFace: FilFactice?
    /// Coupé : ce qui part pendant ce temps-là est perdu, exactement comme
    /// sur un vrai fil — sans erreur, sans accusé, sans rien.
    var coupe = false
    /// Tout ce qui est parti d'ici, dans l'ordre.
    private(set) var envoyes: [Message] = []

    init(_ nom: String, hote: Bool) {
        moi = Pair(id: nom, nom: nom)
        jeSuisLHote = hote
    }

    /// Relier deux faux appareils l'un à l'autre.
    static func paire() -> (hote: FilFactice, invite: FilFactice) {
        let h = FilFactice("hote", hote: true)
        let i = FilFactice("invite", hote: false)
        h.enFace = i; i.enFace = h
        h.relies = [i.moi]; i.relies = [h.moi]
        return (h, i)
    }

    /// La coupure, des deux côtés.
    func couper() {
        coupe = true
        enFace?.coupe = true
    }

    /// Le retour. C'est `onConnected` qui rejoue, et rien d'autre : c'est
    /// exactement ce que font le vrai salon et le vrai Game Center quand un
    /// appareil réapparaît.
    func retablir() {
        coupe = false
        enFace?.coupe = false
        if let enFace {
            onConnected?(jeSuisLHote, enFace.moi)
            enFace.onConnected?(enFace.jeSuisLHote, moi)
        }
    }

    func envoyer(_ data: Data) { livrer(data) }
    func envoyer(_ data: Data, a pair: Pair) { livrer(data) }
    /// À deux appareils, « tous sauf un » ne désigne personne.
    func envoyer(_ data: Data, saufA pair: Pair) {
        guard pair != enFace?.moi else { noter(data); return }
        livrer(data)
    }

    func fermerLaTable() {}
    func arreter() {}

    private func noter(_ data: Data) {
        if case let .message(m) = Message.lire(data) { envoyes.append(m) }
    }

    private func livrer(_ data: Data) {
        noter(data)
        guard !coupe, let enFace, !enFace.coupe else { return }
        enFace.onReceive?(data, moi)
    }
}

// MARK: -

@MainActor
struct LoinTests {

    private func partieNeuve(_ joueurs: Int = 2) -> GameState {
        GameState.start(board: .anneau,
                        players: (0..<joueurs).map { Player(id: $0, name: "J\($0)") },
                        rules: Rules(), seed: 11)
    }

    // MARK: - Le code

    /// Un code se dicte au téléphone autant qu'il se colle dans WhatsApp.
    /// Consonne, voyelle, consonne, voyelle, consonne, voyelle — et rien
    /// d'autre, sans quoi « MARENO » devient « X7KQ2V » et se fait répéter
    /// trois fois.
    @Test func unCodeSAlterneEtSeLit() {
        #expect(Relais.estUnCode("MARENO"))
        #expect(Relais.estUnCode("BABEBI"))
        // Deux consonnes de suite : ce n'est pas la forme d'un code.
        #expect(!Relais.estUnCode("MMRENO"))
        // Trop court, trop long.
        #expect(!Relais.estUnCode("MAREN"))
        #expect(!Relais.estUnCode(""))
        // Les lettres qu'on n'emploie pas, faute de les entendre.
        #expect(!Relais.estUnCode("QAREHO"))
        #expect(!Relais.estUnCode("WAREYO"))
    }

    /// Le zéro et la lettre O, le un et le I : personne ne les distingue à
    /// l'écrit. Les refuser renverrait « ce code n'existe pas » à quelqu'un
    /// qui a tapé exactement ce qu'il voyait.
    @Test func leZeroEtLaLettreOSeValent() {
        #expect(Relais.normaliser("mare n0") == "MARENO")
        #expect(Relais.normaliser("B1RENO") == "BIRENO")
        #expect(Relais.estUnCode("mar3n0") == false)   // le 3 n'est pas redressé
        #expect(Relais.estUnCode("  mareno  "))
    }

    /// Ce qu'on colle depuis WhatsApp n'est jamais le code tout nu.
    @Test func ceQuOnColleEstNettoye() {
        #expect(Relais.normaliser("le code est MARENO !") == "LECODE")
        #expect(Relais.normaliser("MARENOPQRS") == "MARENO")
        #expect(Relais.normaliser("riskelo://p/mareno").hasPrefix("RISKEL"))
    }

    /// Le lien qu'on partage désigne bien le salon, et par une adresse que
    /// WhatsApp acceptera de rendre cliquable.
    @Test func leLienPorteLeCode() {
        let lien = Relais.lien(pour: "MARENO")
        #expect(lien?.scheme == "https")
        #expect(lien?.path == "/p/MARENO")
    }

    // MARK: - La mise en place, commune aux trois fils

    /// Chacun dit son nom en arrivant, sans qu'on le lui demande.
    @Test func chacunDitSonNomEnArrivant() {
        let (hote, invite) = FilFactice.paire()
        MiseEnPlace.preparer(hote, nomVu: { _, _ in }, partieRecue: { _, _, _ in },
                             desaccord: { })
        MiseEnPlace.preparer(invite, nomVu: { _, _ in }, partieRecue: { _, _, _ in },
                             desaccord: { })

        hote.onConnected?(true, invite.moi)
        guard case let .bonjour(nom)? = hote.envoyes.last else {
            Issue.record("aucun salut n'est parti"); return
        }
        #expect(nom == (Pseudo.actuel ?? ""))
    }

    /// Le nom traverse, et arrive nommé.
    @Test func leNomTraverseLeFil() {
        let (hote, invite) = FilFactice.paire()
        var vus: [Pair: String?] = [:]
        MiseEnPlace.preparer(hote, nomVu: { p, n in vus[p] = n },
                             partieRecue: { _, _, _ in }, desaccord: { })
        MiseEnPlace.preparer(invite, nomVu: { _, _ in },
                             partieRecue: { _, _, _ in }, desaccord: { })

        invite.envoyer(Message.bonjour(nom: "Marie").data!)
        #expect(vus[invite.moi] == "Marie")

        // Un nom vide n'est pas un nom : le camp garde sa couleur pour seul
        // nom, et c'est très bien.
        invite.envoyer(Message.bonjour(nom: "").data!)
        #expect(vus[invite.moi] == .some(nil))
    }

    /// Un coup arrivé **avant** la partie n'est pas un désaccord de version.
    ///
    /// C'est la panne que ce test garde : tout ce qui n'était pas la partie
    /// était compté pour un désaccord, et un paquet arrivé une fraction de
    /// seconde trop tôt affichait « Versions différentes » à deux appareils
    /// parfaitement d'accord.
    @Test func unCoupEnAvanceNEstPasUnDesaccord() {
        let (hote, invite) = FilFactice.paire()
        var crie = false
        MiseEnPlace.preparer(hote, nomVu: { _, _ in }, partieRecue: { _, _, _ in },
                             desaccord: { crie = true })
        MiseEnPlace.preparer(invite, nomVu: { _, _ in }, partieRecue: { _, _, _ in },
                             desaccord: { })

        invite.envoyer(Message.coup(.endTurn, numero: 1, empreinte: 0).data!)
        #expect(!crie)
    }

    /// Un paquet d'une autre version, lui, doit crier.
    @Test func uneAutreVersionCrie() {
        let (hote, _) = FilFactice.paire()
        var crie = false
        MiseEnPlace.preparer(hote, nomVu: { _, _ in }, partieRecue: { _, _, _ in },
                             desaccord: { crie = true })

        hote.onReceive?(Data("{\"dialecte\":1,\"message\":{}}".utf8), Pair(id: "x", nom: "x"))
        #expect(crie)
    }

    /// L'hôte distribue les rangs dans l'ordre d'arrivée, et à chacun le sien
    /// seulement.
    @Test func lHoteDonneUnRangAChacunEtLeSienSeulement() {
        let (hote, invite) = FilFactice.paire()
        let session = MiseEnPlace.lancer(hote, joueurs: 2, plateau: .anneau,
                                         regles: Rules(), noms: [invite.moi: "Marie"])
        #expect(session.monRang == 0)

        guard case let .partie(etat, rang, numero)? = hote.envoyes.last else {
            Issue.record("la partie n'est pas partie"); return
        }
        #expect(rang == 1)
        #expect(numero == 0)
        // Les deux appareils tiennent exactement la même partie. C'est la
        // seule chose qui rende le reste possible : ensuite, on n'échange
        // plus que les coups.
        #expect(etat.digest == session.game.digest)
    }

    /// Le nom de chacun part **avec** l'état, et non à côté.
    ///
    /// C'est ce qui garantit que les quatre appareils voient les mêmes
    /// joueurs. Envoyé à part, il arriverait avant chez l'un et après chez
    /// l'autre.
    @Test func leNomEstDansLesCampsQuiPartent() {
        let (hote, invite) = FilFactice.paire()
        let session = MiseEnPlace.lancer(hote, joueurs: 2, plateau: .anneau,
                                         regles: Rules(), noms: [invite.moi: "Marie"])
        let camp = Boards.nomDeCamp(1)
        #expect(session.game.players[1].name == "\(camp) · Marie")

        guard case let .partie(etat, _, _)? = hote.envoyes.last else {
            Issue.record("la partie n'est pas partie"); return
        }
        #expect(etat.players[1].name == "\(camp) · Marie")
    }

    /// Sans nom donné, le camp garde sa couleur — et rien de plus.
    @Test func sansNomLeCampResteUneCouleur() {
        let (hote, _) = FilFactice.paire()
        let session = MiseEnPlace.lancer(hote, joueurs: 2, plateau: .anneau,
                                         regles: Rules(), noms: [:])
        #expect(session.game.players[1].name == Boards.nomDeCamp(1))
    }

    // MARK: - La coupure, et le retour

    /// Un fil coupé ne dit rien. C'est précisément ce qui le rend dangereux.
    @Test func rienNeTraverseUnFilCoupe() {
        let (hote, invite) = FilFactice.paire()
        var recu = 0
        invite.onReceive = { _, _ in recu += 1 }

        hote.envoyer(Message.perdu.data!)
        #expect(recu == 1)

        hote.couper()
        hote.envoyer(Message.perdu.data!)
        #expect(recu == 1)   // parti d'ici, arrivé nulle part
    }

    /// Le retour, côté hôte : il renvoie la partie entière, sans qu'on la lui
    /// demande.
    ///
    /// C'est tout le mécanisme de la reprise, et il n'a demandé **aucun
    /// message nouveau** : `partie` existait pour la poignée de main.
    @Test func auRetourLHoteRenvoieLaPartie() {
        let (hote, invite) = FilFactice.paire()
        let partie = partieNeuve()
        let session = GameSession(fil: hote, heberge: true, game: partie,
                                  monRang: 0, rangs: [invite.moi: 1], compteur: 3)
        hote.couper()
        hote.retablir()

        guard case let .partie(etat, rang, numero)? = hote.envoyes.last else {
            Issue.record("la partie n'a pas été renvoyée"); return
        }
        #expect(rang == 1)
        // Le compte des coups part avec elle : sans lui, celui qui revient
        // croirait la partie neuve et refuserait le coup suivant.
        #expect(numero == 3)
        #expect(etat.digest == session.game.digest)
    }

    /// Le retour, côté invité : il redemande la partie, au cas où celui d'en
    /// face n'aurait pas vu qu'il était parti.
    @Test func auRetourLInviteRedemandeLaPartie() {
        let (hote, invite) = FilFactice.paire()
        // La partie est gardée dans une variable, et ce n'est pas de la
        // coquetterie : `Fil.onConnected` la retient faiblement — sans quoi
        // le fil et la partie se tiendraient l'un l'autre pour toujours. Une
        // partie qu'on ne garde pas disparaît donc entre sa naissance et la
        // ligne suivante, et le rappel ne trouve plus personne.
        let session = GameSession(fil: invite, heberge: false, game: partieNeuve(),
                                  monRang: 1, compteur: 0)
        invite.couper()
        invite.retablir()

        #expect(invite.envoyes.contains { if case .perdu = $0 { return true }; return false })
        #expect(session.liaison == .tenue)
        _ = hote
    }

    /// Une coupure n'est pas une partie finie, et l'écran ne doit pas le dire.
    @Test func uneCoupureNEstPasUnePerte() {
        // L'hôte est gardé bien qu'on ne s'en serve pas : `enFace` est une
        // référence faible, et le jeter couperait le fil pour de bon.
        let (hote, invite) = FilFactice.paire()
        defer { _ = hote }
        let session = GameSession(fil: invite, heberge: false, game: partieNeuve(),
                                  monRang: 1, compteur: 0)
        #expect(session.liaison == .tenue)

        let quand = Date()
        invite.onLiaison?(.rompue(depuis: quand))
        #expect(session.liaison == .rompue(depuis: quand))

        invite.retablir()
        #expect(session.liaison == .tenue)
    }

    /// On ne joue pas dans le vide.
    ///
    /// Sans ce garde, un coup joué pendant que la liaison est tombée est
    /// appliqué ici et n'arrive nulle part. L'appareil se remet d'aplomb au
    /// retour — l'hôte renvoie la partie, qui fait foi — mais le joueur
    /// aurait vu son coup s'effacer sous ses yeux.
    @Test func onNeJouePasPendantUneCoupure() {
        let (hote, invite) = FilFactice.paire()
        var partie = partieNeuve()
        partie.debugSkipToAttack()
        let session = GameSession(fil: hote, heberge: true, game: partie,
                                  monRang: 0, rangs: [invite.moi: 1], compteur: 0)
        #expect(session.aMoiDeJouer)

        hote.onLiaison?(.rompue(depuis: Date()))
        #expect(!session.aMoiDeJouer)

        hote.retablir()
        #expect(session.aMoiDeJouer)
    }

    // MARK: - Se retrouver une autre fois

    /// Reprendre n'est pas recommencer : la partie repart telle quelle, à son
    /// tour, avec les mêmes camps et le même compte de coups.
    @Test func laPartieReprisePartDOuElleEtait() {
        let (hote, invite) = FilFactice.paire()
        var partie = partieNeuve()
        partie.debugSkipToAttack()
        let identite = UUID()

        let session = MiseEnPlace.reprendre(hote, partie: partie,
                                            rangs: [invite.moi: 1], compteur: 12,
                                            partieID: identite)

        #expect(session.game.digest == partie.digest, "ce n'est pas la même partie")
        #expect(session.monRang == 0, "celui qui héberge garde son camp")
        #expect(session.partieID == identite,
                "trois soirées ne doivent pas faire trois parties dans la bibliothèque")
        // Et chacun reçoit la partie, avec son rang : sans cela l'autre
        // appareil attend un lancement qui n'arrive jamais.
        let recue = hote.envoyes.compactMap { message -> (PlayerID, Int)? in
            guard case let .partie(_, rang, numero) = message else { return nil }
            return (rang, numero)
        }
        #expect(recue.count == 1)
        #expect(recue.first?.0 == 1)
        #expect(recue.first?.1 == 12, "le compte des coups repart de là où on s'est quittés")
    }

    /// Le rendez-vous se périme, et il emporte la partie avec lui : rendue
    /// sans son fil, elle ouvrirait les deux camps sur un seul téléphone.
    @Test func unRendezVousPerimeNeVautPlus() {
        let frais = RendezVous(code: "MARENO", jHeberge: true, monRang: 0, compteur: 3,
                               rangs: ["marie": 1], partieID: UUID(), quand: Date())
        #expect(!frais.perime)
        #expect(frais.attendus == ["marie"])

        let vieux = RendezVous(code: "MARENO", jHeberge: true, monRang: 0, compteur: 3,
                               rangs: ["marie": 1], partieID: UUID(),
                               quand: Date().addingTimeInterval(-RendezVous.dureeDeVie - 60))
        #expect(vieux.perime)
    }

    // MARK: - Quand les deux parties divergent

    /// L'hôte ne demande pas la partie : il la donne.
    ///
    /// C'est le défaut qui figeait le téléphone de celui qui avait ouvert la
    /// table, au bout de quelques assauts. Un coup manquant, ou un coup qui ne
    /// donne pas la partie annoncée, et l'hôte envoyait `Message.perdu` —
    /// qu'il est le seul au monde à savoir écouter. Personne ne lui répondait
    /// jamais, son compteur restait décalé, les coups d'en face étaient
    /// ignorés un à un sans que rien ne paraisse, et l'écran ne bougeait plus.
    ///
    /// Rien ici ne fait bouger la partie : un coup qu'on refuse n'est pas
    /// appliqué, et c'est justement ce qu'on vérifie.
    @Test func lHoteQuiPerdLeFilImposeSaPartie() {
        let (hote, invite) = FilFactice.paire()
        let partie = partieNeuve()
        let session = GameSession(fil: hote, heberge: true, game: partie,
                                  monRang: 0, rangs: [invite.moi: 1], compteur: 0)

        // Le coup numéro 3 alors qu'on en attendait le premier : il en manque
        // deux, et l'hôte ne peut pas les deviner.
        let troue = Message.coup(.advance, numero: 3, empreinte: 0).data!
        hote.onReceive?(troue, invite.moi)

        #expect(hote.envoyes.contains { if case .partie = $0 { return true } else { return false } },
                "l'hôte doit renvoyer sa partie, qui fait foi")
        #expect(!hote.envoyes.contains { if case .perdu = $0 { return true } else { return false } },
                "l'hôte n'a personne à qui la demander")
        #expect(session.game.digest == partie.digest, "un coup refusé ne s'applique pas")
    }

    /// Un coup qui ne donne pas la partie annoncée n'est pas joué.
    ///
    /// Il l'était, et la vérification venait après : l'appareil gardait donc
    /// un coup qu'il savait faux, en plus de ne pas savoir s'en défaire.
    @Test func unCoupQuiDivergeNeSApplique() {
        let (hote, invite) = FilFactice.paire()
        let partie = partieNeuve()
        let session = GameSession(fil: hote, heberge: true, game: partie,
                                  monRang: 0, rangs: [invite.moi: 1], compteur: 0)

        // Le bon numéro, mais une empreinte qui ne peut pas être la sienne.
        let faux = Message.coup(.advance, numero: 1, empreinte: 1).data!
        hote.onReceive?(faux, invite.moi)

        #expect(session.game.digest == partie.digest)
        #expect(hote.envoyes.contains { if case .partie = $0 { return true } else { return false } })
    }

    /// Deux coups au même rang : l'hôte redonne la partie plutôt que de se
    /// taire.
    ///
    /// Il se taisait — le numéro était déjà pris, donc le coup passait pour un
    /// doublon de relais. Mais l'hôte ne reçoit jamais de relais. Celui d'en
    /// face, lui, croyait avoir joué et attendait la suite : les deux écrans
    /// s'arrêtaient là, chacun attendant l'autre.
    @Test func deuxCoupsAuMemeRangNeSePerdentPas() {
        let (hote, invite) = FilFactice.paire()
        let partie = partieNeuve()
        let session = GameSession(fil: hote, heberge: true, game: partie,
                                  monRang: 0, rangs: [invite.moi: 1], compteur: 4)

        let enRetard = Message.coup(.advance, numero: 4, empreinte: 0).data!
        hote.onReceive?(enRetard, invite.moi)

        #expect(hote.envoyes.contains { if case .partie = $0 { return true } else { return false } })
        #expect(session.game.digest == partie.digest)
    }

    /// Celui qui a rejoint, lui, demande — et ne renvoie surtout pas la
    /// sienne : c'est la partie de l'hôte qui fait foi, sans quoi deux
    /// appareils se renverraient chacun sa version sans fin.
    @Test func lInviteQuiPerdLeFilRedemandeLaPartie() {
        let (hote, invite) = FilFactice.paire()
        defer { _ = hote }
        let partie = partieNeuve()
        let session = GameSession(fil: invite, heberge: false, game: partie,
                                  monRang: 1, compteur: 0)

        let troue = Message.coup(.advance, numero: 3, empreinte: 0).data!
        invite.onReceive?(troue, hote.moi)

        #expect(invite.envoyes.count == 1)
        #expect(invite.envoyes.contains { if case .perdu = $0 { return true } else { return false } })
        #expect(session.game.digest == partie.digest)
    }

    // Il n'y a pas de test du cas « hors réseau » ici, et c'est délibéré :
    // toutes les autres façons d'ouvrir une `GameSession` écrivent sur le
    // disque dès leur naissance — `GameStore.shared.saveID` et l'archivage de
    // l'ouverture. Le test aurait coûté la partie en cours de celui qui lance
    // les tests, pour vérifier un `!enReseau ||` qui se lit à l'œil nu.
}
