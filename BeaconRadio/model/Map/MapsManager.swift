//
//  MapManager.swift
//  BeaconRadio
//
//  Created by Thomas Bopst on 30/10/14.
//  Copyright (c) 2014 Thomas Bopst. All rights reserved.
//

import UIKit

class MapsManager {
    
    class func loadMap(#name: String) -> Map? {
        
        if let mapPath = ConfigReader.pathToMapImgWithName(name),
            let plistPath = ConfigReader.pathToMapPlistWithName(name) {
        
            if let mapImg = UIImage(contentsOfFile: mapPath), let plist = NSDictionary(contentsOfFile: plistPath) {
                    
                let scale = plist.valueForKey("scale") as! UInt
                let orientation = plist.valueForKey("orientation") as! Double
                let lms = plist.valueForKey("landmarks") as! [NSDictionary]
                
                if scale < 1 || scale > 100 {
                    assertionFailure("[ERROR] Couldn't load plist file that corresponds to map named '\(name)'. Reason: Scale must be 1 < scale <= 100.")
                }
                if orientation < 0 || orientation >= 360 {
                    assertionFailure("[ERROR] Couldn't load plist file that corresponds to map named '\(name)'. Reason: Orientation must be 0 <= orientation < 360.")
                }
                
                var landmarks: [Landmark] = []
                
                for lm in lms {
                    let proximityUUID = NSUUID(UUIDString: lm.valueForKey("proximityUUID") as! String)
                    let major = lm.valueForKey("major") as! UInt
                    let minor = lm.valueForKey("minor") as! UInt
                    let x = lm.valueForKey("x") as! Double
                    let y = lm.valueForKey("y") as! Double
                    
                    if x < 0 || y < 0 {
                        assertionFailure("[ERROR] Couldn't load plist file that corresponds to map named '\(name)'. Reason: Landmark x and/or y must be > 0.")
                    } else {
                        landmarks.append(Landmark(uuid: proximityUUID!, major: major, minor: minor, x: x, y: y))
                    }
                }

                return Map(map: mapImg, scale: scale, orientation: orientation, landmarks: landmarks)
            }
        }
        assertionFailure("Couldn't load map png and/or plist file for name '\(name)'.")
        return nil
    }
    
}
