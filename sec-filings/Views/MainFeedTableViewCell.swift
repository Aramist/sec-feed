//
//  MainFeedTableViewCell.swift
//  sec-filings
//
//  Created by Aramis Tanelus on 5/18/23.
//

import UIKit


class MainFeedTableViewCell: UITableViewCell {
    static let reuseId = "MainFeedTableViewCell"
    
    @IBOutlet var entityName: UILabel?
    @IBOutlet var transactionDate: UILabel?
    @IBOutlet var filingDate: UILabel?
    @IBOutlet var transactionTypeCode: UILabel?
    @IBOutlet var ticker: UILabel?
    @IBOutlet var assetType: UILabel?
    @IBOutlet var quantity: UILabel?
    
}
