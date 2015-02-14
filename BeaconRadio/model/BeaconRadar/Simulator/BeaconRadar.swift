//
//  BeaconRadarSimulator.swift
//  BeaconRadio
//
//  Created by Thomas Bopst on 24/11/14.
//  Copyright (c) 2014 Thomas Bopst. All rights reserved.
//

import Foundation
import CoreLocation

class BeaconRadar: IBeaconRadar, DataPlayerDelegate {
    
    let dataPlayer = DataPlayer()
    private var isRanging = false
    
    var delegate: BeaconRadarDelegate?
    
    required init(uuid: NSUUID) {}
    
    func isAuthorized() -> Bool {
        return true
    }

    func isRangingAvailable() -> Bool {
        return true
    }
    
    func startRanging() {
        isRanging = true
        
        self.dataPlayer.load(dataStoragePath: Util.pathToLogfileWithName("\(Settings.sharedInstance.simulationDataPrefix)_Beacon.csv")! , error: nil)
        self.dataPlayer.playback(self)
    }

    func stopRanging() {
        isRanging = false
    }
    
    // MARK: DataPlayerDelegate
    func dataPlayer(player: DataPlayer, handleData data: [[String:String]]) {
        
        var beacons = [Beacon]()
        
        for d in data {
            let uuid = NSUUID(UUIDString: d["uuid"]!)
            let major: Int = d["major"]!.toInt()!
            let minor: Int = d["minor"]!.toInt()!
            let proximity: CLProximity = CLProximity(rawValue: d["proximity"]!.toInt()!)!
            let accuracy: Double = NSString(string: d["accuracy"]!).doubleValue
            let rssi: Int = d["rssi"]!.toInt()!
            
            let b = Beacon(
                proximityUUID: uuid!,
                major: major,
                minor: minor,
                proximity: proximity,
                accuracy: accuracy,
                rssi: rssi)
            
            beacons.append(b)
        }
        
        if self.isRanging {
            if let delegate = self.delegate {
                delegate.beaconRadar(self, didRangeBeacons: beacons)
            }
        }
    }

}