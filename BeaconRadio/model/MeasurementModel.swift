//
//  MeasurementModel.swift
//  BeaconRadio
//
//  Created by Thomas Bopst on 10/11/14.
//  Copyright (c) 2014 Thomas Bopst. All rights reserved.
//

import Foundation

typealias Measurement = (timestamp: NSDate, z: [String:Double])

protocol MeasurmentModelDelegate {
    func measurmenetModel(model: MeasurementModel, didObserveMeasurement beacons: [Beacon])
}

class MeasurementModel: BeaconRadarDelegate {
    
    
    
    let uuid = NSUUID(UUIDString: "F0018B9B-7509-4C31-A905-1A27D39C003C")
    let beaconRadar: IBeaconRadar
    
    private var beaconsInRange: [Measurement] = []

    var delegate: MeasurmentModelDelegate?
    
    var measurements: [Measurement] {
        get {
            return self.beaconsInRange
        }
    }
    
    init() {
        self.beaconRadar = BeaconRadar(uuid: uuid!)
        self.beaconRadar.delegate = self
    }

    func startBeaconRanging() {
        self.beaconRadar.startRanging()
    }
    
    func stopBeaconRanging() {
        self.beaconRadar.stopRanging()
    }
    
    func resetMeasurementStore() {
        self.beaconsInRange.removeAll(keepCapacity: false)
    }
    
    func returnResidualMeasurements(z: [Measurement]) {
        self.beaconsInRange = (self.beaconsInRange + z).sorted({$0.timestamp.compare($1.timestamp) == NSComparisonResult.OrderedAscending})
    }
    
    
    // MARK: BeaconRadarDelegate protocol
    
    func beaconRadar(radar: IBeaconRadar, didRangeBeacons beacons: [Beacon]) {

        var z: Measurement = (timestamp: NSDate(), z: [String:Double]())
        
        for beacon in beacons {
            if (beacon.accuracy >= 0 && beacon.accuracy < 5.0) { // 5, 6, (> 7 nicht so gut)
                z.z[beacon.identifier] = beacon.accuracy
            }
        }
        
        if z.z.count > 0 {
            self.beaconsInRange.append(z)
        }
        
        if let delegate = self.delegate {
            delegate.measurmenetModel(self, didObserveMeasurement: beacons)
        }
    }
    
    
    //MARK: Particle weighting
    
    class func weightParticle(particle: Particle, withDistanceMeasurements beaconsInRange: [String: Double],  andMap map: Map) -> Double {
        var weight = 0.0
        
        if map.isCellFree(x: particle.x, y: particle.y) {
            weight = 1.0
            
            for bID in beaconsInRange.keys {
                
                if let lm = map.landmarks[bID] {
                    let diffX = lm.x - particle.x
                    let diffY = lm.y - particle.y
                    
                    let d = sqrt( (diffX * diffX) + (diffY * diffY) )

                    let sigma_d = 0.25 * d // standard deviation [0.25 -0.5] nicht schlecht
                    
                    let d_measurment = beaconsInRange[bID]!
                    
                    let w = NormalDistribution.pdf(d_measurment, mu: d, sigma: sigma_d)
                    
                    weight *= w
                    
                    //                    println("LM: \(bID) -> Distance: \(d), measuredDistance: \(self.beaconsInRange[bID]!), weight: \(w)")
                }
            }
        }
        
        return weight
    }
}