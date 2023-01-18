//
//
//  HLPSectionModel.swift
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

class HLPSectionModel {
    
    let nodeId: String?
    let title: String
    let titlePron: String?
    let subtitle: String?
    let subtitlePron: String?
    let toilet: Int

    var nodeLocation: HLPLocation?
    var floor: Int?
    var isExhibitionZone = false

    init(nodeId: String?,
         title: String,
         titlePron: String?,
         subtitle: String?,
         subtitlePron: String?,
         toilet: Int = -1) {
        self.nodeId = nodeId
        self.title = title
        self.titlePron = titlePron
        self.subtitle = subtitle
        self.subtitlePron = subtitlePron
        self.toilet = toilet
    }
}

class SectionModel {

    let nodeId: String
    let title: String
    let titlePron: String
    let subtitle: String
    let subtitlePron: String
    let toilet: Int

    var floor: Int
    var isExhibitionZone = false

    init(model: HLPSectionModel) {
        self.nodeId = model.nodeId ?? ""
        self.title = model.title
        self.titlePron = model.titlePron ?? ""
        self.subtitle = model.subtitle ?? ""
        self.subtitlePron = model.subtitlePron ?? ""
        self.toilet = model.toilet
        let groundFloor = model.floor ?? 0
        self.floor = groundFloor < 0 ? groundFloor: groundFloor + 1
        self.isExhibitionZone = model.isExhibitionZone
    }
}
