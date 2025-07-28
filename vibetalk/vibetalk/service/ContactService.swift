//
//  ContactService.swift
//  vibetalk
//
//  Created by 김동준 on 7/28/25.
//

import Foundation
import Contacts

final class ContactService {
    
    static let shared = ContactService()
    private init() {}
    
    func fetchContacts() -> [[String: String]] {
        let store = CNContactStore()
        var contactsArray: [[String: String]] = []
        
        store.requestAccess(for: .contacts) { granted, error in
            if !granted {
                print("❌ 연락처 접근 권한 거부")
            }
        }
        
        let keys = [CNContactPhoneNumbersKey, CNContactGivenNameKey, CNContactFamilyNameKey]
        let request = CNContactFetchRequest(keysToFetch: keys as [CNKeyDescriptor])
        
        do {
            try store.enumerateContacts(with: request) { contact, stop in
                for number in contact.phoneNumbers {
                    let phone = number.value.stringValue
                        .replacingOccurrences(of: "-", with: "")
                        .replacingOccurrences(of: " ", with: "")
                    let fullName = "\(contact.familyName) \(contact.givenName)".trimmingCharacters(in: .whitespaces)
                    contactsArray.append([
                        "phoneNumber": phone,
                        "contactName": fullName
                    ])
                }
            }
        } catch {
            print("❌ 연락처 가져오기 실패: \(error)")
        }
        return contactsArray
    }
}
