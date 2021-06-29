//
//  OverlayTest.swift
//

import UIKit
import NorthLib

class OverlayTest: UIViewController, CanRotate {
  
  let container = UIView()
  let label = UILabel()
  
  lazy var pickerCtrl = DatePickerController(minimumDate: Date(),
                                              maximumDate: Date().addingTimeInterval(-20000),
                                     selectedDate: Date())
  
  lazy var overlay = Overlay(overlay:pickerCtrl , into: self)
  
  override func viewDidLoad() {
    super.viewDidLoad()
    label.text = "Hallo Test"
    _ = label.titleFont()
    container.addSubview(label)
    (label as UIView).center()//conflict with center labale
    self.view.addSubview(container)
    _ = pin(container, toSafe: self.view, dist: 20, exclude: .top)
    container.pinHeight(400)
    container.tag = 2
    self.view.tag = 1
    label.tag = 3
    label.backgroundColor = .yellow
    container.backgroundColor = .blue
    self.view.backgroundColor = .red
    label.onTapping {   [weak self] _ in
      guard let self = self else { return }
      
      print("Hallo")
      self.label.backgroundColor = self.label.backgroundColor == .yellow ? .orange : .yellow
      self.overlay.debug = true
      self.overlay.onRequestUpdatedCloseFrame {   [weak self] in
        guard let self = self else { return .zero}
        return self.view.getConvertedFrame(self.label) ?? .zero
      }
      self.overlay.openAnimated(fromView: self.label,
                                toView: self.pickerCtrl.content)
//      if let center = self.view.getConvertedCenter(self.label) {
//        self.pickerCtrl.center = center
//        let demoView = UIView(frame: CGRect(origin: center, size: CGSize(width: 20, height: 20)))
//              demoView.addBorder(.green)
//              demoView.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.4)
//              self.view.addSubview(demoView)
//      }
      
//      self.overlay.open(animated: false, fromBottom: false)

//      let fr = self.view.getConvertedFrame(self.label)
//      let demoView = UIView(frame: fr ?? CGRect(x: 10, y: 10, width: 20, height: 20))
//      demoView.addBorder(.green)
//      demoView.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.4)
//      self.view.addSubview(demoView)
      
    }
    
    overlay.enablePinchAndPan = false
    overlay.maxAlpha = 0.0
  }
}
