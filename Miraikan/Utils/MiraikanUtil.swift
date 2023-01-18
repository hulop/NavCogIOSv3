//
//  Util.swift
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
import UIKit

class MiraikanUtil : NSObject {
    
    // Login status
    static public var isLoggedIn : Bool {
        return UserDefaults.standard.bool(forKey: "LoggedIn")
    }
    
    // Selected RouteMode
    static public var routeMode : RouteMode {
        let val = UserDefaults.standard.string(forKey: "RouteMode") ?? "unknown"
        let mode = RouteMode(rawValue: val) ?? .general
        return mode
    }

    static public var presetId : Int {
        let val = UserDefaults.standard.string(forKey: "RouteMode") ?? "unknown"
        let mode = RouteMode(rawValue: val) ?? .general
        return mode.rawInt
    }

    // HLPLocation
    static public var location: HLPLocation? {
        return NavDataStore.shared().currentLocation()
    }
    
    static public var isLocated : Bool {
        if let loc = location {
            return !loc.lat.isNaN && !loc.lng.isNaN
        }
        
        return false
    }
    
    static public var wrappingMode : NSLineBreakMode {
        let lang = NSLocalizedString("lang", comment: "")
        return lang == "en" ? .byWordWrapping : .byCharWrapping
    }
    
    static public var speechSpeed : Float {
        var val = UserDefaults.standard.float(forKey: "speech_speed")
        if val == 0 {
            val = 0.55
            UserDefaults.standard.set(val, forKey: "speech_speed")
        }
        return val
    }
    
    static public var previewSpeed : Float {
        var val = UserDefaults.standard.float(forKey: "preview_speed")
        if val == 0 {
            val = 5
            UserDefaults.standard.set(val, forKey: "preview_speed")
        }
        return val
    }
    
    // Navigation preview on/off
    @objc static public var isPreview : Bool {
        return !isLocated || UserDefaults.standard.bool(forKey: "OnPreview")
    }
    
    // For WebView in different languages
    static public var miraikanHost : String {
        let lang = NSLocalizedString("lang", comment: "")
        if lang != "ja" {
            return "\(Host.miraikan.address)/\(lang)"
        }
        return Host.miraikan.address
    }
    
    // MARK: JSON
    static private var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
    
    static public func readJSONFile<T: Decodable>(filename: String, type: T.Type) -> Any? {
        
        if let path = Bundle.main.path(forResource: filename, ofType: "json"),
           let data = getDataFrom(path: URL(fileURLWithPath: path)),
           let res = decdoeToJSON(type: type, data: data) {
            return res
        }
        return nil
    }
    
    static public func readJSONFile(filename: String) -> Any? {
        if let path = Bundle.main.path(forResource: filename, ofType: "json"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let json = try? JSONSerialization.jsonObject(with: data,
                                                        options: .mutableLeaves) {
            return json
        }
        return nil
    }
    
    // Middle function for getting data from local file
    static private func getDataFrom(path: URL) -> Data? {
        do {
            let data = try Data(contentsOf: path)
            return data
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    // Middle function to decode JSON to specific model
    static public func decdoeToJSON<T: Decodable>(type: T.Type, data: Data) -> T? {
        do {
            let res = try MiraikanUtil.jsonDecoder.decode(type, from: data)
            return res
        } catch let DecodingError.dataCorrupted(context) {
            print(context)
        } catch let DecodingError.keyNotFound(key, context) {
            print("Key '\(key)' not found:", context.debugDescription)
            print("codingPath:", context.codingPath)
        } catch let DecodingError.valueNotFound(value, context) {
            print("Value '\(value)' not found:", context.debugDescription)
            print("codingPath:", context.codingPath)
        } catch let DecodingError.typeMismatch(type, context)  {
            print("Type '\(type)' mismatch:", context.debugDescription)
            print("codingPath:", context.codingPath)
        } catch {
            print("error: ", error)
        }
        return nil
    }
    
    // Use this only for JSON with unclear structure
    private func deserializeJSON(data: Data) -> Any? {
        do {
            let json = try JSONSerialization.jsonObject(with: data,
                                                        options: .mutableLeaves)
            return json
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    // MARK: Date and Calendar
    static public func calendar() -> Calendar {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }
    
    static public func todayText() -> AccessibilityModel {
        if NSLocalizedString("lang", comment: "") == "ja" {
            return AccessibilityModel(string: todayText(df: "yyyy年MM月dd日 (EEEEE)"),
                                      accessibility: todayText(df: "yyyy年MM月dd日 EEEE"))
        }
        return AccessibilityModel(string: todayText(df: "yyyy.MM.dd EEE"),
                                  accessibility: todayText(df: "yyyy.MM.dd EEEE"))
    }
    
    static public func todayText(df: String) -> String {
        let format = DateFormatter()
        format.dateFormat = df
        format.locale = Locale.current
        return format.string(from: Date())
    }
    
    static public func parseDate(_ str: String, df: String = "yyyy-MM-dd") -> Date? {
        let format = DateFormatter()
        format.dateFormat = df
        format.locale = Locale(identifier: "ja_JP")
        let date = format.date(from: str)
        return date
    }
    
    static public func parseDateTime(_ str: String) -> Date? {
        return parseDate(str, df: "yyyy-MM-dd HH:mm")
    }
    
    static public var isWeekend : Bool {
        let calendar = Calendar(identifier: .japanese)
        let weekday = calendar.component(.weekday, from: Date())
        print("Day of week: \(weekday)")
        return weekday == 1 || weekday == 7
    }
    
    //MARK: Objc utils for NavCog3
    // Open the page for Scientist Communicator Talk
    @objc static public func openTalk(eventId: String, date: Date?, nodeId: String, facilityId: String?) {

        if let date = date {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            formatter.locale = Locale(identifier: "ja_JP")
            let time = formatter.string(from: date)

            if let schedules = MiraikanUtil.readJSONFile(filename: "schedule",
                                                         type: [ScheduleModel].self) as? [ScheduleModel],
                let schedule = schedules.first(where: {$0.time == time }),
                let floorMaps = MiraikanUtil.readJSONFile(filename: "floor_map",
                                             type: [FloorMapModel].self) as? [FloorMapModel],
               let floorMap = floorMaps.first(where: {$0.id == facilityId }),
               let event = ExhibitionDataStore.shared.events?.first(where: {$0.id == eventId}) {
                let model = ScheduleRowModel(schedule: schedule,
                                             floorMap: floorMap,
                                             event: event)
                
                if let window = UIApplication.shared.windows.first,
//                   let tab = window.rootViewController as? TabController {
                   let tab = window.rootViewController as? MainTabController {
                    tab.selectedIndex = 2
                    
                    if let baseTab = tab.selectedViewController as? BaseTabController {
                        baseTab.popToRootViewController(animated: false)
                        baseTab.nav.show(EventDetailViewController(model: model, title: model.event.title), sender: nil)
//                        baseTab.nav.openMap(nodeId: nodeId)

//                        let today = Date()
//                        if date < today {
//                            let alert = UIAlertController(title: nil, message: "本日のイベントは終了しています", preferredStyle: .alert)
//                            let yesAction = UIAlertAction(title: "OK", style: .default)
//                            alert.addAction(yesAction)
//                            parent(alert, animated: true, completion: nil)
//                        }

                        return
                    }
                }
            }
        }

        if let window = UIApplication.shared.windows.first,
//           let tab = window.rootViewController as? TabController {
           let tab = window.rootViewController as? MainTabController {
            tab.selectedIndex = 2
            
            if let baseTab = tab.selectedViewController as? BaseTabController {
                baseTab.popToRootViewController(animated: false)
                baseTab.nav.openMap(nodeId: nodeId)
            }
        }
    }
    
    // Print the nodeIds and place names that is easy to copy
    @objc static public func printNode(nodeId: String, place: String) {
        print("\(nodeId), \(place)")
    }
    
    /**
     Configure the HLPLcationManager and start locating
     */
    @objc static public func startLocating() {
        
        NavDataStore.shared().setUpHLPLocationManager()
    }


    @objc static public func initNavData() {
        guard let navDataStore = NavDataStore.shared() else { return }
        navDataStore.reloadDestinations(atLat: 35.618531,
                                        lng: 139.776347,
                                        forUser: navDataStore.userID,
                                        withUserLang: navDataStore.userLanguage())
    }
}
