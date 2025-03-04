//
//  DatabaseManager.swift
//  ChatApp
//
//  Created by Selman Kaya on 9.01.2025.
//

import Foundation
import FirebaseDatabase
import MessageKit
import UIKit
import CoreLocation
 
/// Manager object to read and write data to real time firebase database
final class DatabaseManager{
    
    public static let shared = DatabaseManager()
    
    private let database = Database.database(url: "https://chat-app-57a02-default-rtdb.europe-west1.firebasedatabase.app").reference()

    private init() {}
    
    static func safeEmail(emailAddress: String) -> String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")

        return safeEmail
    }
   
}
extension DatabaseManager{
    public func getDataFor(path: String, completion: @escaping(Result<Any,Error>) -> Void){
        database.child("\(path)").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
}

    // MARK: - Account Mngmt
extension DatabaseManager {
    
    
    public func userExists(with email: String,
                           completion: @escaping ((Bool) -> Void)) {
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.value as? [String: Any] != nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }

    
    /// Insert new user to database
    public func insertUser(with user: ChatAppUser , completion: @escaping ((Bool) -> Void)){
        database.child(user.safeEmail).setValue([
            "first_name": user.firstName,
            "last_name": user.lastName
        ], withCompletionBlock:{[weak self] error , _ in
            
            guard let strongSelf = self else {
                return
            }
            
            guard error == nil else{
                print("failed to write to database")
                completion(false)
                return
            }
            
            strongSelf.database.child("users").observeSingleEvent(of: .value, with: {snapshot in
                if var usersCollection = snapshot.value as? [[String: String]] {
                    //append to user dictionary
                    let newElement =  [
                        "name": user.firstName + " " + user.lastName,
                        "email": user.emailAddress
                    ]
                    usersCollection.append(newElement)
                    strongSelf.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        completion(true)
                        
                    })
                    
                }
                else{
                    //create that array
                    let newCollection: [[String: String]] = [
                        [
                            "name": user.firstName+" "+user.lastName,
                            "email": user.emailAddress
                        ]
                        
                    ]
                    strongSelf.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        completion(true)
                        
                    })
                }
            })
            
            completion(true)
        })
    }
    
    
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void){
        database.child("users").observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    public enum DatabaseError: Error{
        case failedToFetch
        
    }
    
}

// MARK: - Sending messages / Conversations
extension DatabaseManager {
    
    ///creates a new conversation with target use email and first message sent
    public func createNewConversation(with otherUserEmail: String,name: String, firstMessage: Message, completion : @escaping (Bool) -> Void){
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
        let currentName = UserDefaults.standard.value(forKey: "name") as? String else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        let ref = database.child("\(safeEmail)")
        ref.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else{
                completion(false)
                print("User not found")
                return
            }
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            switch firstMessage.kind{
            case.text(let messageText):
                message = messageText
            case.attributedText(_):
                break
            case.photo(_):
                break
            case.video(_):
                break
            case.location(_):
                break
            case.emoji(_):
                break
            case.audio(_):
                break
            case.contact(_):
                break
            case.custom(_):
                break
            case .linkPreview(_):
                break
            }
            
            let conversationId = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String: Any] = [
                "id" : conversationId,
                "other_user_email": otherUserEmail,
                "name":name,
                "latest_message": [
                    "date" : dateString,
                    "message" : message,
                    "is_read": false
                ]
                
            ]
            
            let recipient_newConversationData: [String: Any] = [
                "id" : conversationId,
                "other_user_email": safeEmail,
                "name":currentName,
                "latest_message": [
                    "date" : dateString,
                    "message" : message,
                    "is_read": false
                ]
                
            ]
            //update recipient conversation entry
            let safeOtherUserEmail = DatabaseManager.safeEmail(emailAddress: otherUserEmail)
            self?.database.child("\(safeOtherUserEmail)/conversations").observeSingleEvent(of: .value, with: {[weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]]{
                    //append
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(safeOtherUserEmail)/conversations").setValue(conversations)

                }else {
                    //create
                    self?.database.child("\(safeOtherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            })

            
            // Update current user conversation entry
            if var conversations = userNode["conversations"] as? [[String: Any]]{
                //cnversation array exists for current user
                
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                ref.setValue(userNode, withCompletionBlock: {[weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    
                    self?.finishCreatingConversation(name: name, conversationID: conversationId, firstMessage: firstMessage, completion: completion)

                })
                
            }else {
                //conversation array dosnt exist
                userNode["conversations"] = [
                    newConversationData
                ]
                
                ref.setValue(userNode, withCompletionBlock: {[weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    
                    self?.finishCreatingConversation(name: name,conversationID: conversationId, firstMessage: firstMessage, completion: completion)
                    completion(true)
                })
            }
        })
    }
    
    private func finishCreatingConversation(name: String,conversationID : String, firstMessage: Message, completion: @escaping (Bool) -> Void){
//        {
//            "id": String,
//            "type":text,photo,videos,
//            "content": String,
//            "sender_email": String,
//            "isRead" : true/false
//        }
        
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        
        
        var message = ""
        switch firstMessage.kind{
        case.text(let messageText):
            message = messageText
        case.attributedText(_):
            break
        case.photo(_):
            break
        case.video(_):
            break
        case.location(_):
            break
        case.emoji(_):
            break
        case.audio(_):
            break
        case.contact(_):
            break
        case.custom(_):
            break
        case .linkPreview(_):
            break
        }
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        let collectionMessage: [String:Any]=[
            "id": firstMessage.messageId,
            "type":firstMessage.kind.messageKindString,
            "content":message,
            "date":dateString,
            "sender_email": currentUserEmail,
            "isRead":false,
            "name": name
        ]
        
        let value : [String:Any] = [
            "messages":[
                collectionMessage
            ]
        ]
        print("adding convo : \(conversationID)")
        database.child("\(conversationID)").setValue(value, withCompletionBlock: {error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    ///fetches and returns all conversations for the user with passed in email
    public func getAllConversations(for email: String,completion: @escaping(Result<[Conversation],Error>) -> Void){
        database.child("\(email)/conversations").observe(.value,with: { snapshot in
            guard let value = snapshot.value as? [[String:Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let conversations: [Conversation] = value.compactMap { (dictionary: [String: Any]) -> Conversation? in
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else {
                    return nil
                }

                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)

                return Conversation(
                    id: conversationId,
                    name: name,
                    otherUserEmail: otherUserEmail,
                    latestMessage: latestMessageObject)
            }
            completion(.success(conversations))
        })
    }
    /// Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id: String , completion: @escaping(Result<[Message],Error>) -> Void){
        database.child("\(id)/messages").observe(.value,with: { snapshot in
            guard let value = snapshot.value as? [[String:Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap { (dictionary: [String: Any]) -> Message? in
                
                guard let name = dictionary["name"] as? String,
                      //let isRead = dictionary["is_read"] as? Bool,
                      let messageId = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString)

                else{
                    return nil
                }
                
                var kind: MessageKind?
                if type == "photo" {
                    //photo
                    guard let imageUrl = URL(string: content),
                          let placeholder = UIImage(systemName: "plus")  else {
                        return nil
                    }
                    let media = Media(url: imageUrl,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 300, height: 300))
                    
                    kind = .photo(media)
                }
                else if type == "video" {
                    //photo
                    guard let videoUrl = URL(string: content),
                          let placeholder = UIImage(named: "video_placeholder") else {
                        return nil
                    }
                    let media = Media(url: videoUrl,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: CGSize(width: 300, height: 300))
                    
                    kind = .video(media)
                }
                else if type == "location" {
                    //photo
                    let locationComponents = content.components(separatedBy: ",")
                    guard let longitude = Double(locationComponents[0]),
                          let latitude = Double(locationComponents[1]) else{
                        return nil
                    }
                    
                    
                    
                    let location = Location(location: CLLocation(latitude: latitude, longitude: longitude),
                                            size: CGSize(width: 300, height: 300))
                    
                    kind = .location(location)
                }
                else if type == "file" {
                    // Dosya mesajı (PDF, Word, ZIP vs.)
                    guard let fileUrl = URL(string: content) else {
                        return nil
                    }
                    let filePlaceholder = UIImage(systemName: "doc.fill")!
                    kind = .custom(["url": fileUrl.absoluteString, "thumbnail": filePlaceholder])

                }
                
                else{
                    kind = .text(content)
                }
                guard let finalKind = kind else {
                    return nil
                }
                
                let sender = Sender(senderId: senderEmail,
                                    photoURL: "",
                                    displayName: name)
                
                return Message(sender: sender,
                               messageId: messageId,
                               sentDate: date,
                               kind: finalKind)
            }
            completion(.success(messages))
        })
    }
                                                 
    
    ///Sends a message with target conversation and message
    public func sendMessage(to conversation :String,otherUserEmail: String, name: String, newMessage: Message, completion: @escaping(Bool) -> Void){
        // add new message to messages
        //update sender latest message
        //update recipient latest message
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
        }
        let currentEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        
        database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: {[weak self] snapshot in
            guard let strongSelf = self else { return }
            
            guard var currentMessages = snapshot.value as? [[String:Any]] else{
                completion(false)
                return
                
            }
            let messageDate = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            
            var message = ""
            switch newMessage.kind{
            case.text(let messageText):
                message = messageText
            case.attributedText(_):
                break
            case.photo(let mediaItem):
                if let targetUrl = mediaItem.url?.absoluteString{
                    message = targetUrl
                }
                
                break
            case.video(let mediaItem):
                if let targetUrl = mediaItem.url?.absoluteString{
                    message = targetUrl
                }
                break
            case.location(let locationData):
                let location = locationData.location
                message = "\(location.coordinate.longitude),\(location.coordinate.latitude)"
                break
            case.emoji(_):
                break
            case.audio(_):
                break
            case.contact(_):
                break
            case .custom(let customData):
                if let fileURL = customData as? String {
                    message = fileURL
                }
                break
            case .linkPreview(_):
                break
            }
            guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
                completion(false)
                return
            }
            let currentUserEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
            
            let newMessageEntry: [String:Any]=[
                "id": newMessage.messageId,
                "type":newMessage.kind.messageKindString,
                "content":message,
                "date":dateString,
                "sender_email": currentUserEmail,
                "isRead":false,
                "name": name
            ]
            
            currentMessages.append(newMessageEntry)
            
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages){error, _ in
                guard error == nil else{
                    completion(false)
                    return
                }
                
                strongSelf.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    var databaseEntryConversations = [[String: Any]]()
                    let updatedValue: [String: Any] = [
                        "date": dateString,
                        "is_read": false,
                        "message": message
                    ]
                    if var currentUserConversations = snapshot.value as? [[String:Any]]  {
                            // we need to create conversation entry
                            var targetConversation: [String: Any]?
                            var position = 0
                        
                            for conversationDictionary in currentUserConversations {
                                if let currentId = conversationDictionary["id"] as? String, currentId == conversation {
                                    targetConversation = conversationDictionary
                                    break
                                }
                                position += 1
                            }
                        
                        if var targetConversation = targetConversation{
                            targetConversation["latest_message"] = updatedValue
                            currentUserConversations[position] = targetConversation
                            databaseEntryConversations = currentUserConversations
                    
                        }
                        else{
                            let newConversationData: [String: Any] = [
                                "id" : conversation,
                                "other_user_email": DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                                "name":name,
                                "latest_message": updatedValue
                                
                            ]
                            currentUserConversations.append(newConversationData)
                            databaseEntryConversations = currentUserConversations
                        }
                    }
                    else{
                        let newConversationData: [String: Any] = [
                            "id" : conversation,
                            "other_user_email": DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                            "name":name,
                            "latest_message": updatedValue
                            
                        ]
                        databaseEntryConversations = [
                            newConversationData
                        ]
                    }
                    
                    
                    strongSelf.database.child("\(currentEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: {eror , _ in
                        guard error == nil else{
                            completion(false)
                            return
                        }
                        
                        //update latest message for recipient user
                        let safeOtherUserEmail = DatabaseManager.safeEmail(emailAddress: otherUserEmail)
                        strongSelf.database.child("\(safeOtherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                            let updatedValue: [String: Any] = [
                                "date": dateString,
                                "is_read": false,
                                "message": message
                            ]
                            var databaseEntryConversations: [[String: Any]] = []
                            
                            guard let currentName = UserDefaults.standard.value(forKey: "name") as? String else{
                                return
                            }
                            
                            if var otherUserConversations = snapshot.value as? [[String:Any]] {
                                var targetConversation: [String: Any]?
                                
                                var position = 0
                                for conversationDictionary in otherUserConversations {
                                    if let currentId = conversationDictionary["id"] as? String, currentId == conversation {
                                        targetConversation = conversationDictionary
                                        break
                                    }
                                    position += 1
                                }
                                
                                if var targetConversation = targetConversation{
                                    targetConversation["latest_message"] = updatedValue

                                    
                                    otherUserConversations[position] = targetConversation
                                    databaseEntryConversations = otherUserConversations
                                }
                                else{
                                    // failed to find in current collection
                                    let newConversationData: [String: Any] = [
                                        "id" : conversation,
                                        "other_user_email": DatabaseManager.safeEmail(emailAddress: otherUserEmail),
                                        "name":currentName,
                                        "latest_message": updatedValue
                                        
                                    ]
                                    otherUserConversations.append(newConversationData)
                                    databaseEntryConversations = otherUserConversations
                                }
                                
                                }
                                else {
                                    // current collection doesnt exist
                                    let newConversationData: [String: Any] = [
                                        "id" : conversation,
                                        "other_user_email": DatabaseManager.safeEmail(emailAddress: currentEmail),
                                        "name":currentName,
                                        "latest_message": updatedValue
                                        
                                    ]
                                    databaseEntryConversations = [
                                        newConversationData
                                    ]
                                }
                            
                            strongSelf.database.child("\(safeOtherUserEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: {eror , _ in
                                guard error == nil else{
                                    completion(false)
                                    return
                                }
                                completion(true)
                                
                            })
                            
                        })
                        
                        
                        completion(true)
                        
                    })
                    
                })
                
                completion(true)
                
            }
        })
        
    }
    
    public func deleteConversation(conversationId: String, completion: @escaping (Bool) -> Void){
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        print("Deleting conversation with id: \(conversationId)")
        
        //get all conversations for current user
        
        // delete conversation in collection with target id
        
        // reset those conversations for the user in database
        let ref = database.child("\(safeEmail)/conversations")
        ref.observeSingleEvent(of: .value) { snapshot in
            if var conversations = snapshot.value as? [[String:Any]]{
                var positionToRemove = 0
                for conversation in conversations{
                    if let id = conversation["id"] as? String,
                       id == conversationId{
                        print("found conversation to delete")

                        break
                    }
                    positionToRemove += 1
                }
                
                conversations.remove(at: positionToRemove)
                ref.setValue(conversations, withCompletionBlock: {error, _ in
                    guard error == nil else{
                        completion(false)
                        print("failed to write new conversation array")
                        return
                    }
                    print("deleted conversation")
                    completion(true)
                })
            }
        }
    }
    func conversationExist(with targetRecipientEmail: String , completion: @escaping (Result<String, Error>) -> Void){
        let safeRecipientEmail = DatabaseManager.safeEmail(emailAddress: targetRecipientEmail)
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return
        }
        let safeSenderEmail = DatabaseManager.safeEmail(emailAddress: senderEmail)
        database.child("\(safeRecipientEmail)/conversations").observeSingleEvent(of: .value, with: {snapshot in
            guard let collection = snapshot.value as? [[String:Any]] else{
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            if let conversation = collection.first(where:{
                guard let targetSenderEmail = $0["other_user_email"] as? String else {
                    return false
                }
                return safeSenderEmail == targetSenderEmail
            }){
                //get id
                guard let id = conversation["id"] as? String else{
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                completion(.success(id))
                return
            }
            completion(.failure(DatabaseError.failedToFetch))
            return
        })
    }
}



struct ChatAppUser {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var safeEmail : String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")

        return safeEmail
    }
    var profilePictureFileName: String {
        return " \(safeEmail)_profile_picture.png"
    }
    
}
