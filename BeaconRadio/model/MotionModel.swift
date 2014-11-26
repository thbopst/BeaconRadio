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
        
        init(heading: Double, distance:Double) {
            self.heading = heading
            self.distance = distance
        }
    }
    
    private let motionTracker = MotionTrackerFactory.motionTracker
    
    private var latestHeading: (timestamp: NSDate, heading: Double)?
    private var headingStore: [(timestamp: NSDate, heading: Double)] = []
    private var latestDistanceMeasurement: (timestamp: NSDate, distance: Double)?
    private var motionStore = [Motion]()
    
    private var poseStore = [Pose]()
    
    
    init() {
        
    }
    
    func startMotionTracking() {
        self.motionTracker.startMotionTracking(self)
    }
    
    func stopMotionTracking() {
        self.motionTracker.stopMotionTracking() // TODO: Delete maybe all old data?
    }
    
    // MARK: Sample Motion Model
    class func sampleParticlePoseForPose(p: Pose, withMotions u: [Motion], andMap m: Map) -> Pose {
        
        var i = 0
        var pose: Pose
        
        do {
            var xDiff = 0.0
            var yDiff = 0.0
            
            var h = 0.0
            
            for u_t in u {
                let sigma_rot = Angle.deg2Rad(10.0) // degree
                let sigma_trans = 0.068 * u_t.distance + 2.1559 // FIXME: 2.1559 too big!!! Do distance measurement also for 5m.
                
                h = u_t.heading - Random.sample_normal_distribution(sigma_rot)
                let d = u_t.distance - Random.sample_normal_distribution(sigma_trans)
                
                xDiff += cos(h) * d
                yDiff += sin(h) * d
            }
            
            pose = Pose(x: p.x + xDiff, y: p.y + yDiff, theta: h)

        } while (!m.isCellFree(x: pose.x, y: pose.y) && i++ < 5)
        
        
        return pose
    }
    
    var latestMotions: [Motion] {
        get {
            return self.motionStore + [Motion(heading: self.currentHeading(), distance: 0.0)] // adds current heading => particle moves if motionStore isEmpty
        }
    }
    
    func resetMotionStore() {
        self.motionStore.removeAll(keepCapacity: true)
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
        
        poseStore.append(Pose(x: lastPose.x + xDiff, y: lastPose.y + yDiff, theta: heading))
    }
    
    var lastPoseEstimation: Pose {
        get {
            if let last = self.poseStore.last {
                return last
            } else {
                return Pose(x: 0, y: 0, theta: currentHeading())
            }
        }
    }
    
    var estimatedPath: [Pose] {
        get {
            return self.poseStore
        }
    }

    
    // MARK: MotionTrackerDelegate
    func motionTracker(tracker: IMotionTracker, didReceiveHeading heading: Double, withTimestamp ts: NSDate) {
        
        let tupel: (timestamp: NSDate, heading: Double) = (ts, Angle.compassDeg2UnitCircleRad(heading))
        
        self.headingStore.append(tupel)
    }
    
    func motionTracker(tracker: IMotionTracker, didReceiveDistance d: Double, withStartDate start: NSDate, andEndDate end: NSDate) {
        
        if let last = self.latestDistanceMeasurement {
            self.motionStore += computeMotionsByIntegratingHeadingIntoDistance(d - last.distance, forStartTime: last.timestamp, andEndTime: end)
        } else {
            self.motionStore += computeMotionsByIntegratingHeadingIntoDistance(d, forStartTime: start, andEndTime: end)
        }
        
        self.latestDistanceMeasurement = (end, d)
        computeNewPoseEstimation()
    }
    
    
    // MARK: Motion calculation
    private func computeMotionsByIntegratingHeadingIntoDistance(distance: Double, forStartTime start: NSDate, andEndTime end: NSDate) -> [Motion] {
        
        let headings = self.headingStore.filter({h in (h.timestamp.compare(start) != NSComparisonResult.OrderedAscending && h.timestamp.compare(end) != NSComparisonResult.OrderedDescending)})
        
        let totalDuration = end.timeIntervalSinceDate(start)
        
        
        var motions = [Motion]()
        
        if headings.isEmpty {
            
            let duration = end.timeIntervalSinceDate(start)
            
            motions.append(computeMotionWithHeading(currentHeading(), distance: distance, headingDuration: duration, totalDuration: duration))
        }
        
        // implicit else-Block
        for heading in headings {
            let headingDuration = heading.timestamp.timeIntervalSinceDate(start)
            let magneticHeading = heading.heading
            
            motions.append(computeMotionWithHeading(magneticHeading, distance: distance, headingDuration: headingDuration, totalDuration: totalDuration))
        }
        
        resetHeadingStore()
        
        return motions
    }
    
    private func computeMotionWithHeading(heading: Double, distance: Double, headingDuration: NSTimeInterval, totalDuration: NSTimeInterval) -> Motion {
        
        return Motion(heading: heading, distance: distance * headingDuration/totalDuration)
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

}