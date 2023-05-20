//
//  ViewController.swift
//  sec-filings
//
//  Created by Aramis Tanelus on 5/15/23.
//

import CoreData
import UIKit


class MainFeedViewController: UIViewController {
    
    fileprivate enum sortingCriteria {
        case ticker
        case filingDate
        case transactionDate
        case entityName
        case quantity
    }
    
    private var requester = SECRequester()
    private var filings: [Filing] = []
    private var watchlist: [Int] = [] // CIKs of companies being watched
    
    var container: NSPersistentContainer?
    @IBOutlet var mainFeedTable: UITableView?
    @IBOutlet var showAddTickerButton: UIButton?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Request data
        showAddTickerButton?.addTarget(self, action: #selector(pushAddTicker), for: .touchUpInside)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let addTickerVC = segue.destination as? AddTickerViewController {
            addTickerVC.mainFeed = self
        }
    }
    
    func addCompany(withCIK cik: Int) {
        // should search for ticker's cik, add to watchlist, and trigger data request/update
        guard !watchlist.contains(cik) else { return }
        watchlist.append(cik)
        
        Task {
            await fetchDataOnline()
        }
    }
    
    /// Fetches existing data from CoreData storage and displays on the table
    fileprivate func updateDataOffline() {
        
        mainFeedTable?.reloadData()
    }
    
    /// Requests data if necessary for existing CIKs and updates the table
    fileprivate func fetchDataOnline() async {
        for cik in watchlist {
            guard let submission = await requester.requestSubmission(forCIK: cik) else {
                continue
            }
            // Make persistent objects for company and filings:
            let (company, filings) = submission
            print(company)
            print("Num filings: \(filings.count).")
        }
        
    }
    
    /// Modifies the provided index to apply a custom sorting to the data
    /// - Parameter idx: Index of the row within the table view
    fileprivate func applySorting(forIndex idx: Int) -> Int{
        // TODO: implement sorting procedures
        return idx
    }
    
    
    @objc func pushAddTicker() {
        print("pushed button")
        performSegue(withIdentifier: "showAddTickerSegue", sender: nil)
    }
}

extension MainFeedViewController: UITableViewDelegate {}

extension MainFeedViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.filings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MainFeedTableViewCell.reuseId) as? MainFeedTableViewCell else {
            fatalError("Failed to dequeue table cell (this shouldn't happen)")
        }
        let filing = filings[applySorting(forIndex: indexPath.row)]
        
        // TODO: this should actually be an entity name grabbed from the xml, but this might go over the request budget
        cell.entityName?.text = filing.parent?.name
        
        return cell
    }
    
    
}
