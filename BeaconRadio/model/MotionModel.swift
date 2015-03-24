//
//  MotionModel.swift
//  BeaconRadio
//
//  Created by Thomas Bopst on 06/11/14.
//  Copyright (c) 2014 Thomas Bopst. All rights reserved.
//

import Foundation
import CoreMotion
import CoreLocation


class MotionModel: MotionTrackerDelegate {
    
    struct Motion {
        let heading: Double
        let distance: Double
        let startDate: NSDate
        let endDate: NSDate
        
        init(heading: Double, distance:Double, startDate: NSDate, endDate: NSDate) {
            self.heading = heading
            self.distance = distance
            self.startDate = startDate
            self.endDate = endDate
        }
    }
    
    private let motionTracker: IMotionTracker = MotionTracker()
    private let map: Map
    
    private var latestHeading: (timestamp: NSDate, heading: Double)?
    private var headingStore: [(timestamp: NSDate, heading: Double)] = []
    private var lastCompassHeading: Heading?
    private var lastDMHeading: Heading?
    private var latestDMHeading: Heading?
    
    private var latestDistanceMeasurement: (timestamp: NSDate, distance: Double)?
    private var motionStore_pf = [Motion]() // particle filter
    private var motionStore = [Motion]()
    
    private var poseStore = [Pose]()
    private var startPose: Pose
    
    private var aNormHistory = [Double](count: 50, repeatedValue: 0.0)
    private var aNormHistoryCounter = 0
    private let stationaryThreshold = 0.1
    
    private var _isDeviceStationary = (timestamp: NSDate(), stationary: true)
    var isDeviceStationary: (timestamp: NSDate, stationary: Bool) {
        get {
            
            let aNormAvg = self.aNormHistory.reduce(0.0, combine: +) / Double(self.aNormHistoryCounter)
            
            let stationary = (aNormAvg <= self.stationaryThreshold)
            
            return (timestamp:NSDate(), stationary: stationary)
        }
    }
    
    private let motionLogger = DataLogger(attributeNames: ["x", "y", "theta"])

    
    init(map: Map) {
        self.map = map
        
        let p = ConfigReader.sharedInstance.startPoseMotionTracker
        self.startPose = Pose(x: p.x, y: p.y, theta: 0.0)
    }
    
    func startMotionTracking() {
        self.motionTracker.startMotionTracking(self)
        self.motionLogger.start()
    }
    
    func stopMotionTracking() {
        self.motionTracker.stopMotionTracking() // TODO: Delete maybe all old data?
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd_HH-mm"
        
        if let path = Util.pathToLogfileWithName("\(dateFormatter.stringFromDate(NSDate()))_MotionPose.csv") {
            self.motionLogger.save(dataStoragePath: path, error: nil)
        }
    }
    
    var latestMotions: [Motion] {
        get {
            return self.motionStore_pf
        }
    }
    
    var stationaryMotion: Motion {
        get {
            return Motion(heading: self.currentHeading(), distance: 0.0, startDate: NSDate(), endDate: NSDate())
        }
    }
    
    func timestampOfLatestDistanceMeasurment() -> NSDate? {
        return self.latestDistanceMeasurement?.timestamp
    }
    
    func resetMotionStore() {
        self.motionStore_pf.removeAll(keepCapacity: true)
    }
    
    func returnResidualMotions(u: [Motion]) {
        self.motionStore_pf = (self.motionStore_pf + u).sorted({$0.startDate.compare($1.startDate) == NSComparisonResult.OrderedAscending})
    }
    
    
    // MARK: Motion based pose estimation
    private func computeNewPoseEstimation() {
        
        var xDiff = 0.0
        var yDiff = 0.0
        
        var heading = 0.0
        
        for u_t in self.motionStore {
            xDiff += cos(u_t.heading) * u_t.distance
            yDiff += sin(u_t.heading) * u_t.distance
            
            heading = u_t.heading
        }
        
        let lastPose = self.lastPoseEstimation
        if xDiff != 0.0 && yDiff != 0.0 {
            let x = lastPose.x + xDiff
            let y = lastPose.y + yDiff
            let theta = heading
            poseStore.append(Pose(x: x, y: y, theta: theta))
            self.motionLogger.log([["x":"\(x)", "y":"\(y)", "theta":"\(theta)"]])
        }
        
        self.motionStore.removeAll(keepCapacity: true)
    }
    
    var lastPoseEstimation: Pose {
        get {
            if let last = self.poseStore.last {
                return last
            } else {
                let p = self.startPose
                self.poseStore.append(p)
                
                return p
            }
        }
    }
    
    var estimatedPath: [Pose] {
        get {
            return self.poseStore
        }
    }

    
    // MARK: MotionTrackerDelegate
    
    func motionTracker(tracker: IMotionTracker, didMeasureCompassHeading heading: Heading, withTimestamp ts: NSDate) {
        
        // map based compass heading
        let mapBasedHeading = heading - Heading(headingInDegree: self.map.mapOrientation)
        
        var newHeading = mapBasedHeading
        
        
        // calc diff of device motion heading
        if self.latestDMHeading != nil && self.lastDMHeading != nil {
            let dmHeadingDiff = self.latestDMHeading!.valueInDeg - self.lastDMHeading!.valueInDeg
            
            // diff of compass heading
            
            if let lastCompassHeading = self.lastCompassHeading {
                let compassHeadingDiff = mapBasedHeading.valueInDeg - lastCompassHeading.valueInDeg
                
                // avg difference
                let avgHeadingDiff = (compassHeadingDiff + dmHeadingDiff) / 2.0
                
                
                if avgHeadingDiff < 0 {
                    newHeading = lastCompassHeading - Heading(headingInDegree: abs(avgHeadingDiff))
                } else {
                    newHeading = lastCompassHeading + Heading(headingInDegree: avgHeadingDiff)
                }
                
//                println("Heading cDiff: \(compassHeadingDiff), dmDiff: \(dmHeadingDiff), avg: \(avgHeadingDiff), nHeading: \(newHeading.valueInDeg)")
            }
        }

        
        self.headingStore.append((timestamp: ts, heading: newHeading.valueInRads))
        
        self.lastCompassHeading = mapBasedHeading
        
        if let latest = self.latestDMHeading {
            self.lastDMHeading = latest
        }
    }
        
    func motionTracker(tracker: IMotionTracker, didMeasureDeviceMotionHeading heading: Heading, withTimestamp ts: NSDate) {
        
        self.latestDMHeading = heading - Heading(headingInDegree: self.map.mapOrientation)
    }
    
    func motionTracker(tracker: IMotionTracker, didReceiveDistance d: Double, withStartDate start: NSDate, andEndDate end: NSDate) {
        
        var motions = [Motion]()
        
        if let last = self.latestDistanceMeasurement {
            
            if d > last.distance { // same distance ist sometimes sent multiple times with different timestamp
                motions = computeMotionsByIntegratingHeadingIntoDistance(d - last.distance, forStartTime: last.timestamp, andEndTime: end)
                resetHeadingStore()
            }
            
        } else {
            motions = computeMotionsByIntegratingHeadingIntoDistance(d, forStartTime: start, andEndTime: end)
        }
        
        self.motionStore += motions
        self.motionStore_pf += motions
        
        self.latestDistanceMeasurement = (timestamp: end, distance: d)
        computeNewPoseEstimation()
    }

    
    func motionTracker(tracker: IMotionTracker, didMeasureAccelerationWithNorm aNorm: Double, withTimestamp ts:NSDate) {
        self.aNormHistory[self.aNormHistoryCounter % self.aNormHistory.count] = aNorm
        
        self.aNormHistoryCounter = (self.aNormHistoryCounter + 1) % self.aNormHistory.count
    }
    
    
    // MARK: Motion calculation
    private func computeMotionsByIntegratingHeadingIntoDistance(distance: Double, forStartTime start: NSDate, andEndTime end: NSDate) -> [Motion] {
        
        let headings = self.headingStore.filter({h in (h.timestamp.compare(start) != NSComparisonResult.OrderedAscending && h.timestamp.compare(end) != NSComparisonResult.OrderedDescending)})
        //FIXME headings filter
        
//        if let first = headings.first {
//            if first.timestamp.compare(start) == NSComparisonResult.OrderedDescending && // suche heading davor und setzte startdate auf start
//        }
        
        let totalDuration = end.timeIntervalSinceDate(start)
        
        
        var motions = [Motion]()
        
        if headings.isEmpty {
            motions.append(Motion(heading: currentHeading(), distance: distance, startDate: start, endDate: end))
        } else {
            for (index, heading) in enumerate(headings) {
                
                var startDate: NSDate = start
                var endDate: NSDate = end
                
                if index == 0 && headings.count > 1 { // first heading use start date and next heading
                    endDate = headings[index+1].timestamp
                    startDate = start
                } else if index > 0 && headings.count > index+1 { // successor: yes
                    endDate = headings[index+1].timestamp
                    startDate = heading.timestamp
                } else if index > 0 { // successor: no
                    endDate = end
                    startDate = heading.timestamp
                }
                
                let headingDuration = endDate.timeIntervalSinceDate(startDate)
                
                let d = distance * headingDuration/totalDuration
                
                motions.append(Motion(heading: heading.heading, distance: d, startDate: startDate, endDate: endDate))
            }
        }
        
        return motions
    }
    
    private func currentHeading() -> Double {
        var heading = 0.0
        if let last = self.headingStore.last {
            heading = last.heading
        } else if let last = self.latestHeading {
            heading = last.heading
        }
        return heading
    }
    
    private func resetHeadingStore() {
        if let last = self.headingStore.last {
            self.latestHeading = last
            self.headingStore.removeAll(keepCapacity: true)
        }
    }
    
    
    // MARK: Sample Motion Model
    class func sampleParticlePoseForPose(p: Pose, withMotions u: [Motion], andMap m: Map) -> Pose {
        
        var pose = p
        
        for u_t in u {
            pose = sampleParticlePoseForPose(pose, withMotion: u_t, andMap: m)
        }
        
        return pose
    }
    
    class func sampleParticlePoseForPose(p: Pose, withMotion u: Motion, andMap m: Map) -> Pose {
        var pose = p
        var i = 0
        
        do {
            var sigma_rot = Angle.deg2Rad(20.0) // degree 30, 15
            var sigma_trans = 0.3 * u.distance // m 0.5 * u.distance, 0.25
            
            if u.distance == 0.0 {
                sigma_rot = M_PI
                sigma_trans = 0.3 // 0.5, 0.25
            }
            
            var h = u.heading - Random.sample_normal_distribution(sigma_rot)
            let d = u.distance - Random.sample_normal_distribution(sigma_trans)
            
            var xDiff = cos(h) * d
            var yDiff = sin(h) * d
            
            pose = Pose(x: p.x + xDiff, y: p.y + yDiff, theta: h)
            
        } while (!m.isCellFree(x: pose.x, y: pose.y) && i++ < 10)
        
        return pose
    }

}