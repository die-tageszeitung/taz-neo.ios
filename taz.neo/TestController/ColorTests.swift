//
//  ColorTests.swift
//
//  Created by Norbert Thies on 04.06.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

@available(iOS 13.0, *)
class ColorData: ToString {
  var name: String
  var text: String?
  var light: UIColor
  var dark: UIColor
  
  static var darkMode = UITraitCollection(userInterfaceStyle: .dark)
  static var lightMode = UITraitCollection(userInterfaceStyle: .light)
  
  init(name: String, color: UIColor, text: String? = nil) {
    self.name = name
    self.light = color.resolvedColor(with: ColorData.lightMode)
    self.dark = color.resolvedColor(with: ColorData.darkMode)
    self.text = text
  }
  
  func toString() -> String {
    let str = "\(name): light(\(light.toString())), dark(\(dark.toString()))"
    if let txt = text { return str + "\n  \(txt)" }
    else { return str }
  }
}

// A view controller to test Colors
class ColorTests: UIViewController {
  
  @available(iOS 13.0, *)
  func printColors() {
    print(ColorData(name: "label", color: UIColor.label, 
                    text: "The color for text labels that contain primary content"))
    print(ColorData(name: "secondaryLabel", color: UIColor.secondaryLabel, 
                    text: "The color for text labels that contain secondary content"))
    print(ColorData(name: "tertiaryLabel", color: UIColor.tertiaryLabel, 
                    text: "The color for text labels that contain tertiary content"))
    print(ColorData(name: "quaternaryLabel", color: UIColor.quaternaryLabel, 
                    text: "The color for text labels that contain quaternary content"))
    print(ColorData(name: "systemFill", color: UIColor.systemFill, 
                    text: "An overlay fill color for thin and small shapes"))
    print(ColorData(name: "secondarySystemFill", color: UIColor.secondarySystemFill, 
                    text: "An overlay fill color for medium-size shapes"))
    print(ColorData(name: "tertiarySystemFill", color: UIColor.tertiarySystemFill, 
                    text: "An overlay fill color for large shapes"))
    print(ColorData(name: "quaternarySystemFill", color: UIColor.quaternarySystemFill, 
                    text: "An overlay fill color for large areas that contain complex content"))
    print(ColorData(name: "placeholderText", color: UIColor.placeholderText, 
                    text: "The color for placeholder text in controls or text views"))
    print(ColorData(name: "systemBackground", color: UIColor.systemBackground, 
                    text: "The color for the main background of your interface"))
    print(ColorData(name: "secondarySystemBackground", color: UIColor.secondarySystemBackground, 
                    text: "The color for content layered on top of the main background"))
    print(ColorData(name: "tertiarySystemBackground", color: UIColor.tertiarySystemBackground, 
                    text: "The color for content layered on top of secondary backgrounds"))
    print(ColorData(name: "systemGroupedBackground", color: UIColor.systemGroupedBackground, 
                    text: "The color for the main background of your grouped interface"))
    print(ColorData(name: "secondarySystemGroupedBackground", color: UIColor.secondarySystemGroupedBackground, 
                    text: "The color for content layered on top of the main background of your grouped interface"))
    print(ColorData(name: "tertiarySystemGroupedBackground", color: UIColor.tertiarySystemGroupedBackground, 
                    text: "The color for content layered on top of secondary backgrounds of your grouped interface"))
    print(ColorData(name: "separator", color: UIColor.separator, 
                    text: "The color for thin borders or divider lines that allows some underlying content to be visible"))
    print(ColorData(name: "opaqueSeparator", color: UIColor.opaqueSeparator, 
                    text: "The color for borders or divider lines that hides any underlying content"))
    print(ColorData(name: "link", color: UIColor.link, 
                    text: "The color for links"))
    print(ColorData(name: "darkText", color: UIColor.darkText, 
                    text: "The nonadaptable system color for text on a light background"))
    print(ColorData(name: "lightText", color: UIColor.lightText, 
                    text: "The nonadaptable system color for text on a dark background"))
    print(ColorData(name: "tintColor", color: self.view.tintColor, 
                    text: "The tint color to apply to the button title and image"))
  }
  
  override func viewDidLoad() {
    if #available(iOS 13.0, *) {
      printColors()
    } else {
      print("iOS 13 needed.")
    }
  }

} // ColorTests

