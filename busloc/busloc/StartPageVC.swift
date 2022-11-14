//
//  StartPageVC.swift
//  busloc
//
//  Created by Elnifio on 4/7/22.
//


/**
 SPECIFICATION:
 
 THIS IS THE START PAGE OF THE APPLICATION
 IN THIS PAGE WE NEED TO SHOW:
 
  - User's current location
  - All routes near the user
  - All vehicles near the user
  - All stops near the user
 
 */

import UIKit
import CoreLocation
import MapKit

class Polyline: MKPolyline {
    var color: UIColor?
}
//class for data only
func decodeColor(color: String) -> UIColor {
    let cvalue = Int(color, radix: 16)!
        
    let result = UIColor(
        red: CGFloat( (Float)((cvalue & 0xff0000) >> 16) / 255.0  ),
        green: CGFloat( (Float)((cvalue & 0x00ff00) >> 8) / 255.0 ),
        blue: CGFloat( (Float)(cvalue & 0x0000ff) / 255.0 ),
        alpha: CGFloat(1)
    )
    
    return result
}

class StartPageVC: DataViewController, MKMapViewDelegate {

    // Map between route_id and route long_name
    var routeToName: [String:String] = [:]
    // Map between route_id and route color
    var routeToColor: [String:UIColor] = [:]
    var stopToName: [String:String] = [:]
    let stopIdentifier = "stops"
    let vehicleIdentifier = "vehicles"
    var nextStopSpecific = ""
    // only focus when starting
    var focused = false
    @IBOutlet weak var backToUserButton: UIButton!
    
    @IBAction func backToUser(_ sender: Any) {
        
        focusCurrentRegion(lat: self.userCLLocationCoordinate2D.latitude, lng: self.userCLLocationCoordinate2D.longitude, animated: true)
    }
    
    override func receiveRoutes(value: routes) {
        super.receiveRoutes(value: value)
        self.mapView.removeOverlays(self.mapView.overlays)
        self.removeRoutes()
        self.plotRoutes()


    }
    
    override func receiveStops(value: stopBundle) {
        super.receiveStops(value: value)
        self.removeStops()
        self.plotStops()
    }
    
    override func receiveLocations(value: position) {
        super.receiveLocations(value: value)
//        print(self.userCLLocationCoordinate2D.longitude)
        if !self.focused{
            focusCurrentRegion(lat: value.lat, lng: value.lng, animated: false)
            self.focused = true
        }
    }
    
    override func receiveVehicles(value: vehicles) {
        super.receiveVehicles(value: value)
        self.removeVehicles()
        self.plotVehicles()
    }
    
    
    func removeRoutes() {
        DispatchQueue.main.async {
            self.mapView.removeOverlays(self.mapView.overlays)
        }
    }
    
    
    func plotRoutes() {
        for agency in self.routesInfo.keys {
            print(agency)
            for route in self.routesInfo[agency]!{
                
                routeToName[route.route_id] = route.long_name
                let routeColor = decodeColor(color: route.color)
                routeToColor[route.route_id] = routeColor
                
                let segments = route.segments
                for segment in segments {
                    let segmentedString = self.segmentsInfo[segment[0]]
                    if segmentedString == nil {
                        continue
                    }
                    let decodedList = decode(given: segmentedString!)
                    
                    let polyline = Polyline(coordinates: decodedList, count: decodedList.count)
                    polyline.color = routeColor
                    DispatchQueue.main.async {
                        self.mapView.addOverlay(polyline)
                    }
                }
//                print("==============================End of the route==============================")
            }
        }
    }
    
    
    func removeStops() {
        for annotation in self.mapView.annotations {
            if let subtitle = annotation.subtitle, subtitle != "bus" {
                DispatchQueue.main.async {
                    self.mapView.removeAnnotation(annotation)
                }
            }
        }
    }


    
    func plotStops() {
        for stop in self.stopsInfo.listRepr {
            self.stopToName[stop.stop_id] = stop.name
            let stopCLLocationCoordinate2D = CLLocationCoordinate2D(latitude: stop.location.lat, longitude: stop.location.lng)
            if validRegion(annotationCLLocationCoordinate2D: stopCLLocationCoordinate2D, radius: 1000) {
                let annotation = MKPointAnnotation()
                annotation.coordinate = stopCLLocationCoordinate2D
                annotation.title = stop.name
                annotation.subtitle = stop.stop_id
                DispatchQueue.main.async {
                    self.mapView.addAnnotation(annotation)
                }
            }
        }
    }
    
    
    func removeVehicles() {
        for annotation in self.mapView.annotations {
            if let subtitle = annotation.subtitle, subtitle == "bus" {
                DispatchQueue.main.async {
                    self.mapView.removeAnnotation(annotation)
                }
            }
        }
    }
    
    
    func plotVehicles() {
        for agency in self.vehiclesInfo.keys {
            for vehicle in self.vehiclesInfo[agency]! {
                if vehicle.location == nil {
                    continue
                }
                let vehicleCLLocationCoordinate2D = CLLocationCoordinate2D(latitude: vehicle.location!.lat, longitude: vehicle.location!.lng)
                if validRegion(annotationCLLocationCoordinate2D: vehicleCLLocationCoordinate2D, radius: 5000) {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = vehicleCLLocationCoordinate2D
                    annotation.subtitle = "bus"
                    DispatchQueue.main.async {
                        self.mapView.addAnnotation(annotation)
                    }
                }
            }
        }
    }
    
    //configure annotaionview
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // keep user location out of any cluster
        if annotation is MKUserLocation{
            return nil
        }
//        var type = ""
//        if let temp = annotation.subtitle{
//            if let temp2 = temp{
//                if let typeIndex = temp2.firstIndex(of: " "){
//                    type = String(temp2[...typeIndex])
//                }
//            }
//        }
//        if type == "stop" {
//            return nil
//        }
        
        var annotationView = MKMarkerAnnotationView()/*+02*/
        
        if(annotation.subtitle == "bus"){
            if let dequedView = mapView.dequeueReusableAnnotationView(withIdentifier: self.vehicleIdentifier) as? MKMarkerAnnotationView {
                annotationView = dequedView
            } else {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: self.vehicleIdentifier)
            }
            annotationView.markerTintColor = UIColor(red: (246.0/255), green: (233.0/255), blue: (212.0/255), alpha: 1.0)
            annotationView.glyphImage = UIImage(systemName: "bus.fill")
            annotationView.frame.size = CGSize(width: 10, height: 10)
            annotationView.clusteringIdentifier = self.vehicleIdentifier
        }
        return annotationView
        
    }
    
    //jump to stop specific when select a stop annotation
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotaion = view.annotation else { return }
        if annotaion.subtitle != "bus"{
            self.nextStopSpecific = annotaion.subtitle!!
            performSegue(withIdentifier: "annostop", sender: nil)
        }
    }
    func validRegion(annotationCLLocationCoordinate2D: CLLocationCoordinate2D, radius: Double) -> Bool {
        let annotationCLLocation = CLLocation(latitude: annotationCLLocationCoordinate2D.latitude, longitude: annotationCLLocationCoordinate2D.longitude)
        return self.userCLLocation.distance(from: annotationCLLocation) < radius
    }
    
    
    @IBOutlet weak var mapView: MKMapView!
    
    
    // access instances from appDelegate example
    var ds: DataStore = (UIApplication.shared.delegate as! AppDelegate).ds
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self

        // Do any additional setup after loading the view.
        
        // Here we listen to a notification.
//        NotificationCenter.default.addObserver(self, selector: #selector(self.nameOfFunction), name: NSNotification.Name(rawValue: "receivedAgencies"), object: nil)
        
//        // Here we use Duke Chapel's location at first
//        // since startUpdate() might run before user authorizing location.
    }
    
//    // Here we handle a notification upon receiving it.
//    @objc func nameOfFunction(notif: NSNotification) {
//        update(say: "Received Agencies in StartPageVC")
//    }
//
//    func update(say: String){
//        print(say)
//    }
    
    //MARK: Mapkit Delegate methods
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {

        if let routePolyline = overlay as? Polyline {
            let renderer = MKPolylineRenderer(polyline: routePolyline)
            renderer.strokeColor = routePolyline.color
            renderer.lineWidth = 3
            return renderer
        }

        return MKOverlayRenderer()
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        circulate button
        self.backToUserButton.layer.cornerRadius = self.backToUserButton.frame.width/2
        self.backToUserButton.layer.masksToBounds = true
        
        ds.registerListener(l: self)
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        ds.removeListener(l: self)
    }
    
    
    func focusCurrentRegion(lat: Double, lng: Double, animated: Bool) {
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        let region = MKCoordinateRegion(center: center, span: span)
        
        mapView.setRegion(region, animated: animated)
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "annostop" {
            let stopSpecificVC = segue.destination as! StopSpecificVC
            stopSpecificVC.stopId = self.nextStopSpecific
        }
        if segue.identifier == "test" {
                    let routeSpecificVC = segue.destination as! RouteSpecificVC
                    for agency in self.routesInfo.keys {
                        for route in self.routesInfo[agency]!{
//                            print(route.stops)
                            if route.stops.contains("4260086"){
//                            if route.stops.contains("4051094"){
                                routeSpecificVC.route = route
                                break
                            }
                            
                        }
                    }
                }
    }

}
