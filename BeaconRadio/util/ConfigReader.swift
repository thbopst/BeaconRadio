//
//  Settings.swift
//  BeaconRadio
//
//  Created by Thomas Bopst on 19/12/14.
//  Copyright (c) 2014 Thomas Bopst. All rights reserved.
//

import Foundation

class ConfigReader {
    
    // MARK: Singleton
    class var sharedInstance: ConfigReader {
        struct Static {
            static var instance: ConfigReader?
            static var token: dispatch_once_t = 0
        }
        dispatch_once(&Static.token) {
            Static.instance = ConfigReader()
        }
        return Static.instance!
    }
    
    private var config: [String: AnyObject]?
    
    
    private init() {
        // .pathForResource("Config", ofType: "plist", inDirectory: "resources")
        if let path = NSBundle.mainBundle().pathForResource("Config", ofType: "plist"),
            let configDict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
                self.config = configDict
        } else {
            assertionFailure("Failed to load config file.")
        }
    }
    
    
    // MARK Config Properties
    
    var map: String? {
        get {
            if let config = self.config, let m: AnyObject = config["map"] {
                return m as? String
            } else {
                assertionFailure("Reading map from config failed.")
                return nil
            }
        }
    }
    
    var startPoseMotionTracker: (x: Double, y: Double)? {
        get {
            if let config = self.config,
                let startPose: [String:Double] = config["startPoseMotionTracker"] as? [String:Double],
                let x: Double = startPose["x"],
                let y: Double = startPose["y"] {
                
                    return (x: x, y: y)
            } else {
                assertionFailure("Reading motion tracker's start pose from config failed.")
                return nil
            }
        }
    }
    
    var simulationDataPrefix: String? {
        get {
            if let config = self.config, let prefix: AnyObject = config["simulationDataPrefix"] {
                return prefix as? String
            } else {
                assertionFailure("Reading simulationDataPrefix from config failed.")
                return nil
            }
        }
    }
    // "2015-02-07_17-44" (ok foyer), "2015-02-07_17-54" (gut, Foyer)
    
    class func pathToSimulationDataWithPrefix(prefix: String, dataType type: String) -> String? {
        return NSBundle.mainBundle().pathForResource(type, ofType: "csv", inDirectory: "simulation/\(prefix)")
    }
    
    class func pathToMapImgWithName(name: String) -> String? {
        return NSBundle.mainBundle().pathForResource(name, ofType: "png", inDirectory: "maps")
    }
    
    class func pathToMapPlistWithName(name: String) -> String? {
        return NSBundle.mainBundle().pathForResource(name, ofType: "plist", inDirectory: "maps")
    }
}