//
//  TestController.swift
//  anav01
//
//  Created by Norbert Thies on 19.09.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit

class TestView: UIView {
  
  var index = 0 {
    didSet {
      let v = 0.1 * CGFloat(index)
      self.backgroundColor = UIColor(red: v, green: v, blue: v, alpha: 1.0)
    }
  }
  
}

class TestController: PageCollectionVC<TestView> {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = UIColor.red
    self.collectionView.backgroundColor = UIColor.blue
    self.count = 10
    self.index = 4
    viewProvider { (index, view) in
      var ret: TestView
      if let v = view { ret = v }
      else { ret = TestView() }
      ret.index = index
      return ret
    }
  }
  
}
