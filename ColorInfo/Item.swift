//
//  Item.swift
//  ColorInfo
//
//  Created by Qin Hangyu on 2025/3/11.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
