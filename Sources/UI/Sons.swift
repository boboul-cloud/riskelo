//
//  Sons.swift
//  Riskelo
//
//  Les sons, écrits plutôt qu'enregistrés.
//
//  Peu de signaux, et chacun pour un moment qu'on ne peut pas manquer :
//  l'homme posé, l'échange gagné, l'échange perdu, l'ouverture de
//  l'application, et la fin de la partie — d'un côté ou de l'autre. Un jeu
//  qui commente chaque appui devient vite un jeu qu'on joue en silence.
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
//  Chaque note règle son propre éclat par-dessus, c'est-à-dire ce que pèsent
//  ces harmoniques. Le bois pour tout le jeu, le cuivre pour la seule fanfare
//  de la victoire : une trompette et un maillet ne diffèrent pas par leurs
//  notes, ils diffèrent par là.
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
        /// La partie est gagnée : l'ouverture menée jusqu'au bout, et l'accord
        /// qui reste.
        case victoire
        /// Elle est perdue : le même geste retourné, qui descend et s'éteint.
        case defaite
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

    /// Le son tel qu'il sera joué, rendu hors de l'application.
    ///
    /// Ouvert pour « outils/sons.swift », qui écrit les fichiers qu'on écoute
    /// avant de trancher. Sans cela l'outil recopierait les partitions, et
    /// l'on choisirait au casque un son que l'application ne joue pas.
    func rendu(_ signal: Signal) -> AVAudioPCMBuffer? { tampon(signal) }

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
        /// Le cuivre : ce que pèsent les harmoniques au-dessus de la
        /// fondamentale. À 1, le timbre de bois de tout le jeu. Au-delà, la
        /// note brille et se met à sonner comme une trompette — c'est ce qui
        /// sépare une pièce qu'on pose d'une fanfare, bien plus que la
        /// hauteur des notes.
        var eclat: Double = 1
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
        case .victoire:
            // La fin, pour qui l'emporte. Une sonnerie, et non un arpège : ce
            // qui fait le militaire n'est pas la hauteur des notes, ce sont
            // trois choses — le rythme pointé, le cuivre, et deux trompettes
            // au lieu d'une.
            //
            // Elle ne sonne qu'une fois par partie : c'est ce qui lui vaut ses
            // trois secondes et son aplomb, là où l'échange gagné, qui tombe
            // dix fois par tour, doit se faire oublier.
            var notes: [Note] = []

            /// Les deux trompettes, sur la même figure.
            ///
            /// La seconde suit la première à la tierce en dessous, et se tient
            /// plus bas en volume : deux voix égales ne font pas deux
            /// trompettes, elles font une trompette épaisse.
            ///
            /// La note d'en dessous est écrite à chaque fois plutôt que
            /// calculée. Sous le do, la tierce serait le la — et le la fait
            /// entendre un mineur au beau milieu d'une fanfare : on y met la
            /// quarte. Une règle qui souffre deux exceptions sur cinq n'est
            /// plus une règle, c'est une table.
            func trompettes(_ haute: Double, _ basse: Double,
                            _ debut: Double, _ duree: Double, _ force: Double) {
                notes.append(Note(hauteur: haute, debut: debut, duree: duree,
                                  force: force, eclat: 2.4))
                notes.append(Note(hauteur: basse, debut: debut, duree: duree,
                                  force: force * 0.66, eclat: 2.2))
            }

            // L'appel. Rythme pointé — une longue, une brève, et l'on
            // recommence : c'est la figure de toutes les sonneries militaires,
            // et ce qui la sépare d'une gamme jouée à temps égaux. Deux fois
            // la même cellule, puis la tenue : l'appel est reconnaissable
            // parce qu'il se répète, jamais parce qu'il avance.
            trompettes(392.00, 329.63, 0.000, 0.175, 0.52)   // sol · mi
            trompettes(392.00, 329.63, 0.195, 0.055, 0.52)
            trompettes(523.25, 392.00, 0.260, 0.175, 0.55)   // do · sol
            trompettes(523.25, 392.00, 0.455, 0.055, 0.55)
            trompettes(659.25, 523.25, 0.520, 0.240, 0.58)   // mi · do, tenue

            // La charge. La même cellule pointée, montée d'un cran à chaque
            // fois, jusqu'à l'octave du dessus. Les notes du clairon et pas
            // d'autres — do, mi, sol, do : celles qu'un cuivre sans piston
            // sait donner, ce qui est la raison même de leur son.
            trompettes(523.25, 392.00, 0.780, 0.175, 0.55)
            trompettes(659.25, 523.25, 0.975, 0.055, 0.55)
            trompettes(783.99, 659.25, 1.040, 0.175, 0.58)
            trompettes(783.99, 659.25, 1.235, 0.055, 0.58)
            trompettes(1046.50, 783.99, 1.300, 0.420, 0.60)  // le sommet

            // L'accord, large sur deux octaves, et tenu. Il se pose pendant
            // que le sommet sonne encore, sans quoi la sonnerie retomberait
            // dans un trou avant de se refermer.
            //
            // Chaque voix y est faible : cinq notes ensemble s'additionnent,
            // et c'est la somme qui sature, jamais la note prise à part. Elles
            // brillent moins que l'appel — un accord tenu trop cuivré cesse
            // d'être un accord, il devient un klaxon.
            for hauteur in [261.63, 329.63, 392.00, 523.25, 783.99] {
                notes.append(Note(hauteur: hauteur, debut: 1.62, duree: 1.55,
                                  force: 0.20, eclat: 1.5))
            }
            return notes
        case .defaite:
            // Le même moment, de l'autre côté. Il descend au lieu de monter et
            // s'éteint au lieu de tenir — mais il ne gronde pas : on perd une
            // partie, on en rouvre une.
            //
            // Rien ne descend sous ce sol grave. Un haut-parleur de téléphone
            // ne rend presque plus rien en dessous, et une défaite qu'on
            // n'entend pas est une défaite sans son.
            var notes: [Note] = []
            let descente = [293.66, 233.08, 196.00]   // ré, si bémol, sol
            for (i, hauteur) in descente.enumerated() {
                notes.append(Note(hauteur: hauteur, debut: Double(i) * 0.16,
                                  duree: 0.42, force: 0.30))
            }
            // Plus bas que la montée de la victoire, et plus court : le son
            // qui console ne s'impose pas autant que celui qui félicite.
            for hauteur in [196.00, 233.08, 293.66] {
                notes.append(Note(hauteur: hauteur, debut: 0.55, duree: 1.60, force: 0.14))
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
                // Les harmoniques pèsent l'éclat de la note, et la somme est
                // ramenée à 1 : sans quoi une note brillante serait aussi une
                // note plus forte, et l'on croirait régler le timbre en
                // réglant le volume.
                let h2 = 0.30 * note.eclat
                let h3 = 0.12 * note.eclat
                let h4 = 0.05 * max(0, note.eclat - 1)
                let onde = (sin(phase) + h2 * sin(2 * phase) + h3 * sin(3 * phase)
                            + h4 * sin(4 * phase)) / (1 + h2 + h3 + h4)
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
