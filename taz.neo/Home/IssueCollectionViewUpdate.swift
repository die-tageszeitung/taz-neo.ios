//
//  IssueCollectionViewUpdate.swift
//  taz.neo
//
//  Created by Ringo Müller on 02.06.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit

protocol IssueCollectionViewUpdate: UIContextMenuInteractionDelegate where Self: UICollectionViewController {
  var isHorizontal: Bool { get }
}

extension IssueCollectionViewActions {
  
  var isHorizontal: Bool { return true }
  
  /// Helper to update collectionView
  /// MOVE TO SERVICE UPDATE IS JUST WITH INDEXPATH
  func update(old:[PublicationDate], new:[PublicationDate]) {
    let contentHeight = self.collectionView.contentSize.height
    let offsetY = self.collectionView.contentOffset.y
    
    var insertIp: [IndexPath] = []
    var old = old.sorted { d1, d2 in  d1.date > d2.date }
    var new = new.sorted { d1, d2 in  d1.date > d2.date }
    var reused: [PublicationDate] = []
    
    for (ni, newElm) in new.enumerated() {
      var found = false
      for (oi, oldElm) in new.enumerated() {
        if newElm.date.issueKey == oldElm.date.issueKey {
          
        }
      }
      if found == false {
        
      }
    }
      
      
      if let idx = old.firstIndex(where: { oldEl in
        oldEl.date.issueKey == element.date.issueKey
      }) {
        ///
      }
      else {
        ///element not in oldList add to insertIp
        insertIp.append(IndexPath(row: index, section: 0))
      }
    }
    collectionView.deleteItems(at: <#T##[IndexPath]#>)
    collectionView.inse
    collectionView.moveItem(at: <#T##IndexPath#>, to: <#T##IndexPath#>)
    
    for pd in new {
      if let idx = deleteIp.firstIndex(where: { dpd in
        dpd.date.issueKey == pd.date.issueKey
      }) {
        
        let elm = deleteIp.remove(at: idx)
      }
      else {
        insertIp.append(<#T##newElement: IndexPath##IndexPath#>)
      }
      deleteIp.fi2
    }
    
    
    
    let bottomOffset = contentHeight - offsetY

    CATransaction.begin()
    CATransaction.setDisableActions(true)

    self.collectionView!.performBatchUpdates({
        var indexPaths = [NSIndexPath]()
        for i in 0..<addCnt {
            let index = 0 + i
            indexPaths.append(NSIndexPath(forItem: index, inSection: section))
        }
        if indexPaths.count > 0 {
            self.collectionView!.insertItemsAtIndexPaths(indexPaths)
        }
        }, completion: {
            finished in
            print("completed loading of new stuff, animating")
            self.collectionView!.contentOffset = CGPointMake(0, self.collectionView!.contentSize.height - bottomOffset)
            CATransaction.commit()
    })
  }
  
}
