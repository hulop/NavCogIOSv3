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
    var latitude:Double?, longitude:Double?, floor:Int?, building:String?
    
    var available:Bool = false {
        didSet {            
            NSNotificationCenter.defaultCenter().postNotificationName(DIALOG_AVAILABILITY_CHANGED_NOTIFICATION, object: available)
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
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(serverConfigChanged(_:)), name: SERVER_CONFIG_CHANGED_NOTIFICATION, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(locationChanged(_:)), name: NAV_LOCATION_CHANGED_NOTIFICATION, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(buildingChanged(_:)), name: BUILDING_CHANGED_NOTIFICATION, object: nil)
    }
    
    func isDialogAvailable()->Bool {
        return available
    }
    
    func serverConfigChanged(note:NSNotification) {
        available = false
        // check serverconfig
        if let _ = note.object {
            let config:NSDictionary = note.object as! NSDictionary // config json == NavDataStore.sharedDataStore().serverConfig()

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
    
    func locationChanged (note:NSNotification) {
        if let object = note.object {
            if let current = object["current"] as? HLPLocation {
                self.latitude = current.lat
                self.longitude = current.lng
                self.floor = Int(round(current.floor))
            }
        }
    }
    
    func buildingChanged (note:NSNotification) {
        if let object:NSDictionary = (note.object as! NSDictionary) {
            if let building:String = object["building"] as? String {
                self.building = building
            }
        }
    }
    
    func setLocationContext(context:NSMutableDictionary) {
        if let latitude = latitude {
            context["latitude"] = latitude
        }
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
}
