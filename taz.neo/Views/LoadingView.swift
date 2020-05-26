//
//  LoadingView.swift
//
//  Created by Norbert Thies on 14.01.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

fileprivate var TopFont = UIFont.boldSystemFont(ofSize: 24)
fileprivate var BottomFont = UIFont.boldSystemFont(ofSize: 18)

open class LoadingView: UIView {
  
  private var stack = UIStackView()
  private var topLabel = UILabel()
  private var bottomLabel = UILabel()
  private var spinner = UIActivityIndicatorView()
  
  public var topText: String? {
    get { return topLabel.text }
    set { topLabel.text = newValue }
  }
  public var bottomText: String? {
    get { return bottomLabel.text }
    set { bottomLabel.text = newValue }
  }
  
  public func start() { spinner.startAnimating() }
  public func stop() { spinner.stopAnimating() }
  
  private func setup() {
    backgroundColor = UIColor.clear
    topLabel.font = TopFont
    topLabel.numberOfLines = 0
    topLabel.textAlignment = .center
    bottomLabel.font = BottomFont
    bottomLabel.numberOfLines = 0
    bottomLabel.textAlignment = .center
    if #available(iOS 13.0, *) {
      spinner.style = .large
    }
    spinner.color = UIColor.black
    spinner.startAnimating()
    for view in [topLabel, spinner, bottomLabel] {
      stack.addArrangedSubview(view)
    }
    stack.axis = .vertical
    stack.distribution = .fillEqually
    addSubview(stack)
    pin(stack, to: self)
  }
  
  public override init(frame: CGRect) {
    super.init(frame:frame)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  override open func layoutSubviews() {
    setNeedsDisplay()
  }
  
  override public func draw(_ rect: CGRect) {
    super.draw(rect)
    spinner.startAnimating()
  }

} // LoadingView
