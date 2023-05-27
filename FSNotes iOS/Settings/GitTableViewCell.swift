//
//  GitTableCellView.swift
//  FSNotes iOS
//
//  Created by Oleksandr Hlushchenko on 01.03.2023.
//  Copyright © 2023 Oleksandr Hlushchenko. All rights reserved.
//

import Foundation
import UIKit

class GitTableViewCell: UITableViewCell {
    public var project: Project?
    
    @IBOutlet weak var removeButton: UIButton!
    @IBOutlet weak var cloneButton: UIButton!
    @IBOutlet weak var activity: UIActivityIndicatorView!
    
}
