//
//  MapViewController.swift
//  BeaconRadio
//
//  Created by Thomas Bopst on 30/10/14.
//  Copyright (c) 2014 Thomas Bopst. All rights reserved.
//

import Foundation
import UIKit

class ParticleMapViewController: UIViewController, Observer, UIScrollViewDelegate, ParticleMapViewDataSource {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var particleMapView: ParticleMapView!

    @IBOutlet weak var startStopLocalization: UIBarButtonItem!

    private lazy var map:Map? = {
        let map = ConfigReader.sharedInstance.map
        return MapsManager.loadMap(name: map)
    }()

    private var particleFilter: ParticleFilter? = nil


    // MARK: UIViewController methods
    override func viewDidLoad() {
        super.viewDidLoad()

        self.scrollView.delegate = self
        self.particleMapView.dataSource = self
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if let particleFilter = self.particleFilter {
            particleFilter.addObserver(self)
        }

        //centerMap()

    }

    private func centerMap() {
        let offsetX:CGFloat = max((self.scrollView.bounds.size.width - self.particleMapView.bounds.size.width) / 2, 0.0)
        let offsetY:CGFloat = max((self.scrollView.bounds.size.height - self.particleMapView.bounds.size.height) / 2, 0.0)
        self.particleMapView.center = CGPoint(x: self.particleMapView.bounds.size.width / 2 + offsetX, y: self.particleMapView.bounds.size.height / 2 + offsetY);
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)

        if let particleFilter = self.particleFilter {
            particleFilter.removeObserver(self)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func toggleLocalization(sender: UIBarButtonItem) {

        if self.particleFilter != nil {
            self.particleFilter!.removeObserver(self)
            self.particleFilter!.stopLocalization()
            self.startStopLocalization.title = "Start"
            self.particleFilter = nil
        } else {
            if let map = self.map {
                self.particleFilter = ParticleFilter(map: self.map!)
                self.particleFilter!.addObserver(self)
                self.particleFilter!.startLocalization()
                self.startStopLocalization.title = "Stop"
            } else {
                println("[ERROR] No map found!")
            }
        }
    }

    // MARK: Observer protocol
    func update() {
        self.particleMapView.setNeedsDisplay()
    }


    // MARK: ParticleMapView DataSource
    func mapImgForParticleMapView(view: ParticleMapView) -> UIImage? {
        return self.map?.mapImg
    }

    func particlesForParticleMapView(view: ParticleMapView) -> [Particle] {

        if let map = self.map {
            if let particleFilter = self.particleFilter {

                let particles = particleFilter.particles

                // convert particles to right size
                return particles.map({p in self.transformParticle(p, ToMapCS: map)})
            }
        }
        return []
    }

    func estimatedPathForParticleMapView(view: ParticleMapView) -> [Pose] {
        if let map = self.map {
            if let particleFilter = self.particleFilter {

                let poses = particleFilter.estimatedPath

                // convert particles to right size
                return poses.map({p in self.transformParticle(p, ToMapCS: map)})
            }
        }
        return []
    }

    func estimatedMotionPathForParticleMapView(view: ParticleMapView) -> [Pose] {
        if let map = self.map {
            if let particleFilter = self.particleFilter {

                let poses = particleFilter.motionPath

                // convert particles to right size
                return poses.map({p in self.transformParticle(p, ToMapCS: map)})
            }
        }
        return []
    }

    func landmarkForParticleMapView(view: ParticleMapView) -> [Landmark] {
        if let map = self.map {
            return map.landmarks.values.array.map({l in self.transformLandmark(landmark: l, ToMapCS: map)})
        }
        return []
    }

//    func particleSetMeanForParticleMapView(view: ParticleMapView) -> (x: Double, y: Double) {
//        if let map = self.map {
//            if let particleFilter = self.particleFilter {
//                let p = transformPoint(particleFilter.particleSetMeanAndCov.mu, ToMapCS: map)
//                return (x: p.x, y: p.y)
//            }
//        }
//        return (x: -1, y: -1)
//    }

    func pointsOfSigellipseForParticleMapView(view: ParticleMapView) -> [Sigellipse.Point] {

        var sigellipseTransformed = Array<Sigellipse.Point>()

        if let map = self.map, particleFilter = self.particleFilter, muSigma = particleFilter.particleSetMeanAndCov {

            let ellipse = Sigellipse(mu: muSigma.mu, sigma: muSigma.sigma).points

            for p in ellipse {
                sigellipseTransformed.append(transformPoint(p, ToMapCS: map))
            }
        }
        return sigellipseTransformed
    }

    // from Meters to pixels
    private func transformParticle(p: Particle, ToMapCS map: Map) -> Particle{
        let x = p.x * Double(map.scale)
        let y = p.y * Double(map.scale)
        let theta = p.theta // map orientation already integrated in MotionModel

        return Particle(x: x, y: y, theta: theta)
    }

    // from Meters to pixels
    private func transformLandmark(landmark l: Landmark, ToMapCS map: Map) -> Landmark {
        let xNew = l.x * Double(map.scale)
        let yNew = l.y * Double(map.scale)

        return Landmark(uuid: l.uuid, major: l.major, minor: l.minor, x: xNew, y: yNew)
    }

    private func transformPose(p: (x:Double, y: Double), ToMapCS map: Map) -> (x: Double, y: Double) {
        return (x: p.x * Double(map.scale), y: p.y * Double(map.scale))
    }

    private func transformPoint(p: Sigellipse.Point, ToMapCS map: Map) -> Sigellipse.Point {

        let xNew = p.x * Double(map.scale)
        let yNew = p.y * Double(map.scale)

        return Sigellipse.Point(x: xNew, y: yNew)
    }


    // MARK: UIScrollView delegate
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return self.particleMapView
    }

}
