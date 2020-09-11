//
//  MonthPicker.swift
//  taz.neo
//
//  Created by Ringo on 10.09.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import UIKit


/**
 A Picker is a straight forward UIPickerView subclass intended to simplify
 UIPickerView usage. This implementation only supports one component.
 */
open class MonthPicker: UIPickerView, UIPickerViewDelegate, UIPickerViewDataSource {
  
  
  open var minimumDate = Date(timeIntervalSince1970: 0)
  open var maximumDate = Date()
  
  
  /// The currently selected index
  open var index: Int {
    get { return selectedRow(inComponent: 0) }
    set { selectRow(newValue, inComponent: 0, animated: false) }
  }
  
  /// The color to use for text
  open var textColor = UIColor.black
  
  // The closure to call upon selection
  var selectionClosure: ((Int)->())?
  
  /// Define the closure to call upon selection
  open func onSelection(closure: ((Int)->())?) { selectionClosure = closure }
  
  func setup() {
    delegate = self
    dataSource = self
    
    /*
      may use picker views 2 components
      https://stackoverflow.com/questions/44559014/how-to-hide-days-in-uidatepicker
      
      */
    //ToolBar
       let toolbar = UIToolbar();
       toolbar.sizeToFit()
       let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(donedatePicker));
       let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
      let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelDatePicker));

     toolbar.setItems([doneButton,spaceButton,cancelButton], animated: false)

      txtDatePicker.inputAccessoryView = toolbar
      txtDatePicker.inputView = self
    
    
  }
  
  var txtDatePicker = UITextField()
     @objc func donedatePicker(){

//      let formatter = DateFormatter()
//      formatter.dateFormat = "dd/MM/yyyy"
//      txtDatePicker.text = formatter.string(from: datePicker.date)
//      self.endEditing(true)
      txtDatePicker.resignFirstResponder()
    }

    @objc func cancelDatePicker(){
//       self.endEditing(true)
      txtDatePicker.resignFirstResponder()
     }
  
  var yearIdicies : YearsAndInicies
  let germanMonthNames : [String]
  
  //add to parentContaierView
  public init(targetView: UIView,
              selectedDate : Date = Date(),
              minimumDate : Date = Date(timeIntervalSince1970: 0),
              maximumDate : Date = Date()) {
    
    germanMonthNames = Date.gMonthNames
    let minYear = Calendar.current.dateComponents(Set(arrayLiteral: Calendar.Component.year), from: minimumDate).year ?? 0
    let maxYear = Calendar.current.dateComponents(Set(arrayLiteral: Calendar.Component.year), from: maximumDate).year ?? 0
    yearIdicies = YearsAndInicies(minimum: 0, minimumSelectable: minYear, maximum: maxYear, maximumSelectable: maxYear*2)
    super.init(frame: .zero)
    targetView.addSubview(txtDatePicker)
    self.showsSelectionIndicator = true
    setup()
    self.selectRow(3, inComponent: 0, animated: false)
    self.selectRow(2018, inComponent: 1, animated: false)
    self.backgroundColor = UIColor.red.withAlphaComponent(0.4)
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - UIPickerViewDataSource protocol
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
  
  // MARK: - UIPickerViewDelegate protocol
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
  
}
// Picker


extension Array{
  func valueAt(_ index : Int) -> Any?{
    return self.indices.contains(index) ? self[index] : nil
  }
}
