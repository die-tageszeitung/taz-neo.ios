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
  
  init(onDoneHandler: @escaping (() -> ()), onCancelHandler: @escaping (() -> ())) {
    self.onDoneHandler = onDoneHandler
    self.onCancelHandler = onCancelHandler
    super.init(nibName: nil, bundle: nil)
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
    var yearIdicies : YearsAndInicies = YearsAndInicies(minimum: 0, minimumSelectable: 1980, maximum: 4020, maximumSelectable: 2020)
  
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
    
    if true {//Debug
      self.view.addBorder(UIColor.yellow.withAlphaComponent(0.3))
      picker.addBorder(.red)
      content.addBorder(UIColor.green.withAlphaComponent(0.3), 5)
    }
    
    self.picker.selectRow(3, inComponent: 0, animated: false)
    self.picker.selectRow(2018, inComponent: 1, animated: false)
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
        txtDatePicker.resignFirstResponder()
      }

      @objc func cancelDatePicker(){
        onCancelHandler()
       }
    
  var germanMonthNames : [String] = []
  
  
}

 // MARK: - UIPickerViewDelegate protocol
extension MonthPickerController {
  public func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
    var label = view as? UILabel
    if label == nil {
      label = UILabel()
      label?.textAlignment = .center
      label?.font = UIFont.preferredFont(forTextStyle: .headline)
    }
    label!.textColor = textColor
    if component == 0 {
      label!.text = "\(germanMonthNames.valueAt(row+1) ?? "")"
    }
    else if component == 1 {
      label!.textColor = yearIdicies.isValidIndex(row) ? textColor : UIColor.red
      label!.text = "\(yearIdicies.valueForIndex(row))"
    } else {
      label!.text = "*"
    }

    return label!
  }
  
  public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    self.selectionClosure?(row)
  }
}

// MARK: - UIPickerViewDataSource protocol
extension MonthPickerController{
   
  public func numberOfComponents(in pickerView: UIPickerView) -> Int { 2 }
  
  public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    if component == 0 {
      return 12
    }
    else if component == 1 {
      return yearIdicies.maximumIndex
    }
    return 0
  }
}

extension Array{
  func valueAt(_ index : Int) -> Any?{
    return self.indices.contains(index) ? self[index] : nil
  }
}

class YearsAndInicies {
  //    0            2               4            8
  let minimum, minimumSelectable, maximum, maximumSelectable : Int
  init(minimum: Int, minimumSelectable: Int, maximum: Int, maximumSelectable: Int){
    //TODO: ensure minimum < minimumSelectable < maximumSelectable < maximum
    self.minimum = minimum
    self.minimumSelectable = minimumSelectable
    self.maximum = maximum
    self.maximumSelectable = maximumSelectable
  }
  
  let minimumIndex : Int = 0
  var minimumSelectableIndex : Int { get { return minimumSelectable - minimum}}
  var maximumSelectableIndex : Int { get { return maximumSelectable - minimum}}
  var maximumIndex : Int { get { return maximum - minimum}}
  func valueForIndex(_ index : Int) -> Int { return index - minimum }
  func isValidIndex(_ index : Int) -> Bool { return minimumSelectableIndex ... maximumSelectableIndex ~= index }
}
