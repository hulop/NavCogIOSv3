//
//  ImageType.swift
//  NavCog3
//
//  Created by yoshizawr204 on 2023/01/12.
//  Copyright © 2023 HULOP. All rights reserved.
//

import Foundation

/**
 Determine the image size
 */
enum ImageType : String {
    case ASIMO
    case GEO_COSMOS
    case DOME_THEATER
    case CO_STUDIO
    case FLOOR_MAP
    case CARD
    
    var size: CGSize {
        switch self {
        case .ASIMO:
            return CGSize(width: 683, height: 453)
        case .GEO_COSMOS:
            return CGSize(width: 538, height: 404)
        case .DOME_THEATER:
            return CGSize(width: 612, height: 459)
        case .CO_STUDIO:
            return CGSize(width: 600, height: 450)
        case .FLOOR_MAP:
            // 640 x 407.55 is the full size on web
            return CGSize(width: 640, height: 407.55)
        case .CARD:
            return CGSize(width: 538, height: 350)
        }
    }
}
