//
//  TableSectionSeperatorFooterView.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

import UIKit
import NorthLib

/// A simple black/white line used as a separator between table sections.
class TableSectionSeperatorFooterView: UITableViewHeaderFooterView, UIStyleChangeDelegate {
  
  // Reuse identifier for the view
  static let ReuseIdentifier = "TableSectionSeparatorFooterViewIdentifier"
  
  // Line view used as the separator
  private let line: UIView = UIView()
  
  /// Configures the initial setup of the footer view.
  private func setup() {
    // Set the initial background color of the line
    line.backgroundColor = Const.SetColor.ios(.systemBackground).color
    
    // Add the line view as a subview of the content view
    contentView.addSubview(line)
    
    // Set up Auto Layout constraints
    pin(line.left, to: contentView.left, dist: Const.Size.DefaultPadding, priority: .fittingSizeLevel)
    pin(line.right, to: contentView.right, dist: -Const.Size.DefaultPadding, priority: .fittingSizeLevel)
    line.centerY()
    line.pinHeight(0.7) // Set the height of the line to 0.7 points
    
    // Adjust the layout margins of the content view
    contentView.layoutMargins.left = Const.Size.DefaultPadding
    contentView.layoutMargins.right = Const.Size.DefaultPadding
    
    // Register for style updates (e.g., to respond to theme changes)
    registerForStyleUpdates()
  }
  
  /// Updates the styles of the separator based on the current theme.
  func applyStyles() {
    line.backgroundColor = Const.SetColor.HText.color
  }
  
  /// Initializes the footer view programmatically and sets up its layout and styles.
  override init(reuseIdentifier: String?) {
    super.init(reuseIdentifier: reuseIdentifier)
    setup()
  }
  
  /// Initializes the footer view from a storyboard or nib and sets up its layout and styles.
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}
