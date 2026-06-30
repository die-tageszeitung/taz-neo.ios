//
//  String+Extension.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation
import UIKit

extension String {
  var authorsFormated: String {
#if LMD
    return self.length > 0 ? self.xmlEscaped().prepend("von ") : ""
#else
    return self.xmlEscaped()
#endif
  }
}

extension NSAttributedString {
  
  ///Warning: Fontsize overwrites font!
  convenience init?(
    _ text: String?,
    font: UIFont? = nil,
    fontSize: CGFloat? = nil,
    lineHeight: CGFloat? = nil
  ) {
    guard let text else {
      return nil
    }
    
    let fontSize = fontSize ?? Const.Size.DefaultFontSize
    let font = font ?? Const.Fonts.contentFont(size: fontSize)
    
    let paragraphStyle = NSMutableParagraphStyle()
    
    if let lineHeight {
      paragraphStyle.minimumLineHeight = lineHeight
      paragraphStyle.maximumLineHeight = lineHeight
    }
    
    self.init(
      string: text,
      attributes: [
        .font: font,
        .paragraphStyle: paragraphStyle
      ]
    )
  }
}
