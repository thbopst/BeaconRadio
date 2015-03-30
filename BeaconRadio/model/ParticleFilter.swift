//
//  ParticleFilter.swift
//  BeaconRadio
//
//  Created by Thomas Bopst on 04/11/14.
//  Copyright (c) 2014 Thomas Bopst. All rights reserved.
//

import Foundation

class ParticleFilter: NSObject, Observable, MeasurmentModelDelegate {
    
    let map: Map
    
    private let particleSetSize = 200
    private var particleSet: [Particle] = [] {
        didSet {
            notifyObservers()
        }
    }
    private let desiredParticleDiversity = 0.20 // in % [0,1]
        
    private var motionModel: MotionModel
    private let measurementModel: MeasurementModel
    
    private var rangedBeacons = [Beacon]()
    
    private var _isRunning = false
    var isRunning: Bool {
        get {
            return _isRunning
        }
    }
    
    var particles: [Particle] {
        get {
            return self.particleSet
        }
    }

    private let particleWeightSumLogger = DataLogger(attributeNames: ["normalizedWeightSum", "particleDiversity", "measurementCount"])
    private let estimatedPathLogger = DataLogger(attributeNames: ["mu_x", "mu_y", "sigma_11", "sigma_12", "sigma_21", "sigma_22", "wMu_x", "wMu_y", "wSigma_11", "wSigma_12", "wSigma_21", "wSigma_22"])
    
    private var meanAndCov: (mu: Sigellipse.Point, sigma: Sigellipse.Sigma)? = nil
    private var weightedMeanAndCov: (mu: Sigellipse.Point, sigma: Sigellipse.Sigma)? = nil
    
    var particleSetMeanAndCov: (mu: Sigellipse.Point, sigma: Sigellipse.Sigma)? {
        get {
            return self.weightedMeanAndCov
        }
    }
    
    
    var estimatedPath = [Pose]()
    
    var motionPath: [Pose] {
        return self.motionModel.estimatedPath
    }
    
    private var recoveryParticleWeightSum = [Double]()
    private var recoveryParticleWeightSumIndex = 0
    
    
    init(map: Map) {
        
        let mm = MeasurementModel()
        self.measurementModel = mm
        
        
        self.map = map
        self.motionModel = MotionModel(map: map)
        super.init()
        mm.delegate = self
    }
    
    func startLocalization() {
        
        // start MotionTracking
        self.motionModel.startMotionTracking()
        self.measurementModel.startBeaconRanging()
        
        // register for beacon updates and wait until first beacons are received
        // particle generation around beacons
        
        self.particleWeightSumLogger.start()
        self.estimatedPathLogger.start()
        
        self._isRunning = true
    }
    
    func stopLocalization() {
        
        self._isRunning = false
        
        self.motionModel.stopMotionTracking()
        self.measurementModel.stopBeaconRanging()
        
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd_HH-mm"
        
        if let path = Util.pathToLogfileWithName("\(dateFormatter.stringFromDate(NSDate()))_ParticleWeight.csv") {
            self.particleWeightSumLogger.save(dataStoragePath: path, error: nil)
        }
        if let path = Util.pathToLogfileWithName("\(dateFormatter.stringFromDate(NSDate()))_EstimatedPath.csv") {
            self.estimatedPathLogger.save(dataStoragePath: path, error: nil)
        }
    }
    
    
    // MARK: Particle Filter algorithm
    func mcl() {
        
        var particlesT = self.particles // copies particleset
        
        // Distance measurements to Beacons
        var z_reverse = self.measurementModel.measurements.reverse()
        self.measurementModel.resetMeasurementStore()
        
        // motions
        var u_reverse = self.motionModel.latestMotions.reverse()
        self.motionModel.resetMotionStore()
        

        while !u_reverse.isEmpty && !z_reverse.isEmpty {
            
            let u_k: MotionModel.Motion = u_reverse.last!
            let z_k: Measurement = z_reverse.last!
            
            let compResult = u_k.endDate.compare(z_k.timestamp)
            
            if compResult == NSComparisonResult.OrderedAscending {
                
                // u_k.end <= z_k.timestamp => add to list
                particlesT = self.integrateMotion(u_k, intoParticleSet: particlesT)
                u_reverse.removeLast()
                
            } else if compResult == NSComparisonResult.OrderedSame {
              
                particlesT = self.integrateMotion(u_k, intoParticleSet: particlesT)
                u_reverse.removeLast()
                // filter
                particlesT = self.filter(particlesT, andMeasurements: z_k)
                z_reverse.removeLast()
                
            } else if u_k.startDate.compare(z_k.timestamp) == NSComparisonResult.OrderedAscending && z_k.timestamp.compare(u_k.endDate) != NSComparisonResult.OrderedDescending {
                
                // u_k.start < z_k.timestamp && z_k.timestamp < u_k.end => split up u_k
                let motionDuration: NSTimeInterval = u_k.endDate.timeIntervalSinceDate(u_k.startDate)
                let durationUntilZ: NSTimeInterval = z_k.timestamp.timeIntervalSinceDate(u_k.startDate)
                
                // create submotion
                let d = u_k.distance * durationUntilZ/motionDuration
                let subMotion1 = MotionModel.Motion(heading: u_k.heading, distance: d, startDate: u_k.startDate, endDate: z_k.timestamp)
                let subMotion2 = MotionModel.Motion(heading: u_k.heading, distance: u_k.distance - d, startDate: z_k.timestamp, endDate: u_k.endDate)
                
                // integrate submotion 1 and filter
                particlesT = self.integrateMotion(subMotion1, intoParticleSet: particlesT)
                u_reverse.removeLast()
                
                // add submotion 2 to
                u_reverse.append(subMotion2)
                
                // filter
                particlesT = self.filter(particlesT, andMeasurements: z_k)
                z_reverse.removeLast()
            } else {
                particlesT = self.filter(particlesT, andMeasurements: z_k)
                z_reverse.removeLast()
            }
        }

        
        // integrate residual motions
        while !u_reverse.isEmpty {
            
            // integrate motion
            let u_k: MotionModel.Motion = u_reverse.last!
            let p = self.integrateMotion(u_k, intoParticleSet: particlesT)
            u_reverse.removeLast()
            
            // filter just with map (without measurements)
            let emptyMeasurement = (timestamp: NSDate(), z: [String:Double]())
            particlesT = self.filter(p, andMeasurements: emptyMeasurement)
        }
        
        
        
        // integrate measurement if no distance was measured until now
        // or if last distance measurement is more than 2.7 seconds ago
        let ts_latesDistance = self.motionModel.timestampOfLatestDistanceMeasurment()
        
        // if device is Stationary => integrate sensor values, if not return them to measurement model
        if self.motionModel.isDeviceStationary.stationary && (ts_latesDistance == nil ||  NSDate().timeIntervalSinceDate(ts_latesDistance!) > 2.7) {
            println("stationary")
            
            while !z_reverse.isEmpty {
                let z_k = z_reverse.last!
                particlesT = self.integrateMotion(self.motionModel.stationaryMotion, intoParticleSet: particlesT)
                particlesT = self.filter(particlesT, andMeasurements: z_k)
                
                z_reverse.removeLast()
            }
            
        } else {
            // return residual values to measurement model
            self.measurementModel.returnResidualMeasurements(z_reverse)
        }
        
        self.particleSet = particlesT // -> notifyObservers

    }
    
    private func integrateMotion(u: MotionModel.Motion, intoParticleSet particles: [Particle]) -> [Particle] {
        
        return particles.map({p in MotionModel.sampleParticlePoseForPose(p, withMotion: u, andMap: self.map)})
    }
    
    private func filter(particles_tMinus1: [Particle], andMeasurements z: Measurement) -> [Particle] {

        var particles_tMinus1 = particles_tMinus1
        let beacons = self.rangedBeacons.sorted({$0.accuracy < $1.accuracy})
        
        // RECOVERY? (Kidnapped?)
        let rCount = self.recoveryParticleWeightSum.count
        
        if rCount == 3 && self.recoveryParticleWeightSum.reduce(0.0, combine: +)/Double(rCount) < 1.0 {
            
            let generatedParticles = generateParticlesAroundBeacons(beacons, count: Int(Double(self.particleSetSize) * 0.2))
            particles_tMinus1 += generatedParticles
            
            println("RECOVERY")
        }
        
        // Sample motion + weight particles
        var weightedParticleSet: [(weight: Double,particle: Particle)] = []
        weightedParticleSet.reserveCapacity(self.particleSetSize)
        
        for particle in particles_tMinus1 {
            
            var w: Double = MeasurementModel.weightParticle(particle, withDistanceMeasurements: z.z, andMap: self.map)
            if w > 0 {
                // commute weights
                if weightedParticleSet.count > 1 {
                    w += weightedParticleSet.last!.0 // add weight of predecessor
                }
                weightedParticleSet += [(weight: w, particle: particle)]
            }
        }
        

        // Histogram to measure particle diversity
        var particleHistogram = [Int](count: weightedParticleSet.count, repeatedValue: 0)
        var differentParticleCount = 0

        // weightedMean
        var weightedParticleSetMean: (x: Double, y: Double) = (0.0, 0.0)
        var weightSum = 0.0
        
        // mean
        var particleSetMean: (x: Double, y: Double) = (0.0, 0.0)
        
        // roulette
        var particles_t: [Particle] = []
        particles_t.reserveCapacity(weightedParticleSet.count)
        
        
        var logCount_addedRandomParticleCount = 0
        
        while weightedParticleSet.count > 0 && particles_t.count < self.particleSetSize {

            let particleDiversity: Double = Double(differentParticleCount) / Double(particleHistogram.count)
            
            // draw particle with probability
            if let last = weightedParticleSet.last {
                let random = Random.rand_uniform() * last.weight
                
                // binary search
                var m: Int = 0;
                var left: Int = 0;
                var right: Int = weightedParticleSet.count-1;
                while left <= right {
                    m = (left + right)/2
                    if random < weightedParticleSet[m].weight {
                        right = m - 1
                    } else if random > weightedParticleSet[m].weight {
                        left = m + 1
                    } else {
                        break
                    }
                }
                
                // drawn particle
                let particle = weightedParticleSet[m].particle
                let weight = weightedParticleSet[m].weight
                
                // add particle to new set
                particles_t.append(particle)
                
                // histogram
                particleHistogram[m] += 1
                if particleHistogram[m] == 1 {
                    ++differentParticleCount
                }
                
                // calc weightedMean
                weightedParticleSetMean.x += particle.x * weight
                weightedParticleSetMean.y += particle.y * weight
                weightSum += weight
                
                // calc mean
                particleSetMean.x += particle.x
                particleSetMean.y += particle.y
            }
        }
        
        // mean calculation && regeneration
        if weightSum > 0 {
            
            // weighted
            let wMean = Sigellipse.Point(x: weightedParticleSetMean.x/weightSum, y: weightedParticleSetMean.y/weightSum)
            let wSigma = self.sigmaForParticleSet(particles_t, withMean: wMean)!
            self.weightedMeanAndCov = (mu: wMean, sigma: wSigma)
            
            // not weighted
            let pCount = Double(particles_t.count)
            let mean = Sigellipse.Point(x: particleSetMean.x/pCount, y: particleSetMean.y/pCount)
            let sigma = self.sigmaForParticleSet(particles_t, withMean: mean)!
            self.meanAndCov = (mu: mean, sigma: sigma)
            
            
            // estimated path
            self.estimatedPath.append(Pose(x: wMean.x, y: wMean.y, theta: 0.0))
            
            // logging
            self.estimatedPathLogger.log([["mu_x":"\(mean.x)", "mu_y":"\(mean.y)", "sigma_11":"\(sigma.m[0])", "sigma_12":"\(sigma.m[1])", "sigma_21":"\(sigma.m[2])", "sigma_22":"\(sigma.m[3])", "wMu_x":"\(wMean.x)", "wMu_y":"\(wMean.y)", "wSigma_11":"\(wSigma.m[0])", "wSigma_12":"\(wSigma.m[1])", "wSigma_21":"\(wSigma.m[2])", "wSigma_22":"\(wSigma.m[3])"]])
            
            // store for recovery
            if !z.z.isEmpty {
                
                // set normalized weight sum (Normalization with particle count and measurment count)
                let normalizedWeightSum = weightSum/Double(particles_t.count)
                
                if self.recoveryParticleWeightSum.count < 3 {
                    self.recoveryParticleWeightSum.append(normalizedWeightSum)
                } else {
                    self.recoveryParticleWeightSum[self.recoveryParticleWeightSumIndex] = normalizedWeightSum
                }
                
                self.recoveryParticleWeightSumIndex = (self.recoveryParticleWeightSumIndex+1) % 3
                
                self.particleWeightSumLogger.log([["normalizedWeightSum" : "\(normalizedWeightSum)", "particleDiversity":"\(Double(differentParticleCount) / Double(particleHistogram.count))", "measurementCount":"\(z.z.count)"]])
                println("normalizedWeightSum: \(normalizedWeightSum), particleDiversity: \(Double(differentParticleCount) / Double(particleHistogram.count)), measurementCount: \(z.z.count)")
            }
            
        } else {
            self.weightedMeanAndCov = nil
            self.meanAndCov = nil
            
            // empty particle set --> complete new generation
            particles_t = generateParticlesAroundBeacons(beacons, count: self.particleSetSize)
            
            self.recoveryParticleWeightSum.removeAll(keepCapacity: true)
            self.recoveryParticleWeightSumIndex = 0
            
            println("COMPLETE RECOVERY")
        }

        return particles_t
    }
    
    
    // MARK: Sigma Calculation
    private func sigmaForParticleSet(pSet: [Particle], withMean mu: Sigellipse.Point) -> Sigellipse.Sigma? {

        if !pSet.isEmpty {
            let n = Double(pSet.count)
            
            // calc sigma
            var sigma_xx = 0.0
            var sigma_xy = 0.0
            var sigma_yx = 0.0
            var sigma_yy = 0.0
            
            for p in pSet {
                sigma_xx += (p.x - mu.x) * (p.x - mu.x)
                sigma_xy += (p.x - mu.x) * (p.y - mu.y)
                sigma_yx += (p.y - mu.y) * (p.x - mu.x)
                sigma_yy += (p.y - mu.y) * (p.y - mu.y)
            }
            
            // standard deviation (sigma)
            sigma_xx = sigma_xx / (n - 1)
            sigma_xy = sigma_xy / (n - 1)
            sigma_yx = sigma_yx / (n - 1)
            sigma_yy = sigma_yy / (n - 1)
            
            return Sigellipse.Sigma(m: [sigma_xx, sigma_xy, sigma_yx, sigma_yy])
        }
        return nil
    }
    
    
    // MARK: Particle Generation
    private func generateParticlesAroundBeacons(beacons: [Beacon], count: Int) -> [Particle] {
        var particles = [Particle]()
        
        for (i, b) in enumerate(beacons) {
            if let landmark = self.map.landmarks[b.identifier] {
                
                var size:Int = 0
                
                if b === beacons.last {
                    size = count - particles.count
                } else {
                    size =  Int(pow(0.5, Double(i+1)) * Double(count))
                }
                
                var addedParticles = 0
                
                while addedParticles < size {
                    let theta = Random.rand_uniform(2 * M_PI)
                    let d = Random.sample_normal_distribution(0.2 * b.accuracy)
                    
                    let deltaX = cos(theta) * (b.accuracy + d)
                    let deltaY = sin(theta) * (b.accuracy + d)
                    
                    let x = landmark.x + deltaX
                    let y = landmark.y + deltaY
                    
                    if map.isCellFree(x: x, y: y) {
                        particles.append(Particle(x: x, y: y, theta: Random.rand_uniform(2 * M_PI))) // different end orientation
                        ++addedParticles
                    }
                }
                
                
            }
        }
        return particles
    }
    
    private func generateRandomParticle() -> Particle {
        
        let xMin: Double = 0
        let xMax:Double = self.map.size.x
        let yMin: Double = 0
        let yMax: Double = self.map.size.y
        
        var x = 0.0
        var y = 0.0
        
        do {
            
            x = Double(arc4random_uniform(UInt32( (xMax-xMin) * 100)))/100.0 + xMin
            y = Double(arc4random_uniform(UInt32( (yMax-yMin) * 100)))/100.0 + yMin
            
        } while !self.map.isCellFree(x: x, y: y) // check if paricle coordinates fit to map
        
        let theta = Angle.deg2Rad(Double(arc4random_uniform(36000))/100.0)
        
        return Particle(x: x, y: y, theta: theta)
    }
    
    
    // MARK: Observer protocol - BeaconRadio
    
    func measurmenetModel(model: MeasurementModel, didObserveMeasurement beacons: [Beacon]) {

        self.rangedBeacons = beacons
        
        // particle set empty => generation
        if self.particleSet.isEmpty {
            // get Beacons ordered by accuracy ascending
            let beacons = self.rangedBeacons.sorted({$0.accuracy < $1.accuracy})
            
            let particles = generateParticlesAroundBeacons(beacons, count: self.particleSetSize)
            if !particles.isEmpty {
                self.particleSet = particles // -> notifies observers
            }
        }
        
        if !self.particleSet.isEmpty {
            NSOperationQueue.mainQueue().addOperationWithBlock({
                self.mcl()
            })
        }
    }
    
    
    // MARK: Observable protocol
    
    private var observers = NSMutableSet()
    
    func addObserver(o: Observer) {
        observers.addObject(o)
    }
    
    func removeObserver(o: Observer) {
        observers.removeObject(o)
    }
    
    func notifyObservers() {
        for observer in observers {
            observer.update()
        }
    }
}