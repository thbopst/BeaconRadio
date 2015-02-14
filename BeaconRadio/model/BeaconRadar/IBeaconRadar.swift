//
//  BeaconRadarFactory.swift
//  BeaconRadio
//
//  Created by Thomas Bopst on 23/11/14.
//  Copyright (c) 2014 Thomas Bopst. All rights reserved.
//

import Foundation
import CoreLocation


protocol IBeaconRadar {
    
    var delegate: BeaconRadarDelegate? {get set}
    
    init(uuid: NSUUID)
    
    func startRanging()
    func stopRanging()
    func isAuthorized() -> Bool
    func isRangingAvailable() -> Bool
}

protocol BeaconRadarDelegate {
    func beaconRadar(radar: IBeaconRadar, didRangeBeacons beacons: [Beacon])
}