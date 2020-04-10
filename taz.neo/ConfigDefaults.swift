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
  "isTextNotification" : "true", // shall text notifications be displayed on notification screen
  "nStarted" : "0",              // number of starts since installation
  "lastStarted": "0",            // last time app has been started (as UsTime)
])
