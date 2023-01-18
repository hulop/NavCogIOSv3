//
//
//  ExhibitionModel.swift
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

/**
 Model for ExhibitionList items
 
 - Parameters:
 - id : The primary index
 - nodeId: The destination id
 - title: The name displayed as link title
 - category: The category
 - counter: The location on FloorMap
 - floor: The floor
 - locations: Used for multiple locations
 - intro: The description for general and wheelchair mode
 - blindModeIntro: The description for blind mode
 - blindModeIntro: The description for blind mode
 */
struct ExhibitionModel: Decodable {
    let id: String
    let nodeId: String?
    let latitude: String?
    let longitude: String?
    let title: String
    let titlePron: String?
    let category: String
    let counter: String
    let floor: Int?
    let locations: [ExhibitionLocation]?
    let intro: String
    let blindIntro: String
    let blindOverview: String
    let blindDetail: String
}
