//
//  ContactService.swift
//  vibetalk
//
//  Created by 김동준 on 7/28/25.
//

import Foundation
import Contacts

import Contacts

final class ContactService {
    
    static let shared = ContactService()
    private init() {}
    
    func fetchContacts(completion: @escaping ([[String: String]]) -> Void) {
        let store = CNContactStore()
        
        store.requestAccess(for: .contacts) { granted, error in
            guard granted, error == nil else {
                print("❌ 연락처 접근 거부됨")
                completion([])
                return
            }
            
            var contactsArray: [[String: String]] = []
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
                completion(contactsArray)
            } catch {
                print("❌ 연락처 가져오기 실패: \(error)")
                completion([])
            }
        }
    }
}
