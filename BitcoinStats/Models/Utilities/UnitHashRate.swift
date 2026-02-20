//
//  UnitHashRate.swift
//  BitcoinStats
//
//  Created by Jonathan Lehr on 2/16/26.
//

import Foundation

/// Custom Dimension subclass for representing Bitcoin network hash rate.
class UnitHashRate: Dimension, @unchecked Sendable {

    static let hashesPerSecond = UnitHashRate(
        symbol: "H/s",
        converter: UnitConverterLinear(coefficient: 1)
    )

    static let kilohashesPerSecond = UnitHashRate(
        symbol: "KH/s",
        converter: UnitConverterLinear(coefficient: 1e3)
    )

    static let megahashesPerSecond = UnitHashRate(
        symbol: "MH/s",
        converter: UnitConverterLinear(coefficient: 1e6)
    )

    static let gigahashesPerSecond = UnitHashRate(
        symbol: "GH/s",
        converter: UnitConverterLinear(coefficient: 1e9)
    )

    static let terahashesPerSecond = UnitHashRate(
        symbol: "TH/s",
        converter: UnitConverterLinear(coefficient: 1e12)
    )

    static let petahashesPerSecond = UnitHashRate(
        symbol: "PH/s",
        converter: UnitConverterLinear(coefficient: 1e15)
    )

    static let exahashesPerSecond = UnitHashRate(
        symbol: "EH/s",
        converter: UnitConverterLinear(coefficient: 1e18)
    )

    override class func baseUnit() -> Self {
        hashesPerSecond as! Self
    }
}
