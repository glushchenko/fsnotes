//
//  Colors.swift
//  FSNotes iOS
//
//  Created by Oleksandr Glushchenko on 9/15/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import NightNight

class Colors {
    public static let Header = MixedColor(normal: 0xa6c1d3, night: 0x47444e)

    public static let titleText = MixedColor(normal: 0x000000, night: 0xfafafa)

    public static let buttonText = MixedColor(normal: 0x4d8be6, night: 0x7eeba1)

    public var gl: CAGradientLayer!

    init() {
        let colorTop = UIColor(red: 192.0 / 255.0, green: 38.0 / 255.0, blue: 42.0 / 255.0, alpha: 1.0).cgColor
        let colorBottom = UIColor(red: 35.0 / 255.0, green: 2.0 / 255.0, blue: 2.0 / 255.0, alpha: 1.0).cgColor

        self.gl = CAGradientLayer()
        self.gl.colors = [colorTop, colorBottom]
        self.gl.locations = [0.0, 50.0]
    }
}
