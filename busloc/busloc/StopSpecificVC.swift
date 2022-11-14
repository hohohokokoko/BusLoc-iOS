//
//  StopSpecificVC.swift
//  busloc
//
//  Created by Elnifio on 4/7/22.
//

/**
 SPECIFICATION:
 
 THIS PAGE SHOWS THE INFO OF THE SPECIFIC STOP
 IN THIS PAGE WE NEED TO SHOW:
 
  - User's current location on the map
  - the specific stop that the user selected, visualized on the map
  - All routes passing through the stop
  - All vehicles on each routes
  - All Arrival Estimates for each route, passing through the stop
 */

//floating panel workflow: select an annotaion->close old one->open new one(half)->refocus
//after back to user: reopen previous panel(bottom)->refocus
//Floating panel info: https://github.com/scenee/FloatingPanel
import UIKit
import MapKit
import FloatingPanel

class MyFloatingPanelLayout: FloatingPanelLayout {
    let position: FloatingPanelPosition = .bottom
    var initialState: FloatingPanelState = .tip
    var anchors: [FloatingPanelState: FloatingPanelLayoutAnchoring] {
        return [
            .full: FloatingPanelLayoutAnchor(absoluteInset: 16.0, edge: .top, referenceGuide: .safeArea),
            .half: FloatingPanelLayoutAnchor(fractionalInset: 0.5, edge: .bottom, referenceGuide: .safeArea),
            .tip: FloatingPanelLayoutAnchor(absoluteInset: 44.0, edge: .bottom, referenceGuide: .safeArea),
        ]
    }
}

class StopSpecificVC: StartPageVC, FloatingPanelControllerDelegate {
    
    var stopId = ""
    var fpc: FloatingPanelController!
    var stopToPlot : Set<String> = []
    var firstPanel = false
    var stopSelect : String = ""
    override func receiveRoutes(value: routes) {
        let date = Date()
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        let dstring = df.string(from: date)
        print("\(dstring) received \(value.count) routes")
        self.routesInfo = value
        self.removeRoutes()
        self.plotRoutes()
        self.removeStops()
        self.plotStops()
//        focus to current stop
        guard let current_stop = self.stopsInfo.dictRepr[self.stopId] else{return}
        focusCurrentRegion(lat: current_stop.location.lat-0.004, lng: current_stop.location.lng, animated: false)
    }
    override func receiveStops(value: stopBundle) {
        let date = Date()
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        let dstring = df.string(from: date)
        print("\(dstring) received stops update")
        self.stopsInfo = value
    }

//only plot routes passing through current stop
    override func plotRoutes() {
        guard let current_stop = self.stopsInfo.dictRepr[self.stopId] else{return}
        for agency in self.routesInfo.keys {
            for route in self.routesInfo[agency]!{
                routeToName[route.route_id] = route.long_name
                    if current_stop.routes.contains(route.route_id){
//                        record stops to plot
                        for stop in route.stops{
                            self.stopToPlot.insert(stop)
                        }
                        
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
                }
//                print("==============================End of the route==============================")
            }
        }
    }
    
    override func plotVehicles() {
        guard let current_stop = self.stopsInfo.dictRepr[self.stopId] else{return}
        for agency in self.vehiclesInfo.keys {
            for vehicle in self.vehiclesInfo[agency]! {
                if current_stop.routes.contains(vehicle.route_id) && vehicle.location != nil{
                if current_stop.routes.contains(vehicle.route_id){
                    if vehicle.location == nil {
                        continue
                    }
                    let vehicleCLLocationCoordinate2D = CLLocationCoordinate2D(latitude: vehicle.location!.lat, longitude: vehicle.location!.lng)
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
    }
    override func plotStops() {
        for stop in self.stopsInfo.listRepr {
            if self.stopToPlot.contains(stop.stop_id){
                let stopCLLocationCoordinate2D = CLLocationCoordinate2D(latitude: stop.location.lat, longitude: stop.location.lng)
                let annotation = MKPointAnnotation()
                annotation.coordinate = stopCLLocationCoordinate2D
                annotation.title = stop.name
                annotation.subtitle = stop.stop_id
                DispatchQueue.main.async {
                    self.mapView.addAnnotation(annotation)
//                    select current stop by default
                    if self.stopId == stop.stop_id {
                        self.mapView.selectAnnotation(annotation, animated: true)
                    }
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.fpc = FloatingPanelController()
        self.fpc.delegate = self
        self.view.addSubview(self.fpc.view)
        self.fpc.view.frame = self.view.bounds
        self.addChild(self.fpc)
    }
    @IBAction func backToUser2(_ sender: Any) {
        self.focusCurrentRegion(lat: self.userCLLocationCoordinate2D.latitude, lng: self.userCLLocationCoordinate2D.longitude, animated: true)
        DispatchQueue.main.async {
            self.closePanel()
            self.openPanel(s_id: self.stopSelect, half: false)
        }
    }
    //    open panel give a stop id
    func openPanel(s_id:String, half:Bool){
        guard let stopDetailVC = storyboard?.instantiateViewController(identifier:"fpc_stopDetail") as? StopDetailViewController else {
            return
        }
        guard let current_stop = self.stopsInfo.dictRepr[s_id] else{return}
        let esimates = self.arrivalEstimatesInfo.filter{$0.stop_id==s_id}
        var routesName:[String] = []
        var estimateData:[Int] = []
        for esimate in esimates {
            for arrival in esimate.arrivals{
                let routeName = self.routeToName[arrival.route_id]
                let interval = self.intervalCalculator(arrival: arrival.arrival_at)
                routesName.append(routeName ?? "NO")
                estimateData.append(interval)
            }
        }

        stopDetailVC.stopName = current_stop.name
        stopDetailVC.routes = routesName
        stopDetailVC.estimates = estimateData

        
      
        
        
        DispatchQueue.main.async {
            if !half{
    //            print(111)
                self.fpc.layout = MyFloatingPanelLayout()
            }
            else{
                let half_layout = MyFloatingPanelLayout()
                half_layout.initialState = .half
                self.fpc.layout = half_layout
            }
            self.fpc.set(contentViewController: stopDetailVC)
            self.fpc.track(scrollView: stopDetailVC.myTable)
            self.fpc.show(animated: true){
                self.fpc.didMove(toParent: self)
            }
        }
//        self.view.addSubview(fpc.view)
//
//        // REQUIRED. It makes the floating panel view have the same size as the controller's view.
//        fpc.view.frame = self.view.bounds
//
//        // In addition, Auto Layout constraints are highly recommended.
//        // Constraint the fpc.view to all four edges of your controller's view.
//        // It makes the layout more robust on trait collection change.
//        fpc.view.translatesAutoresizingMaskIntoConstraints = true
//
//        fpc.layout = MyFloatingPanelLayout()
//
//        // Add the floating panel controller to the controller hierarchy.
//        self.addChild(fpc)
//        fpc.set(contentViewController: stopDetailVC)
//        // Show the floating panel at the initial position defined in your `FloatingPanelLayout` object.
//        fpc.show(animated: true) {
//            // Inform the floating panel controller that the transition to the controller hierarchy has completed.
//            self.fpc.didMove(toParent: self)
//        }
    }
    
    func closePanel(){
//        self.fpc.willMove(toParent: nil)
//        self.fpc.hide(animated: true){
//            self.fpc.view.removeFromSuperview()
//            self.removeFromParent()
//        }
        DispatchQueue.main.async {
            self.fpc.willMove(toParent: nil)
                
            // Hide the floating panel.
            self.fpc.hide(animated: true) {
                // Remove the floating panel view from your controller's view.
//                self.fpc.view.removeFromSuperview()
                // Remove the floating panel controller from the controller hierarchy.
                self.fpc.removeFromParent()
        }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    
    
//    time difference bwteen arrive estimates and current time
    func intervalCalculator(arrival: String)-> Int{
        // The default timeZone for ISO8601DateFormatter is UTC
        let utcISODateFormatter = ISO8601DateFormatter()

        // Printing a Date
        let date = Date()
        
        let utcDate = utcISODateFormatter.date(from: arrival)
        let timeInterval = Int(date.timeIntervalSince(utcDate!)/60)
        return -timeInterval
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
//        self.myPanel.removeFromParent()
        
    }
    
    override func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotaion = view.annotation else { return }
        guard let current_stop = self.stopsInfo.dictRepr[(annotaion.subtitle ?? "No") ?? "No"] else{return}
        //open first current stop's panel
        if !self.firstPanel{
//            print(111111111)
            self.openPanel(s_id: self.stopId, half: true)
            self.firstPanel = true
            self.stopSelect = (annotaion.subtitle ?? "") ?? ""
        }
        else{
            self.stopSelect = (annotaion.subtitle ?? "") ?? ""
            focusCurrentRegion(lat: current_stop.location.lat-0.004, lng: current_stop.location.lng, animated: true)
            self.closePanel()
            self.openPanel(s_id: annotaion.subtitle!!, half: true)
        }
//        a panel is already open, remove it before open next
    }
    
    

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        
    }


}
