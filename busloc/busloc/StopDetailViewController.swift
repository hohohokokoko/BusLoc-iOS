//
//  StopDetailViewController.swift
//  busloc
//
//  Created by 卿山 on 4/16/22.
//

import UIKit

class StopDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var stopName = "None"
    @IBOutlet var myTable: UITableView!
    var routes:[String] = []
    var estimates:[Int] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        myTable.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        myTable.delegate = self
        myTable.dataSource = self
//        myTable.frame.
        // Do any additional setup after loading the view.
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return stopName
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedRoute = routes[indexPath.row]
        let selectedEstimate = estimates[indexPath.row]
        let message = selectedRoute + " Arriving in " + String(selectedEstimate) + " Minutes"
        let alert = UIAlertController(title: "Detail", message: message, preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .default, handler: {
            ACTION in
            alert.dismiss(animated: true, completion: nil)
        })
                
        alert.addAction(ok)
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
            header.textLabel?.textColor = UIColor.black
            header.textLabel?.font = UIFont.boldSystemFont(ofSize: 15)
            header.textLabel?.frame = header.bounds
            header.textLabel?.textAlignment = .center
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.routes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = "Route " + self.routes[indexPath.row] + " Arriving in "+String( self.estimates[indexPath.row]) + " Minutes"
//        cell.contentView.backgroundColor = UIColor.clear
        return cell
    }
    
//    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
//        cell.backgroundColor = UIColor.clear
//        cell.backgroundView?.backgroundColor = UIColor.clear
//    }


}
