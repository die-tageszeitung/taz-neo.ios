//
//  MonthPicker.swift
//  taz.neo
//
//  Created by Ringo on 10.09.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import UIKit
import NorthLib


open class MonthPickerController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
  
  private var onCancelHandler: (() -> ())
  private var onDoneHandler: (() -> ())
  
    
    
    
    
    
  var initialSelectedDate : Date?
  
  public var selectedDate : Date {
    get {
      return DateComponents(calendar: Calendar.current,
                            year: self.picker.selectedRow(inComponent: 1) + data.minimumYear,
                            month: self.picker.selectedRow(inComponent: 0) + 1,
                            day: 1,
                            hour: 12).date
      ?? Date()
    }
  }
  
  init(onDoneHandler: @escaping (() -> ()), onCancelHandler: @escaping (() -> ()), minimumDate:Date, maximumDate:Date, selectedDate:Date) {
    self.onDoneHandler = onDoneHandler
    self.onCancelHandler = onCancelHandler
    initialSelectedDate = selectedDate
    data = DatePickerData(minimumDate: minimumDate, maximumDate: maximumDate)
    
    super.init(nibName: nil, bundle: nil)
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  let data : DatePickerData
  
  let picker = UIPickerView()
  let content = UIView()
  let applyButton = UIButton()
  
  open override func viewDidLoad() {
    picker.delegate = self
    picker.dataSource = self
//    picker.backgroundColor = UIColor.white.withAlphaComponent(0.8)
    germanMonthNames = Date.gMonthNames
     
    
    content.addSubview(picker)
    pin(picker.bottomGuide(), to: content.bottomGuide())
    pin(picker.topGuide(), to: content.topGuide())
    pin(picker.leftGuide(), to: content.leftGuide(), dist: 90)
    pin(picker.rightGuide(), to: content.rightGuide(), dist: -90)
    //checkmark
    //arrow.2.circlepath arrow.right.square.fill  chevron.right.2
    applyButton.setImage(UIImage(name: "arrow.2.circlepath"), for: .normal)
    applyButton.imageView?.tintColor = textColor
    
//    applyButton.setTitle("OK", for: .normal)
    applyButton.pinSize(CGSize(width: 24, height: 24))
//    applyButton.imageEdgeInsets = UIEdgeInsets(top: 3, left: 3, bottom: 3, right: 3)
//    applyButton.layer.cornerRadius = 3
    applyButton.backgroundColor = .clear
//    applyButton.setBackgroundColor(color: UIColor.white.withAlphaComponent(0.1), forState: .highlighted)
//    applyButton.addBorder(UIColor.white)
    applyButton.addTarget(self, action: #selector(donedatePicker), for: .touchUpInside)
    
    content.addSubview(applyButton)
    pin(picker.rightGuide(), to: applyButton.leftGuide(), dist: -10)
    pin(picker.centerY, to: applyButton.centerY)
        
    self.view.addSubview(content)
    
    pin(content.topGuide(), to: self.view.topGuide()).priority = .fittingSizeLevel
    content.pinHeight(181).priority = .required
    pin(content.bottomGuide(), to: self.view.bottomGuide())
    pin(content.leftGuide(), to: self.view.leftGuide())
    pin(content.rightGuide(), to: self.view.rightGuide())
    
    if let dateToSet = self.initialSelectedDate {
      self.setDate(dateToSet, animated: false)
      self.initialSelectedDate = nil //disable on re-use
    }
  }
  
    /// The currently selected index
    open var index: Int {
      get { return self.picker.selectedRow(inComponent: 0) }
      set { self.picker.selectRow(newValue, inComponent: 0, animated: false) }
    }
    
    /// The color to use for text
    open var textColor = UIColor.white
    
    // The closure to call upon selection
    var selectionClosure: ((Int)->())?
    
    /// Define the closure to call upon selection
    open func onSelection(closure: ((Int)->())?) { selectionClosure = closure }
    
   
    
    var txtDatePicker = UITextField()
       @objc func donedatePicker(){
        onDoneHandler()
      }

      @objc func cancelDatePicker(){
        onCancelHandler()
       }
    
  var germanMonthNames : [String] = []
  
  
}

 // MARK: - UIPickerViewDelegate protocol
extension MonthPickerController {
  
  public func selectedVal()->String{
    
    return "\(data.monthLabel(idx: self.picker.selectedRow(inComponent: 0))) - \(data.yearLabel(idx: self.picker.selectedRow(inComponent: 1)))"
    
  }
  
  public func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
    var label = view as? UILabel
    if label == nil {
      label = UILabel()
      label?.textAlignment = .center
      label?.font = UIFont.preferredFont(forTextStyle: .headline)
    }
    label!.textColor = textColor
    if component == 0 {
      label!.text = data.monthLabel(idx: row)
    }
    else if component == 1 {
      label!.text = data.yearLabel(idx: row)
      
    } else {
      label!.text = "*"
    }

    return label!
  }
  
  public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    UIView.animate(withDuration: 0.9) {
      self.applyButton.transform = self.applyButton.transform.rotated(by: CGFloat.pi)
      self.applyButton.transform = self.applyButton.transform.rotated(by: CGFloat.pi)
    }
    
    if self.selectedDate < self.data.minimumDate {
      self.setDate(self.data.minimumDate, animated : true)
      return;
    } else if self.selectedDate > self.data.maximumDate {
      self.setDate(self.data.maximumDate, animated : true)
      return;
    }
    
    self.selectionClosure?(row)
  }
  
  func setDate(_ date:Date, animated:Bool){
    self.picker.selectRow((date.components().month ?? 0) - 1, inComponent: 0, animated: animated)
    self.picker.selectRow((date.components().year ?? 0) - data.minimumYear, inComponent: 1, animated: animated)
  }
}

// MARK: - UIPickerViewDataSource protocol
extension MonthPickerController{
   
  public func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }
  
  public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    if component == 0 {
      return data.monthIniciesCount
    }
    else if component == 1 {
      return data.yearIniciesCount
    }
    return 0
  }
}

// MARK: - ext:MPC DatePickerData
/// Data Helper as inner class
extension MonthPickerController {
  class DatePickerData {
    
    var germanMonthNames : [String]
    let minimumDate : Date
    let maximumDate : Date
    let minimumYear : Int
    let monthIniciesCount : Int
    let yearIniciesCount : Int
    
    init(minimumDate : Date, maximumDate : Date) {
      self.minimumDate = minimumDate
      self.maximumDate = maximumDate
      
      germanMonthNames = Date.gMonthNames

      minimumYear = minimumDate.components().year ?? 0
      
      let intervall = Calendar.current.dateComponents([.month, .year], from: minimumDate, to: maximumDate)
      
      yearIniciesCount = 1 + (intervall.year ?? 0)
      monthIniciesCount = 12
    }

    func monthLabel(idx:Int) -> String {
      return "\(germanMonthNames.valueAt(idx+1) ?? "")"
    }
    
    func yearLabel(idx:Int) -> String {
      return "\(minimumYear + idx)"
    }
  }
}


extension Array{
  func valueAt(_ index : Int) -> Any?{
    return self.indices.contains(index) ? self[index] : nil
  }
}



/****************************************************************************

TODO's
 - Check done handlers
 - Cleanup
 - icons for ios 11/12
  - wert bereitstellen in Format Date() DONE
  - wenn Monat jahr überschreitet dann 2. Picker erhöhen erniedrigen!
      XXX Problematisch, da nur in view for row for component registriert wird, wann ein wechsel stattfindet, genaues datum fehlt aber
      XXX Kompliziert, da dies mit beiden Pickern implementiert werden muss
 ==> erstmal einfache Lösung!
 
 
 Ich möchte mit Dates arbeiten!
 
 DONE minimum month problem : erste Ausgabe ist 4/2010 spinner gibt 1/2010


****************************************************************************/
