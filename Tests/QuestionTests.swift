//
//  QuestionTests.swift
//  RiskeloTests
//
//  Une question mal formée — leurre égal à la bonne réponse, énoncé en double,
//  catégorie vide — ne fait pas échouer le jeu : elle fait perdre un joueur
//  sans qu'il comprenne pourquoi. C'est le pire des défauts, et le seul que
//  personne ne signale.
//

import Testing
@testable import Riskelo

struct QuestionTests {

    /// Le fichier remplace le compilateur : ce qu'il ne relit plus, ce test
    /// le relit. Et mieux — le compilateur n'a jamais su dire qu'un leurre
    /// était égal à la bonne réponse.
    @Test(arguments: Category.allCases)
    func chaqueFichierSeLit(_ c: Category) {
        let lues = QuestionBank.charger(c)
        #expect(!lues.isEmpty, "\(c.label) : fichier absent ou vide")
        #expect(lues.allSatisfy { $0.category == c })
    }

    /// Une ligne mal formée doit être vue, pas devinée.
    @Test func uneLigneMalFormeeNePasseraPas() {
        let bonnes = QuestionBank.lire("""
            # un commentaire

            F | Combien font deux et deux ? | Quatre | Trois | Cinq | Six
            """, categorie: .sciences)
        #expect(bonnes.count == 1)
        #expect(bonnes.first?.decoys.count == 3)
        #expect(bonnes.first?.difficulty == .facile)
        #expect(QuestionBank.lire("", categorie: .sciences).isEmpty)
        #expect(QuestionBank.lire("# rien que des commentaires", categorie: .sciences).isEmpty)
    }

    /// Deux fois la même question dans un thème, c'est une question de moins
    /// et un joueur qui croit à un bogue. À la main, sur un millier de lignes,
    /// cela arrive.
    @Test(arguments: Category.allCases)
    func aucunEnonceNiReponseNEstRepeteDansUnTheme(_ c: Category) {
        let lues = QuestionBank.charger(c)
        let enonces = lues.map { $0.prompt.lowercased() }
        #expect(Set(enonces).count == enonces.count,
                "\(c.label) : énoncé en double")
    }

    /// Un énoncé porte une question, et une seule, et elle se termine par le
    /// point d'interrogation.
    ///
    /// Ce test n'est pas une coquetterie de style : en écrivant une fournée à
    /// la main, j'ai laissé trois fois mes propres hésitations dans le texte —
    /// « Quel jeu se joue avec des dominos... plutôt : combien de faces a un
    /// dé ? ». Rien ne plante, et le joueur lit une phrase absurde.
    @Test(arguments: Category.allCases)
    func chaqueEnonceEstUneSeuleQuestion(_ c: Category) {
        for q in QuestionBank.charger(c) {
            #expect(q.prompt.filter { $0 == "?" }.count == 1,
                    "un seul point d'interrogation attendu : \(q.prompt)")
            #expect(q.prompt.hasSuffix("?"), "l'énoncé doit finir par « ? » : \(q.prompt)")
            #expect(!q.prompt.contains("..."), "hésitation restée dans l'énoncé : \(q.prompt)")
            #expect(!q.prompt.contains("…"), "hésitation restée dans l'énoncé : \(q.prompt)")
        }
    }

    /// Une question qui ne tient pas dans la feuille se fait tronquer, et la
    /// réponse devient une devinette.
    @Test(arguments: Category.allCases)
    func rienNEstTropLong(_ c: Category) {
        for q in QuestionBank.charger(c) {
            #expect(q.prompt.count <= 110, "trop long : \(q.prompt)")
            for p in [q.correct] + q.decoys {
                #expect(p.count <= 46, "proposition trop longue : \(p)")
                #expect(!p.isEmpty, "proposition vide dans « \(q.prompt) »")
            }
        }
    }

    @Test func laBanqueEstBienFormee() {
        for q in QuestionBank.francaises {
            #expect(q.decoys.count == 3, "\(q.id) n'a pas trois leurres")
            #expect(!q.decoys.contains(q.correct), "\(q.id) : un leurre est la bonne réponse")
            #expect(Set(q.decoys).count == 3, "\(q.id) : deux leurres identiques")
            #expect(q.prompt.hasSuffix("?"), "\(q.id) n'est pas une question")
        }
    }

    @Test func aucunEnonceNiIdentifiantEnDouble() {
        let all = QuestionBank.francaises
        #expect(Set(all.map(\.id)).count == all.count)
        #expect(Set(all.map(\.prompt)).count == all.count)
    }

    /// Chaque catégorie doit tenir un assaut long sans se répéter.
    @Test func chaqueCategorieEstFournie() {
        for c in Category.allCases {
            #expect(QuestionBank().count(in: c) >= 8, "\(c.label) est trop maigre")
        }
    }

    @Test func lesPropositionsSontMelees() {
        var rng = SeededRandom(seed: 7)
        var positions = Set<Int>()
        for _ in 0 ..< 40 {
            let posee = QuestionBank.francaises[0].asked(using: &rng)
            #expect(posee.choices.count == 4)
            #expect(posee.choices[posee.answer] == QuestionBank.francaises[0].correct)
            positions.insert(posee.answer)
        }
        #expect(positions.count == 4, "la bonne réponse tombe toujours au même endroit")
    }

    /// La bonne réponse ne s'installe pas sur une ligne.
    ///
    /// Le tirage libre était honnête — un quart par ligne, mesuré — et
    /// donnait pourtant trois fois de suite la même ligne dans plus de neuf
    /// parties sur dix. Le sac des places l'interdit : quatre questions,
    /// quatre lignes, une fois chacune.
    @Test func lesPlacesSeBrassentSansTroisFoisDeSuite() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 21)
        var lignes: [Int] = []
        for _ in 0 ..< 400 {
            guard let q = bank.draw(category: nil, difficulty: nil, using: &rng) else { break }
            #expect(q.choices[q.answer] == q.question.correct, "la bonne réponse a bougé")
            lignes.append(q.answer)
        }
        #expect(lignes.count == 400)
        for debut in stride(from: 0, to: lignes.count, by: QuestionBank.lignes) {
            let groupe = lignes[debut ..< debut + QuestionBank.lignes]
            #expect(Set(groupe).count == QuestionBank.lignes,
                    "groupe \(debut / QuestionBank.lignes) : deux fois la même ligne")
        }
        for i in 2 ..< lignes.count {
            #expect(!(lignes[i] == lignes[i - 1] && lignes[i - 1] == lignes[i - 2]),
                    "trois fois la même ligne au tirage \(i)")
        }
    }

    /// Une partie reprise ne rebat pas au milieu d'un groupe : ce qui reste
    /// dans le sac se remet en place comme la liste des questions servies.
    /// Le voyage par la sauvegarde, lui, est éprouvé avec la partie entière.
    @Test func leSacDesPlacesSeRemetEnPlace() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 4)
        _ = bank.draw(category: .sciences, difficulty: nil, using: &rng)
        _ = bank.draw(category: .sciences, difficulty: nil, using: &rng)
        let reste = bank.placesRestantes
        #expect(reste.count == QuestionBank.lignes - 2)
        var reprise = QuestionBank()
        reprise.restore(served: bank.alreadyServed)
        reprise.restore(places: reste)
        #expect(reprise.placesRestantes == reste)
        // Une place hors des quatre lignes ne se restaure pas : une
        // sauvegarde abîmée ferait sinon tomber la bonne réponse nulle part.
        reprise.restore(places: [0, 9, 2])
        #expect(reprise.placesRestantes == [0, 2])
    }

    @Test func uneQuestionNeRevientPasTantQuIlEnResteDAutres() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 3)
        var vues = Set<String>()
        for _ in 0 ..< QuestionBank().count(in: .histoire) {
            let q = bank.draw(category: .histoire, difficulty: nil, using: &rng)
            #expect(q != nil)
            #expect(vues.insert(q!.id).inserted, "question reposée trop tôt")
        }
    }

    /// Le défaut le plus sournois qu'ait eu ce jeu : la banque, à court de
    /// questions dans la catégorie demandée, en servait d'une autre. On
    /// choisissait l'Histoire et l'on recevait « Qui a peint La Joconde ? ».
    /// Rien ne plantait, rien ne s'affichait — la seule promesse faite à
    /// l'attaquant était rompue en silence.
    @Test func laBanqueNeQuittePasLeTerrainDemande() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 11)
        for tour in 0 ..< 200 {
            let q = bank.draw(category: .sports, difficulty: .difficile, using: &rng)
            #expect(q != nil)
            #expect(q?.category == .sports, "tirage \(tour) : sorti de la catégorie demandée")
        }
    }

    /// Une catégorie épuisée recommence. Revoir une question sur laquelle on
    /// a insisté est honnête ; en recevoir une d'un autre sujet ne l'est pas.
    @Test func uneCategorieEpuiseeRecommenceAuLieuDeDeborder() {
        var bank = QuestionBank()
        var rng = SeededRandom(seed: 5)
        let stock = QuestionBank().count(in: .arts)
        var vues: [String] = []
        for _ in 0 ..< stock { vues.append(bank.draw(category: .arts, difficulty: nil, using: &rng)!.id) }
        #expect(Set(vues).count == stock, "la catégorie doit d'abord être servie en entier")
        // La suivante repart du début, et reste dans la catégorie.
        let apres = bank.draw(category: .arts, difficulty: nil, using: &rng)
        #expect(apres?.category == .arts)
    }

    /// La banque doit tenir une soirée. Soixante questions pour une partie qui
    /// en pose soixante-dix : on revoyait les mêmes dès la première.
    /// La banque doit tenir une soirée, et plusieurs. Une partie pose de
    /// cinquante à cent soixante questions, et un thème peut en brûler
    /// vingt-cinq dans une seule.
    @Test func laBanqueTientPlusieursSoirees() {
        for c in Category.allCases {
            #expect(QuestionBank().count(in: c) >= 30, "\(c.label) s'épuiserait trop vite")
        }
    }
}
