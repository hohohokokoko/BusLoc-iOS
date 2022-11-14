//
//  StopsListVC.swift
//  busloc
//
//  Created by Elnifio on 4/17/22.
//

import UIKit

class RouteListCell: UITableViewCell {
    @IBOutlet weak var icon: UILabel!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var subtitle: UILabel!
    
    var route: routeInfo?
}

class RoutesListVC: UITableViewController, DataListener {
    
    // MARK: - DATA
    var routeInfo: [routeInfo] = []
    var stopsInfo: [String: busStop] = [:]
    var currlocation: position?
    var agencyInfo: [String:agency] = [:]
    var rangeMultiplier = 5
    
    // MARK: - DATA STORE & UPDATE
    var ds: DataStore = (UIApplication.shared.delegate as! AppDelegate).ds
    
    func receiveArrivalEstimates(value: estimates) {}
    func receiveSegments(value: segments) {}
    func receiveVehicles(value: vehicles) {}
    func receiveAgencies(value: agencies) {
        self.agencyInfo = [:]
        for a in value {
            self.agencyInfo[a.agency_id] = a
        }
        self.updateTable()
    }
    
    func measureDistance(r: routeInfo) -> Double {
        var mindistance = Double(1e+10)
        for stopID in r.stops {
            if (self.stopsInfo[stopID] == nil || self.currlocation == nil) {
                continue
            } else {
                mindistance = min(mindistance, distance(p1: self.stopsInfo[stopID]!.location, p2: self.currlocation!))
            }
        }
        return mindistance
    }
    
    func receiveRoutes(value: routes) {
        self.routeInfo = []
        for (_, rinfos) in value {
            for rinfo in rinfos {
                self.routeInfo.append(rinfo)
            }
        }
        
        self.routeInfo = self.routeInfo.filter { (val: routeInfo) -> Bool in
            measureDistance(r: val) < Double(self.rangeMultiplier * searchRange)
        }.sorted(by: { route1, route2 in
            // route1.stops.map
            //    { stopID in distance(p1: self.stopsInfo[stopID]!.location, p2: self.currlocation!) }.min()!
            // <
            // route2.stops.map
            //    { stopID in distance(p1: self.stopsInfo[stopID]!.location, p2: self.currlocation!) }.min()!
            measureDistance(r: route1) < measureDistance(r: route2)
        })
        
        print("\(self.routeInfo.count) routes provided")
        
        self.updateTable()
    }

    func receiveStops(value: stopBundle) {
        self.stopsInfo = value.dictRepr
        self.updateTable()

    }
    
    func receiveLocations(value: position) {
        self.currlocation = value
        print("Received Location in RouteListVC")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.ds.registerListener(l: self)
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.ds.removeListener(l: self)
    }
    
    // MARK: TABLE DELEGATION METHODS

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        if (self.routeInfo.count != 0) {
            return 1
        } else {
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.routeInfo.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "routeListCell", for: indexPath) as! RouteListCell
        
        // Configure the cell...
        
        cell.route = self.routeInfo[indexPath.row]
        cell.title?.text = cell.route!.long_name
        cell.icon?.text = cell.route!.short_name
        cell.icon?.textColor = decodeColor(color: cell.route!.text_color)
        cell.icon?.backgroundColor = decodeColor(color: cell.route!.color)
        cell.subtitle?.text = self.agencyInfo["\(cell.route!.agency_id)"]?.long_name ?? ""
        cell.isUserInteractionEnabled = true

        return cell
    }
    
    func updateTable() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        guard let row = sender! as? RouteListCell else { return }
        let dest = segue.destination as! RouteSpecificVC
        guard row.route != nil else { return }
        
        dest.route = row.route!
    }

}
