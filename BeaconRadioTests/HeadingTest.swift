//
//  Heading.swift
//  BeaconRadio
//
//  Created by Thomas Bopst on 06/02/15.
//  Copyright (c) 2015 Thomas Bopst. All rights reserved.
//

import UIKit
import XCTest

class HeadingTest: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    
    func testEqualToOperator() {
        XCTAssert(Heading(headingInDegree: 0.0) == Heading(headingInDegree: 0.0), "Headings should be equal")
        XCTAssertFalse(Heading(headingInDegree: 0.0) == Heading(headingInDegree: 0.1), "Headings should not be equal")
        XCTAssertFalse(Heading(headingInDegree: 0.1) == Heading(headingInDegree: 0.0), "Headings should not be equal")
    }
    
    func testNotEqualToOperator() {
        XCTAssert(Heading(headingInDegree: 0.0) != Heading(headingInDegree: 0.1), "Headings should not be equal")
        XCTAssert(Heading(headingInDegree: 0.1) != Heading(headingInDegree: 0.0), "Headings should not be equal")
        XCTAssertFalse(Heading(headingInDegree: 0.0) != Heading(headingInDegree: 0.0), "Headings should be equal")
    }
    
    func testAdditionOperator() {
        XCTAssertEqual(Heading(headingInDegree: 0.0) + Heading(headingInDegree: 0.0), Heading(headingInDegree: 0.0), "0.0 + 0.0 should be 0.0")
        
        XCTAssertEqual(Heading(headingInDegree: 0.0) + Heading(headingInDegree: 0.1), Heading(headingInDegree: 0.1), "0.0 + 0.1 should be 0.1")
        XCTAssertEqual(Heading(headingInDegree: 0.1) + Heading(headingInDegree: 0.0), Heading(headingInDegree: 0.1), "0.1 + 0.0 should be 0.1")
        XCTAssertEqual(Heading(headingInDegree: 0.1) + Heading(headingInDegree: 0.1), Heading(headingInDegree: 0.2), "0.1 + 0.1 should be 0.2")
        
        XCTAssertEqual(Heading(headingInDegree: 0.0) + Heading(headingInDegree: 359.9), Heading(headingInDegree: 359.9), "0.0 + 359.9 should be 359.9")
        XCTAssertEqual(Heading(headingInDegree: 359.9) + Heading(headingInDegree: 0.0), Heading(headingInDegree: 359.9), "359.9 + 0.0 should be 359.9")
        
        XCTAssertEqual(Heading(headingInDegree: 0.1) + Heading(headingInDegree: 359.9), Heading(headingInDegree: 0.0), "0.1 + 359.9 should be 0.0")
        XCTAssertEqual(Heading(headingInDegree: 359.9) + Heading(headingInDegree: 0.1), Heading(headingInDegree: 0.0), "359.9 + 0.1 should be 0.0")
        
        XCTAssertEqual(Heading(headingInDegree: 359.0) + Heading(headingInDegree: 2.0), Heading(headingInDegree: 1.0), "359.0 + 2.0 should be 1.0")
        XCTAssertEqual(Heading(headingInDegree: 2.0) + Heading(headingInDegree: 359.0), Heading(headingInDegree: 1.0), "2.0 + 359.0 should be 1.0")
        
        XCTAssertEqual(Heading(headingInDegree: 359.0) + Heading(headingInDegree: 359.0), Heading(headingInDegree: 358.0), "359.0 + 359.0 should be 358.0")
    }
    
    func testSubtractionOperator() {
        XCTAssertEqual(Heading(headingInDegree: 0.0) - Heading(headingInDegree: 0.0), Heading(headingInDegree: 0.0), "0.0 - 0.0 should be 0.0")
        
        XCTAssertEqual(Heading(headingInDegree: 0.0) - Heading(headingInDegree: 1.0), Heading(headingInDegree: 359.0), "0.0 - 1.0 should be 359")
        XCTAssertEqual(Heading(headingInDegree: 1.0) - Heading(headingInDegree: 2.0), Heading(headingInDegree: 359.0), "0.0 - 1.0 should be 359")
        XCTAssertEqual(Heading(headingInDegree: 1.0) - Heading(headingInDegree: 0.0), Heading(headingInDegree: 1.0), "1.0 - 0.0 should be 1.0")
        
        XCTAssertEqual(Heading(headingInDegree: 1.0) - Heading(headingInDegree: 1.0), Heading(headingInDegree: 0.0), "1.0 - 1.0 should be 0.0")
        XCTAssertEqual(Heading(headingInDegree: 2.0) - Heading(headingInDegree: 1.0), Heading(headingInDegree: 1.0), "2.0 - 1.0 should be 1.0")
    }
    
}
