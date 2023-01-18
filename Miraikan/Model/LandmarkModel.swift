//
//
//  LandmarkModel.swift
//  NavCogMiraikan
//
/*******************************************************************************
 * Copyright (c) 2022 © Miraikan - The National Museum of Emerging Science and Innovation  
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

import Foundation

class LandmarkModel {
    
    let id: String
    let nodeId: String
    var title: String
    var titlePron: String
    var titleEn: String?
    let nodeLocation: HLPLocation
    let spotLocation: HLPLocation
    let groundFloor: Int
    let checkPointOnly: Bool

    var isExhibitionZone = false
    var distance: Double = 0

    ///groundFloor: -2-,-1,0,1,2
    ///floor: -2, -1, 1, 2, 3
    init(id: String,
         nodeId: String,
         groundFloor: Int,
         title: String,
         titlePron: String,
         titleEn: String? = nil,
         nodeLocation: HLPLocation,
         spotLocation: HLPLocation,
         checkPointOnly: Bool = false) {
        self.id = id
        self.nodeId = nodeId
        self.groundFloor = groundFloor
        self.title = title.trimmingCharacters(in: .newlines)
        self.titlePron = titlePron.trimmingCharacters(in: .newlines)
        self.titleEn = titleEn
        self.nodeLocation = nodeLocation
        self.spotLocation = spotLocation
        self.checkPointOnly = checkPointOnly
    }

    var floor: Int {
        groundFloor < 0 ? groundFloor : groundFloor + 1
    }

    func titleUpdate(title: String, titlePron: String, titleEn: String? = nil) {
        self.title = title.trimmingCharacters(in: .newlines)
        self.titlePron = titlePron.trimmingCharacters(in: .newlines)
        self.titleEn = titleEn
    }
}

class PositionModel {
    let id: String
    let titlePron: String
    let titleEn: String?
    var distance: Double = 0
    var angle: Double = 0
    var latitude: Double = 0
    var longitude: Double = 0

    init(id: String, titlePron: String, titleEn: String? = nil) {
        self.id = id
        self.titlePron = titlePron
        self.titleEn = titleEn
    }
}
