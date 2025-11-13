//
//  DeepLinkManager.swift
//  Celestia
//
//  Manages deep linking for referral codes
//

import Foundation
import SwiftUI

@MainActor
class DeepLinkManager: ObservableObject {
    @Published var referralCode: String? = nil

    func clearReferralCode() {
        referralCode = nil
    }
}
