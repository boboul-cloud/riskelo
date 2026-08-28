//
//  Random.swift
//  Riskelo
//
//  Un tirage reproductible.
//
//  Le générateur du système ne se rejoue pas : une partie qui tourne mal est
//  perdue pour l'analyse, et un test qui échoue une fois sur trente n'apprend
//  rien. Celui-ci est un SplitMix64 — quelques lignes, une graine, et la même
//  partie deux fois.
//

import Foundation

struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }
    init() { state = UInt64.random(in: .min ... .max) }

    /// Où en est la suite. Reprendre une partie sans cela n'en serait pas
    /// une reprise : ce serait une autre partie qui commence au même endroit.
    /// `init(seed:)` la remet exactement où elle était.
    var rawState: UInt64 { state }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
