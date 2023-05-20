//
//  AddTickerViewController.swift
//  sec-filings
//
//  Created by Aramis Tanelus on 5/19/23.
//

import UIKit


class AddTickerViewController: UIViewController {
    
    // Ref to main feed for sending data back
    weak var mainFeed: MainFeedViewController!
    // this snippet creates space for the suggestion dropdown in the ticker input field
    @IBOutlet var tickerInput: UITextField?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tickerInput?.delegate = self
    }
}

extension AddTickerViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        resignFirstResponder()
        // Send information back to the Main Feed view
        let contents = textField.text ?? ""
        guard let cik = Int(contents) else { return false }
        mainFeed.addCompany(withCIK: cik)
        // Return to main feed
        navigationController?.popViewController(animated: true)
        return false
    }
}
