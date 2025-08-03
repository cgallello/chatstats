import Foundation
import Contacts
import Combine

class ContactResolver: ObservableObject {
    private let store = CNContactStore()
    @Published private(set) var permissionGranted = false
    private var contactCache: [String: String] = [:]
    
    init() {}
    
    /// Explicitly request contacts permission. Calls completion with the result.
    func requestPermission(completion: @escaping (Bool) -> Void) {
        store.requestAccess(for: .contacts) { granted, error in
            DispatchQueue.main.async {
                self.permissionGranted = granted
                completion(granted)
            }
        }
    }
    
    /// Returns the full name for a given phone number or email, or nil if not found or permission denied.
    func name(for identifier: String) -> String? {
        // Check current authorization status instead of relying on stored flag
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .authorized else {
            return nil
        }
        
        // Check cache first
        if let cachedName = contactCache[identifier] {
            return cachedName == "NOT_FOUND" ? nil : cachedName
        }
        
        // Handle email addresses
        if identifier.contains("@") {
            if let name = findContactByEmail(identifier) {
                contactCache[identifier] = name
                return name
            }
            contactCache[identifier] = "NOT_FOUND"
            return nil
        }
        
        // Handle phone numbers
        guard isValidPhoneNumber(identifier) else {
            contactCache[identifier] = "NOT_FOUND"
            return nil
        }
        
        // Try different phone number formats
        let searchNumbers = generateSearchNumbers(for: identifier)
        
        for searchNumber in searchNumbers {
            if let name = findContactByPhoneNumber(searchNumber) {
                contactCache[identifier] = name
                return name
            }
        }
        
        // Cache the "not found" result to avoid repeated searches
        contactCache[identifier] = "NOT_FOUND"
        return nil
    }
    

    
    private func generateSearchNumbers(for phoneNumber: String) -> [String] {
        let normalized = normalizePhoneNumber(phoneNumber)
        var searchNumbers: [String] = [phoneNumber] // Original format
        
        // Add normalized version if different
        if normalized != phoneNumber {
            searchNumbers.append(normalized)
        }
        
        // Add +1 prefix for US numbers
        if normalized.count == 10 && !normalized.hasPrefix("+") {
            searchNumbers.append("+1\(normalized)")
        }
        
        // Remove +1 prefix if present
        if phoneNumber.hasPrefix("+1") && phoneNumber.count >= 11 {
            let without1 = String(phoneNumber.dropFirst(2))
            searchNumbers.append(without1)
        }
        
        return Array(Set(searchNumbers)) // Remove duplicates
    }
    
    private func findContactByEmail(_ email: String) -> String? {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactMiddleNameKey,
            CNContactEmailAddressesKey
        ] as [CNKeyDescriptor]

        do {
            let predicate = CNContact.predicateForContacts(matchingEmailAddress: email)
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            if let contact = contacts.first {
                let fullName = "\(contact.givenName) \(contact.middleName) \(contact.familyName)".replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
                return fullName.isEmpty ? nil : fullName
            }
        } catch {
            // Silently handle errors
        }
        return nil
    }
    
    private func findContactByPhoneNumber(_ phoneNumber: String) -> String? {
        // Validate phone number before creating predicate
        guard !phoneNumber.isEmpty else { return nil }
        
        // Create phone number object safely
        let cnPhoneNumber = CNPhoneNumber(stringValue: phoneNumber)
        
        let predicate = CNContact.predicateForContacts(matching: cnPhoneNumber)
        
        // Only request the properties we actually need to avoid warnings
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey, 
            CNContactMiddleNameKey,
            CNContactPhoneNumbersKey
        ] as [CNKeyDescriptor]
        
        do {
            let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            if let contact = contacts.first {
                // Build name from only the properties we requested
                let fullName = "\(contact.givenName) \(contact.middleName) \(contact.familyName)".replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
                return fullName.isEmpty ? nil : fullName
            }
        } catch {
            // Silently handle errors - they're usually just "not found" or invalid predicates
        }
        return nil
    }
    
    private func normalizePhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-digit characters
        let digits = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Handle different formats
        if digits.hasPrefix("1") && digits.count == 11 {
            // US number with country code, remove the 1
            return String(digits.dropFirst())
        } else if digits.count == 10 {
            // Standard US number
            return digits
        }
        
        return digits
    }
    
    private func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        // Basic validation to avoid invalid predicates
        let digits = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return digits.count >= 7 && digits.count <= 15 // Reasonable phone number length
    }
} 