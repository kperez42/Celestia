//
//  VerificationManagers.swift
//  Celestia
//
//  Manages verification data structures
//  NOTE: Face verification has been removed. ID verification is now manual review only.
//

import Foundation
import UIKit

// MARK: - Verification Results

enum DocumentType: String {
    case passport = "passport"
    case driversLicense = "drivers_license"
    case nationalID = "national_id"
    case stateID = "state_id"
    case other = "other"
}

// Note: BackgroundCheckManager is defined in BackgroundCheckManager.swift
