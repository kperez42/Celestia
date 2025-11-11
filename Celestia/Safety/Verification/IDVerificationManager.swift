//
//  IDVerificationManager.swift
//  Celestia
//
//  ID document verification using OCR and face matching
//  Supports driver's license, passport, national ID
//

import Foundation
import UIKit
import Vision
import VisionKit

// MARK: - ID Verification Manager

class IDVerificationManager {

    // MARK: - Singleton

    static let shared = IDVerificationManager()

    // MARK: - Initialization

    private init() {
        Logger.shared.info("IDVerificationManager initialized", category: .general)
    }

    // MARK: - Verification

    /// Verify ID document and compare with selfie
    func verifyID(idImage: UIImage, selfieImage: UIImage) async throws -> IDVerificationResult {
        Logger.shared.info("Starting ID verification", category: .general)

        // Step 1: Detect document type
        let documentType = try await detectDocumentType(idImage)
        Logger.shared.debug("Detected document type: \(documentType.rawValue)", category: .general)

        // Step 2: Extract text from ID using OCR
        let extractedText = try await extractText(from: idImage)
        Logger.shared.debug("Extracted \(extractedText.count) characters from ID", category: .general)

        // Step 3: Parse ID information
        let idInfo = parseIDInformation(from: extractedText, documentType: documentType)

        // Step 4: Validate ID information
        guard let idInfo = idInfo else {
            return IDVerificationResult(
                isVerified: false,
                documentType: documentType,
                extractedInfo: nil,
                failureReason: "Could not extract valid ID information"
            )
        }

        // Step 5: Verify age (must be 18+)
        let isAgeValid = verifyAge(dateOfBirth: idInfo.dateOfBirth)
        guard isAgeValid else {
            return IDVerificationResult(
                isVerified: false,
                documentType: documentType,
                extractedInfo: idInfo,
                failureReason: "User must be 18 or older"
            )
        }

        // Step 6: Detect face in ID photo
        guard let idFaceImage = try? await extractFaceFromID(idImage) else {
            return IDVerificationResult(
                isVerified: false,
                documentType: documentType,
                extractedInfo: idInfo,
                failureReason: "Could not detect face in ID photo"
            )
        }

        // Step 7: Compare ID face with selfie
        let faceMatchResult = try await PhotoVerificationManager.shared.verifySelfie(
            selfieImage,
            againstProfiles: [idFaceImage]
        )

        guard faceMatchResult.isVerified else {
            return IDVerificationResult(
                isVerified: false,
                documentType: documentType,
                extractedInfo: idInfo,
                failureReason: "Selfie does not match ID photo"
            )
        }

        // Success
        Logger.shared.info("ID verification successful", category: .general)

        return IDVerificationResult(
            isVerified: true,
            documentType: documentType,
            extractedInfo: idInfo,
            failureReason: nil
        )
    }

    // MARK: - Document Type Detection

    private func detectDocumentType(_ image: UIImage) async throws -> DocumentType {
        // Analyze image to determine document type
        // In production, use ML model or API for accurate detection

        let extractedText = try await extractText(from: image)

        if extractedText.contains("PASSPORT") || extractedText.contains("PASSEPORT") {
            return .passport
        } else if extractedText.contains("DRIVER") || extractedText.contains("LICENSE") {
            return .driversLicense
        } else {
            return .nationalID
        }
    }

    // MARK: - Text Extraction (OCR)

    private func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw VerificationError.invalidID
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                continuation.resume(returning: recognizedStrings.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Information Parsing

    private func parseIDInformation(from text: String, documentType: DocumentType) -> IDInformation? {
        // Parse extracted text to extract structured information
        // This is simplified - production would use sophisticated parsing

        var firstName: String?
        var lastName: String?
        var dateOfBirth: Date?
        var idNumber: String?

        let lines = text.components(separatedBy: .newlines)

        // Look for date of birth pattern (MM/DD/YYYY or DD/MM/YYYY)
        let datePattern = #"(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})"#
        if let match = text.range(of: datePattern, options: .regularExpression) {
            let dateString = String(text[match])
            dateOfBirth = parseDate(dateString)
        }

        // Look for ID number pattern
        let idPattern = #"[A-Z0-9]{8,}"#
        if let match = text.range(of: idPattern, options: .regularExpression) {
            idNumber = String(text[match])
        }

        // Extract names (simplified)
        for line in lines {
            if line.contains("NAME") || line.contains("GIVEN") {
                let components = line.components(separatedBy: .whitespaces)
                if components.count >= 2 {
                    firstName = components[1]
                }
            }
        }

        guard let dob = dateOfBirth else {
            return nil
        }

        return IDInformation(
            firstName: firstName ?? "Unknown",
            lastName: lastName ?? "Unknown",
            dateOfBirth: dob,
            idNumber: idNumber,
            documentType: documentType
        )
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"

        if let date = formatter.date(from: dateString) {
            return date
        }

        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.date(from: dateString)
    }

    // MARK: - Age Verification

    private func verifyAge(dateOfBirth: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()

        guard let age = calendar.dateComponents([.year], from: dateOfBirth, to: now).year else {
            return false
        }

        return age >= 18
    }

    // MARK: - Face Extraction

    private func extractFaceFromID(_ image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw VerificationError.invalidID
        }

        // Detect face in ID
        let faces = try await PhotoVerificationManager.shared.detectFaces(in: image)

        guard let face = faces.first else {
            throw VerificationError.faceNotDetected
        }

        // Crop face region
        let faceRect = VNImageRectForNormalizedRect(
            face.boundingBox,
            cgImage.width,
            cgImage.height
        )

        guard let faceCGImage = cgImage.cropping(to: faceRect) else {
            throw VerificationError.verificationFailed
        }

        return UIImage(cgImage: faceCGImage)
    }
}

// MARK: - Document Type

enum DocumentType: String, Codable {
    case driversLicense = "drivers_license"
    case passport = "passport"
    case nationalID = "national_id"
    case stateID = "state_id"

    var displayName: String {
        switch self {
        case .driversLicense:
            return "Driver's License"
        case .passport:
            return "Passport"
        case .nationalID:
            return "National ID"
        case .stateID:
            return "State ID"
        }
    }
}

// MARK: - ID Information

struct IDInformation: Codable {
    let firstName: String
    let lastName: String
    let dateOfBirth: Date
    let idNumber: String?
    let documentType: DocumentType

    var age: Int? {
        let calendar = Calendar.current
        let now = Date()
        return calendar.dateComponents([.year], from: dateOfBirth, to: now).year
    }
}

// MARK: - ID Verification Result

struct IDVerificationResult {
    let isVerified: Bool
    let documentType: DocumentType
    let extractedInfo: IDInformation?
    let failureReason: String?
}

// MARK: - Extension removed - detectFaces is already defined in PhotoVerificationManager
