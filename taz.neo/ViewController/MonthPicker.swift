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
  
  init(onDoneHandler: @escaping (() -> ()), onCancelHandler: @escaping (() -> ()), minimumDate:Date, maximumDate:Date, selectedDate:Date) {
    self.onDoneHandler = onDoneHandler
    self.onCancelHandler = onCancelHandler
    
    epoch = wtf(minimumDate: minimumDate, maximumDate: maximumDate, selectedDate: selectedDate)
    
    super.init(nibName: nil, bundle: nil)
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  let epoch : wtf
  
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
    
    applyButton.setTitle("OK", for: .normal)
    applyButton.pinSize(CGSize(width: 24, height: 24))
    applyButton.layer.cornerRadius = 12
    applyButton.addBorder(.white)
    applyButton.setBackgroundColor(color: .clear, forState: .normal)
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
    
    if false {//Debug
      self.view.addBorder(UIColor.yellow.withAlphaComponent(0.3))
      picker.addBorder(.red)
      content.addBorder(UIColor.green.withAlphaComponent(0.3), 5)
    }
    self.picker.selectRow((epoch.selectedDate.components().month ?? 0) - 1, inComponent: 0, animated: false)
    self.picker.selectRow((epoch.selectedDate.components().year ?? 0) - epoch.minimumYear, inComponent: 1, animated: false)
  }
  
  open var minimumDate = Date(timeIntervalSince1970: 0)
    open var maximumDate = Date()
    
    
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

  //      let formatter = DateFormatter()
  //      formatter.dateFormat = "dd/MM/yyyy"
  //      txtDatePicker.text = formatter.string(from: datePicker.date)
  //      self.endEditing(true)
//        txtDatePicker.resignFirstResponder()
      }

      @objc func cancelDatePicker(){
        onCancelHandler()
       }
    
  var germanMonthNames : [String] = []
  
  
}

 // MARK: - UIPickerViewDelegate protocol
extension MonthPickerController {
  
  public func selectedVal()->String{
    
    return "\(epoch.monthLabel(idx: self.picker.selectedRow(inComponent: 0))) - \(epoch.yearLabel(idx: self.picker.selectedRow(inComponent: 1)))"
    
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
      label!.text = epoch.monthLabel(idx: row)
      print("set lb txt: \(label!.text)")
    }
    else if component == 1 {
      label!.text = epoch.yearLabel(idx: row)
      
    } else {
      label!.text = "*"
    }

    return label!
  }
  
  public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    if component == 0 {
        print("idx: \(row%12)")
    }
    print("...sel")
    self.selectionClosure?(row)
  }
}

// MARK: - UIPickerViewDataSource protocol
extension MonthPickerController{
   
  public func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }
  
  public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    if component == 0 {
      return epoch.monthIniciesCount
    }
    else if component == 1 {
      return epoch.yearIniciesCount
    }
    return 0
  }
}

extension Array{
  func valueAt(_ index : Int) -> Any?{
    return self.indices.contains(index) ? self[index] : nil
  }
}



class wtf {
  
  var germanMonthNames : [String]
  
  let minimumDate : Date
  let maximumDate : Date
  let selectedDate : Date
  
  let minimumMonth : Int
  let minimumYear : Int
  let maximumMonth : Int
  let maximumYear : Int
  
  let monthIniciesCount : Int
  let yearIniciesCount : Int
  
  init(minimumDate : Date, maximumDate : Date, selectedDate : Date) {
    self.minimumDate = minimumDate
    self.maximumDate = maximumDate
    self.selectedDate = maximumDate
    
    germanMonthNames = Date.gMonthNames

    minimumMonth = minimumDate.components().month ?? 0
    minimumYear = minimumDate.components().year ?? 0
    
    maximumMonth = maximumDate.components().month ?? 0
    maximumYear = maximumDate.components().year ?? 0
    
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
/****************************************************************************

TODO's
  
  - wert bereitstellen in Format Date()
  - wenn Monat jahr überschreitet dann 2. Picker erhöhen erniedrigen!
      XXX Problematisch, da nur in view for row for component registriert wird, wann ein wechsel stattfindet, genaues datum fehlt aber
      XXX Kompliziert, da dies mit beiden Pickern implementiert werden muss
 ==> erstmal einfache Lösung!


****************************************************************************/
