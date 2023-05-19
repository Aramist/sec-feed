//
//  SECRequester.swift
//  sec-filings
//
//  Created by Aramis Tanelus on 5/18/23.
//

import Foundation


enum SECRetrievalError: Error {
    case FileNotFound
    case ConnectionError
    case InvalidAccessionNumber
}

struct SubmissionService: Decodable {  // Intermediate struct for decoding JSON
    var cik: String
    var entityType: String
    var sic: String
    var sicDescription: String
    var name: String
    var tickers: [String]
    var exchanges: [String]
    var filings: FilingsNestService
    
    struct FilingsNestService: Decodable {
        var recent: FilingsService

        struct FilingsService: Decodable {
            var accessionNumber: [String]
            var filingDate: [String]
            var reportDate: [String]
            var form: [String]
            var primaryDocument: [String]
        }
    }
}

struct Submission {
    static var ARCHIVE_BASE_URL = "https://www.sec.gov/Archives/edgar/data/"
    var cik: Int  // Central Index Key
    var entityType: String
    var sic: Int  // Standard Industrial Classification
    var sicDescription: String
    var name: String
    var tickers: [String]
    var exchanges: [String]  // Exchange(s) on which the company is listed
    var filings: [Filing]

    struct Filing {
        var accessionNumber: String
        var filingDate: Date  // Date the filing was submitted to the SEC
        var reportDate: Date?  // Date(s) of the transaction(s) reported
        var form: String
        var fileURL: String
    }
}

fileprivate func getStem(from filename: String) -> String {
    if filename.contains("/") {
        guard let stem = filename.split(separator: "/", omittingEmptySubsequences: true).last else {
            return filename  // This shouldn't happen
        }
        return String(stem)
    }
    return filename
}

extension Submission {
    init(from submission: SubmissionService) {
        self.cik = Int(submission.cik)!
        self.entityType = submission.entityType
        self.sic = Int(submission.sic)!
        self.sicDescription = submission.sicDescription
        self.name = submission.name
        self.tickers = submission.tickers
        self.exchanges = submission.exchanges
        self.filings = []
        
        for i in 0..<submission.filings.recent.accessionNumber.count {
            let filename = submission.filings.recent.primaryDocument[i]
            let fileStem = getStem(from: filename)
            let accession = submission.filings.recent.accessionNumber[i].replacingOccurrences(of: "-", with: "")
            let filing = Submission.Filing(
                accessionNumber: accession,
                filingDate: Date(from: submission.filings.recent.filingDate[i])!,
                reportDate: Date(from: submission.filings.recent.reportDate[i]),
                form: submission.filings.recent.form[i],
                fileURL: "\(Submission.ARCHIVE_BASE_URL)/\(self.cik)/\(accession)/\(fileStem)"
            )
            self.filings.append(filing)
        }
    }
}

extension Date {
    init?(from string: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: string) {
            self = date
        } else {
            return nil
        }
    }
}

func getSubmission(from filename: String) throws -> Submission{
    let fileContents = try String(contentsOfFile: filename)
    let data = Data(fileContents.utf8)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let submissionIntermediate = try decoder.decode(SubmissionService.self, from: data)
    return Submission(from: submissionIntermediate)
}



// MARK: Load ticker data
fileprivate struct TickerExchangeInfoService: Decodable {
    var fields: [String]
    var data: [[String]]
}

struct Ticker {
    var cik: Int
    var companyName: String
    var ticker: String
    var exchange: String

    init? (from tickerInfo: [String]) {
        // Field order: cik (int), companyName(str), ticker(str), exchange(str)
        guard let cik = Int(tickerInfo[0]) else { return nil }
        let companyName = tickerInfo[1]
        let ticker = tickerInfo[2]
        let exchange = tickerInfo[3]
        self.cik = cik
        self.companyName = companyName
        self.ticker = ticker
        self.exchange = exchange
    }
}


fileprivate func getTickerExchangeInfo(from filepath: String) -> [Ticker] {
    let decoder = JSONDecoder()
    guard let dataString = try? String(contentsOfFile: filepath).utf8 else {
        fatalError("Error reading file")
    }

    let data = Data(dataString)
    guard let tickerInfo = try? decoder.decode(TickerExchangeInfoService.self, from: data) else {
        fatalError("Failed to decode cik-ticker-exchange JSON")
    }

    let tickers = tickerInfo.data.compactMap {Ticker(from: $0)}
    return tickers
}
