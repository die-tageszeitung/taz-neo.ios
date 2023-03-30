//
//  ViewWithTextField.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 07.10.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import UIKit
import NorthLib


/// A UITextView with Top Label (for Description), Bottom Label (for Errormessages), Placeholder Label (Placeholder)
public class ViewWithTextField : UIStackView, KeyboardToolbarForText{
  public var inputToolbar: UIToolbar { textfield.inputToolbar }
  
  public override var tag: Int {
    get { return textfield.tag}
    set { textfield.tag = newValue }
  }
  
  var textViewheightConstraint:NSLayoutConstraint?
  
  let topLabel = UILabel()
  let bottomLabel = UILabel()
  let textfield = CustomUITextField()
  
  // MARK: > bottomMessage
  var bottomMessage: String?{
    didSet{
      bottomLabel.text = bottomMessage
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.bottomLabel.alpha = self?.bottomMessage?.isEmpty == false ? 1.0 : 0.0
      }
    }
  }
  
  var placeholder: String?{
    didSet{
      textfield.attributedPlaceholder
        = NSAttributedString(string: placeholder ?? "",
                             attributes: [NSAttributedString.Key.foregroundColor: Const.SetColor.ForegroundLight.color])
    }
  }
  
  var text: String?{
    get {
      return self.textfield.text}
    set {
      self.textfield.text = newValue
    }
  }
  
  var topMessage: String?{
    didSet{
      topLabel.text = topMessage
      UIView.animate(seconds: 0.3) { [weak self] in
        self?.topLabel.alpha = self?.topMessage?.isEmpty == false ? 1.0 : 0.0
      }
    }
  }
  
  required init(text: String? = nil,
                font: UIFont = Const.Fonts.contentFont(size: Const.Size.DefaultFontSize)) {
    super.init(frame: .zero)
    
    self.axis = .vertical
    
    textfield.font = font
    textfield.textColor = Const.SetColor.CTDate.color
    
    topLabel.numberOfLines = 1
    topLabel.alpha = 0.0
    topLabel.font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
    self.topLabel.textColor = Const.SetColor.ForegroundLight.color
    
    bottomLabel.alpha = 0.0
    bottomLabel.numberOfLines = 1
    bottomLabel.font = Const.Fonts.contentFont(size: Const.Size.MiniPageNumberFontSize)
    bottomLabel.textColor = Const.SetColor.CIColor.color
    
    self.addArrangedSubview(topLabel)
    self.addArrangedSubview(textfield)
    self.addArrangedSubview(bottomLabel)
    
    textfield.text = text
    textfield.backgroundColor = .clear
  }
  
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class CustomUITextField:UITextField, KeyboardToolbarForText{
  lazy public var inputToolbar: UIToolbar = createToolbar()
  
  var container: UIView? { return self.superview?.superview}
}
