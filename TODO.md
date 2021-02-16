#  TODO taz.neo

Things that should be done soon

## Important before next release
- IssueVcWithBottomTiles:
    - Test: scrolling or stocking if new items added (insertItems)
    - may Refactor & Integrate both Controller after merge
    - iPad Layout
    - Cloud Icon disapear on Download finish
    - PDF Moments/Page 1



## Less-Important keep in mind for future releases

- IssueVcWithBottomTiles: 
  - line 246  collectionView.cellForItemAt :: issueVC.feeder.momentImage(issue: issue)
    image is 2.4MB currently may use smaller to increase Performance
    especially with BottomTiles (8 and more images at the same time)
    Check with: print("Moment Image Size: \(img.mbSize) for: \(img) with scale: \(img.scale)")
  - line 146 viewDidLoad may add auto scroll animations (removed within this commit)
  
 
