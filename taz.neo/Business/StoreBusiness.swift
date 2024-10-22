//
//  StoreBusiness.swift
//  taz.neo
//
//  Created by Ringo Müller on 22.10.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib
import StoreKit

/// The `StoreBusiness` class manages the business logic to determine
/// if registration is allowed for EU users
/// It checks the App Store storefront or alternatively  the device's locale region code to see
/// if the user is located in an EU country.
class StoreBusiness: DoesLog {
  
  // MARK: - Properties
  
  /// This property stores the evaluation result status.
  @Default("canRegisterEvaluationResult")
  private var canRegisterEvaluationResult: String
  
  ///currently StoreFront returns USA in Simulator, so to test Device Location use: Device.isSimulator == false
  private var evaluateStoreFront = Device.isSimulator == false
  
  /// Enum to represent possible evaluation results.
  private enum RegisterEvaluationResult: String, CodableEnum {
    case allowed = "allowed"
    case forbidden = "forbidden"
    case unknown = "unknown"
  }
  
  // MARK: - Singleton
  
  /// Shared singleton instance of the `StoreBusiness` class.
  private static let shared = StoreBusiness()
  
  /// Determines whether registration is allowed based on the stored evaluation result.
  /// If the stored value is `unknown` or not determinated, it will trigger the evaluation process.
  static var canRegister: Bool {
    switch shared.canRegisterEvaluationResult {
      case RegisterEvaluationResult.allowed.rawValue:
        return true
      case RegisterEvaluationResult.forbidden.rawValue:
        return false
      default:
        return shared.evaluate()
    }
  }
  
  // MARK: - Private Methods
  
  /// Evaluates whether registration is allowed based on the user's App Store country code
  /// or device's locale region code. It checks if the user is located in an EU country.
  ///
  /// - Returns: `true` if the user is in an EU country, otherwise `false`.
  private func evaluate() -> Bool {
    // First, attempt to get the App Store country code
    if evaluateStoreFront,
       let storefront = SKPaymentQueue.default().storefront {
      let regionCode = storefront.countryCode
      debug("App Store country code: \(regionCode)")
      return handleEvaluation(for: regionCode)
    }
    
    // Fall back to device's locale region if the store region can't be determined
    if let currentRegion = Locale.current.regionCode {
      debug("Device region code: \(currentRegion)")
      return handleEvaluation(for: currentRegion)
    }
    
    // Log an error if neither the App Store nor the device region can be determined
    log("Neither the App Store nor the device region can be determined.")
    canRegisterEvaluationResult = RegisterEvaluationResult.unknown.rawValue
    return false
  }
  
  /// Helper method to handle evaluation logic by checking if the region is in the EU.
  ///
  /// - Parameters:
  ///   - regionCode: The region code to evaluate.
  /// - Returns: `true` if the region is in the EU, otherwise `false`.
  private func handleEvaluation(for regionCode: String) -> Bool {
    let euCountries = ["AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE"]
    
    if euCountries.contains(regionCode) {
      debug("Region \(regionCode) is in the EU. Registration is allowed.")
      canRegisterEvaluationResult = RegisterEvaluationResult.allowed.rawValue
      return true
    } else {
      debug("Region \(regionCode) is not in the EU. Registration is forbidden.")
      canRegisterEvaluationResult = RegisterEvaluationResult.forbidden.rawValue
      return false
    }
  }
}
