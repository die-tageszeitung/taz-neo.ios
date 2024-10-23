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
    if #available(iOS 15.0, *) {
      evaluateStoreFrontRegion()
      return false	
    } else if let storefront = SKPaymentQueue.default().storefront {
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
  
  var regionCode: String? = nil
  
  @available(iOS 15.0, *)
  private func evaluateStoreFrontRegion() {
      let semaphore = DispatchSemaphore(value: 0) // Semaphore to wait for async task completion
      Task {
          do {
              // Fetch the storefront using StoreKit's new API
              let storefront = await Storefront.current
              regionCode = storefront?.countryCode
          }
          semaphore.signal() // Signal that the async task is complete
      }
      
      // Wait for the async task to complete (timeout after 10 seconds to prevent deadlock)
    _ = semaphore.wait(timeout: .now() + 10)
    
    guard let regionCode = regionCode else { return }
    let storeMessage = handleEvaluation(for: regionCode) ? "eu store" : "non-eu store"
    log("Updating RegisterEvaluationResult for Store Region Code: \(regionCode) with result: \(storeMessage)")
  }
  
  
  /// Helper method to handle evaluation logic by checking if the region is in the EU.
  ///
  /// - Parameters:
  ///   - regionCode: The region code to evaluate.
  /// - Returns: `true` if the region is in the EU, otherwise `false`.
  private func handleEvaluation(for regionCode: String) -> Bool {
    if regionCode.length > 3 || regionCode.length < 2 {
      log("============== W A R N I N G =============")
      log("Wrong Region Code length for \(regionCode), expected 2 or 3 letters!")
      log("==========================================")
      return false
    }
    
    ///Countries from: https://support.apple.com/en-lb/118110 About alternative app distribution in the European Union > Eligible countries and regions
    let euCountriesAlpha2 = [
        "AT", // Austria
        "BE", // Belgium
        "BG", // Bulgaria
        "HR", // Croatia
        "CY", // Cyprus
        "CZ", // Czechia
        "DK", // Denmark
        "EE", // Estonia
        "FI", // Finland
        "AX", // Åland Islands
        "FR", // France
        "GF", // French Guiana
        "GP", // Guadeloupe
        "MQ", // Martinique
        "YT", // Mayotte
        "RE", // Reunion
        "MF", // Saint Martin
        "DE", // Germany
        "GR", // Greece
        "HU", // Hungary
        "IE", // Ireland
        "IT", // Italy
        "LV", // Latvia
        "LT", // Lithuania
        "LU", // Luxembourg
        "MT", // Malta
        "NL", // Netherlands
        "PL", // Poland
        "PT", // Portugal
        "RO", // Romania
        "SK", // Slovakia
        "SI", // Slovenia
        "ES", // Spain
        "SE"  // Sweden
    ]
    
    let euCountriesAlpha3 = [
      "AUT", //Austria
      "BEL", //Belgium
      "BGR", //Bulgaria
      "HRV", //Croatia
      "CYP", //Cyprus
      "CZE", //Czechia
      "DNK", //Denmark
      "EST", //Estonia
      "FIN", //Finland
      "ALA", //Åland Islands
      "FRA", //France
      "GUF", //French Guiana
      "GLP", //Guadeloupe
      "MTQ", //Martinique
      "MYT", //Mayotte
      "REU", //Reunion
      "MAF", //Saint Martin
      "DEU", //Germany
      "GRC", //Greece
      "HUN", //Hungary
      "IRL", //Ireland
      "ITA", //Italy
      "LVA", //Latvia
      "LTU", //Lithuania
      "LUX", //Luxembourg
      "MLT", //Malta
      "NLD", //Netherlands
      "POL", //Poland
      "PRT", //Portugal
      "ROU", //Romania
      "SVK", //Slovakia
      "SVN", //Slovenia
      "ESP", //Spain
      "SWE", //Sweden"
    ]
    let euCountries = regionCode.length == 3 ? euCountriesAlpha3 : euCountriesAlpha2
    
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
