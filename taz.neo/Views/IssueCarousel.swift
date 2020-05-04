//
//  IssueCarousel.swift
//
//  Created by Norbert Thies on 15.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/**
 An IssueCarousel displays the "Moments" (ie. images) of Issues in a
 carousel. 
 */
public class IssueCarousel: UIView {
  
  // Array of Image/Activity pairs
  private var issues:[(issue: UIImage, isActivity: Bool)] = []
  // The Carousel
  public var carousel = CarouselView()
  // Label for the center image
  private var label = CubeLabel()
  
  /// Current central image
  public var index: Int? {
    get { return carousel.index }
    set { carousel.index = newValue }
  }
  
  /// Text to show in label
  public var text: String? {
    get { label.text }
    set { label.text = newValue }
  }
  
  /// Text to show in label and defining the scrolling direction in the CubeLabel
  public func setText(_ text: String, isUp: Bool) {
    label.setText(text, isUp: isUp)
  }
  
  /// Append issue images to list of images
  public func appendIssues(_ issues: [UIImage]) {
    self.issues.append(contentsOf: issues.map { (issue: $0, isActivity: false) })
    setup()
    carousel.count = self.issues.count
  }
  
  /// Insert Issue at index
  public func insertIssue(_ issue: UIImage, at index: Int) {
    if carousel.provider == nil { reset() }
    self.issues.insert((issue: issue, isActivity: false), at: index)
    carousel.insert(at: index)
  }
  
  /// Define list of images
  public func setIssues(_ issues: [UIImage]) {
    reset()
    self.issues.append(contentsOf: issues.map { (issue: $0, isActivity: false) })
    carousel.count = issues.count
  }
  
  /// Reset to empty carousel
  public func reset() {
    self.issues = []
    setup()
    carousel.count = 0
    self.index = 0    
  }
  
  /// Get activity indicator of issue
  public func getActivity(idx: Int) -> Bool {
    guard idx >= 0 && idx < issues.count else { return false }
    return issues[idx].isActivity
  }

  /// Set activity indicator of issue
  public func setActivity(idx: Int, isActivity: Bool) {
    guard idx >= 0 && idx < issues.count else { return }
    issues[idx].isActivity = isActivity
    if let moment = carousel.optionalView(at: idx) as? MomentView {
      moment.isActivity = isActivity
    }
    else { carousel.reload(index: idx) }
  }
  
  private var tapClosure: ((Int)->())? = nil
  /// Define Tap handler
  public func onTap(closure: ((Int)->())?) { tapClosure = closure }
  
  private var labelTapClosure: ((Int)->())? = nil
  /// Define Tap handler
  public func onLabelTap(closure: ((Int)->())?) { labelTapClosure = closure }
  
  // Define view provider
  private func setup() {
    guard carousel.provider == nil else { return }
    self.addSubview(carousel)
    self.addSubview(label)
    pin(carousel.left, to: self.left)
    pin(carousel.right, to: self.right)
    pin(carousel.bottom, to: label.top)
    pin(carousel.top, to: self.top, dist: 20)
    pin(label.bottom, to: self.bottom)
    pin(label.left, to: self.left, dist: 20)
    pin(label.right, to: self.right, dist: -20)
    label.textAlignment = .center
    label.numberOfLines = 1
    label.font = .boldSystemFont(ofSize: 17)
    label.adjustsFontSizeToFitWidth = true
    label.textColor = UIColor.rgb(0xeeeeee)
    label.onTap {_ in
      self.labelTapClosure?(self.index!)
    }
    carousel.viewProvider { [weak self] (idx, view) in
      guard let self = self else { return MomentView() }
      var moment: MomentView? = view as? MomentView
      if moment == nil { moment = MomentView() }
      moment!.image = self.issues[idx].issue
      moment!.isActivity = self.issues[idx].isActivity
      moment!.menu = self.menu
      moment!.onTap {_ in self.tapClosure?(idx) }
      return moment!
    }
  }
  
  /// Animate the scrolling between Moments
  public func showAnimations() {
    if let last = index, carousel.count > 1 {
      var next: Int
      if last > 0 { next = max(0, last-2) }
      else { next = min(carousel.count-1, last+2) }
      delay(seconds: 1) { self.carousel.scrollto(next, animated: true) }
      delay(seconds: 3) { self.carousel.scrollto(last, animated: true) }
    }
  }
    
  /// Define the menu to display on long touch of a MomentView
  public var menu: [(title: String, icon: String, closure: (String)->())] = []
  
  /// Add an additional menu item
  public func addMenuItem(title: String, icon: String, closure: @escaping (String)->()) {
    menu += (title: title, icon: icon, closure: closure)
  }

  
} // IssueCarousel
