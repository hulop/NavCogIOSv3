/*******************************************************************************
 * Copyright (c) 2014, 2016  IBM Corporation, Carnegie Mellon University and others
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

import UIKit

class DialogManager: NSObject {
    var latitude:Double?, longitude:Double?, floor:Int?, building:String?, isActive:Bool = false
    
    var available:Bool = false {
        didSet {            
            NotificationCenter.default.post(name: Notification.Name(rawValue: DIALOG_AVAILABILITY_CHANGED_NOTIFICATION), object:self, userInfo:["available":available])
        }
    }
    static var instance:DialogManager?
    static func sharedManager()->DialogManager {
        if instance == nil {
            instance = DialogManager()
        }
        return instance!
    }
    
    override init() {
        super.init()
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(serverConfigChanged(_:)), name: NSNotification.Name(rawValue: SERVER_CONFIG_CHANGED_NOTIFICATION), object: nil)
        nc.addObserver(self, selector: #selector(locationChanged(_:)), name: NSNotification.Name(rawValue: NAV_LOCATION_CHANGED_NOTIFICATION), object: nil)
        nc.addObserver(self, selector: #selector(buildingChanged(_:)), name: NSNotification.Name(rawValue: BUILDING_CHANGED_NOTIFICATION), object: nil)
        nc.addObserver(self, selector: #selector(RestartConversation(_:)), name:NSNotification.Name(rawValue: "RestartConversation"), object: nil)
        nc.addObserver(self, selector: #selector(ResetConversation(_:)), name:NSNotification.Name(rawValue: "ResetConversation"), object: nil)
    }
    
    func isDialogAvailable()->Bool {
        return available
    }
    
    func serverConfigChanged(_ note:Notification) {
        available = false
        // check serverconfig
        if let config = note.userInfo {
            //let config:NSDictionary = note.userInfo! // config json == NavDataStore.sharedDataStore().serverConfig()

            let server = config["conv_server"]
            if let _server = server as? String {
                if !_server.isEmpty {
                    let key = config["conv_api_key"]
                    if let _key = key as? String {
                        if !_key.isEmpty {
                            available = true
                        }
                    }
                }
            }
        }
    }
    
    func locationChanged (_ note:Notification) {
        if let object = note.userInfo {
            if let current = object["current"] as? HLPLocation {
                self.latitude = nil
                self.longitude = nil
                self.floor = nil
                if (!current.lat.isNaN && !current.lng.isNaN) {
                    self.latitude = current.lat
                    self.longitude = current.lng
                }
                if (!current.floor.isNaN) {
                    self.floor = Int(round(current.floor))
                }
            }
        }
    }
    
    func buildingChanged (_ note:Notification) {
        //if let object:NSDictionary = (note.object as! NSDictionary) {
        if let object:NSDictionary = note.userInfo as NSDictionary? {
            self.building = nil
            if let building:String = object["building"] as? String {
                self.building = building
            }
        }
    }
    
    func RestartConversation (_ note:Notification) {
        isActive = true
    }
    func ResetConversation (_ note:Notification) {
        isActive = false
    }
    
    func setLocationContext(_ context:inout [String: Any]) {
        if let latitude = latitude {
            context["latitude"] = latitude
            if let longitude = longitude {
                context["longitude"] = longitude
            }
            if let floor = floor {
                context["floor"] = floor
            }
            if let building = building {
                context["building"] = building
            }
        }
        let ud = UserDefaults.standard
        context["user_mode"] = ud.string(forKey: "user_mode")
    }
}
