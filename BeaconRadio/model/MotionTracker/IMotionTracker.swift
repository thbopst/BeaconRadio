//
//  MotionTrackerFactory.swift
//  BeaconRadio
//
//  Created by Thomas Bopst on 24/11/14.
//  Copyright (c) 2014 Thomas Bopst. All rights reserved.
//

import Foundation
import CoreMotion


protocol IMotionTracker {
    init()
    func startMotionTracking(delegate: MotionTrackerDelegate)
    func stopMotionTracking()
}

protocol MotionTrackerDelegate {
    func motionTracker(tracker: IMotionTracker, didMeasureCompassHeading heading: Heading, withTimestamp ts: NSDate)
    func motionTracker(tracker: IMotionTracker, didMeasureDeviceMotionHeading heading: Heading, withTimestamp ts: NSDate)
    func motionTracker(tracker: IMotionTracker, didReceiveDistance d: Double, withStartDate start: NSDate, andEndDate end: NSDate)
    func motionTracker(tracker: IMotionTracker, didMeasureAccelerationWithNorm aNorm: Double, withTimestamp ts:NSDate)
}
