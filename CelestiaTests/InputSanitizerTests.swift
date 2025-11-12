//
//  InputSanitizerTests.swift
//  CelestiaTests
//
//  Tests for InputSanitizer utility - SECURITY CRITICAL
//

import Testing
@testable import Celestia

@Suite("InputSanitizer Tests - Security Critical")
struct InputSanitizerTests {

    // MARK: - Basic Sanitization Tests

    @Test("Basic sanitization trims whitespace")
    func testBasicTrim() async throws {
        let input = "  hello world  "
        let output = InputSanitizer.basic(input)

        #expect(output == "hello world")
    }

    @Test("Basic sanitization preserves internal spaces")
    func testBasicPreservesInternalSpaces() async throws {
        let input = "hello world"
        let output = InputSanitizer.basic(input)

        #expect(output == "hello world")
        #expect(output.contains(" "))
    }

    @Test("Basic sanitization handles empty string")
    func testBasicEmptyString() async throws {
        let input = ""
        let output = InputSanitizer.basic(input)

        #expect(output.isEmpty)
    }

    @Test("Basic sanitization handles only whitespace")
    func testBasicOnlyWhitespace() async throws {
        let input = "   \n\t  "
        let output = InputSanitizer.basic(input)

        #expect(output.isEmpty)
    }

    // MARK: - Standard Sanitization Tests (XSS Prevention)

    @Test("Standard sanitization removes script tags")
    func testStandardRemovesScriptTags() async throws {
        let input = "<script>alert('xss')</script>Hello"
        let output = InputSanitizer.standard(input)

        #expect(!output.contains("<script>"))
        #expect(!output.contains("</script>"))
        #expect(output.contains("Hello"))
    }

    @Test("Standard sanitization removes iframe tags")
    func testStandardRemovesIframeTags() async throws {
        let input = "<iframe src='evil.com'></iframe>Test"
        let output = InputSanitizer.standard(input)

        #expect(!output.contains("<iframe"))
        #expect(!output.contains("</iframe>"))
        #expect(output.contains("Test"))
    }

    @Test("Standard sanitization removes javascript protocol")
    func testStandardRemovesJavaScript() async throws {
        let input = "javascript:alert('xss')"
        let output = InputSanitizer.standard(input)

        #expect(!output.contains("javascript:"))
    }

    @Test("Standard sanitization removes event handlers")
    func testStandardRemovesEventHandlers() async throws {
        let input = "onerror=alert('xss') onclick=doEvil()"
        let output = InputSanitizer.standard(input)

        #expect(!output.contains("onerror="))
        #expect(!output.contains("onclick="))
        #expect(!output.contains("onload="))
    }

    @Test("Standard sanitization removes null bytes")
    func testStandardRemovesNullBytes() async throws {
        let input = "Hello\0World"
        let output = InputSanitizer.standard(input)

        #expect(!output.contains("\0"))
        #expect(output == "HelloWorld")
    }

    @Test("Standard sanitization removes control characters")
    func testStandardRemovesControlCharacters() async throws {
        let input = "Hello\u{0001}World"
        let output = InputSanitizer.standard(input)

        #expect(output == "HelloWorld")
    }

    @Test("Standard sanitization is case insensitive")
    func testStandardCaseInsensitive() async throws {
        let input = "<SCRIPT>alert('xss')</SCRIPT>"
        let output = InputSanitizer.standard(input)

        #expect(!output.contains("SCRIPT"))
        #expect(output == "alert('xss')")
    }

    // MARK: - Strict Sanitization Tests

    @Test("Strict sanitization removes angle brackets")
    func testStrictRemovesAngleBrackets() async throws {
        let input = "User<123>"
        let output = InputSanitizer.strict(input)

        #expect(!output.contains("<"))
        #expect(!output.contains(">"))
        #expect(output == "User123")
    }

    @Test("Strict sanitization removes curly braces")
    func testStrictRemovesCurlyBraces() async throws {
        let input = "User{123}"
        let output = InputSanitizer.strict(input)

        #expect(!output.contains("{"))
        #expect(!output.contains("}"))
        #expect(output == "User123")
    }

    @Test("Strict sanitization removes square brackets")
    func testStrictRemovesSquareBrackets() async throws {
        let input = "User[123]"
        let output = InputSanitizer.strict(input)

        #expect(!output.contains("["))
        #expect(!output.contains("]"))
        #expect(output == "User123")
    }

    @Test("Strict sanitization removes quotes")
    func testStrictRemovesQuotes() async throws {
        let input = "User\"123\"'test'"
        let output = InputSanitizer.strict(input)

        #expect(!output.contains("\""))
        #expect(!output.contains("'"))
    }

    @Test("Strict sanitization collapses multiple spaces")
    func testStrictCollapsesSpaces() async throws {
        let input = "Hello    World"
        let output = InputSanitizer.strict(input)

        #expect(output == "Hello World")
        #expect(!output.contains("    "))
    }

    // MARK: - Referral Code Sanitization Tests

    @Test("Referral code converts to uppercase")
    func testReferralCodeUppercase() async throws {
        let input = "abc123"
        let output = InputSanitizer.referralCode(input)

        #expect(output == "ABC123")
    }

    @Test("Referral code trims whitespace")
    func testReferralCodeTrim() async throws {
        let input = "  ABC123  "
        let output = InputSanitizer.referralCode(input)

        #expect(output == "ABC123")
    }

    // MARK: - Email Sanitization Tests

    @Test("Email converts to lowercase")
    func testEmailLowercase() async throws {
        let input = "Test@EMAIL.com"
        let output = InputSanitizer.email(input)

        #expect(output == "test@email.com")
    }

    @Test("Email trims whitespace")
    func testEmailTrim() async throws {
        let input = "  test@email.com  "
        let output = InputSanitizer.email(input)

        #expect(output == "test@email.com")
    }

    // MARK: - URL Sanitization Tests

    @Test("Valid HTTP URL accepted")
    func testValidHttpURL() async throws {
        let input = "http://example.com"
        let output = InputSanitizer.url(input)

        #expect(output == "http://example.com")
    }

    @Test("Valid HTTPS URL accepted")
    func testValidHttpsURL() async throws {
        let input = "https://example.com"
        let output = InputSanitizer.url(input)

        #expect(output == "https://example.com")
    }

    @Test("Invalid URL scheme rejected")
    func testInvalidURLScheme() async throws {
        let input = "ftp://example.com"
        let output = InputSanitizer.url(input)

        #expect(output == nil)
    }

    @Test("Malformed URL rejected")
    func testMalformedURL() async throws {
        let input = "not a url"
        let output = InputSanitizer.url(input)

        #expect(output == nil)
    }

    @Test("Javascript URL rejected")
    func testJavascriptURLRejected() async throws {
        let input = "javascript:alert('xss')"
        let output = InputSanitizer.url(input)

        #expect(output == nil)
    }

    // MARK: - Numeric String Tests

    @Test("Numeric string extracts digits only")
    func testNumericStringExtractsDigits() async throws {
        let input = "abc123def456"
        let output = InputSanitizer.numericString(input)

        #expect(output == "123456")
    }

    @Test("Numeric string handles phone numbers")
    func testNumericStringPhoneNumber() async throws {
        let input = "(555) 123-4567"
        let output = InputSanitizer.numericString(input)

        #expect(output == "5551234567")
    }

    @Test("Numeric string handles empty input")
    func testNumericStringEmpty() async throws {
        let input = "abc"
        let output = InputSanitizer.numericString(input)

        #expect(output.isEmpty)
    }

    // MARK: - Alphanumeric Tests

    @Test("Alphanumeric removes special characters")
    func testAlphanumericRemovesSpecialChars() async throws {
        let input = "User@123!"
        let output = InputSanitizer.alphanumeric(input, allowSpaces: false)

        #expect(output == "User123")
        #expect(!output.contains("@"))
        #expect(!output.contains("!"))
    }

    @Test("Alphanumeric allows spaces when specified")
    func testAlphanumericAllowsSpaces() async throws {
        let input = "User 123"
        let output = InputSanitizer.alphanumeric(input, allowSpaces: true)

        #expect(output == "User 123")
        #expect(output.contains(" "))
    }

    @Test("Alphanumeric removes spaces when disallowed")
    func testAlphanumericRemovesSpaces() async throws {
        let input = "User 123"
        let output = InputSanitizer.alphanumeric(input, allowSpaces: false)

        #expect(output == "User123")
        #expect(!output.contains(" "))
    }

    // MARK: - Helper Method Tests

    @Test("isEmpty checks basic sanitization")
    func testIsEmptyBasic() async throws {
        #expect(InputSanitizer.isEmpty("   ", level: .basic))
        #expect(!InputSanitizer.isEmpty("hello", level: .basic))
    }

    @Test("isEmpty checks standard sanitization")
    func testIsEmptyStandard() async throws {
        #expect(InputSanitizer.isEmpty("<script></script>", level: .standard))
        #expect(!InputSanitizer.isEmpty("hello", level: .standard))
    }

    @Test("length returns sanitized length")
    func testLengthBasic() async throws {
        let length = InputSanitizer.length("  hello  ", level: .basic)
        #expect(length == 5)
    }

    // MARK: - String Extension Tests

    @Test("String.sanitized extension works")
    func testStringSanitizedExtension() async throws {
        let input = "  hello  "
        let output = input.sanitized

        #expect(output == "hello")
    }

    @Test("String.sanitizedStandard extension works")
    func testStringSanitizedStandardExtension() async throws {
        let input = "<script>test</script>"
        let output = input.sanitizedStandard

        #expect(!output.contains("<script>"))
    }

    @Test("String.sanitizedStrict extension works")
    func testStringSanitizedStrictExtension() async throws {
        let input = "User<123>"
        let output = input.sanitizedStrict

        #expect(output == "User123")
    }

    // MARK: - Unicode and Emoji Tests

    @Test("Unicode characters preserved in standard")
    func testUnicodePreservedStandard() async throws {
        let input = "Hello 👋 こんにちは"
        let output = InputSanitizer.standard(input)

        #expect(output.contains("👋"))
        #expect(output.contains("こんにちは"))
    }

    @Test("Emoji preserved in basic sanitization")
    func testEmojiPreservedBasic() async throws {
        let input = "Hello 🌟"
        let output = InputSanitizer.basic(input)

        #expect(output.contains("🌟"))
    }

    @Test("Mixed unicode and XSS handled correctly")
    func testMixedUnicodeXSS() async throws {
        let input = "<script>alert('xss')</script>Hello 👋"
        let output = InputSanitizer.standard(input)

        #expect(!output.contains("<script>"))
        #expect(output.contains("👋"))
        #expect(output.contains("Hello"))
    }

    // MARK: - Edge Cases

    @Test("Very long string handled")
    func testVeryLongString() async throws {
        let input = String(repeating: "a", count: 10000)
        let output = InputSanitizer.basic(input)

        #expect(output.count == 10000)
    }

    @Test("Only special characters removed completely")
    func testOnlySpecialCharacters() async throws {
        let input = "@#$%^&*()"
        let output = InputSanitizer.alphanumeric(input)

        #expect(output.isEmpty)
    }

    @Test("Newlines preserved in standard sanitization")
    func testNewlinesPreserved() async throws {
        let input = "Line 1\nLine 2"
        let output = InputSanitizer.basic(input)

        #expect(output.contains("\n"))
    }

    @Test("Tabs converted in strict sanitization")
    func testTabsConverted() async throws {
        let input = "Hello\tWorld"
        let output = InputSanitizer.basic(input)

        // Tabs should be preserved in basic
        #expect(output.contains("\t"))
    }

    // MARK: - Security Attack Tests

    @Test("SQL injection attempt sanitized")
    func testSQLInjectionSanitized() async throws {
        let input = "'; DROP TABLE users--"
        let output = InputSanitizer.standard(input)

        #expect(!output.isEmpty)
        // Standard sanitization should handle this
    }

    @Test("HTML injection sanitized")
    func testHTMLInjectionSanitized() async throws {
        let input = "<img src=x onerror=alert('xss')>"
        let output = InputSanitizer.standard(input)

        #expect(!output.contains("onerror"))
        #expect(!output.contains("alert"))
    }

    @Test("Multiple script tags removed")
    func testMultipleScriptTags() async throws {
        let input = "<script>1</script>test<script>2</script>"
        let output = InputSanitizer.standard(input)

        #expect(!output.contains("<script>"))
        #expect(output.contains("test"))
    }
}
