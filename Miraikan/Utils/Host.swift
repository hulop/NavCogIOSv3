//
//  Host.swift
//  NavCog3
//
//  Created by yoshizawr204 on 2023/01/12.
//  Copyright © 2023 HULOP. All rights reserved.
//

import Foundation

enum Host {
    case miraikan
    case inkNavi
    
    var address: String {
        switch self {
        case .miraikan:
            return "https://www.miraikan.jst.go.jp"
        case .inkNavi:
            return ""
        }
    }
}
