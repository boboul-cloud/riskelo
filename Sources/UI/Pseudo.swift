//
//  Pseudo.swift
//  Riskelo
//
//  Le nom de celui qui tient l'appareil.
//
//  Les camps s'appellent Bleu, Rouge, Vert : c'est ce qu'il faut, parce que
//  le plateau ne connaît que des couleurs et qu'un nom qui ne s'y retrouve
//  pas ne sert à rien. Mais à quatre camps dont trois machines, « lequel
//  suis-je » se redemande à chaque coup d'œil.
//
//  D'où ce nom, facultatif, qui s'ajoute au camp sans le remplacer — « Rouge
//  · Robert » et non « Robert ». La couleur reste ce qui relie le nom au
//  plateau ; le pseudo dit seulement de quel côté de l'écran on est.
//
//  Il vit dans les préférences du système et non dans la partie : c'est le
//  propriétaire de l'appareil qu'il nomme, pas un joueur d'une partie
//  donnée. Une partie reprise six mois plus tard portera le nom du moment,
//  et c'est bien ainsi.
//

import Foundation

enum Pseudo {

    static let cle = "riskelo.pseudo"

    /// La longueur au-delà de laquelle la bande des camps déborde sur un
    /// téléphone. Elle tient sur une ligne, et un nom à rallonge la ferait
    /// défiler pour rien.
    static let maximum = 14

    /// Le nom donné, ou rien s'il n'y en a pas. Jamais une chaîne vide ni des
    /// espaces seuls : « rien » et « trois espaces » doivent se comporter
    /// pareil, sinon la pastille affiche un séparateur suivi du vide.
    static var actuel: String? {
        let brut = UserDefaults.standard.string(forKey: cle) ?? ""
        let net = String(brut.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximum))
        return net.isEmpty ? nil : net
    }
}
