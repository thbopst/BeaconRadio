//
//  Sigellipse.swift
//  BeaconRadio
//
//  Created by Thomas Bopst on 16/02/15.
//  Copyright (c) 2015 Thomas Bopst. All rights reserved.
//

import Accelerate

class Sigellipse {
    
    struct Point {
        let x: Double
        let y: Double
        
        init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }
    
    struct Sigma {
        let m: [Double]
        
        init(m11: Double, m12: Double, m21: Double, m22: Double) {
            self.m = [m11, m12, m21, m22]
        }
        
        init(m: [Double]) {
            assert(m.count == 4, "m has to be a 2x2 matrix")
            self.m = m
        }
    }
    
    let mu: Point
    let sigma: Sigma
    let points: [Point]
    
    private var pointsOfEllipse = [Point]()
    
    init(mu: Point, sigma: Sigma) {
        self.mu = mu
        self.sigma = sigma
        self.points = Sigellipse.calcPointsOfSigellipse(mu, sigma: sigma)
    }
    
    // MARK: calculation of points for sigellipse
    private class func calcPointsOfSigellipse(mu: Point, sigma: Sigma) -> [Point] {
        
        var points = [Point]()
        
        if let invSig = Sigellipse.invert(sigma.m), let eig = Sigellipse.eigen(invSig) {
            let lamda = eig.lamda // l1, l2
            let m_ev = eig.ev // 2x2 Matrix
            
            if lamda[0] >= 0 && lamda[1] >= 0 {
                let n = 360
                let step = 2 * M_PI / Double(n)
                
                for (var t = 0.0; t < 2 * M_PI; t=t+step)  {
                    
                    // point on unit circle
                    var x = cos(t)
                    var y = sin(t)
                    
                    // streched with 1/lamda1 resp. 1/lamda2
                    x = x / sqrt(lamda[0])
                    y = y / sqrt(lamda[1])
                    
                    // rotation with eigenvector matrix (m*(x,y))
                    x = (m_ev[0] * x) + (m_ev[1] * y)
                    y = (m_ev[2] * x) + (m_ev[3] * y)
                    
                    // translation (0,0) -> mu
                    x += mu.x
                    y += mu.y
                    
                    points.append(Point(x: x, y: y))
                }
            }
        }
        
        return points
    }
    
    private class func invert(matrix : [Double]) -> [Double]? {
        // Source: http://stackoverflow.com/questions/26811843/matrix-inversion-in-swift-using-accelerate-framework
        
        var inMatrix = matrix
        var N = __CLPK_integer(sqrt(Double(matrix.count)))
        var pivots = [__CLPK_integer](count: Int(N), repeatedValue: 0)
        var workspace = [Double](count: Int(N), repeatedValue: 0.0)
        var error : __CLPK_integer = 0
        dgetrf_(&N, &N, &inMatrix, &N, &pivots, &error)
        
        if error != 0 {
            println("[ERROR] invert (dgetrf_) code: \(error)")
            return nil
        }
        
        dgetri_(&N, &inMatrix, &N, &pivots, &workspace, &N, &error)
        
        if error != 0 {
            println("[ERROR] invert (dgetri_) code: \(error)")
            return nil
        }
        
        return inMatrix
    }
    
    private class func eigen(matrix: [Double]) -> (lamda: [Double], ev: [Double])? {
        // Source: http://quabr.com/27887215/trouble-with-the-accelerate-framework-in-swift
        
        var matrix:[__CLPK_doublereal] = matrix //[2,1,1,2] //[m11, m12, m21, m22] //
        var N = __CLPK_integer(sqrt(Double(matrix.count)))
        // Real parts of eigenvalues
        var wr = [Double](count: Int(N), repeatedValue: 0)
        // Imaginary parts of eigenvalues
        var wi = [Double](count: Int(N), repeatedValue: 0)
        // Left eigenvectors
        var vl = [__CLPK_doublereal](count: Int(N*N), repeatedValue: 0)
        // Right eigenvectors
        var vr = [__CLPK_doublereal](count: Int(N*N), repeatedValue: 0)
        var error : __CLPK_integer = 0
        var lwork = __CLPK_integer(-1)
        
        var workspaceQuery: Double = 0.0
        dgeev_(UnsafeMutablePointer(("V" as NSString).UTF8String), UnsafeMutablePointer(("V" as NSString).UTF8String), &N, &matrix, &N, &wr, &wi, &vl, &N, &vr, &N, &workspaceQuery, &lwork, &error)
        
        
        // size workspace per the results of the query:
        var workspace = [Double](count: Int(workspaceQuery), repeatedValue: 0.0)
        lwork = __CLPK_integer(workspaceQuery)
        
        dgeev_(UnsafeMutablePointer(("V" as NSString).UTF8String), UnsafeMutablePointer(("V" as NSString).UTF8String), &N, &matrix, &N, &wr, &wi, &vl, &N, &vr, &N, &workspace, &lwork, &error)
        
        if error != 0 {
            println("[ERROR] eigen (dgeev_) code: \(error)")
            return nil
        }
        
        // this now prints non-zero values
//        println("\(wr), \(vl), \(vr)")
        
        return (lamda: wr, ev: vr)
    }
    
}