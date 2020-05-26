//
//  ForgotPW.swift
//  taz.neo
//
//  Created by Nicolas Patzelt on 26.05.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit

class ForgotPwVC: UIViewController {
  
  var feeder: GqlFeeder!
  lazy var authenticator = Authentication(feeder: self.feeder)
  var returnclosure : ((Result<String,Error>)->())!
  
  @IBOutlet weak var topLabel: UILabel!
  @IBOutlet weak var emailTF: UITextField!
  @IBOutlet weak var sendButton: UIButton!
  @IBOutlet weak var cancelButton: UIButton!
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    sendButton.backgroundColor = TazRot
    cancelButton.backgroundColor = UIColor.darkGray
    sendButton.layer.cornerRadius = 5
    cancelButton.layer.cornerRadius = 5
  }
  
  @IBAction func sendButtonPressed(_ sender: UIButton) {
    if let id : String = emailTF.text,  !emailTF.text!.isEmpty {
      self.authenticator.resetPassword(id: id)
    }
  }
  @IBAction func cancelButtonPressed(_ sender: UIButton) {
    self.dismiss(animated: true, completion: nil )
  }

}
