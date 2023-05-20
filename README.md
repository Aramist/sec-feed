#  SEC Form 4 Feed

### Random project-related notes and TODOs are as follows:
* Thinking of storing several fields:
  - Datetime of last request per CIK. Only request each CIK once every 12 hours
  - list of requested filings per CIK
  - make data structure containing important information from XML forms, cache these upon download
    - For development, cache entire xml file to avoid exceeding request limits

### Data models:
 * Company: holds information about a financial entity and possesses a one-to-many relationship with Filings relating to this entity
   - int cik
   - str entityType
   - int sic
   - str sicDescription
   - str name
   - str ticker
   - str exchange
   - [Filing] filings (many-to-one)
 * Filing: Holds information about a single filing and possible, XML data of the filing
   - Company (weak) parent
   - str accessionNumber
   - date filingDate
   - date? transactionDate
   - str formType
   - str fileURL
   - str? xmlContents
