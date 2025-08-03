//
//  Contact.swift
//  chatstats
//
//  Created by Christopher Gallello on 7/18/25.
//

import Foundation
import SwiftData

@Model
final class Contact {
    var firstName: String
    var lastName: String
    var phoneNumbers: String // Store as comma-separated string
    var emails: String // Store as comma-separated string
    var recordId: String
    
    init(firstName: String, lastName: String, phoneNumbers: [String], emails: [String], recordId: String) {
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumbers = phoneNumbers.joined(separator: ",")
        self.emails = emails.joined(separator: ",")
        self.recordId = recordId
    }
    
    var fullName: String {
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Unknown Contact" : name
    }
    
    var phoneNumbersArray: [String] {
        return phoneNumbers.isEmpty ? [] : phoneNumbers.components(separatedBy: ",")
    }
    
    var emailsArray: [String] {
        return emails.isEmpty ? [] : emails.components(separatedBy: ",")
    }
} 