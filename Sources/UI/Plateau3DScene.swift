//
//  Plateau3DScene.swift
//  Riskelo
//
//  Le plateau en relief : chaque territoire est une dalle découpée dans son
//  contour, posée sur un socle, et portant un fanion qui dit combien d'hommes
//  la tiennent.
//
//  La scène ne décide de rien. Elle reçoit l'état du plateau — à qui est
//  chaque terre, combien d'hommes, ce qui est choisi ou visé — et le montre.
//  Les couleurs sont celles du plateau à plat, et elles disent les mêmes
//  choses : la teinte du camp, assombrie hors de ce qui est jouable ; le
//  liseré du continent ; le blanc de la place choisie, le rouge de la cible.
//  Le relief n'ajoute qu'une chose : ce qui est en jeu se soulève.
//

import RealityKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

#if canImport(UIKit)
private typealias CouleurNative = UIColor
private typealias PoliceNative = UIFont
#else
private typealias CouleurNative = NSColor
private typealias PoliceNative = NSFont
#endif

/// Une couleur en trois composantes, qu'on peut mêler et comparer.
///
/// La scène ne peut pas jouer de la transparence comme le plateau à plat : une
/// dalle à moitié transparente laisserait voir ses propres flancs au travers.
/// Une terre « dans l'ombre » est donc mêlée à la couleur de la mer, ce qui
/// revient exactement au même que de la poser à demi effacée sur ce fond.
struct RVB: Equatable {
    var r: CGFloat
    var v: CGFloat
    var b: CGFloat

    init(r: CGFloat, v: CGFloat, b: CGFloat) { self.r = r; self.v = v; self.b = b }

    init(_ c: Color) {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(r: r, v: g, b: b)
        #else
        let n = NSColor(c).usingColorSpace(.sRGB) ?? .gray
        self.init(r: n.redComponent, v: n.greenComponent, b: n.blueComponent)
        #endif
    }

    /// Cette couleur à la part `t`, le reste pris à l'autre.
    func mele(_ autre: RVB, _ t: CGFloat) -> RVB {
        RVB(r: r * t + autre.r * (1 - t), v: v * t + autre.v * (1 - t), b: b * t + autre.b * (1 - t))
    }

    func fois(_ k: CGFloat) -> RVB { RVB(r: r * k, v: v * k, b: b * k) }

    fileprivate var native: CouleurNative {
        CouleurNative(red: min(1, r), green: min(1, v), blue: min(1, b), alpha: 1)
    }

    /// Une matière sans lumière ni retouche : la couleur telle quelle.
    ///
    /// Le moteur adoucit d'office les tons de toute l'image, comme le ferait
    /// une pellicule. La mer en sortait plus sombre que celle du plateau à
    /// plat — une couture se voyait au bord de la vue — et le bleu d'un camp
    /// n'était plus tout à fait le sien.
    @available(iOS 18.0, macOS 15.0, *)
    @MainActor
    var plate: UnlitMaterial {
        var m = UnlitMaterial(applyPostProcessToneMap: false)
        m.color = .init(tint: native)
        return m
    }
}

@available(iOS 18.0, macOS 15.0, *)
@MainActor
final class Scene3D {

    /// Tout ce qui se voit est accroché ici.
    let racine = Entity()
    /// L'œil. La vue en règle la place ; la scène se contente de le porter.
    let camera = PerspectiveCamera()

    private(set) var repere = Repere3D(aspect: 1)
    /// L'épaisseur d'une dalle. Tout le relief se mesure à elle.
    private(set) var epaisseur: Float = 0.3
    /// De combien se soulève une terre en jeu.
    private(set) var levee: Float = 0.25
    private var layout = BoardLayout(centers: [:], cellRadius: 0.1, aspect: 1)
    private var ordre: [TerritoryID] = []
    private var tints: [TerritoryID: Int] = [:]
    private var noms: [TerritoryID: String] = [:]
    private var commencee = false
    private var construite = false

    /// Chaque territoire : la terre qui se soulève, la dalle qu'elle porte, et
    /// le fanion qui dit le nombre.
    private struct Terre {
        let pivot: Entity
        let dalle: ModelEntity
        let fanion: Entity
        /// Ce qui grossit d'un coup quand le nombre change — le fanion lui-
        /// même est tourné face à l'écran, et l'on ne peut pas animer les deux
        /// sur la même entité.
        let contenu: Entity
        let disque: ModelEntity
        let anneau: ModelEntity
        var chiffre: ModelEntity?
        var nom: Entity?
        let centre: SIMD3<Float>
        let diametre: Float
        let rayon: Float
        /// La place qu'un nom peut prendre sans mordre sur la terre voisine.
        let largeurNom: Float
    }
    private var terres: [TerritoryID: Terre] = [:]

    /// Ce qu'on a montré la dernière fois : on ne retouche que ce qui change.
    private struct Aspect: Equatable {
        var dessus: RVB
        var flanc: RVB
        var anneau: RVB
        var leve: Bool
        var hommes: Int
        var camp: PlayerID
    }
    private var aspects: [TerritoryID: Aspect] = [:]
    private var dernier: Instantane3D?
    private var derniereCamera: Camera3D?
    private var derniereTaille: CGSize = .zero
    private var dernierCouvert: CGFloat = 0
    private var mouvementCamera: AnimationPlaybackController?
    private var fleche: Entity?
    private var flecheMontree: Instantane3D.Assaut?
    /// Les chiffres déjà taillés. Un nombre ne change pas de forme d'une
    /// partie à l'autre, et le tailler coûte : on le garde.
    private var chiffres: [Int: MeshResource] = [:]

    init() {
        camera.camera.fieldOfViewInDegrees = Camera3D.champ
        camera.camera.fieldOfViewOrientation = .vertical
        camera.camera.near = 0.05
        camera.camera.far = 600
    }

    // MARK: - La construction

    /// Taille le plateau une fois pour toutes. Les dalles ne changent jamais
    /// de forme : seules leurs couleurs et leur hauteur bougent ensuite.
    ///
    /// Une demi-seconde pour une carte du monde : la main est rendue à
    /// l'écran entre deux terres, pour que le bouton qui vient d'être touché
    /// ne reste pas figé le temps de la taille.
    func construire(board: Board, nom: (TerritoryID) -> String) async {
        guard !commencee else { return }
        commencee = true
        layout = board.layout
        ordre = board.map.order
        repere = Repere3D(aspect: layout.aspect)
        for id in ordre {
            tints[id] = board.map.tint(of: id)
            noms[id] = nom(id)
        }

        let r = repere.longueur(layout.typicalRadius)
        epaisseur = r * 0.42
        levee = epaisseur * 0.95

        racine.addChild(camera)
        poserLaTable()
        poserLesLumieres()
        for id in ordre {
            poserLaTerre(id, rayonOrdinaire: r)
            await Task.yield()
        }
        poserLesTraversees(rayonOrdinaire: r)
        // Seulement maintenant : un état montré pendant la taille aurait
        // laissé sans couleur les terres qui n'étaient pas encore posées.
        construite = true
    }

    /// La mer, et le socle sur lequel le plateau est posé.
    private func poserLaTable() {
        let mer = ModelEntity(mesh: .generatePlane(width: 600, depth: 600),
                              materials: [RVB(Palette.sea).plate])
        mer.position.y = -0.4
        racine.addChild(mer)

        // Le socle déborde du plateau d'une bordure, et sa tranche se voit :
        // c'est ce qui fait d'une carte un plateau qu'on a posé sur la table.
        let bord: Float = 0.45
        let largeur = repere.demiLargeur * 2 + bord * 2
        let profondeur = repere.demiProfondeur * 2 + bord * 2
        let socle = ModelEntity(
            mesh: .generateBox(size: SIMD3(largeur, 0.3, profondeur), cornerRadius: 0.18),
            materials: [SimpleMaterial(color: RVB(r: 0.12, v: 0.165, b: 0.22).native,
                                       roughness: .float(0.85), isMetallic: false)])
        socle.position.y = -0.15
        racine.addChild(socle)
    }

    /// Une lumière haute et de biais, qui porte les ombres, et une autre plus
    /// faible en face, pour que les flancs à contre-jour ne tombent pas au
    /// noir.
    private func poserLesLumieres() {
        let soleil = DirectionalLight()
        soleil.light.intensity = 3200
        soleil.shadow = DirectionalLightComponent.Shadow(maximumDistance: 60, depthBias: 2)
        soleil.look(at: .zero, from: SIMD3(-5, 12, 7), relativeTo: nil)
        racine.addChild(soleil)

        let reflet = DirectionalLight()
        reflet.light.intensity = 900
        reflet.look(at: .zero, from: SIMD3(6, 6, -8), relativeTo: nil)
        racine.addChild(reflet)
    }

    /// Le contour d'une terre, ramené à son propre centre.
    ///
    /// Retourné : le plateau compte ses y vers le bas, comme l'écran, et
    /// l'extrusion vers le haut. Tracé tel quel, le contour sortait en miroir,
    /// et la dalle avait le dessus tourné vers la table — un dessus noir, que
    /// la lumière n'atteignait jamais.
    private func contour(_ id: TerritoryID, centre c: Point) -> Path {
        let echelle = Double(Repere3D.largeur)
        func point(_ s: Point, _ k: Double = 1) -> CGPoint {
            CGPoint(x: (s.x - c.x) * echelle * k, y: -(s.y - c.y) * echelle * k)
        }
        var p = Path()
        if let boucles = layout.shapes[id] {
            for boucle in boucles where boucle.count > 2 {
                p.move(to: point(boucle[0]))
                for s in boucle.dropFirst() { p.addLine(to: point(s)) }
                p.closeSubpath()
            }
        } else {
            // Un rien plus petite que sa place : le joint entre deux cases
            // laisse voir les flancs, et c'est le flanc qui dit le relief.
            let sommets = layout.corners(of: id).map { point($0, 0.94) }
            if let premier = sommets.first {
                p.move(to: premier)
                for s in sommets.dropFirst() { p.addLine(to: s) }
                p.closeSubpath()
            }
        }
        return p
    }

    /// Taille la dalle. Le biseau du dessus est ce qui détache deux terres
    /// voisines tenues par le même camp — sans lui elles se fondraient en une
    /// seule plaque. S'il ne passe pas sur un contour trop découpé, la dalle se
    /// fait sans.
    private func dalle(_ chemin: Path) -> MeshResource? {
        var options = MeshResource.ShapeExtrusionOptions()
        options.extrusionMethod = .linear(depth: epaisseur)
        options.chamferRadius = epaisseur * 0.28
        options.chamferMode = .both
        options.materialAssignment = .init(front: 0, back: 0, extrusion: 1,
                                           frontChamfer: 2, backChamfer: 2)
        if let m = try? MeshResource(extruding: chemin, extrusionOptions: options) { return m }
        options.chamferRadius = 0
        return try? MeshResource(extruding: chemin, extrusionOptions: options)
    }

    private func poserLaTerre(_ id: TerritoryID, rayonOrdinaire r: Float) {
        guard let c = layout.centers[id], let mesh = dalle(contour(id, centre: c)) else { return }
        let centre = repere.monde(c)

        let pivot = Entity()
        pivot.position = centre
        racine.addChild(pivot)

        // Le contour est tracé debout, dans le plan de l'écran ; on le couche
        // sur la table, l'extrusion vers le ciel. Son dessus est posé à la
        // hauteur de la dalle, quelle que soit l'origine que l'extrusion a
        // choisie.
        let modele = ModelEntity(mesh: mesh, materials: [])
        modele.orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))
        modele.position.y = epaisseur - mesh.bounds.max.z
        pivot.addChild(modele)

        // Le fanion : un disque à la couleur du camp, cerclé, le nombre
        // dessus. Il se tient face à l'écran — une table se regarde de tous
        // les côtés, et un nombre couché ne se lit que d'un seul.
        let propre = repere.longueur(layout.radius(of: id))
        let diametre = repere.fanion(id, layout: layout)
        let hauteur = epaisseur + diametre * 0.62
        let fanion = Entity()
        fanion.position.y = hauteur
        pivot.addChild(fanion)
        let contenu = Entity()
        fanion.addChild(contenu)

        let anneau = ModelEntity(mesh: .generatePlane(width: diametre * 1.16, height: diametre * 1.16,
                                                      cornerRadius: diametre * 0.58),
                                 materials: [])
        contenu.addChild(anneau)
        let disque = ModelEntity(mesh: .generatePlane(width: diametre, height: diametre,
                                                      cornerRadius: diametre / 2),
                                 materials: [])
        disque.position.z = 0.004
        contenu.addChild(disque)

        // La hampe, de la dalle au fanion : sans elle, le disque flotte, et
        // vu de biais on ne sait plus au-dessus de quelle terre il se tient.
        let longueurHampe = hauteur - epaisseur - diametre * 0.5
        if longueurHampe > 0 {
            let hampe = ModelEntity(mesh: .generateCylinder(height: longueurHampe, radius: diametre * 0.045),
                                    materials: [RVB(Palette.sea).mele(.init(r: 1, v: 1, b: 1), 0.6).plate])
            hampe.position.y = epaisseur + longueurHampe / 2
            pivot.addChild(hampe)
        }

        // Sur un damier, la largeur de la case ; sur une carte, le plus large
        // rectangle où le plateau à plat écrit déjà ce nom, avec le même
        // débord permis.
        let boite = (layout.labelBoxes[id] ?? []).map(\.width).max().map { repere.longueur($0) }
        let largeurNom = boite.map { max(diametre * 1.6, $0 * Float(Legendes.debord)) }
            ?? diametre * 2.35
        terres[id] = Terre(pivot: pivot, dalle: modele, fanion: fanion, contenu: contenu,
                           disque: disque, anneau: anneau, chiffre: nil, nom: nil,
                           centre: centre, diametre: diametre, rayon: max(propre, r * 0.5),
                           largeurNom: largeurNom)
    }

    /// Les traversées, en pointillé d'une côte à l'autre — et en arc, haut
    /// au-dessus de la mer : en relief, une route maritime se lit comme un
    /// saut, ce qu'elle est.
    private func poserLesTraversees(rayonOrdinaire r: Float) {
        let perle = MeshResource.generateSphere(radius: max(0.025, r * 0.055))
        let matiere = RVB(Palette.ink).mele(RVB(Palette.sea), 0.78).plate
        for route in layout.seaRoutes {
            guard let a = layout.centers[route.from], let b = layout.centers[route.to] else { continue }
            let points = arc(de: repere.monde(a, hauteur: epaisseur),
                             vers: repere.monde(b, hauteur: epaisseur),
                             recul: r * 0.75, bosse: nil)
            let longueur = zip(points, points.dropFirst()).reduce(Float(0)) { $0 + simd_distance($1.0, $1.1) }
            let n = max(3, Int(longueur / (r * 0.32)))
            for i in 0 ... n {
                let p = echantillon(points, a: Float(i) / Float(n))
                let e = ModelEntity(mesh: perle, materials: [matiere])
                e.position = p
                racine.addChild(e)
            }
        }
    }

    /// Une courbe d'une place à l'autre, qui s'élève en son milieu.
    ///
    /// Les deux bouts reculent pour ne pas mordre sur les terres ; une route
    /// qui traverse tout le plateau — l'Alaska au Kamtchatka — s'écarte en
    /// plus vers l'extérieur, comme sur la carte à plat, au lieu de passer
    /// au-dessus de tout le monde.
    private func arc(de a: SIMD3<Float>, vers b: SIMD3<Float>, recul: Float,
                     bosse: Float?) -> [SIMD3<Float>] {
        let plat = SIMD2(b.x - a.x, b.z - a.z)
        let d = simd_length(plat)
        guard d > 0.0001 else { return [a, b] }
        let u = plat / d
        var controle = SIMD2((a.x + b.x) / 2, (a.z + b.z) / 2)
        if d > max(repere.longueur(layout.typicalRadius) * 4, Repere3D.largeur * 0.28) {
            var n = SIMD2(-u.y, u.x)
            if simd_dot(controle, n) < 0 { n = -n }
            controle += n * d * 0.22
        }
        let haut = bosse ?? min(d * 0.22, epaisseur * 5) + epaisseur * 0.6
        let depart = SIMD2(a.x, a.z) + simd_normalize(controle - SIMD2(a.x, a.z)) * min(recul, d * 0.3)
        let arrivee = SIMD2(b.x, b.z) + simd_normalize(controle - SIMD2(b.x, b.z)) * min(recul, d * 0.3)
        let pas = 24
        return (0 ... pas).map { i in
            let t = Float(i) / Float(pas)
            let q = depart * (1 - t) * (1 - t) + controle * 2 * t * (1 - t) + arrivee * t * t
            let y = a.y * (1 - t) + b.y * t + 4 * haut * t * (1 - t)
            return SIMD3(q.x, y, q.y)
        }
    }

    /// Le point de la polyligne à la fraction `a` de sa longueur.
    private func echantillon(_ points: [SIMD3<Float>], a: Float) -> SIMD3<Float> {
        let segments = zip(points, points.dropFirst()).map { simd_distance($0.0, $0.1) }
        let total = segments.reduce(0, +)
        var reste = a * total
        for (i, l) in segments.enumerated() {
            if reste <= l || i == segments.count - 1 {
                let t = l > 0 ? min(1, reste / l) : 0
                return points[i] * (1 - t) + points[i + 1] * t
            }
            reste -= l
        }
        return points.last ?? .zero
    }

    // MARK: - Ce que la couleur raconte

    private func aspect(_ id: TerritoryID, dans e: Instantane3D) -> Aspect {
        let camp = e.proprietaires[id] ?? 0
        let base = RVB(Palette.camp(camp))
        let mer = RVB(Palette.sea)
        let enAssaut = e.assaut?.de == id || e.assaut?.vers == id
        let enVue = enAssaut || e.choisi == id || e.cibles.contains(id)
        // Les mêmes parts que l'opacité du plateau à plat.
        let part: CGFloat = enAssaut ? 1 : enVue ? 0.95 : e.jouables.contains(id) ? 0.72 : 0.45
        let surligne: RVB?
        if e.assaut?.vers == id { surligne = RVB(Palette.lost) }
        else if let a = e.assaut, a.de == id { surligne = RVB(Palette.campVif(a.camp)) }
        else if e.choisi == id { surligne = RVB(r: 1, v: 1, b: 1) }
        else if e.cibles.contains(id) { surligne = RVB(Palette.lost) }
        else { surligne = nil }
        return Aspect(dessus: base.mele(mer, part),
                      flanc: surligne ?? base.mele(mer, part).fois(0.62),
                      anneau: surligne ?? mer,
                      leve: enVue,
                      hommes: e.hommes[id] ?? 0,
                      camp: camp)
    }

    // MARK: - L'application

    /// Montre cet état, de cet œil, dans une vue de cette taille, dont le
    /// panneau du bas mange la part `couvert`.
    func appliquer(_ etat: Instantane3D, camera vue: Camera3D, duree: Double, taille: CGSize,
                   couvert: CGFloat = 0) {
        guard construite else { return }
        if etat != dernier {
            for id in ordre {
                let nouveau = aspect(id, dans: etat)
                if nouveau != aspects[id] { retoucher(id, aspect: nouveau, avant: aspects[id]) }
            }
            if etat.assaut != flecheMontree { poserLaFleche(etat.assaut) }
        }
        let cameraChangee = vue != derniereCamera || taille != derniereTaille
        if cameraChangee { placer(vue, duree: duree) }
        if etat != dernier || cameraChangee || couvert != dernierCouvert {
            montrerLesNoms(etat, camera: vue, taille: taille, couvert: couvert)
        }
        dernierCouvert = couvert
        dernier = etat
        derniereCamera = vue
        derniereTaille = taille
    }

    private func placer(_ vue: Camera3D, duree: Double) {
        mouvementCamera?.stop()
        mouvementCamera = nil
        let t = Transform(scale: .one, rotation: vue.orientation, translation: vue.position)
        // Les fanions se tiennent face à l'écran, et non tournés vers l'œil :
        // tournés vers lui, ceux des bords penchaient, et leurs noms se
        // lisaient de travers. Ils suivent donc l'orientation de la caméra —
        // d'un coup, ce qui oblige la caméra à pivoter d'un coup elle aussi :
        // un recadrage glisse, il ne tourne jamais.
        let tourne = derniereCamera.map { $0.lacet != vue.lacet || $0.tangage != vue.tangage } ?? true
        if tourne {
            for terre in terres.values { terre.fanion.orientation = vue.orientation }
        }
        if duree > 0, derniereCamera != nil, !tourne {
            mouvementCamera = camera.move(to: t, relativeTo: nil, duration: duree,
                                          timingFunction: .easeInOut)
        } else {
            camera.transform = t
        }
    }

    private func retoucher(_ id: TerritoryID, aspect a: Aspect, avant: Aspect?) {
        guard var terre = terres[id] else { return }
        aspects[id] = a
        let premiere = avant == nil

        if premiere || a.dessus != avant?.dessus || a.flanc != avant?.flanc {
            let continent = RVB(Palette.continent(rang: tints[id] ?? 0))
            terre.dalle.model?.materials = [
                SimpleMaterial(color: a.dessus.native, roughness: .float(0.7), isMetallic: false),
                SimpleMaterial(color: a.flanc.native, roughness: .float(0.8), isMetallic: false),
                SimpleMaterial(color: continent.native, roughness: .float(0.5), isMetallic: false),
            ]
        }
        if premiere || a.camp != avant?.camp {
            terre.disque.model?.materials = [RVB(Palette.camp(a.camp)).plate]
        }
        if premiere || a.anneau != avant?.anneau {
            terre.anneau.model?.materials = [a.anneau.plate]
        }
        if premiere || a.leve != avant?.leve {
            // `simd_quatf()` n'est pas « aucune rotation » : c'est un
            // quaternion nul, qui écrase la terre à rien. Posé d'un coup, le
            // moteur le corrigeait ; animé, il le suivait — et la place qu'on
            // touchait disparaissait au lieu de se soulever.
            let cible = Transform(scale: .one, rotation: simd_quatf(angle: 0, axis: SIMD3(0, 1, 0)),
                                  translation: terre.centre + SIMD3(0, a.leve ? levee : 0, 0))
            if premiere { terre.pivot.transform = cible } else {
                terre.pivot.move(to: cible, relativeTo: racine, duration: 0.18,
                                 timingFunction: .easeInOut)
            }
        }
        if premiere || a.hommes != avant?.hommes {
            terre.chiffre?.removeFromParent()
            let chiffre = nombre(a.hommes, diametre: terre.diametre)
            terre.contenu.addChild(chiffre)
            terre.chiffre = chiffre
            // Le fanion bat d'un coup quand le nombre change : c'est ce qui
            // montre qu'un homme vient de tomber, pendant qu'on répond.
            if !premiere {
                terre.contenu.scale = SIMD3(repeating: 1.35)
                terre.contenu.move(to: Transform(), relativeTo: terre.fanion, duration: 0.28,
                                   timingFunction: .easeOut)
            }
        }
        terres[id] = terre
    }

    /// Le nombre, taillé une fois et posé au milieu du disque.
    private func nombre(_ n: Int, diametre: Float) -> ModelEntity {
        let mesh: MeshResource
        if let deja = chiffres[n] { mesh = deja } else {
            mesh = MeshResource.generateText("\(n)", extrusionDepth: 0.02,
                                             font: police(gras: true))
            chiffres[n] = mesh
        }
        let e = ModelEntity(mesh: mesh, materials: [RVB(r: 1, v: 1, b: 1).plate])
        let b = mesh.bounds
        let hauteurVoulue = diametre * 0.52
        let largeurMax = diametre * 0.8
        let k = min(hauteurVoulue / max(0.001, b.extents.y), largeurMax / max(0.001, b.extents.x))
        e.scale = SIMD3(repeating: k)
        e.position = SIMD3(-b.center.x * k, -b.center.y * k, 0.008)
        return e
    }

    private func police(gras: Bool) -> PoliceNative {
        let base = PoliceNative.systemFont(ofSize: 1, weight: gras ? .heavy : .semibold)
        #if canImport(UIKit)
        if let d = base.fontDescriptor.withDesign(.rounded) { return UIFont(descriptor: d, size: 1) }
        return base
        #else
        if let d = base.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: 1) {
            return f
        }
        return base
        #endif
    }

    // MARK: - Les noms

    /// Le nom paraît sous le fanion quand il se lit — la terre assez grande à
    /// l'écran — et toujours pour les places en jeu : c'est d'elles qu'on
    /// parle dans le panneau du bas.
    ///
    /// Jamais sous ce panneau : il est translucide, et un nom vu au travers
    /// se mêlait à son texte.
    private func montrerLesNoms(_ etat: Instantane3D, camera vue: Camera3D, taille: CGSize,
                                couvert: CGFloat) {
        guard taille.width > 0, taille.height > 0 else { return }
        for id in ordre {
            guard var terre = terres[id] else { continue }
            let enJeu = etat.choisi == id || etat.cibles.contains(id)
                || etat.assaut?.de == id || etat.assaut?.vers == id
            let lisible = vue.points(pour: terre.rayon * 2, taille: taille) > 74
            let dessous = couvert > 0
                && (vue.ecran(terre.centre + SIMD3(0, epaisseur, 0), taille: taille)?.y ?? 0)
                    > taille.height * (1 - couvert) - 6
            let montre = (enJeu || lisible) && !dessous
            if montre, terre.nom == nil {
                terre.nom = etiquette(noms[id] ?? id, diametre: terre.diametre, largeurMax: terre.largeurNom)
                terre.contenu.addChild(terre.nom!)
                terres[id] = terre
            }
            terre.nom?.isEnabled = montre
        }
    }

    /// Le nom, en blanc sur une plaquette sombre — posé à même la carte, il
    /// se perdrait sur les couleurs des camps.
    ///
    /// Il passe par-dessus tout, comme les noms du plateau à plat. Tenu à sa
    /// place dans l'espace, il s'enfonçait à moitié dans sa propre dalle, et
    /// ceux du fond du plateau disparaissaient derrière la rangée de devant.
    private func etiquette(_ texte: String, diametre: Float, largeurMax: Float) -> Entity {
        // Le corps des lettres est le même pour tous les noms d'un fanion de
        // cette taille. Pris sur la hauteur de chaque mot, il variait avec
        // ses lettres : « Québec » s'écrivait plus petit que « Alaska », à
        // cause de son accent.
        let corps = diametre * 0.27
        let interligne: Float = 1.18
        func tailler(_ ligne: String) -> MeshResource {
            MeshResource.generateText(ligne, extrusionDepth: 0.02, font: police(gras: false))
        }
        // Une ligne si elle tient ; sinon les deux lignes les mieux
        // équilibrées ; et si rien ne tient, la forme la plus étroite, réduite
        // juste ce qu'il faut. Un nom ne déborde jamais sur la terre d'à côté :
        // il y cachait le fanion du voisin.
        let formes = Legendes.coupures(texte).map { $0.components(separatedBy: "\n").map(tailler) }
        func largeur(_ f: [MeshResource]) -> Float { (f.map(\.bounds.extents.x).max() ?? 0) * corps }
        let retenue = formes.first { largeur($0) <= largeurMax }
            ?? formes.min { largeur($0) < largeur($1) } ?? []
        let k = corps * min(1, largeurMax / max(0.001, largeur(retenue)))

        let groupe = Entity()
        var blanc = RVB(r: 1, v: 1, b: 1).plate
        blanc.readsDepth = false
        let n = Float(retenue.count)
        let haut = -diametre * 0.62 - diametre * 0.07
        let hauteurBloc = n * interligne * k
        let milieu = haut - hauteurBloc / 2
        for (i, mesh) in retenue.enumerated() {
            let lettres = ModelEntity(mesh: mesh, materials: [blanc])
            lettres.components.set(ModelSortGroupComponent(group: Self.dessus, order: 1))
            lettres.scale = SIMD3(repeating: k)
            // La ligne se pose sur sa ligne de base ; le milieu d'une lettre
            // ordinaire est à un tiers du corps au-dessus.
            let base = milieu + ((n - 1) / 2 - Float(i)) * interligne * k - 0.34 * k
            lettres.position = SIMD3(-mesh.bounds.center.x * k, base, 0.01)
            groupe.addChild(lettres)
        }

        var fond = RVB(Palette.sea).plate
        fond.blending = .transparent(opacity: .init(floatLiteral: 0.82))
        fond.readsDepth = false
        let plaque = ModelEntity(
            mesh: .generatePlane(width: (retenue.map(\.bounds.extents.x).max() ?? 0) * k + diametre * 0.2,
                                 height: hauteurBloc + diametre * 0.08,
                                 cornerRadius: diametre * 0.08),
            materials: [fond])
        plaque.position = SIMD3(0, milieu, 0.002)
        plaque.components.set(ModelSortGroupComponent(group: Self.dessus, order: 0))
        groupe.addChild(plaque)
        return groupe
    }

    /// Ce qui se dessine par-dessus le reste, dans l'ordre : les plaquettes,
    /// puis les lettres.
    private static let dessus = ModelSortGroup(depthPass: nil)

    // MARK: - La flèche de l'assaut

    /// D'où part l'assaut et où il tombe : un arc à la couleur de
    /// l'assaillant, qui saute d'une terre à l'autre, et sa pointe.
    private func poserLaFleche(_ assaut: Instantane3D.Assaut?) {
        fleche?.removeFromParent()
        fleche = nil
        flecheMontree = assaut
        guard let assaut, let a = layout.centers[assaut.de], let b = layout.centers[assaut.vers] else { return }
        let r = repere.longueur(layout.typicalRadius)
        let haut = epaisseur + levee
        let depart = repere.monde(a, hauteur: haut), arrivee = repere.monde(b, hauteur: haut)
        // L'arc se mesure à l'écart entre les deux places : haut entre deux
        // terres éloignées, à peine bombé entre deux voisines. Pris à la
        // mesure du plateau, il faisait entre voisines un crochet qui
        // retombait à pic, et la pointe ne se voyait que par-dessous.
        let ecart = simd_distance(SIMD2(depart.x, depart.z), SIMD2(arrivee.x, arrivee.z))
        let points = arc(de: depart, vers: arrivee, recul: r * 0.5,
                         bosse: max(epaisseur * 1.2, ecart * 0.2))
        let groupe = Entity()
        let matiere = RVB(Palette.campVif(assaut.camp)).plate
        let epais = max(0.03, r * 0.09)
        let longueur = zip(points, points.dropFirst()).reduce(Float(0)) { $0 + simd_distance($1.0, $1.1) }
        let tete = min(r * 0.5, longueur * 0.38)
        // La pointe prend la place des derniers pas de l'arc.
        var corps = points
        while corps.count > 2, simd_distance(corps[corps.count - 1], points.last!) < tete * 0.8 {
            corps.removeLast()
        }
        for (p, q) in zip(corps, corps.dropFirst()) {
            let l = simd_distance(p, q)
            guard l > 0.0001 else { continue }
            let troncon = ModelEntity(mesh: .generateCylinder(height: l * 1.04, radius: epais),
                                      materials: [matiere])
            troncon.position = (p + q) / 2
            troncon.orientation = simd_quatf(from: SIMD3(0, 1, 0), to: simd_normalize(q - p))
            groupe.addChild(troncon)
        }
        if let depart = corps.last, let bout = points.last, simd_distance(depart, bout) > 0.0001 {
            let pointe = ModelEntity(mesh: .generateCone(height: simd_distance(depart, bout) * 1.1,
                                                         radius: epais * 2.6),
                                     materials: [matiere])
            pointe.position = (depart + bout) / 2
            pointe.orientation = simd_quatf(from: SIMD3(0, 1, 0), to: simd_normalize(bout - depart))
            groupe.addChild(pointe)
        }
        racine.addChild(groupe)
        fleche = groupe
    }
}
