//
//  ConfigDefaults.swift
//
//  Created by Norbert Thies on 06.03.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/**
 Configuration variables and default values to store in Apple's UserDefaults
 */

public let ConfigDefaults = Defaults.Values([
  // shall text notifications be displayed on notification screen
  "isTextNotification" : "true", 
  // number of starts since installation
  "nStarted" : "0", 
  // last time app has been started (as UsTime)
  "lastStarted": "0", 
  // has our data policy been accepted
  "dataPolicyAccepted" : "false" 
])
