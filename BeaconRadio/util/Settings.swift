//
//  Settings.swift
//  BeaconRadio
//
//  Created by Thomas Bopst on 19/12/14.
//  Copyright (c) 2014 Thomas Bopst. All rights reserved.
//

import Foundation

class Settings {
    
    // MARK: Singleton
    class var sharedInstance: Settings {
        struct Static {
            static var instance: Settings?
            static var token: dispatch_once_t = 0
        }
        dispatch_once(&Static.token) {
            Static.instance = Settings()
        }
        return Static.instance!
    }
    
    private init() {}
    
    // MARK: Settings
    let simulationDataPrefix = "2015-02-07_17-54" //"2015-02-07_17-44" (ok foyer) // "2015-02-07_17-54" (gut, Foyer)
}