//
//  FeederContext+Polling.swift
//  taz.neo
//
//  Created by Ringo Müller on 07.08.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib
import UIKit

extension FeederContext {
  
  /// Ask Authenticator to poll server for authentication,
  /// send
  func doPolling(_ fetchCompletionHandler: FetchCompletionHandler? = nil) {
    ///prevent login with another acount
    if authenticator.feeder.authToken?.isEmpty == false {
      log("still logged in, prevent login with another acount")
      return
    }
    authenticator.pollSubscription { [weak self] doContinue in
      ///No matter if continue or not, iusually activate account takes more than 30s
      ///so its necessary to call push fetchCompletionHandler after first attempt
      fetchCompletionHandler?(.noData)
      guard let self = self else { return }
      guard let pollEnd = self.pollEnd else { self.endPolling(); return }
      if doContinue { if UsTime.now.sec > pollEnd { self.endPolling() } }
      else { self.endPolling() }
    }
  }
  
  
  /// Terminate polling
  public func endPolling() {
    if pollingTimer != nil {
      log("stop active polling")
    }
    self.pollingTimer?.invalidate()
    self.pollEnd = nil
    Defaults.singleton["pollEnd"] = nil
  }
  
  /// Start Polling if necessary
  public func setupPolling() {
    authenticator.whenPollingRequired { self.startPolling() }
    if let peStr = Defaults.singleton["pollEnd"]  {
      if self.isAuthenticated {
        endPolling()
        return
      }
      let pe = Int64(peStr)
      if pe! <= UsTime.now.sec { endPolling() }
      else {
        pollEnd = pe
        self.pollingTimer = Timer.scheduledTimer(withTimeInterval: 60.0,
          repeats: true) { _ in self.doPolling() }
      }
    }
  }

}
