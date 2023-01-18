//
//  MapManager.swift
//  NavCog3
//
//  Created by yoshizawr204 on 2023/01/12.
//  Copyright © 2023 HULOP. All rights reserved.
//

import Foundation

// Singleton
final public class MapManager: NSObject {
    
    public static let shared = MapManager()
    
//    var mapVC: UIViewController?
    var mapVC: MapViewController?

    private override init() {
        super.init()

        self.mapVC = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "map_ui") as? MapViewController
//            .instantiateViewController(withIdentifier: "map_ui_navigation")
    }

//    func getMap() -> UIViewController? {
    func getMap() -> MapViewController? {
        if let mapVC = mapVC {
            return mapVC
        }
        
        return nil
    }
}
