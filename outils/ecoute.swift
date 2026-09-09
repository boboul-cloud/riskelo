//
//  ecoute.swift
//  Riskelo — outil, hors application
//
//  Les sons, écrits dans des fichiers pour qu'on les écoute.
//
//  Une partition se relit, elle ne s'entend pas : « un arpège qui monte sur
//  une octave et demie » ne dit rien de ce que rendra le haut-parleur. Cet
//  outil rend les six signaux tels quels et les pose sur le disque, de quoi
//  trancher à l'oreille avant de trancher dans le code.
//
//  Il ne recopie aucune note : il appelle `Sons.rendu`, c'est-à-dire le même
//  calcul que celui de l'application. Un son qu'on approuve ici est le son
//  qu'on entendra en jouant.
//
//  Il mesure aussi la crête de chaque mélange. Plusieurs notes qui sonnent
//  ensemble s'additionnent, et au-delà de 1 le son ne monte plus : il se
//  coupe, et ce hachage s'entend plus que l'accord. Mieux vaut le lire ici
//  qu'en écoutant.
//
//      swiftc -O -parse-as-library -o /tmp/ecoute Sources/UI/Sons.swift outils/ecoute.swift && /tmp/ecoute
//

import AVFoundation

@main
enum Ecoute {

    static let signaux: [(String, Sons.Signal)] = [
        ("1-ouverture", .ouverture),
        ("2-pose", .pose),
        ("3-echange-gagne", .gagne),
        ("4-echange-perdu", .perdu),
        ("5-VICTOIRE", .victoire),
        ("6-DEFAITE", .defaite),
    ]

    @MainActor
    static func main() {
        let dossier = URL(fileURLWithPath: "/tmp/riskelo-sons")
        try? FileManager.default.createDirectory(at: dossier,
                                                 withIntermediateDirectories: true)
        for (nom, signal) in signaux {
            guard let tampon = Sons.shared.rendu(signal) else {
                print("  \(nom) — rendu impossible"); continue
            }
            let url = dossier.appendingPathComponent("\(nom).wav")
            try? FileManager.default.removeItem(at: url)
            do {
                let fichier = try AVAudioFile(forWriting: url, settings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 44_100.0,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                ])
                try fichier.write(from: tampon)
            } catch {
                print("  \(nom) — écriture impossible : \(error)"); continue
            }
            let secondes = Double(tampon.frameLength) / tampon.format.sampleRate
            let haut = crete(tampon)
            let colonne = nom.padding(toLength: 18, withPad: " ", startingAt: 0)
            print(String(format: "  %@%5.2f s   crête %.2f %@", colonne, secondes,
                         haut, haut >= 1 ? "⚠️ saturé" : ""))
        }
        print("\nDans \(dossier.path)")
    }

    /// Le plus fort échantillon du mélange, en valeur absolue.
    static func crete(_ tampon: AVAudioPCMBuffer) -> Float {
        guard let canal = tampon.floatChannelData?[0] else { return 0 }
        var haut: Float = 0
        for i in 0 ..< Int(tampon.frameLength) { haut = max(haut, abs(canal[i])) }
        return haut
    }
}
