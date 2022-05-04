//
//  SearchSettingsVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 28.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib
import SwiftUI

class SearchSettingsVC: UITableViewController {
  
  var finishedClosure: ((Bool)->())?
  
  
  lazy var header:HeaderActionBar = {
    let h = HeaderActionBar()
    h.leftButton.onTapping {[weak self] _ in
      self?.dismiss(animated: true, completion: {[weak self] in
//        self?.restoreInitialState()
        self?.finishedClosure?(false)
      })
    }
    h.rightButton.onTapping {[weak self] _ in
      self?.dismiss(animated: true, completion: {[weak self] in
        self?.finishedClosure?(true)
      })
    }
    return h
  }()
  
  
  
  var viewWidthConstraint: NSLayoutConstraint?
  
}

class HeaderActionBar: UIStackView {
  
  public lazy var leftButton: UIButton = {
    let btn = UIButton()
    btn.translatesAutoresizingMaskIntoConstraints = false
    btn.setTitle("Zurücksetzen", for: .normal)
    btn.titleLabel?.font = Const.Fonts.contentFont
    btn.setTitleColor(Const.SetColor.ios(.label).color, for: .normal)
    return btn
  }()
  
  public lazy var rightButton: UIButton = {
    let btn = UIButton()
    btn.translatesAutoresizingMaskIntoConstraints = false
    btn.setTitleColor(Const.SetColor.ios(.label).color, for: .normal)
    btn.setTitle("Suchen", for: .normal)
    btn.titleLabel?.font = Const.Fonts.contentFont
    btn.titleLabel?.textColor = .red
    return btn
  }()
  
  public lazy var label: UILabel = {
    let lbl = UILabel().boldContentFont()
    lbl.textColor = .black
    lbl.numberOfLines = 0
    lbl.textAlignment = .center
    lbl.text = "Suchoptionen"
    return lbl
  }()
  
  
}







