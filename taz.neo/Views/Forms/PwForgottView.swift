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
  var idInput = TazTextField(placeholder: Localized("login_username_hint"))
  var submitButton =  Padded.PUIButton(title: Localized("login_forgot_password_send"))
  var cancelButton =  Padded.PUIButton(type:.outline, title: Localized("cancel_button"))
  var introLabel = Padded.PUILabel(title: Localized("login_forgot_password_header"))
  
  override func createSubviews() -> [UIView] {
    return  [
      TazHeader(),
      introLabel,
      idInput,
      submitButton,
      cancelButton
    ]
  }
}
