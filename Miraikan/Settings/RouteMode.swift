//
//  RouteMode.swift
//  NavCog3
//
//  Created by yoshizawr204 on 2023/01/25.
//  Copyright © 2023 HULOP. All rights reserved.
//

import Foundation

/**
 Caution: This is related to but not the same as the modes in NavCog3
 */
enum RouteMode: String, CaseIterable {
    case general
    case wheelchair
//    case stroller
    case blind
    
    var description: String {
        switch self {
        case .general:
            return NSLocalizedString("user_general", comment: "")
        case .wheelchair:
            return NSLocalizedString("user_wheelchair", comment: "")
//        case .stroller:
//            return NSLocalizedString("user_stroller", comment: "")
        case .blind:
            return NSLocalizedString("user_blind", comment: "")
        }
    }

    var rawInt: Int {
        switch self {
        case .general:
            return 1
        case .wheelchair:
            return 2
//        case .stroller:
//            return 3
        case .blind:
            return 9
        }
    }
}
