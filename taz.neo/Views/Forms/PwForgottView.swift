//
//
// PwForgottView.swift
//
// Created by Ringo Müller-Gromes on 14.08.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 
import UIKit
import NorthLib

public class PwForgottView : FormView{
  var idInput = TazTextField(placeholder: Localized("login_username_hint"),
                             textContentType: .emailAddress,
                             enablesReturnKeyAutomatically: true,
                             keyboardType: .emailAddress,
                             autocapitalizationType: .none)
  var submitButton =  Padded.Button(title: Localized("login_forgot_password_send"))
  var introLabel = Padded.Label(title: Localized("login_forgot_password_header"))
  
  override func createSubviews() -> [UIView] {
    let spacer = UIView()
    spacer.pinHeight(100)///quickfix: modally pushed Result Screen was too small
    return  [
      introLabel,
      idInput,
      submitButton,
      spacer
    ]
  }
}
