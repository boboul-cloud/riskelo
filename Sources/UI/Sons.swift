//
//  Sons.swift
//  Riskelo
//
//  Les sons, écrits plutôt qu'enregistrés.
//
//  Trois signaux, pas un de plus : l'échange gagné, l'échange perdu, et
//  l'ouverture de l'application. Un jeu qui commente chaque appui devient
//  vite un jeu qu'on joue en silence.
//
//  Ils sont calculés au premier besoin, échantillon par échantillon, comme
//  l'icône est dessinée en code. La raison est la même : aucun fichier à
//  porter, aucune licence à vérifier, et l'on règle une note en changeant un
//  chiffre plutôt qu'en rouvrant un éditeur. Trois quarts de seconde de son
//  tiennent en vingt lignes de partition.
//
//  Le timbre n'est pas une sinusoïde nue — cela sonne comme un test auditif.
//  Deux harmoniques par-dessus la fondamentale, une attaque brève et une
//  extinction douce : de quoi évoquer une pièce de bois qu'on pose.
//

import AVFoundation

@MainActor
final class Sons {

    static let shared = Sons()

    /// L'option, gardée d'une partie à l'autre. Le réglage vit dans les
    /// préférences du système et non dans la partie : il vaut pour
    /// l'application entière, pas pour une partie en particulier.
    static let cle = "riskelo.sons"

    static var actifs: Bool {
        get { UserDefaults.standard.object(forKey: cle) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: cle) }
    }

    enum Signal: Hashable {
        /// Un homme posé sur le plateau : une note brève, et sourde.
        case pose
        /// L'échange tourne en ma faveur : trois notes qui montent.
        case gagne
        /// Il tourne contre moi : trois notes qui descendent.
        case perdu
        /// L'ouverture : les deux camps qui se rejoignent, puis l'accord.
        case ouverture
    }

    private let moteur = AVAudioEngine()
    private let voix = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    /// Une panne du son ne doit jamais gêner le jeu : on la note une fois et
    /// on n'y revient plus.
    private var enPanne = false
    private var tampons: [Signal: AVAudioPCMBuffer] = [:]

    private init() {
        guard let format else { enPanne = true; return }
        moteur.attach(voix)
        moteur.connect(voix, to: moteur.mainMixerNode, format: format)
        moteur.mainMixerNode.outputVolume = 0.85
    }

    func jouer(_ signal: Signal) {
        guard Sons.actifs, !enPanne, let tampon = tampon(signal) else { return }
        demarrer()
        guard moteur.isRunning else { return }
        // `interrupts` : un second verdict qui tombe vite coupe le premier
        // plutôt que de sonner par-dessus.
        voix.scheduleBuffer(tampon, at: nil, options: .interrupts, completionHandler: nil)
        if !voix.isPlaying { voix.play() }
    }

    private func demarrer() {
        guard !moteur.isRunning, !enPanne else { return }
        #if os(iOS)
        // Une session « ambiante » : le jeu ne coupe pas la musique de qui
        // joue en écoutant la sienne, et le bouton silence de l'iPhone le
        // fait taire — c'est ce qu'on attend d'un bruitage, pas d'un lecteur.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
        do { try moteur.start() } catch { enPanne = true }
    }

    // MARK: - Les partitions

    /// Une note : sa hauteur, son entrée, sa longueur, et ce qu'elle pèse
    /// dans le mélange. Le tout en secondes et en hertz — rien en
    /// échantillons, qui ne se relisent pas.
    private struct Note {
        let hauteur: Double
        let debut: Double
        let duree: Double
        let force: Double
    }

    private func partition(_ signal: Signal) -> [Note] {
        switch signal {
        case .pose:
            // Une pièce de bois qu'on pose : brève, sourde, et trois fois
            // plus discrète que le reste. Elle tombe jusqu'à dix fois de
            // suite au début d'un tour — c'est ce qui commande sa retenue.
            // L'octave par-dessus ne s'entend pas comme une note : elle donne
            // du grain à l'attaque, et rien de plus.
            return [
                Note(hauteur: 392.00, debut: 0, duree: 0.13, force: 0.22),  // sol
                Note(hauteur: 784.00, debut: 0, duree: 0.09, force: 0.09),  // son octave
            ]
        case .gagne:
            // Un accord majeur qui monte, jusqu'à l'octave. Court : il tombe
            // plusieurs fois par tour.
            return [
                Note(hauteur: 440.00, debut: 0.000, duree: 0.30, force: 0.42),  // la
                Note(hauteur: 554.37, debut: 0.075, duree: 0.30, force: 0.42),  // do dièse
                Note(hauteur: 659.25, debut: 0.150, duree: 0.34, force: 0.45),  // mi
                Note(hauteur: 880.00, debut: 0.225, duree: 0.46, force: 0.39),  // la
            ]
        case .perdu:
            // Le même geste retourné : un accord mineur qui descend, plus
            // lent et plus grave. Il ne gronde pas — on perd un homme, pas la
            // partie.
            return [
                Note(hauteur: 349.23, debut: 0.00, duree: 0.34, force: 0.39),   // fa
                Note(hauteur: 293.66, debut: 0.11, duree: 0.40, force: 0.36),   // ré
                Note(hauteur: 220.00, debut: 0.22, duree: 0.60, force: 0.42),   // la
            ]
        case .ouverture:
            // Ce que l'écran montre au même instant : deux voix parties des
            // deux bords qui se rejoignent — l'une monte, l'autre descend —
            // et l'accord qui se referme quand les deux moitiés se touchent.
            var notes: [Note] = []
            let montante = [261.63, 329.63, 392.00]     // do, mi, sol
            let descendante = [783.99, 659.25, 523.25]  // sol, mi, do
            for (i, (bas, haut)) in zip(montante, descendante).enumerated() {
                let t = Double(i) * 0.17
                notes.append(Note(hauteur: bas, debut: t, duree: 0.28, force: 0.20))
                notes.append(Note(hauteur: haut, debut: t, duree: 0.28, force: 0.18))
            }
            for hauteur in [261.63, 329.63, 392.00, 523.25] {
                notes.append(Note(hauteur: hauteur, debut: 0.55, duree: 1.50, force: 0.17))
            }
            return notes
        }
    }

    // MARK: - La fabrique

    private func tampon(_ signal: Signal) -> AVAudioPCMBuffer? {
        if let deja = tampons[signal] { return deja }
        guard let format else { return nil }
        let notes = partition(signal)
        let secondes = (notes.map { $0.debut + $0.duree }.max() ?? 0) + 0.05
        let images = AVAudioFrameCount(secondes * format.sampleRate)
        guard images > 0,
              let tampon = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: images),
              let canal = tampon.floatChannelData?[0] else { return nil }
        tampon.frameLength = images
        for i in 0 ..< Int(images) { canal[i] = 0 }

        let taux = format.sampleRate
        for note in notes {
            let depart = Int(note.debut * taux)
            for k in 0 ..< Int(note.duree * taux) {
                let i = depart + k
                guard i < Int(images) else { break }
                let t = Double(k) / taux
                let phase = 2 * Double.pi * note.hauteur * t
                let onde = (sin(phase) + 0.30 * sin(2 * phase) + 0.12 * sin(3 * phase)) / 1.42
                canal[i] += Float(note.force * enveloppe(t, duree: note.duree) * onde)
            }
        }
        tampons[signal] = tampon
        return tampon
    }

    /// Attaque brève, extinction douce, et une sortie en fondu. Les deux
    /// bouts comptent autant que le milieu : une note qui commence ou s'arrête
    /// d'un coup claque, et ce claquement s'entend plus que la note.
    private func enveloppe(_ t: Double, duree: Double) -> Double {
        let montee = min(1, t / 0.008)
        let chute = exp(-3.2 * t / duree)
        let sortie = max(0, min(1, (duree - t) / 0.03))
        return montee * chute * sortie
    }
}
