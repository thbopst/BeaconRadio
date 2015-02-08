//
//  Heading.swift
//  BeaconRadio
//
//  Created by Thomas Bopst on 06/02/15.
//  Copyright (c) 2015 Thomas Bopst. All rights reserved.
//

import Foundation

class Heading: Comparable {
    
    private var heading: Double // in compass degree
    
    var valueInDeg: Double {
        get {
            return self.heading
        }
    }
    
    var valueInRads: Double {
        get {
            return Angle.compassDeg2UnitCircleRad(self.heading)
        }
    }
    
    init(headingInDegree h:Double) {
        assert(h >= 0.0, "Heading has to be >= 0 deg")
        assert(h < 360.0, "Heading has to be < 360 deg")
        
        self.heading = h
    }
}

func == (lhs: Heading, rhs: Heading) -> Bool {
    return lhs.valueInDeg == rhs.valueInDeg
}

func < (lhs: Heading, rhs: Heading) -> Bool {
    return lhs.valueInDeg < rhs.valueInDeg
}

func + (lhs: Heading, rhs: Heading) -> Heading {
    return Heading(headingInDegree: (lhs.valueInDeg + rhs.valueInDeg) % 360.0)
}

func - (lhs: Heading, rhs: Heading) -> Heading {
    
    var result: Double
    
    if lhs.valueInDeg >= 0 && lhs.valueInDeg < rhs.valueInDeg {
        result = 360.0 - (rhs.valueInDeg - lhs.valueInDeg)
    } else {
        result = lhs.valueInDeg - rhs.valueInDeg
    }
    
    return Heading(headingInDegree: result)
}