//
//  DeclarationsTests.swift
//  RiskeloTests
//
//  Ce que l'application déclare au système.
//
//  Le jeu à plusieurs appareils ne dépend pas que du code : sans deux entrées
//  dans l'Info.plist, iOS refuse le réseau local, et il le refuse **en
//  silence**. Les appareils continuent de se voir — la découverte passe par le
//  Bluetooth — mais la liaison ne s'établit jamais. Rien dans le code ne peut
//  s'en apercevoir, et aucune compilation n'échoue.
//
//  Ce fichier est là parce que la panne est arrivée : deux dossiers de
//  compilation coexistaient, et l'un contenait une version bâtie sans ces
//  entrées. Un test qui interroge le paquet lui-même l'aurait dit tout de
//  suite.
//

import Foundation
import MultipeerConnectivity
import Testing
@testable import Riskelo

struct DeclarationsTests {

    private var paquet: Bundle { Bundle(for: Link.self) }

    @Test func leReseauLocalEstDeclare() {
        let raison = paquet.object(forInfoDictionaryKey: "NSLocalNetworkUsageDescription")
        // Sans NSLocalNetworkUsageDescription, iOS ne demande jamais
        // l'autorisation et la liaison échoue sans rien dire.
        #expect(raison is String)

        let services = paquet.object(forInfoDictionaryKey: "NSBonjourServices") as? [String]
        #expect(services != nil, "NSBonjourServices manque à l'Info.plist")
        // Le nom du service et sa déclaration doivent aller ensemble : les
        // séparer est une panne muette de plus, et rien ne les relie sinon.
        #expect(services?.contains("_\(Link.service)._tcp") == true)
        #expect(services?.contains("_\(Link.service)._udp") == true)
    }

    /// Bonjour n'accepte pas n'importe quel nom : quinze caractères au plus,
    /// minuscules, chiffres et tirets. Un nom invalide fait échouer la
    /// recherche au démarrage, sans autre signe qu'un rappel qu'on n'écoutait
    /// pas jusqu'ici.
    @Test func leNomDuServiceEstValide() {
        let nom = Link.service
        #expect(!nom.isEmpty && nom.count <= 15)
        let permis = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        let valide = nom.unicodeScalars.allSatisfy { permis.contains($0) }
        #expect(valide, "ce n'est pas un nom de service Bonjour valide")
        #expect(!nom.hasPrefix("-") && !nom.hasSuffix("-"))
    }
}

/// L'identité de l'appareil sur le fil.
@MainActor
struct IdentiteTests {

    /// Elle doit survivre au lancement suivant. Un `MCPeerID` refait à chaque
    /// démarrage laisse le système avec des identités périmées pour le même
    /// appareil : la liaison marche une fois, puis plus jamais.
    @Test func lIdentiteNeChangePasDUnAppelALAutre() {
        let a = Link.identite()
        let b = Link.identite()
        #expect(a == b, "deux appels doivent rendre la même identité")
        #expect(a.displayName == b.displayName)
        #expect(!a.displayName.isEmpty)
    }
}
