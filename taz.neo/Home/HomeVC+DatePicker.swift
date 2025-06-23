//
//  HomeVC+DatePicker.swift
//  taz.neo
//
//  Created by Ringo Müller on 23.06.25.
//  Copyright © 2025 taz. All rights reserved.
//

import UIKit
import NorthLib

extension HomeVC {
  func showDatePicker(sourceView: UIView){
    if pickerCtrl == nil {
      let selected = service.date(at: centerIndex ?? 0)?.date
      let isMonthly = service.feed.cycle == .monthly
      pickerCtrl = DatePickerController(minimumDate: service.firstIssueDate,
                                        maximumDate: service.lastIssueDate,
                                        selectedDate: selected ?? service.firstIssueDate,
                                        isMonthly: isMonthly)
      pickerCtrl?.pickerFont = Const.Fonts.contentFont
    }
    guard let pickerCtrl = pickerCtrl else { return }
    
    if overlay == nil {
      overlay = Overlay(overlay:pickerCtrl , into: self)
      overlay?.enablePinchAndPan = false
      overlay?.maxAlpha = 0.9
    }
    
    pickerCtrl.doneHandler = {[weak self] in
      guard let self else { return }
      let date = pickerCtrl.selectedDate
      let idx = self.service.nextIndex(for: date)
      #warning("todo")
//      self.scrollTo(idx, animated: true)
      self.overlay?.close(animated: true)
    }
    overlay?.onClose(closure: {  [weak self] in
      self?.overlay = nil
#warning("todo?")
//      (self?.parent as? HomeTVC)?.tilesController.isActive = true
      self?.pickerCtrl = nil
    })
    overlay?.openAnimated(fromView: sourceView, toView: pickerCtrl.content)
#warning("todo?")
//    (self.parent as? HomeTVC)?.tilesController.isActive = false
  }
}
