BeaconRadio
===========
This README file provides a short overview of my Proof of Concept implementation corresponding to my [Master-Thesis “Indoor Self-Localization with Smartphones using iBeacons”](thesis.pdf).

# General Details
The PoC is implemented for Apple’s smartphone platform iOS 8.3. The App is written in Apple’s new programming language [Swift](https://developer.apple.com/swift/) (v1.2). For the development Xcode 6.3.1 is used. The application is tested on an iPhone 5S running iOS 8.3. The app requires an iPhone 5S or iPhone 6 due to the used motion co-processor. iPad and iPodtouch are not applicable due to the missing CMPedometer support.

# App-Architecture
The Application follows the Model-View-Controller pattern as usual for iOS applications.
* Views: Are stored in the *Main.storyboard* and *ParticleMapView.swift* file
* Controllers: ViewControllers are stored in the *controllers* folder
* Model: Model classes are stored in the *model* folder

# Localization Algorithm
The algorithm is described in my [thesis](thesis.pdf).

# Build & Run
The App can either run on a real device using the device’s real sensors or run in simulator using recorded sensor data. To do so, two different *Targets*, i.e. *Schemes* are provided by Xcode.

## Hardware
To run the App on a real device select the *BeaconRadio* target in Xcode.  It builds the App by including the specific models to access the real hardware sensors.

## Simulator
To run the App on a real device select the *BeaconRadioSimulator* target in Xcode.  It builds the App by including the specific models to access the recorded sensor data. The sensor data needs to be stored in the *resources/simulation* folder. The folder already contains various example data. The corresponding maps are stored in *resources/maps*. To select the used simulation data use the *Config.plist* file which is also stored in the *resources* folder.

## Configuration
The *resources/Config.plist* file contains the applications configuration parameters.

First, it specifies which map, stored in the maps folder, should be loaded. To load a specific map the  *map* key needs to be set to the map’s file name (e.g. *map* = F_007, not F_007.png/plist).

Second, the motion trackers (i.e. the odometrie’s) start position (x, y in meters) is defined via the **startPoseMotionTracker** key.

For the simulation also the folder name of the simulation data needs to be defined by setting the **simulationDataPrefix** key.

# Map
A map always consists of an image, depicting the map and a plist file. Both are stored in the *resources/maps* folder and named equally (e.g. F_007.png, F_007.plist). The plist file contains the deployed *beacons’* positions and their identifiers, a *scale* factor for the map, and the maps magnetic *orientation*. The scale factor defines how many pixels represent 1 meter on the map (e.g. 100 pixel = 1m => scale = 100). The maps orientation is defined in degrees. Examples can be found in the maps folder.

# Data Recording
Simulation data can be recorded using the built-in logger. To do so, one has to press the *stop* button on the interface and the measured data is stored in the iPhone application’s document directory which can be accessed via iTunes. This data can then be moved to the *resources/simulation* folder to use it for the simulation. The logged data is stored in csv format.

# Demo Videos
The following example videos demonstrate the implementations behavior.

Particles are shown as red arrows. The beacons are shown as small blue filled circles. The blue dashed line shows the estimated path. The black dashed line depicts the motion (i.e. odometry) path.

* [1_F-Foyer_F007.mov](movies/1_F-Foyer_F007.mov)
* [2_F-Foyer_F023_F007_0.mov](movies/2_F-Foyer_F023_F007_0.mov)
* [3_F-Foyer_F007_F023_F022_F007.mov](movies/3_F-Foyer_F007_F023_F022_F007.mov)
* [F-Foyer_F023_F007_1.mov](movies/F-Foyer_F023_F007_1.mov)
* [F-Foyer_F023_F007_2.mov](movies/F-Foyer_F023_F007_2.mov)

# License
Creative Commons Attribution-NonCommercial-ShareAlike 4.0 (CC BY-NC-SA 4.0)
