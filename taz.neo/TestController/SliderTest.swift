//
//  SliderTest.swift
//
//  Created by Norbert Thies on 06.05.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class SliderTest: UIViewController {
  
  var textSettingsVC = TextSettingsVC()
  var viewLogger = Log.ViewLogger()
  var slider: BottomSheet!

  override func viewDidLoad() {
    super.viewDidLoad()
    let view = self.view!
    view.backgroundColor = .red
    view.addSubview(viewLogger.logView)
    viewLogger.logView.pinToView(view)
    Log.append(logger: viewLogger)
    Log.minLogLevel = .Debug
    slider = BottomSheet(slider: textSettingsVC, into: self)
    slider.color = .white
    slider.coverage = 160
    slider.handleColor = UIColor.gray
    viewLogger.logView.onTap {_ in
      self.slider.open()
    }
    Defaults.singleton.receive() { dnot in
      self.debug("Defaults Notification: key \(dnot.key), " +
        "value \(dnot.val ?? "none"), scope \(dnot.scope ?? "none")")
    }
    debug("test")
    slider.open()
  }

}
