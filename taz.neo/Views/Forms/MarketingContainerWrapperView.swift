//
//  MarketingContainerWrapperView.swift
//  taz.neo
//
//  Created by Ringo Müller on 18.06.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class MarketingContainerWrapperView: UIView {
  
  var wrapperConstrains: tblrConstrains?
  private var marketingContainer: [MarketingContainerView] = []
  
  override func willMove(toSuperview newSuperview: UIView?) {
    setupIfNeeded()
    super.willMove(toSuperview: newSuperview)
  }
  
  let wrapper = UIView()
  
  func addViewToWrapper(_ v:UIView){
    if let mc = v as? MarketingContainerView {
      marketingContainer.append(mc)
    }
    wrapper.addSubview(v)
  }
  
  func setupIfNeeded(){
    guard wrapper.superview == nil else { return }
    self.addSubview(wrapper)
    wrapperConstrains = pin(wrapper, to: self, dist: Const.Size.DefaultPadding)
  }
  
  func updateCustomConstraints(isTabletLayout: Bool){
    let dist = isTabletLayout ? Const.Size.TabletSidePadding : Const.Size.DefaultPadding
    wrapperConstrains?.left?.constant = dist
    wrapperConstrains?.right?.constant = -dist
    marketingContainer.forEach { c in c.updateCustomConstraints(isTabletLayout: isTabletLayout) }
  }
}
