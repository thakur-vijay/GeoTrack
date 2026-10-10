//
//  TabModel.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//

import Foundation

enum TabModel: String, Hashable {
    case map = "Map"
    case settings = "Settings"
    
    var symbolImage: String {
        switch self {
        case .map:
            return "map"
        case .settings:
            return "gear"
        }
    }
}
