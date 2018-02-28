//
//  InterfaceController.swift
//  FSNotes watchOS Extension
//
//  Created by Oleksandr Glushchenko on 2/25/18.
//  Copyright © 2018 Oleksandr Glushchenko. All rights reserved.
//

import WatchKit
import Foundation


class InterfaceController: WKInterfaceController {
    @IBOutlet var notesTable: WKInterfaceTable!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        loadNotes()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        
    }
    
    var data = ["note1", "note2"]
    
    func loadNotes() {
        notesTable.setNumberOfRows(data.count, withRowType: "row")

        for index in 0..<notesTable.numberOfRows{
            let row = notesTable.rowController(at: index) as! TableRowController
            row.name.setText("test")
        }
        notesTable.scrollToRow(at: notesTable.numberOfRows - 1)
    }

}
