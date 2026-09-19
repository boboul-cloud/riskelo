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

    private func rendezVous(_ code: String = "MARENO") -> RendezVous {
        RendezVous(code: code, jHeberge: true, monRang: 0, compteur: 4,
                   rangs: ["marie": 1], partieID: UUID(), quand: Date())
    }

    /// Les deux attendent en même temps, et ne se voient pas.
    @Test func lesDeuxPartiesAttendentCoteACote() throws {
        dansUnCoin { tiroirs, _ in
            var duLoin = partie()
            duLoin.debugSkipToAttack()

            tiroirs.save(partie(), dans: .ici)
            tiroirs.save(duLoin, dans: .auLoin)
            tiroirs.saveRendezVous(rendezVous())

            #expect(tiroirs.has(.ici))
            #expect(tiroirs.has(.auLoin))
            #expect(tiroirs.load(.ici)?.digest == partie().digest)
            #expect(tiroirs.load(.auLoin)?.digest == duLoin.digest)
            #expect(tiroirs.loadRendezVous()?.code == "MARENO")
        }
    }

    /// Finir une partie ici ne touche pas à celle qui attend au loin.
    @Test func finirIciNeTouchePasAuLoin() throws {
        dansUnCoin { tiroirs, _ in
            tiroirs.save(partie(), dans: .ici)
            tiroirs.save(partie(), dans: .auLoin)
            tiroirs.saveRendezVous(rendezVous())

            tiroirs.discard(.ici)

            #expect(!tiroirs.has(.ici))
            #expect(tiroirs.has(.auLoin), "la partie au loin n'a rien à voir avec celle-ci")
            #expect(tiroirs.loadRendezVous() != nil, "et son rendez-vous non plus")
        }
    }

    /// Le tiroir du loin, lui, emporte son rendez-vous : l'un sans l'autre ne
    /// mène nulle part.
    @Test func leLoinEmporteSonRendezVous() throws {
        dansUnCoin { tiroirs, _ in
            tiroirs.save(partie(), dans: .ici)
            tiroirs.save(partie(), dans: .auLoin)
            tiroirs.saveRendezVous(rendezVous())

            tiroirs.discard(.auLoin)

            #expect(tiroirs.loadRendezVous() == nil)
            #expect(tiroirs.has(.ici), "celle d'ici reste")
        }
    }

    /// Un rendez-vous périmé emporte sa partie, et elle seule.
    @Test func unRendezVousPerimeNEmporteQueLaSienne() throws {
        dansUnCoin { tiroirs, _ in
            tiroirs.save(partie(), dans: .ici)
            tiroirs.save(partie(), dans: .auLoin)
            tiroirs.saveRendezVous(
                RendezVous(code: "MARENO", jHeberge: true, monRang: 0, compteur: 4,
                           rangs: ["marie": 1], partieID: UUID(),
                           quand: Date().addingTimeInterval(-RendezVous.dureeDeVie - 60)))

            #expect(tiroirs.loadRendezVous() == nil)
            #expect(!tiroirs.has(.auLoin), "une partie au loin sans code ne se joue pas")
            #expect(tiroirs.has(.ici))
        }
    }

    /// Ce qui dormait dans l'ancien tiroir unique déménage tout seul.
    ///
    /// Une partie au loin y était rangée avec son rendez-vous posé à côté.
    /// Sans ce déménagement, elle serait rendue par le bouton d'ici — donc
    /// sans son fil, les deux camps sur un seul téléphone.
    @Test func lAncienneSauvegardeAuLoinDemenage() throws {
        dansUnCoin { tiroirs, coin in
            var avant = partie()
            avant.debugSkipToAttack()
            let identite = UUID()

            // L'état d'avant : tout dans « partie-en-cours », rendez-vous à côté.
            tiroirs.save(avant, dans: .ici)
            tiroirs.saveID(identite, dans: .ici)
            tiroirs.saveRendezVous(rendezVous())

            // Le premier regard suffit à ranger.
            #expect(tiroirs.load(.auLoin)?.digest == avant.digest)
            #expect(tiroirs.loadID(.auLoin) == identite)
            #expect(!tiroirs.has(.ici), "elle n'est plus là : elle a déménagé")
            #expect(FileManager.default.fileExists(atPath: coin.path))
        }
    }

    /// Et une partie d'ici, sans rendez-vous, ne déménage pas.
    @Test func unePartieDIciResteChezElle() throws {
        dansUnCoin { tiroirs, _ in
            tiroirs.save(partie(), dans: .ici)
            #expect(tiroirs.load(.auLoin) == nil)
            #expect(tiroirs.has(.ici))
        }
    }
}
