//
//  APICall.swift
//  busloc
//
//  Created by Elnifio on 4/7/22.
//

import Foundation
import CoreLocation
import MapKit

// MARK: CONFIGURATION
public var searchRange: Int = 1000
var headers: [String: String] = [
    "x-rapidapi-key": "769bc5245amsh4e1513d8ec468acp1a40e3jsn5496f12d2222",
    "x-rapidapi-host": "transloc-api-1-2.p.rapidapi.com"
]
var baseLink: String = "https://transloc-api-1-2.p.rapidapi.com/"

// MARK: - JSON Data Structures
class Response<dataType: Codable>: Codable {
    let rate_limit: Int
    let expires_in: Int
    let api_latest_version: String
    let generated_on: String
    let data: dataType
    let api_version: String
}

// MARK: Agencies
// returned data is a list of agency structure
typealias agencies = [agency]

struct agency: Codable {
    let long_name: String
    let language: String
    let position: position
    let name: String
    let short_name: String
    let phone: String?
    let url: String
    let timezone: String
    let bounding_box: [position]
    let agency_id: String
}

struct position: Codable {
    let lat: Double
    let lng: Double
}

// MARK: Stops
// returned stop is a list of busStop structure
typealias stops = [busStop]

// make a dictionary of each stop for easier search
typealias stopDict = [String: busStop]

struct stopBundle {
    let dictRepr: stopDict
    let listRepr: stops
}

// stop structure
struct busStop: Codable {
    let code: String
    let description: String
    let url: String
    let parent_station_id: String?
    let agency_ids: [String]
    let location_type: String
    let location: position
    let stop_id: String
    let routes: [String]
    let name: String
}

// MARK: Arrival Estimates
// returned data is a list of arrivalEstimates
typealias estimates = [arrivalEstimate]

struct arrivalEstimate: Codable {
    let arrivals: [arrival]
    let agency_id: String
    let stop_id: String
}

struct arrival: Codable {
    let route_id: String
    let vehicle_id: String
    let arrival_at: String
    let type: String
}

// MARK: Segments
typealias segments = [String: String]

// MARK: Vehicles
typealias vehicles = [String: [vehicleInfo]]

struct vehicleInfo: Codable {
    let description: String?
    let passenger_load: Double?
    let standing_capacity: String?
    let seating_capacity: String?
    let last_updated_on: String?
    let call_name: String
    let speed: Double?
    let vehicle_id: String
    let segment_id: String?
    let route_id: String
    let arrival_estimates: [vehicleArrivalEstimates]
    let tracking_status: String
    let location: position?
    let heading: Int? // degree representation clockwise starting at North
}

struct vehicleArrivalEstimates: Codable {
    let route_id: String
    let arrival_at: String
    let stop_id: String
}

// MARK: Route
typealias routes = [String: [routeInfo]]

struct routeInfo: Codable {
    let description: String
    let short_name: String
    let route_id: String
    let color: String
    let segments: [[String]] // A list of [SegmentID, "forward" | "backward"] elements
    let is_active: Bool
    let agency_id: Int
    let text_color: String
    let long_name: String
    let url: String
    let is_hidden: Bool
    let type: String
    let stops: [String] // A list of StopID
}

// MARK: Endpoint enum
enum endpoint: String, CaseIterable {
    case agency = "agencies.json"
    case stop = "stops.json"
    case segment = "segments.json"
    case route = "routes.json"
    case vehicle = "vehicles.json"
    case arrivalEstimate = "arrival-estimates.json"
}

// MARK: Parameter Constraints
// this is here only to pass the type checking system
protocol Parameter {
    // All attributes should be string
}

func dictify(src: Parameter) -> [String: String] {
    let mirror = Mirror(reflecting: src)
    
    var result: [String: String] = [:]
    
    for child in mirror.children {
        if let val = child.value as? [String] {
            result[child.label!] = val.joined(separator: "%2C")
        } else if let val = child.value as? String {
            result[child.label!] = val
        }
        // else: we neglect the element
        // since it's of type nil or other types than [String] or String
    }
    
    return result
}

// these parameters are here to constrain the values available to pass in as argument
// and avoid some typos otherwise could occur when setting it as [String:String]
struct AgenciesParam: Parameter {
    let geo_area: String?
}

struct ArrivalEstimatesParam: Parameter {
    let agencies: [String]
    let routes: [String]?
    let stops: [String]?
}

struct StopsParam: Parameter {
    let agencies: [String]
    let geo_area: String?
}

struct SegmentsParam: Parameter {
    let agencies: [String]
    let routes: [String]?
    let geo_area: String?
}

struct RoutesParam: Parameter {
    let agencies: [String]
    let geo_area: String?
}

struct VehiclesParam: Parameter {
    let agencies: [String]
    let routes: [String]?
    let geo_area: String?
}

// MARK: ERROR AND STATUS UPDATE ENUMERATOR
// used in DataStore.errorAndStatusUpdateHandler
enum status: String, CaseIterable {
    case error = "error"
    case statusUpdate = "status update"
}

// MARK: - HELPER FUNCTIONS
// formats the geo area argument
func GeoArea(lat: Double, lng: Double) -> String {
    return "\(lat)%2C\(lng)%7C\(searchRange)"
}

// Decode Point according to encoded polyline algorithm
// Reference: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
func decode(given: String, precision: Double = 1e5) -> [CLLocationCoordinate2D] {
    // decode
    var points: [[Double]] = []
    var point: [Double] = []
    
    var curr: Int32 = 0
    var position: Int8 = 0
    for ascii in given.utf8 {
        let orig: Int32 = Int32(ascii - 63)
        let is_last: Bool = orig & 0x20 != 0x20
        curr = curr | ((orig & 0x1f) << (position * 5))
        position += 1
        if (is_last) {
            // lowest bit indicate that it is negative
            if (curr & 0x01 == 1) {
                // is negative, invert the encoding
                curr = curr >> 1
                curr = ~curr
            } else {
                curr = curr >> 1
            }
            point.append(Double(curr) / precision)
            if (point.count >= 2) {
                points.append(point)
                point = []
            }
            curr = 0
            position = 0
        }
    }
    
    // build list of points
    var coordinates: [CLLocationCoordinate2D] = []
    for p in points {
        if (coordinates.count == 0) {
            coordinates.append(CLLocationCoordinate2D(latitude: p[0], longitude: p[1]))
        } else {
            let last = coordinates.last!
            coordinates.append(CLLocationCoordinate2D(latitude: p[0] + last.latitude, longitude: p[1] + last.longitude))
        }
    }
    return coordinates
}

func distance(p1: position, p2: position) -> Double {
    let a = (p1.lat - p2.lat) * Double.pi / 180
    let b = (p1.lng - p2.lng) * Double.pi / 180
    let result = 2 * asin(
        sqrt(
            pow(sin(a/2), 2) + cos(p1.lat * Double.pi / 180) * cos(p2.lat * Double.pi / 180) * pow(sin(b/2), 2)
        )
    ) * 6378.137 * 1000
    return round(result * 100) / 100.0
}

// MARK: - API Caller Functions
// Generic API Call
func query<dataType: Codable>(
    appLink: endpoint,
    ds: DataStore,
    options: [String:String?],
    successHandler: @escaping (dataType?) -> Void,
    errorHandler: @escaping (String) -> Void,
    statusUpdateHandler: @escaping (String) -> Void
) -> Void {
    statusUpdateHandler("Initialized Nearby Agencies Call")
    
    let session = URLSession(configuration: URLSessionConfiguration.default)
    let link = baseLink + appLink.rawValue + "?" + options.filter{$1 != nil}.map{"\($0)=\($1!)"}.joined(separator: "&")
    
    let url = URL(string: link)!
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    for (header, value) in headers {
        request.addValue(value, forHTTPHeaderField: header)
    }
    
    statusUpdateHandler("Initialized GET request with header")
    
    let task = session.dataTask(with: request) { data, response, error in
        guard error == nil else {
            errorHandler("Error: \(error!)")
            return
        }
        
        guard let jsonData = data else {
            successHandler(nil)
            return
        }
        
        statusUpdateHandler("Data fetch success, decoding")
        
        do {
            let response = try JSONDecoder().decode(Response<dataType>.self, from: jsonData)
            statusUpdateHandler("Decoding Agencies Complete")
            ds.timeouts[appLink] = response.expires_in
            successHandler(response.data)
        }
        catch {
            print(jsonData)
            errorHandler("Endpoint \(appLink.rawValue) Error: \(error)")
        }
    }
    
    statusUpdateHandler("API Call Task built")
    task.resume()
}

// MARK: Agencies
func queryAgencies(
    param: AgenciesParam,
    ds: DataStore,
    successHandler: @escaping (agencies?) -> Void,
    errorHandler: @escaping (String) -> Void,
    statusUpdateHandler: @escaping (String) -> Void
) -> Void {
    
    query(
        appLink: endpoint.agency,
        ds: ds,
        options: dictify(src: param),
        successHandler: successHandler,
        errorHandler: errorHandler,
        statusUpdateHandler: statusUpdateHandler
    )
}

// MARK: Arrival Estimates
func queryArrivalEstimates(
    param: ArrivalEstimatesParam,
    ds: DataStore,
    successHandler: @escaping (estimates?) -> Void,
    errorHandler: @escaping (String) -> Void,
    statusUpdateHandler: @escaping (String) -> Void
) -> Void {
    
    query(
        appLink: endpoint.arrivalEstimate,
        ds: ds,
        options: dictify(src: param),
        successHandler: successHandler,
        errorHandler: errorHandler,
        statusUpdateHandler: statusUpdateHandler)
}

// ----------------
// MARK: Segments
// ----------------
func querySegments(
    param: SegmentsParam,
    ds: DataStore,
    successHandler: @escaping (segments?) -> Void,
    errorHandler: @escaping (String) -> Void,
    statusUpdateHandler: @escaping (String) -> Void
) -> Void {
    
    query(appLink: endpoint.segment,
          ds: ds,
          options: dictify(src: param),
          successHandler: successHandler,
          errorHandler: errorHandler,
          statusUpdateHandler: statusUpdateHandler)
}

// ----------------
// MARK: Routes
// ----------------
func queryRoutes(
    param: RoutesParam,
    ds: DataStore,
    successHandler: @escaping (routes?) -> Void,
    errorHandler: @escaping (String) -> Void,
    statusUpdateHandler: @escaping (String) -> Void
) -> Void {
    
    query(appLink: endpoint.route,
          ds: ds,
          options: dictify(src: param),
          successHandler: successHandler,
          errorHandler: errorHandler,
          statusUpdateHandler: statusUpdateHandler)
}

// ----------------
// MARK: Vehicles
// ----------------
func queryVehicles(
    param: VehiclesParam,
    ds: DataStore,
    successHandler: @escaping (vehicles?) -> Void,
    errorHandler: @escaping (String) -> Void,
    statusUpdateHandler: @escaping (String) -> Void
) -> Void {
    
    query(appLink: endpoint.vehicle,
          ds: ds,
          options: dictify(src: param),
          successHandler: successHandler,
          errorHandler: errorHandler,
          statusUpdateHandler: statusUpdateHandler)
}

// ----------------
// MARK: Stops
// ----------------
// Parameters:
func queryStops(
    param: StopsParam,
    ds: DataStore,
    successHandler: @escaping (stops?) -> Void,
    errorHandler: @escaping (String) -> Void,
    statusUpdateHandler: @escaping (String) -> Void
) -> Void {
    
    query(appLink: endpoint.stop,
          ds: ds,
          options: dictify(src: param),
          successHandler: successHandler,
          errorHandler: errorHandler,
          statusUpdateHandler: statusUpdateHandler)
}
