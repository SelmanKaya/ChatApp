//
//  DatabaseManager.swift
//  ChatApp
//
//  Created by Selman Kaya on 9.01.2025.
//

import Foundation
import FirebaseDatabase
 
final class DatabaseManager{
    
    static let shared = DatabaseManager()
    
    private let database = Database.database(url: "https://chat-app-57a02-default-rtdb.europe-west1.firebasedatabase.app").reference()

   
}

    // MARK: - Account Mngmt
extension DatabaseManager {
    
    
    
    public func userExists(with email: String, completion: @escaping ((Bool) -> Void)){
        
        database.child(email).observeSingleEvent(of: .value, with: {snapshot in
            
            guard snapshot.value as? String != nil else {
                completion(false)
                return
            }
            
            completion(true)
        })
    }
    
    /// Insert new user to database
    public func insertUser(with user: ChatAppUser){
        database.child(user.emailAddress).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ])
    }
}
struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    //let profilePictureUrl: String
}
