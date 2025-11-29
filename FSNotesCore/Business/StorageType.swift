//
//  StorageType.swift
//  FSNotes
//
//  Created by Олександр Глущенко on 06.05.2020.
//  Copyright © 2020 Oleksandr Glushchenko. All rights reserved.
//

import Foundation

public enum StorageType: Int {
    case none        = 0x00
    case local       = 0x01
    case iCloudDrive = 0x02
    case custom      = 0x03
}
