//
//  RouteSpecificVC.swift
//  busloc
//
//  Created by Elnifio on 4/7/22.
//

/**
 SPECIFICATION:
 
 THIS PAGE SHOWS THE INFO OF THE SPECIFIC ROUTE
 IN THIS PAGE WE NEED TO SHOW:
 
  - User's current location on the map
  - the specific route that the user selected, visualized on the map
  - All Vehicles on the routes
  - All stops on the routes
  - All Arrival Estimates on each of the stops
 */

import UIKit
import MapKit
import FloatingPanel

class CellData {
    var stopName: String //fields
    var arrivalTime: String
    init(stopName: String, arrivalTime: String) { //constructor
        self.stopName = stopName
        self.arrivalTime = arrivalTime
    }
}

struct Rectangle {
    let left: Double
    let right: Double
    let up: Double
    let down: Double
    let center: position
}

class RouteSpecificVC: StartPageVC, FloatingPanelControllerDelegate {
    
    var myPanel: FloatingPanelController!
    var panelOpened = false
    var route: routeInfo!
    var data: [CellData] = []



//    @IBOutlet weak var mapView: MKMapView!
    
//    var ds: DataStore = (UIApplication.shared.delegate as! AppDelegate).ds


    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        myPanel = FloatingPanelController()
        myPanel.delegate = self
    }
    
    func openPanel(){
        guard let routeDetailVC = storyboard?.instantiateViewController(identifier:"fpc_routesDetail") as? RouteDetailViewController else {
            return
        }
        if self.data.count == 0 {
            showAlert()
            routeDetailVC.routeName = "No arrival info for " + (self.routeToName[route.route_id] ?? "route chosen")
            
        } else {
            routeDetailVC.routeName = self.routeToName[route.route_id] ?? "route chosen"
        }
        
        routeDetailVC.data = self.data
        
        myPanel.set(contentViewController: routeDetailVC)
        myPanel.addPanel(toParent: self, animated: true)
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
//        ds.registerListener(l: self)
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.myPanel.removeFromParent()
        
//        ds.removeListener(l: self)
    }
    
//    func filterRoute(id: String, agency: String) -> routeInfo{
//        var result: routeInfo? = nil
//        for route in self.routesInfo[agency]!{
//            if route.route_id == id{
//                result = route
//            }
//        }
//        print("GOT the ROUTE", result)
//        return result!
//
//    }
    
    override func receiveRoutes(value: routes) {
        let val:routes = [route.route_id:[route]]
        super.receiveRoutes(value: val)
//        if !panelOpened{
//            print("data length: ", self.data)
//            self.openPanel()
//        }
    }
    
    override func receiveStops(value: stopBundle) {
        var filtered:[busStop] = []
        var locations:[position] = []
        for stop in value.listRepr {
            self.stopToName[stop.stop_id] = stop.name
            if stop.routes.contains(self.route.route_id){
                filtered.append(stop)
                locations.append(stop.location)
            }
        }
        let val = stopBundle(dictRepr:value.dictRepr, listRepr:filtered)
//        super.receiveStops(value: val)
        self.stopsInfo = val
        self.removeStops()
        self.plotStops()
        let area: Rectangle = getCenter(locations:locations)
        let center = CLLocationCoordinate2D(latitude: area.center.lat, longitude: area.center.lng)
        let span = MKCoordinateSpan(latitudeDelta: area.up - area.down + 0.01, longitudeDelta: area.right - area.left + 0.01)
                
        let region = MKCoordinateRegion(center: center, span: span)

        mapView.setRegion(region, animated: true)
    }
    
    override func receiveVehicles(value: vehicles) {
        var val:vehicles = [:]
        for agency in value.keys{
            if agency == String(route.agency_id){
                val[agency] = []
                for vehicle in value[agency]!{
                    if vehicle.route_id == route.route_id{
                        val[agency]!.append(vehicle)
                    }
                }
            }
        }
        self.vehiclesInfo = val
        self.removeVehicles()
        self.plotVehicles()
    }
    
    override func plotVehicles() {
        for agency in self.vehiclesInfo.keys {
            for vehicle in self.vehiclesInfo[agency]! {
                if vehicle.location == nil {
                    continue
                }
                let vehicleCLLocationCoordinate2D = CLLocationCoordinate2D(latitude: vehicle.location!.lat, longitude: vehicle.location!.lng)
//                if validRegion(annotationCLLocationCoordinate2D: vehicleCLLocationCoordinate2D, radius: 5000) {
                let annotation = MKPointAnnotation()
                annotation.coordinate = vehicleCLLocationCoordinate2D
                annotation.subtitle = "bus"
                DispatchQueue.main.async {
                    self.mapView.addAnnotation(annotation)
                }
//                }
            }
        }
    }
    
    override func receiveArrivalEstimates(value: estimates){
        for estimates in value {
            if estimates.agency_id == String(self.route.agency_id){
                for arrivals in estimates.arrivals {
//                    print("my route", self.route.route_id)
//                    print("arrivals: ",arrivals.route_id,getTime(str:arrivals.arrival_at))
                    if arrivals.route_id == self.route.route_id{
                        let cell = CellData(stopName: getStopName(str: stopToName[estimates.stop_id]!), arrivalTime: getTime(str: arrivals.arrival_at))
                        self.data.append(cell)
                    }
                }

            }
        }
        if !panelOpened && Thread.current.isMainThread{
//            let tmp = CellData(stopName: "stop2", arrivalTime: "10:45")
//            self.data.append(tmp)
//            print("data length: ", self.data)

            self.openPanel()
        }
    }
    
    override func receiveLocations(value: position) {
        self.userCLLocation = CLLocation(latitude: value.lat, longitude: value.lng)
        self.userCLLocationCoordinate2D.latitude = value.lat
        self.userCLLocationCoordinate2D.longitude = value.lng
    }
    
    override func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
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
    
//    override func focusCurrentRegion(lat: Double, lng: Double, animated: Bool) {
//        let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
//
//        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
//        let region = MKCoordinateRegion(center: center, span: span)
//
//        mapView.setRegion(region, animated: animated)
//    }
    override func plotStops() {
            for stop in self.stopsInfo.listRepr {
//                if self.stopsInfo.contains(stop.stop_id){
                let stopCLLocationCoordinate2D = CLLocationCoordinate2D(latitude: stop.location.lat, longitude: stop.location.lng)
                let annotation = MKPointAnnotation()
                annotation.coordinate = stopCLLocationCoordinate2D
                annotation.title = stop.name
                annotation.subtitle = stop.stop_id
                DispatchQueue.main.async {
                    self.mapView.addAnnotation(annotation)
                }
//                }
            }
        }

    func getTime(str: String) -> String {
        let start = str.index(str.startIndex, offsetBy: 11)
        let end = str.index(str.startIndex, offsetBy: 18)
        let range = start...end
        let newString = String(str[range])
        return newString
    }
    func getStopName(str: String) -> String {
        if str.count > 30 {
            let index = str.index(str.startIndex, offsetBy: 28)
            let newName = String(str[..<index])
            return newName + ".."
        } else {
            return str
        }
    }
    
    func getCenter(locations:[position]) -> Rectangle {
        var left:Double = locations[0].lng
        var right:Double = locations[0].lng
        var up:Double = locations[0].lat
        var down:Double = locations[0].lat
        for loc in locations {
            left = min(left, loc.lng)
            right = max(right, loc.lng)
            up = max(up, loc.lat)
            down = min(down, loc.lat)
        }
        let center:position = position(lat:(up + down) / 2,lng:(left + right) / 2)
        return Rectangle(left: left, right: right, up: up, down: down, center: center)
            
    }

    
    override func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        return
    }
    
    func showAlert() {
        let dialogMessage = UIAlertController(title: "No Arrival Info Currently", message: "Please request later or change to another route", preferredStyle: .alert)

        let ok = UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
            print("Ok button tapped")
        })
            
        dialogMessage.addAction(ok)
        
        self.present(dialogMessage, animated: true, completion: nil)
    }
    
    @IBAction func backToUserBT(_ sender: Any) {
        print("backtouser",self.userCLLocationCoordinate2D.latitude)
        self.focusCurrentRegion(lat: self.userCLLocationCoordinate2D.latitude, lng: self.userCLLocationCoordinate2D.longitude, animated: true)
//        self.closePanel()
//        self.openPanel(s_id: self.stopSelect, half: false)
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

