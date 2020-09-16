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
  
  open override func viewDidLoad() {
    picker.delegate = self
    picker.dataSource = self
    picker.backgroundColor = UIColor.white.withAlphaComponent(0.8)
    germanMonthNames = Date.gMonthNames
     
    
    content.addSubview(picker)
    pin(picker.bottomGuide(), to: content.bottomGuide())
    pin(picker.leftGuide(), to: content.leftGuide())
    pin(picker.rightGuide(), to: content.rightGuide())
    
    let toolbar = UIToolbar();
    let doneButton = UIBarButtonItem(title: "Done",
                                     style: .plain,
                                     target: self,
                                     action: #selector(donedatePicker));
    let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                                      target: nil,
                                      action: nil)
    let cancelButton = UIBarButtonItem(title: "Cancel",
                                       style: .plain,
                                       target: self,
                                       action: #selector(cancelDatePicker));
    toolbar.setItems([cancelButton, spaceButton, doneButton], animated: false)
    content.addSubview(toolbar)
    pin(toolbar.topGuide(), to: content.topGuide())
    pin(toolbar.leftGuide(), to: content.leftGuide())
    pin(toolbar.rightGuide(), to: content.rightGuide())
    pin(toolbar.bottomGuide(), to: picker.topGuide())
    
    self.view.addSubview(content)
    pin(content.bottomGuide(), to: self.view.bottomGuide())
    pin(content.leftGuide(), to: self.view.leftGuide())
    pin(content.rightGuide(), to: self.view.rightGuide())
    
    if true {//Debug
      self.view.addBorder(UIColor.yellow.withAlphaComponent(0.3))
      toolbar.addBorder(.green)
      picker.addBorder(.red)
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
    open var textColor = UIColor.black
    
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
