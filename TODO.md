#  TODO taz.neo

Things that should be done soon

## Important before next release

### ToDO's in Source
/Users/taz/src/TAZ/taz-neo.ios/taz.neo/AppDelegate.swift:  
//#warning("ToDo: 0.9.4 Server Switch without App Restart")

/Users/taz/src/TAZ/taz-neo.ios/taz.neo/FeederContext.swift:              
//#warning("ToDo 0.9.4+: Missing Update of an stored Issue")
//is this still current and relevant?

## Merges

Merge documentation in case of big and late merges, 
not needed if fast foreward or small merges.

### merge 24/03/11

- Device Ringo/Desktop Repo: "taz dev 2"
- Content: Lmd after Release > taz.alpha
- **NorthLib:**
  - ringo/release Pushed to origin/release
  - #7bdc079 
  - 6. März 2024 
  - Up to Date
  - **valid for: taz Branches, lmd Branch**
  - no conflicts
- **taz Repository**
  - Commit: 1e72f57f / Tag: 1.1.1 / 16. November 2023
  - Commit: 60ae79a3 / origin/release /29. Februar 2024 is 50+ Commits Ahead
  - Commit: c2e48014 / Labels: LMd-1.2.0 / 7. Februar 2024 
    ...based on direct Child of 1e72f57f 
  - Commit: 7851ffbf / origin/lmd / 9. Februar 2024 
    ...based on Lmd Release 1.2.0
  - Commit: 7e5741cf / ringo-private/coachmarks / 25. Februar 2024 
    ...based on Lmd Current
    ...not needed changes has been cherry picked to taz
  - **MERGE**
    - 1st: Origin/release > origin/alpha  
      Not needed, already done with #60ae79a3 on 29.2.24
    - 2nd: origin/lmd > origin/alpha 
      DONE #fad4f810
    - test
      DONE Fixed some smaller merge issues with #f3ccc87d ff.
    - 3rd: origin/alpha => origin/beta
      DONE #583697d4
    - Merge Issue Reminder and Checks
      - LMd Bookmarks List Play All
      DONE/OK
      - delete Issue from IssueCollectionViewActions instead of reduceToOverview
      DONE/OK
      - compare serach result list taz store app with simulator
      DONE/OK
      - togglePdfButtonin HomeTVC
      ERROR Fixed, was showAnimated and would not work for Coachmarks

...seams to be **successful** 
