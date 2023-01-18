//
//  ExhibitionDataStore.swift
//  NavCogMiraikan
//
/*******************************************************************************
 * Copyright (c) 2021 © Miraikan - The National Museum of Emerging Science and Innovation
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
 The sub-struct for multiple locations
 
 - Parameters:
 - nodeId: The destination id
 - floor: The floor
 */
struct ExhibitionLocation : Decodable {
    let nodeId: String
    let floor: Int
}

/**
 Model for EventList items
 
 - Parameters:
 - time: The time scheduled on that day
 - place: The place
 - event: The event id
 - desc: The additional description
 - onHoliday: For both weekends and public holidays
 */
struct ScheduleModel : Decodable {
    let time: String
    let place: String
    let event: String
    let description: String?
    let onHoliday: Bool?
    let viewType: Int?
    let type: Int?
    let runningTime: Int?
    let reserve: Bool?
}

/**
 Model for EventView details
 
 - Parameters:
 - id: event id
 - title: The name displayed as link title
 - talkTitle: The name for communication talk
 - imageType: This is in order to determine the image scale ratio
 - schedule: list of scheduled time
 - desc: list of additional description
 - content: The content
 */
struct EventModel : Decodable {
    let id: String
    let title: String
    let titleEn: String?
    let titlePron: String?
    let talkTitle: String?
    let imageType: String
    let schedule: [String]?
    let description: [String]?
    let content: String
    let viewType: [EventTypeModel]?
    let type: [EventTypeModel]?
}

struct EventTypeModel : Decodable {
    let id: Int
    let name: String
    let nameEn: String?
}

/**
 Singleton for exhibition data transfer between different views
 */
@objc class ExhibitionDataStore: NSObject {
    
    @objc static let shared = ExhibitionDataStore()
    
//    var exhibitions: [ExhibitionModel]?
    
    var schedules: [ScheduleModel]?
    
    var events: [EventModel]?
    
    @objc var descriptions: [String]?
    
}
