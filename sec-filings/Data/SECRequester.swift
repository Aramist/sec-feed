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

// MARK: fileprivates
fileprivate func getStem(from filename: String) -> String {
    
    if filename.contains("/") {
        guard let stem = filename.split(separator: "/", omittingEmptySubsequences: true).last else {
            return filename  // This shouldn't happen
        }
        return String(stem)
    }
    return filename
}

fileprivate func getTickerExchangeInfo(from filepath: String) -> [SECRequester.Ticker] {
    guard let fileContents = try? String(contentsOfFile: filepath)  else {
        fatalError("Failed to read local ticker data (this shouldn't happen")
        // return []
    }
    let decoder = JSONDecoder()
    let data = Data(fileContents.utf8)
    
    guard let tickerInfo = try? decoder.decode(SECRequester.TickerExchangeInfoService.self, from: data) else {
        fatalError("Failed to decode cik-ticker-exchange JSON  (This also shouldn't happen")
    }
    
    let tickers = tickerInfo.data.compactMap {SECRequester.Ticker(from: $0)}
    return tickers
}


// Namespace to disambuguate some things
class SECRequester {
    // MARK: Internal classes
    fileprivate struct SubmissionService: Decodable {  // Intermediate struct for decoding JSON
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
    
    class Company {
        static var ARCHIVE_BASE_URL = "https://www.sec.gov/Archives/edgar/data/"
        var cik: Int  // Central Index Key
        var entityType: String
        var sic: Int  // Standard Industrial Classification
        var sicDescription: String
        var name: String
        var ticker: String
        var exchange: String  // Exchange on which the company is listed. If multiple are available, choose the first
        private var submission: SubmissionService?
        
        class func getSubmissionURL(for cik: Int) throws -> URL{
            let formattedCIK = String(format:"%010d", cik)
            guard let url = URL(string: "https://data.sec.gov/submissions/CIK\(formattedCIK).json") else {
                throw SECRetrievalError.FileNotFound
            }
            return url
        }
        
        init() {
            // Will likely never be used
            self.cik = 0
            self.entityType = ""
            self.sic = 0
            self.sicDescription = ""
            self.name = ""
            self.ticker = ""
            self.exchange = ""
        }
        
        fileprivate convenience init(from submission: SubmissionService) {
            self.init()
            self.cik = Int(submission.cik) ?? -1
            self.entityType = submission.entityType
            self.sic = Int(submission.sic) ?? -1
            self.sicDescription = submission.sicDescription
            self.name = submission.name
            self.ticker = submission.tickers.first ?? ""
            self.exchange = submission.exchanges.first ?? ""
            self.submission = submission
        }
        
        func extractFilings() -> [Filing] {
            guard let submission = self.submission else { return [] }
            var filings: [Filing] = []
            for i in 0..<submission.filings.recent.accessionNumber.count {
                let filename = submission.filings.recent.primaryDocument[i]
                let fileStem = getStem(from: filename)
                let accession = submission.filings.recent.accessionNumber[i].replacingOccurrences(of: "-", with: "")
                let filing = Company.Filing(
                    company: self,
                    accessionNumber: accession,
                    filingDate: Date(from: submission.filings.recent.filingDate[i])!,
                    transactionDate: Date(from: submission.filings.recent.reportDate[i]),
                    formType: submission.filings.recent.form[i],
                    fileURL: "\(Company.ARCHIVE_BASE_URL)/\(self.cik)/\(accession)/\(fileStem)"
                )
                filings.append(filing)
            }
            return filings
        }
        
        struct Filing {
            weak var company: Company?
            var accessionNumber: String
            var filingDate: Date  // Date the filing was submitted to the SEC
            var transactionDate: Date?  // Date(s) of the transaction(s) reported
            var formType: String
            var fileURL: String
        }
    }
    
    // MARK: Actual class code
    
    private var tickers: [Ticker]
    
    init() {
        let tickerDataPath = Bundle.main.path(forResource: "", ofType: "json")
        guard let tickerDataPath = tickerDataPath else {
            self.tickers = []
            return
        }
        
        self.tickers = getTickerExchangeInfo(from: tickerDataPath)
    }
    
    
    func search(forTicker ticker: String) -> [(name: String, cik: Int)] {
        guard let t = self.tickers.first else { return [] }
        print("Requesting ticker \(ticker)")
        return [(name: t.companyName, cik: t.cik)]
    }
    
    func requestSubmission(forCIK cik: Int) async -> (SECRequester.Company, [SECRequester.Company.Filing])?{
        let session = URLSession.shared
        let dataURL = try? SECRequester.Company.getSubmissionURL(for: cik)
        guard let dataURL = dataURL else { fatalError("Invalid URL format??")}
        
        var request = URLRequest(url: dataURL)
        // Add headers as indicated by https://www.sec.gov/os/accessing-edgar-data
        request.setValue("Aramis Tanelus aramis.tanelus@gmail.com", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("data.sec.gov", forHTTPHeaderField: "Host")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")  // idk why but copying this header entry from Firofox's request fixed the issue of not being able to make a secure connection
        
        guard let data = try? await session.data(for: request).0 else {
            print("Failed to get data. for request url \(dataURL.absoluteString)")
            return nil
        }
    
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let submissionIntermediate = try? decoder.decode(SubmissionService.self, from: data) else {
            print("Failed to decode json. (Probably shouldn't happen?)")
            print("Request url \(dataURL.absoluteString)")
            return nil
        }
        let company = SECRequester.Company(from: submissionIntermediate)
        let filings = company.extractFilings()
        return (company, filings)
    }
    
    // MARK: Load ticker data
    fileprivate struct TickerExchangeInfoService: Decodable {
        var fields: [String]
        var data: [[String]]
    }
    
    
    fileprivate struct Ticker {
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
