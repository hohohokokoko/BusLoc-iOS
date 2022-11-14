//
//  DataStore.swift
//  busloc
//
//  Created by Elnifio on 4/7/22.
//

import Foundation
import CoreLocation

/**
 
 ## DataStore Instance Usage:
 
 1. create an instance that conforms to the DataListener protocol
 2. implement the following receive() methods
 
 --------
 
 ## Data Usage:
 
 ### Agencies
 
 A list of Agencies
 
 The most important attribute for visualization is `agency.long_name`, which represents the full name of the agency.
 
 Other stuffs to be noticed is the `agency.agency_id`, which is the primary key over each agency.
 
 ### Arrival Estimates
 
 A List of Arrival Estimates
 
 Pseudo-code to find the estimates at a stop: `estimates.filter(estimates.stop_id == stopID)`
 
 Each element of the list is an arrival estimation of `<stop_id, agency_id>`. Inside each element, the `arrival` list contains the specific information about the time `arrival_at` where `vehicle_id` on `route_id` arrives at the current stop, with time formatted as `<year 4>-<Month 2>-<Day 2>T<Hour 2>:<Minute 2>:<Second2><UTC Time Zone>`
 
 ### Routes
 
 A dictionary of structure `<agency_id> -> <Array(route info)>`
 
 Each value within the array represents a route. Important values: `routeInfo.short_name` -> eg. "LL", `routeInfo.long_name` -> eg. "LL - LaSaille Loop"
 
 Pseudo-code to visualize Routes:
 
 ```
 chosenRoute.segments.map(
    // maps the route segments to a list of decoded CLLocationCoordinates and "forward | backward"
    x => ( decode(Segments[x[0]]), x[1] )
 ).map(
    // draw on map
    x => drawOnMap( x[0] )
 )
 ```

 ### Segments
 
 A dictionary of structure `<segment_id> -> <encoded polyline representation>`
 
 Use together with Routes
 
 ### Vehicles
 
 important value:
 - `heading` if exists, implies the angle from North clockwise, measured in 360 degree.
 
 ### Stops
 
 each `route in routes` represents a route ID passing through this stop. Join with Routes to get the names
 
 */

// MARK: - DataListener Protocol
// Any listeners that requires data should conform to this protocol
// being notified by DataStore each time the Data changes
protocol DataListener: NSObject {
    func receiveAgencies(value: agencies)
    func receiveArrivalEstimates(value: estimates)
    func receiveRoutes(value: routes)
    func receiveSegments(value: segments)
    func receiveStops(value: stopBundle)
    func receiveVehicles(value: vehicles)
    func receiveLocations(value: position)
}

func handleError(err: String) {
    print(err)
}

func statusUpdate(status: String) {
//        print("    \(status)")
}

// MARK: - DataStore object
// Manages the update and notification of the retrieved data
class DataStore: NSObject, CLLocationManagerDelegate {
    
    // MARK: Attributes for Data Storage
    private var agencyInfo: agencies = []
    private var arrivalEstimatesInfo: estimates = []
    private var routesInfo: routes = [:]
    private var segmentsInfo: segments = [:]
    private var stopsInfo: stopBundle = stopBundle(dictRepr: [:], listRepr: [])
    private var vehiclesInfo: vehicles = [:]
    
    var latitude: Double? = nil
    var longitude: Double? = nil
    
    // MARK: Location Manager and Timer stuffs
    var locationManager = CLLocationManager()
    
    // The timer ticks every second,
    // and the counters count the number of seconds passed
    // for each endpoint
    var timer: DispatchSourceTimer? = nil
    
    var timeouts: [endpoint:Int] = [
        endpoint.agency: 300,
        endpoint.route: 300,
        endpoint.segment: 300,
        endpoint.arrivalEstimate: 30,
        endpoint.stop: 300,
        endpoint.vehicle: 5
    ]
    
    var counters: [endpoint: Int] = [:]
    
    // MARK: Data Listeners
    var listeners: [DataListener] = []
    
    // Registers the listener
    // first update the location
    // then update according to the order listed in endpoint enumerator
    // if the value is not yet to be initialized (timer not started)
    // then the data will not be updated
    func registerListener(l: DataListener) {
        self.listeners.append(l)
        if (self.latitude != nil && self.longitude != nil) {
            self.updateLocation(lat: latitude!, lng: longitude!)
        }
        for ep in endpoint.allCases {
            if (self.counters[ep] != nil) {
                self.update(ep: ep)
            }
        }
    }
    
    // removes a listener from the listener list
    func removeListener(l: DataListener) {
        self.listeners.removeAll(where: { $0 == l })
    }
    
    // update endpoint
    func update(ep: endpoint) {
        switch ep {
        case endpoint.agency:
            self.listeners.forEach{ $0.receiveAgencies(value: self.agencyInfo)}
        case endpoint.route:
            self.listeners.forEach{ $0.receiveRoutes(value: self.routesInfo)}
        case endpoint.segment:
            self.listeners.forEach{ $0.receiveSegments(value: self.segmentsInfo)}
        case endpoint.arrivalEstimate:
            self.listeners.forEach{ $0.receiveArrivalEstimates(value: self.arrivalEstimatesInfo)}
        case endpoint.stop:
            self.listeners.forEach{ $0.receiveStops(value: self.stopsInfo)}
        case endpoint.vehicle:
            self.listeners.forEach{ $0.receiveVehicles(value: self.vehiclesInfo)}
        }
    }
    
    // MARK: Error and Update Handler
    // In order to re-write the handler, do something like `ds.errorAndStatusHandler[status.error] = new_function`
    var errorAndStatusHandler: [status:(String) -> Void] = [
        status.error: handleError,
        status.statusUpdate: statusUpdate
    ]

    // MARK: - update callback to be provided as argument to APICall.query
    func updateRoute(result: routes?) {
        guard let data = result else {
            print("No routes found")
            routesInfo = [:]
            return
        }
        routesInfo = data
        self.update(ep: endpoint.route)
    }
    
    func updateSegment(result: segments?) {
        guard let data = result else {
            print("No Segments found")
            segmentsInfo = [:]
            return
        }
        
        segmentsInfo = data
        
        if (self.counters[endpoint.route] == nil) {
            self.startReceive(ep: endpoint.route)
        }
        
        self.update(ep: endpoint.segment)
    }
    
    func updateArrivalEstimates(result: estimates?) {
        guard let data = result else {
            print("No Arrival Estimates found")
            arrivalEstimatesInfo = []
            return
        }
        
        arrivalEstimatesInfo = data
        self.update(ep: endpoint.arrivalEstimate)
    }
    
    func updateStop(result: stops?) {
        guard let data = result else {
            print("No stops found")
            stopsInfo = stopBundle(dictRepr: [:], listRepr: [])
            return
        }
        
        var drepr: [String:busStop] = [:]
        for lrepr in data {
            drepr[lrepr.stop_id] = lrepr
        }
        
        stopsInfo = stopBundle(dictRepr: drepr, listRepr: data)
        
        if (self.counters[endpoint.route] == nil) {
            self.startReceive(ep: endpoint.route)
        }
        
        self.update(ep: endpoint.stop)
    }
    
    func updateVehicle(result: vehicles?) {
        guard let data = result else {
            print("No vehicles found")
            vehiclesInfo = [:]
            return
        }
        
        vehiclesInfo = data
        self.update(ep: endpoint.vehicle)
    }
    
    func updateAgency(result: agencies?) {
        guard let data = result else {
            print("No agencies returned")
            agencyInfo = []
            return
        }
        
        agencyInfo = data
        
        if (self.counters[endpoint.segment] == nil) {
            self.startReceive(ep: endpoint.segment)
        }
        
        if (self.counters[endpoint.arrivalEstimate] == nil) {
            self.startReceive(ep: endpoint.arrivalEstimate)
        }
        
        if (self.counters[endpoint.stop] == nil) {
            self.startReceive(ep: endpoint.stop)
        }
        
        if (self.counters[endpoint.vehicle] == nil) {
            self.startReceive(ep: endpoint.vehicle)
        }
        
        self.update(ep: endpoint.agency)
    }
    
    // MARK: - Initialization methods
    override init() {
        super.init()
        print("DataStore initialized")
        self.locationManager.delegate = self
        self.locationManager.requestWhenInUseAuthorization()
        self.startTimer()
    }
    
    deinit {
        print("De-initted")
        stopTimer()
    }
    
    // Starts the timer, each tick updates the `counter` property
    func startTimer() {
        let queue = DispatchQueue(label: "edu.duke.teamx")
        self.timer = DispatchSource.makeTimerSource(queue: queue)
        
        timer!.schedule(deadline: .now(), repeating: .seconds(1))
        timer!.setEventHandler{ [weak self] in
            for ep in self!.counters.keys {
                self!.counters[ep]! += 1
                if (self!.counters[ep]! >= self!.timeouts[ep]!) {
                    self!.makeQuery(ep: ep)
                    self!.counters[ep] = 0
                }
            }
        }
        timer!.resume()
    }
    
    func startUpdate(lat: Double, lng: Double) {
        self.latitude = lat
        self.longitude = lng
        self.startReceive(ep: endpoint.agency)
    }
    
    // start receiving the given endpoint
    func startReceive(ep: endpoint) {
        // query it first, and start timer after returned data
        self.counters[ep] = self.timeouts[ep]
    }
    
    func stopTimer() {
        self.timer = nil
    }
    
    func isStarted() -> Bool {
        var rval = true
        
        for ep in endpoint.allCases {
            if self.counters[ep] == nil {
                rval = false
            }
        }
        
        return rval
    }
    
    // calls the API query functions
    func makeQuery(ep: endpoint) {
        switch ep {
        case endpoint.agency:
            queryAgencies(param: AgenciesParam(geo_area: GeoArea(lat: self.latitude!, lng: self.longitude!)),
                          ds: self,
                          successHandler: self.updateAgency,
                          errorHandler: self.errorAndStatusHandler[status.error]!,
                          statusUpdateHandler: self.errorAndStatusHandler[status.statusUpdate]!)
        case endpoint.route:
            queryRoutes(param: RoutesParam(agencies: self.agencyInfo.map{ $0.agency_id }, geo_area: nil),
                        ds: self,
                        successHandler: self.updateRoute,
                        errorHandler: self.errorAndStatusHandler[status.error]!,
                        statusUpdateHandler: self.errorAndStatusHandler[status.statusUpdate]!)
        case endpoint.segment:
            querySegments(param: SegmentsParam(agencies: self.agencyInfo.map{$0.agency_id},
                                               routes: nil, geo_area: nil),
                          ds: self,
                          successHandler: self.updateSegment,
                          errorHandler: self.errorAndStatusHandler[status.error]!,
                          statusUpdateHandler: self.errorAndStatusHandler[status.statusUpdate]!)
        case endpoint.arrivalEstimate:
            queryArrivalEstimates(param: ArrivalEstimatesParam(agencies: self.agencyInfo.map{$0.agency_id}, routes: nil, stops: nil),
                                  ds: self,
                                  successHandler: self.updateArrivalEstimates(result:),
                                  errorHandler: self.errorAndStatusHandler[status.error]!,
                                  statusUpdateHandler: self.errorAndStatusHandler[status.statusUpdate]!)
        case endpoint.stop:
            queryStops(param: StopsParam(agencies: self.agencyInfo.map{$0.agency_id}, geo_area: nil),
                       ds: self,
                       successHandler: self.updateStop(result:),
                       errorHandler: self.errorAndStatusHandler[status.error]!,
                       statusUpdateHandler: self.errorAndStatusHandler[status.statusUpdate]!)
        case endpoint.vehicle:
            queryVehicles(param: VehiclesParam(agencies: self.agencyInfo.map{$0.agency_id}, routes: nil, geo_area: nil),
                          ds: self,
                          successHandler: self.updateVehicle(result:),
                          errorHandler: self.errorAndStatusHandler[status.error]!,
                          statusUpdateHandler: self.errorAndStatusHandler[status.statusUpdate]!)
        }
    }
    
    // MARK: - Location Stuffs
    func updateLocation(lat: Double, lng: Double) {
        self.latitude = lat
        self.longitude = lng
        if (!self.isStarted()) {
            self.startUpdate(lat: lat, lng: lng)
        }
        self.listeners.forEach{ $0.receiveLocations(value: position(lat: lat, lng: lng)) }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            print("Location authorized!")
            self.locationManager.startUpdatingLocation()
        }
        
        if status == .notDetermined || status == .denied {
            self.locationManager.requestWhenInUseAuthorization()
        }
    }
    
    // called when there is a change on the location
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        let currentLocation = locations.last!
        
        self.updateLocation(lat: currentLocation.coordinate.latitude, lng: currentLocation.coordinate.longitude)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Did failed with error")
        print(error.localizedDescription)
    }
    

}
