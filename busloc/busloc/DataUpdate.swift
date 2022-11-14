//
//  DataUpdate.swift
//  busloc
//
//  Created by 卿山 on 4/16/22.
//
import UIKit
import Foundation
import CoreLocation

// Class only for receive and update data
// If you need to plot data on map, please inherit from StartPageVC
extension DataListener where Self: UIViewController{
    
}

class DataViewController: UIViewController, DataListener{
    var agencyInfo: agencies = []
    var arrivalEstimatesInfo: estimates = []
    var routesInfo: routes = [:]
    var segmentsInfo: segments = [:]
    var stopsInfo: stopBundle = stopBundle(dictRepr: [:], listRepr: [])
    var vehiclesInfo: vehicles = [:]
    
    var userCLLocation = CLLocation()
    var userCLLocationCoordinate2D = CLLocationCoordinate2D()
    
    func receiveAgencies(value: agencies) {
        let date = Date()
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        let dstring = df.string(from: date)
        print("\(dstring) received agencies update")
        self.agencyInfo = value
    }
    
    func receiveArrivalEstimates(value: estimates) {
        let date = Date()
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        let dstring = df.string(from: date)
        print("\(dstring) received arrival estimates update")
//        print("ssssssss\(self.arrivalEstimatesInfo.count)sssssssss")
        self.arrivalEstimatesInfo = value
    }
    
    func receiveRoutes(value: routes) {
        let date = Date()
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        let dstring = df.string(from: date)
        print("\(dstring) received \(value.count) routes")
        self.routesInfo = value
        // Should not remove listeners here as vehicle info need to be continuously updated
//        ds.removeListener(l: self)
    }
    
    func receiveSegments(value: segments) {
        let date = Date()
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        let dstring = df.string(from: date)
        print("\(dstring) received segments update")
        self.segmentsInfo = value
    }
    
    func receiveStops(value: stopBundle) {
        let date = Date()
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        let dstring = df.string(from: date)
        print("\(dstring) received stops update")
        self.stopsInfo = value
    }
    
    func receiveVehicles(value: vehicles) {
        let date = Date()
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        let dstring = df.string(from: date)
        print("\(dstring) received vehicles update")
        self.vehiclesInfo = value
    }
    
    func receiveLocations(value: position) {
        let date = Date()
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        let dstring = df.string(from: date)
        print("\(dstring) Updated location")
        self.userCLLocation = CLLocation(latitude: value.lat, longitude: value.lng)
        self.userCLLocationCoordinate2D.latitude = value.lat
        self.userCLLocationCoordinate2D.longitude = value.lng
//        print(self.userCLLocationCoordinate2D.longitude)
        
    }
    
}
