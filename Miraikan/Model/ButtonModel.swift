//
//  ButtonModel.swift
//  NavCog3
//
//  Created by yoshizawr204 on 2023/02/01.
//  Copyright © 2023 HULOP. All rights reserved.
//

import Foundation

struct ButtonModel {
    let title: String
    let key: String
    let isEnabled : Bool?
    var tapAction: (()->())?
}
