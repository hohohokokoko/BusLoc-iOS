//
//  StopsListVC.swift
//  busloc
//
//  Created by Elnifio on 4/17/22.
//

import UIKit

class StopListCell: UITableViewCell {
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var subtitle: UILabel!
    var stop: busStop?
}

class StopsListVC: UITableViewController, DataListener {
    
    // MARK: - DATA
    var routeInfo: [String:routeInfo] = [:]
    var stopsInfo: stops = []
    var currlocation: position?
    
    // COLOR CONSTANTS
    let colors: [UIColor] = [UIColor.systemGray, UIColor.systemBlue, UIColor.systemYellow, UIColor.systemGreen, UIColor.systemOrange, UIColor.systemPink, UIColor.systemTeal, UIColor.systemPurple]
    
    // MARK: - DATA STORE & UPDATE
    var ds: DataStore = (UIApplication.shared.delegate as! AppDelegate).ds
    
    func receiveArrivalEstimates(value: estimates) {}
    func receiveSegments(value: segments) {}
    func receiveVehicles(value: vehicles) {}
    func receiveAgencies(value: agencies) {}
    
    func receiveRoutes(value: routes) {
        self.routeInfo = [:]
        for (_, rinfos) in value {
            for r in rinfos {
                self.routeInfo[r.route_id] = r
            }
        }
        
        self.updateTable()
    }

    func receiveStops(value: stopBundle) {
        self.stopsInfo = value.listRepr.filter {
            distance(p1: $0.location, p2: self.currlocation!) <= Double(searchRange)
        }.sorted {
            distance(p1: $0.location, p2: self.currlocation!) < distance(p1: $1.location, p2: self.currlocation!)
        }
        self.updateTable()

    }
    
    func receiveLocations(value: position) {
        self.currlocation = value
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
        if (self.stopsInfo.count != 0) {
            return 1
        } else {
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.stopsInfo.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "stopListCell", for: indexPath) as! StopListCell
        
        // Configure the cell...
        
        cell.stop = self.stopsInfo[indexPath.row]
        cell.title?.text = cell.stop!.name
        cell.icon?.image = UIImage(systemName: "\(cell.stop!.routes.count).square.fill")
        cell.icon?.tintColor = self.colors[(cell.stop!.routes.count % self.colors.count)]
        cell.isUserInteractionEnabled = true
        
        
        
        cell.subtitle?.text = "Available Routes: \(cell.stop!.routes.filter { self.routeInfo[$0] != nil }.map{ self.routeInfo[$0]!.short_name }.joined(separator: ", "))"

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
        guard let row = sender! as? StopListCell else { return }
        let dest = segue.destination as! StopSpecificVC
        guard row.stop != nil else { return }
        dest.stopId = row.stop!.stop_id
    }

}
