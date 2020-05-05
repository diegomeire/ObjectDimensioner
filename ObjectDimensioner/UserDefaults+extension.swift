//
//  UserDefaults+extension.swift
//  ObjectDimensioner
//
//  Created by Diego Meire on 30/04/20.
//  Copyright © 2020 Diego Meire. All rights reserved.
//

import Foundation

extension UserDefaults {
     func setColor(color: UIColor?, forKey key: String) {
         var colorData: NSData?
         if let color = color {
          colorData = NSKeyedArchiver.archivedData(withRootObject: color) as NSData?
         }
         set(colorData, forKey: key)// UserDefault Built-in Method into Any?
    }
    
    func colorForKey(key: String) -> UIColor? {
        var color: UIColor?
        if let colorData = data(forKey: key) {
            color = NSKeyedUnarchiver.unarchiveObject(with: colorData) as? UIColor
        }
        return color
    }
}
