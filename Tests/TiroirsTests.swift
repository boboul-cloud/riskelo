//
//  TiroirsTests.swift
//  RiskeloTests
//
//  Les deux tiroirs : celui d'ici, et celui du loin.
//
//  Ils n'en faisaient qu'un, et chacune des deux parties chassait l'autre. On
//  ouvrait une partie contre la machine un soir de semaine, et la partie
//  commencée avec sa sœur disparaissait avec son rendez-vous — sans rien dire,
//  et sans qu'on puisse la retrouver autrement que par la bibliothèque.
//
//  Rien ici ne touche au vrai dossier de l'application : chaque essai range
//  dans un dossier à lui, qu'il jette en partant. C'est ce que la porte de
//  `GameStore(dossier:)` a rendu possible.
//

import Foundation
import Testing
@testable import Riskelo

@MainActor
struct TiroirsTests {

    /// Un dossier neuf, effacé à la fin.
    private func dansUnCoin(_ essai: (GameStore, URL) throws -> Void) rethrows {
        let coin = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("riskelo-essai-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: coin) }
        try essai(GameStore(dossier: coin), coin)
    }

    private func partie() -> GameState {
        GameState.start(board: .anneau,
                        players: [Player(id: 0, name: "J0"), Player(id: 1, name: "J1")],
                        rules: Rules(), seed: 11)
    }

    private func rendezVous(_ code: String = "MARENO", quand: Date = Date(),
                           contre: [String] = ["Rouge · Marie"], tour: Int = 3) -> RendezVous {
        RendezVous(code: code, jHeberge: true, monRang: 0, compteur: 4,
                   rangs: ["marie": 1], partieID: UUID(), quand: quand,
                   contre: contre, tour: tour)
    }

    /// Ranger une partie au loin, avec son rendez-vous, en une fois.
    private func poser(_ tiroirs: GameStore, _ rendezVous: RendezVous) {
        tiroirs.save(partie(), dans: .auLoin(code: rendezVous.code))
        tiroirs.saveRendezVous(rendezVous)
    }

    // MARK: - Plusieurs parties au loin

    /// Deux amis, deux parties, et elles ne se connaissent pas.
    ///
    /// Elles tenaient dans le même fichier : ouvrir une partie avec Paul
    /// effaçait celle de Marie, rendez-vous compris et sans rien dire.
    @Test func deuxPartiesAuLoinTiennentEnsemble() throws {
        dansUnCoin { tiroirs, _ in
            poser(tiroirs, rendezVous("MARENO", contre: ["Rouge · Marie"]))
            poser(tiroirs, rendezVous("VABETO", contre: ["Rouge · Paul", "Vert · Léa"]))

            let liste = tiroirs.partiesAuLoin()
            #expect(liste.count == 2)
            #expect(Set(liste.map(\.code)) == ["MARENO", "VABETO"])
            #expect(tiroirs.rendezVous("MARENO")?.contre == ["Rouge · Marie"])
            #expect(tiroirs.rendezVous("VABETO")?.contre.count == 2)
        }
    }

    /// La dernière jouée en tête : c'est celle qu'on vient reprendre.
    @Test func laDerniereJoueeEstEnTete() throws {
        dansUnCoin { tiroirs, _ in
            poser(tiroirs, rendezVous("MARENO", quand: Date().addingTimeInterval(-86_400)))
            poser(tiroirs, rendezVous("VABETO", quand: Date()))
            poser(tiroirs, rendezVous("SODIRA", quand: Date().addingTimeInterval(-3_600)))

            #expect(tiroirs.partiesAuLoin().map(\.code) == ["VABETO", "SODIRA", "MARENO"])
        }
    }

    /// En abandonner une ne touche pas aux autres.
    @Test func abandonnerUnePartieLaisseLesAutres() throws {
        dansUnCoin { tiroirs, _ in
            poser(tiroirs, rendezVous("MARENO"))
            poser(tiroirs, rendezVous("VABETO"))
            tiroirs.save(partie(), dans: .ici)

            tiroirs.discard(.auLoin(code: "MARENO"))

            #expect(tiroirs.partiesAuLoin().map(\.code) == ["VABETO"])
            #expect(tiroirs.rendezVous("MARENO") == nil)
            #expect(tiroirs.has(.ici), "et surtout pas à celle d'ici")
        }
    }

    /// Une partie périmée s'efface, les autres restent.
    @Test func seuleLaPerimeeSEfface() throws {
        dansUnCoin { tiroirs, _ in
            poser(tiroirs, rendezVous("MARENO"))
            poser(tiroirs, rendezVous("VABETO",
                                      quand: Date().addingTimeInterval(-RendezVous.dureeDeVie - 60)))

            #expect(tiroirs.partiesAuLoin().map(\.code) == ["MARENO"])
            #expect(!tiroirs.has(.auLoin(code: "VABETO")))
            #expect(tiroirs.has(.auLoin(code: "MARENO")))
        }
    }

    /// Un rendez-vous sans sa partie ne mène nulle part : on le balaie plutôt
    /// que de proposer une ligne qui ne s'ouvre pas.
    @Test func unRendezVousOrphelinNeSePropose() throws {
        dansUnCoin { tiroirs, _ in
            tiroirs.saveRendezVous(rendezVous("MARENO"))
            #expect(tiroirs.partiesAuLoin().isEmpty)
        }
    }

    /// Un rendez-vous d'avant ne dit pas contre qui l'on joue. Il se complète
    /// tout seul au premier regard, en lisant sa partie — sinon la liste
    /// afficherait « Partie à plusieurs · tour 1 » autant de fois qu'il y a de
    /// parties, ce qui est exactement ce qu'elle existe pour éviter.
    @Test func unRendezVousDAvantSeCompleteToutSeul() throws {
        dansUnCoin { tiroirs, _ in
            var avancee = partie()
            avancee.debugSkipToAttack()
            tiroirs.save(avancee, dans: .auLoin(code: "MARENO"))
            tiroirs.saveRendezVous(rendezVous("MARENO", contre: [], tour: 1))

            let liste = tiroirs.partiesAuLoin()
            #expect(liste.first?.contre == ["J1"], "le camp d'en face, lu dans la partie")
            #expect(liste.first?.tour == avancee.turn)
            // Et réécrit : la fois d'après, il n'y a plus rien à lire.
            #expect(tiroirs.rendezVous("MARENO")?.contre == ["J1"])
        }
    }

    /// Un rendez-vous écrit par la version d'avant n'a ni le nom de l'autre ni
    /// le tour. Il doit se relire quand même — sinon la mise à jour coûte la
    /// partie en cours.
    @Test func unRendezVousDAvantSeRelitQuandMeme() throws {
        let ancien = """
            {"code":"MARENO","jHeberge":true,"monRang":0,"compteur":4,
             "rangs":{"marie":1},"partieID":"\(UUID().uuidString)",
             "quand":\(Date().timeIntervalSinceReferenceDate)}
            """
        let lu = try JSONDecoder().decode(RendezVous.self, from: Data(ancien.utf8))
        #expect(lu.code == "MARENO")
        #expect(lu.contre.isEmpty)
        #expect(lu.tour == 1)
    }


    /// Les deux attendent en même temps, et ne se voient pas.
    @Test func lesDeuxPartiesAttendentCoteACote() throws {
        dansUnCoin { tiroirs, _ in
            var duLoin = partie()
            duLoin.debugSkipToAttack()

            tiroirs.save(partie(), dans: .ici)
            tiroirs.save(duLoin, dans: .auLoin(code: "MARENO"))
            tiroirs.saveRendezVous(rendezVous())

            #expect(tiroirs.has(.ici))
            #expect(tiroirs.has(.auLoin(code: "MARENO")))
            #expect(tiroirs.load(.ici)?.digest == partie().digest)
            #expect(tiroirs.load(.auLoin(code: "MARENO"))?.digest == duLoin.digest)
            #expect(tiroirs.rendezVous("MARENO")?.code == "MARENO")
        }
    }

    /// Finir une partie ici ne touche pas à celle qui attend au loin.
    @Test func finirIciNeTouchePasAuLoin() throws {
        dansUnCoin { tiroirs, _ in
            tiroirs.save(partie(), dans: .ici)
            tiroirs.save(partie(), dans: .auLoin(code: "MARENO"))
            tiroirs.saveRendezVous(rendezVous())

            tiroirs.discard(.ici)

            #expect(!tiroirs.has(.ici))
            #expect(tiroirs.has(.auLoin(code: "MARENO")), "la partie au loin n'a rien à voir avec celle-ci")
            #expect(tiroirs.rendezVous("MARENO") != nil, "et son rendez-vous non plus")
        }
    }

    /// Le tiroir du loin, lui, emporte son rendez-vous : l'un sans l'autre ne
    /// mène nulle part.
    @Test func leLoinEmporteSonRendezVous() throws {
        dansUnCoin { tiroirs, _ in
            tiroirs.save(partie(), dans: .ici)
            tiroirs.save(partie(), dans: .auLoin(code: "MARENO"))
            tiroirs.saveRendezVous(rendezVous())

            tiroirs.discard(.auLoin(code: "MARENO"))

            #expect(tiroirs.rendezVous("MARENO") == nil)
            #expect(tiroirs.has(.ici), "celle d'ici reste")
        }
    }

    /// Un rendez-vous périmé emporte sa partie, et elle seule.
    @Test func unRendezVousPerimeNEmporteQueLaSienne() throws {
        dansUnCoin { tiroirs, _ in
            tiroirs.save(partie(), dans: .ici)
            tiroirs.save(partie(), dans: .auLoin(code: "MARENO"))
            tiroirs.saveRendezVous(
                RendezVous(code: "MARENO", jHeberge: true, monRang: 0, compteur: 4,
                           rangs: ["marie": 1], partieID: UUID(),
                           quand: Date().addingTimeInterval(-RendezVous.dureeDeVie - 60)))

            #expect(tiroirs.rendezVous("MARENO") == nil)
            #expect(!tiroirs.has(.auLoin(code: "MARENO")), "une partie au loin sans code ne se joue pas")
            #expect(tiroirs.has(.ici))
        }
    }

    /// Ce qui dormait dans les rangements d'avant déménage tout seul.
    ///
    /// La partie au loin n'était qu'une, et elle a dormi à deux endroits avant
    /// celui-ci : d'abord dans le tiroir d'ici avec son rendez-vous posé à
    /// côté, puis dans un tiroir « partie-au-loin » unique. Sans ce
    /// déménagement, elle serait rendue par le bouton d'ici — donc sans son
    /// fil, les deux camps sur un seul téléphone — ou perdue tout court.
    @Test func lesAnciensRangementsDemenagent() throws {
        for ancienNom in ["partie-en-cours", "partie-au-loin"] {
            try dansUnCoin { tiroirs, coin in
                var avant = partie()
                avant.debugSkipToAttack()
                let garde = rendezVous("MARENO")

                // L'état d'avant, écrit tel qu'il l'était : la partie sous son
                // ancien nom, le rendez-vous seul à la racine.
                try JSONEncoder().encode(avant).write(
                    to: coin.appendingPathComponent("\(ancienNom).json"))
                try JSONEncoder().encode(garde).write(
                    to: coin.appendingPathComponent("rendez-vous.json"))

                // Le premier regard suffit à ranger.
                #expect(tiroirs.partiesAuLoin().map(\.code) == ["MARENO"],
                        "déménagement depuis « \(ancienNom) »")
                #expect(tiroirs.load(.auLoin(code: "MARENO"))?.digest == avant.digest)
                #expect(tiroirs.rendezVous("MARENO")?.partieID == garde.partieID)
                #expect(!FileManager.default.fileExists(
                    atPath: coin.appendingPathComponent("rendez-vous.json").path),
                        "l'ancien rendez-vous ne traîne plus")
            }
        }
    }

    /// Une partie d'ici qui dort à côté d'une partie au loin ne déménage pas
    /// avec elle. C'est le cas de celui qui jouait les deux.
    @Test func lePlusAncienRangementNEmportePasLaPartieDIci() throws {
        try dansUnCoin { tiroirs, coin in
            var duLoin = partie()
            duLoin.debugSkipToAttack()

            // L'étape intermédiaire : chacune son fichier, un seul rendez-vous.
            try JSONEncoder().encode(partie()).write(
                to: coin.appendingPathComponent("partie-en-cours.json"))
            try JSONEncoder().encode(duLoin).write(
                to: coin.appendingPathComponent("partie-au-loin.json"))
            try JSONEncoder().encode(rendezVous("MARENO")).write(
                to: coin.appendingPathComponent("rendez-vous.json"))

            #expect(tiroirs.load(.auLoin(code: "MARENO"))?.digest == duLoin.digest)
            #expect(tiroirs.has(.ici), "celle d'ici reste chez elle")
            #expect(tiroirs.load(.ici)?.digest == partie().digest)
        }
    }

    /// Et une partie d'ici, sans rendez-vous, ne déménage pas.
    @Test func unePartieDIciResteChezElle() throws {
        dansUnCoin { tiroirs, _ in
            tiroirs.save(partie(), dans: .ici)
            #expect(tiroirs.load(.auLoin(code: "MARENO")) == nil)
            #expect(tiroirs.has(.ici))
        }
    }
}
