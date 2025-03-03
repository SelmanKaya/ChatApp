//
//  ChatViewController.swift
//  ChatApp
//
//  Created by Selman Kaya on 25.01.2025.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation



final class ChatViewController: MessagesViewController {
    
    private var senderPhotoUrl: URL?
    private var otherUserPhotoUrl: URL?

    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
        
    }()
    
    public let otherUserEmail: String
    private var conversationId: String?


    public var isNewConversation = false

    
    private var messages = [Message]()
    
    private var selfSender:Sender? {
        guard let email = UserDefaults.standard.value(forKeyPath: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        return Sender(senderId: safeEmail,
                      photoURL: "",
                      displayName: "Me")
    }
    
   
    
    init(with email:String, id: String?){
        self.conversationId = id
        self.otherUserEmail = email
        
        super.init(nibName: nil, bundle: nil)
        if let conversationId = conversationId{
            listenForMessages(id: conversationId, shouldScrollToBottom: true)

        }
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        view.backgroundColor = .white
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self

        messageInputBar.delegate = self
        
        messagesCollectionView.reloadData()
        messagesCollectionView.scrollToLastItem()
        setupInputButton()
    }
    private func setupInputButton(){
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: true)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside {[weak self] _ in
            self?.presentInputActionSheet()
            
        }
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: true)
        messageInputBar.setStackViewItems( [button],forStack: .left, animated: true)
        
    }
    
    private func presentInputActionSheet(){
        let actionSheet = UIAlertController(title: "Attach Media", message: "Waht would you like to attach?", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: {[weak self] _ in
            self?.presentPhotoInputActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: {[weak self] _ in
            self?.presentVideoInputActionSheet()
        }))
        actionSheet.addAction(UIAlertAction(title: "Audio", style: .default, handler: { _ in
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Location", style: .default, handler: {[weak self] _ in
            self?.presentLocationPicker()
        }))
        actionSheet.addAction(UIAlertAction(title: "File", style: .default, handler: {[weak self] _ in
                self?.presentDocumentPicker()
            }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        
        present(actionSheet,animated: true)
    }
    private func presentDocumentPicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true)
    }


    private func presentLocationPicker(){
        let vc = LocationPickerViewController(coordinates: nil)
        vc.title = "Select Location"
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = {[weak self] selectedCoordinates in
            
            guard let strongSelf = self else {
                return
            }
            
            guard let messageId = strongSelf.createMessageId(),
                  let conversationId = strongSelf.conversationId,
                  let name = strongSelf.title,
                  let selfSender = strongSelf.selfSender else {
                    return
            }
                
            let longitude: Double = selectedCoordinates.longitude
            let latitude: Double = selectedCoordinates.latitude

            print("long=\(longitude) | lat=\(latitude)")
            
            
            let location = Location(location: CLLocation(latitude: latitude, longitude: longitude), size: .zero)
            
            let message = Message(sender: selfSender,
                                  messageId: messageId,
                                  sentDate: Date(),
                                  kind: .location(location))
            
            
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: { success in
                if success{
                    print("sent location message")
                }else{
                    print("failed to send message")
                }
            })

        }
        navigationController?.pushViewController(vc, animated: true)
    }
    private func presentPhotoInputActionSheet(){
        let actionSheet = UIAlertController(title: "Attach Photo ", message: "Waht would you like to attach?", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: {[weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker,animated: true)
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: {[weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker,animated: true)
            
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        
        present(actionSheet,animated: true)
    }
    
    private func presentVideoInputActionSheet(){
        let actionSheet = UIAlertController(title: "Attach Video ", message: "What would you like to attach?", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: {[weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker,animated: true)
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Video Library", style: .default, handler: {[weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.allowsEditing = true
            self?.present(picker,animated: true)
            
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        
        present(actionSheet,animated: true)
    }
    
    
    private func listenForMessages(id: String,shouldScrollToBottom: Bool){
        DatabaseManager.shared.getAllMessagesForConversation(with: id, completion: {[weak self] result in
            switch result{
            case .success(let messages):
                print("success in getting messages")
                guard !messages.isEmpty else{
                    return
                }
                self?.messages = messages
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()

                    if shouldScrollToBottom{
                        self?.messagesCollectionView.scrollToLastItem(animated: true)

                    }

                }
            case .failure(let error):
                print("failed to get messages: \(error)")
            }
        })
    }
    
    func viewdidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        

    }

    
}
extension ChatViewController: UIImagePickerControllerDelegate , UINavigationControllerDelegate{
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let messageId = createMessageId(),
              let conversationId = conversationId,
              let name = self.title,
              let selfSender = selfSender else {
                return
        }
        
        if let image = info[.editedImage] as? UIImage, let imageData = image.pngData(){
            
            let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
            // upload image
            
            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName, completion: {[weak self] result in
                guard let strongSelf = self else { return }
            switch result {
            case .success(let urlString):
                // ready to send message
                print("Uploaded Message Video: \(urlString)")
                
                guard let url = URL(string: urlString),
                        let placeholder = UIImage(systemName: "plus") else {
                    return
                }
                
                let media = Media(url: url,
                                  image: nil,
                                  placeholderImage: placeholder,
                                  size: .zero)
                
                let message = Message(sender: selfSender,
                                      messageId: messageId,
                                      sentDate: Date(),
                                      kind: .photo(media))
                
                
                DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: { success in
                    if success{
                        print("sent photo message")
                    }else{
                        print("failed to send message")
                    }
                })

            case .failure(let error):
                print("Failed to upload image: \(error.localizedDescription)")
                }
            })
            
        }
        else if let videoUrl = info[.mediaURL]  as? URL{
            let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".mov"
            //upload video
            
            StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: fileName, completion: {[weak self] result in
                guard let strongSelf = self else { return }
            switch result {
            case .success(let urlString):
                // ready to send message
                print("Uploaded Message Photo: \(urlString)")
                
                guard let url = URL(string: urlString),
                        let placeholder = UIImage(systemName: "plus") else {
                    return
                }
                
                let media = Media(url: url,
                                  image: nil,
                                  placeholderImage: placeholder,
                                  size: .zero)
                
                let message = Message(sender: selfSender,
                                      messageId: messageId,
                                      sentDate: Date(),
                                      kind: .video(media))
                
                
                DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: { success in
                    if success{
                        print("sent photo message")
                    }else{
                        print("failed to send message")
                    }
                })

            case .failure(let error):
                print("Failed to upload image: \(error.localizedDescription)")
                }
            })
            
        }
        
    }
        

}
    
    
    
    // send message
    



extension ChatViewController: InputBarAccessoryViewDelegate{
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: "", with: "").isEmpty,
        let selfSender = self.selfSender,
        let messageId = createMessageId() else {
            return
        }
        
        print("Sending : \(text) ")
        
        let message = Message(sender: selfSender,
                              messageId: messageId,
                              sentDate: Date(),
                              kind: .text(text))
        
        //send message
        if isNewConversation{
            //create convo in db
            
            DatabaseManager.shared.createNewConversation(with: otherUserEmail,name: self.title ?? "User", firstMessage: message, completion: {[weak self] success in
                if success {
                    print("message sent")
                    self?.isNewConversation = false
                    let newConversationId = "conversation_\(message.messageId)"
                    self?.conversationId = newConversationId
                    
                    self?.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
                    self?.messageInputBar.inputTextView.text = nil
                }else{
                    print("message dont send")
                }
            })
        }
        else {
            //append to existing conversation data
            guard let conversationId = conversationId, let name = self.title else{
                return
            }

            DatabaseManager.shared.sendMessage(to: conversationId,otherUserEmail: otherUserEmail, name: name , newMessage: message, completion: {[weak self] success in
                if success {
                    self?.messageInputBar.inputTextView.text = nil

                    print("message sent")
                    
                }else{
                    print("failed to send")
                }
            })
        }
        
    }
    
    private func createMessageId() -> String? {
        //date, otheruserEmail,senderEmail,randomInt
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        let safeOtherEmail = DatabaseManager.safeEmail(emailAddress: otherUserEmail)
        
        let dateString = Self.dateFormatter.string(from: Date())
        let newIdentifier = "\(safeOtherEmail)_\(safeCurrentEmail)_\(dateString)"
        print("created message id : \(newIdentifier)")
        return newIdentifier
    }
}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    var currentSender: any MessageKit.SenderType {
        if let sender = selfSender{
            return sender
        }
        
        fatalError("Self sender is nil , email should be cached")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessageKit.MessagesCollectionView) -> any MessageKit.MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else {
            return
        }
        
        switch message.kind{
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            imageView.sd_setImage(with: imageUrl, completed: nil)
        default:
            break
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
    }
    func backgroundColor(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            //our message we send
            return .link
        }
        return .secondarySystemBackground
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {

        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            if let currentUserImage = self.senderPhotoUrl {
                avatarView.sd_setImage(with: currentUserImage)
            }else{
                guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
                    return
                }
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "images/ \(safeEmail)_profile_picture.png"
                
                StorageManager.shared.downloadURL(for: path, completion: {[weak self] result in
                    switch result{
                    case .success(let url):
                        self?.senderPhotoUrl = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url)

                        }
                    case .failure(let error):
                        print("Error downloading image: \(error)")
                    }
                    
                })
            }
        }
        else {
            if let otherUserPhotoUrl = self.otherUserPhotoUrl {
                avatarView.sd_setImage(with: otherUserPhotoUrl)
            }else{
                
                let email = self.otherUserEmail
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "images/ \(safeEmail)_profile_picture.png"
                
                StorageManager.shared.downloadURL(for: path, completion: {[weak self] result in
                    switch result{
                    case .success(let url):
                        self?.otherUserPhotoUrl = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url)

                        }
                    case .failure(let error):
                        print("Error downloading image: \(error)")
                    }
                    
                })
                
            }
        }
    }
}

extension ChatViewController: MessageCellDelegate{
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else{
            return
        }
        let message = messages[indexPath.section]
        
        switch message.kind{
        case .location(let locationData):
            let coordinates = locationData.location.coordinate
            let vc = LocationPickerViewController(coordinates: coordinates)
            vc.title = "Location"
            
            navigationController?.pushViewController(vc, animated: true)
         
        default:
            break
        }

    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else{
            return
        }
        let message = messages[indexPath.section]
        
        switch message.kind{
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            let vc = PhotoViewerViewController(with: imageUrl)
            navigationController?.pushViewController(vc, animated: true)
          
        case .video(let media):
            guard let videoUrl = media.url else {
                return
            }
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoUrl)
            
            present(vc,animated: true)

        default:
            break
        }

    }
}

extension ChatViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let fileURL = urls.first else { return }
        
        let vc = DocumentPreviewViewController()
        vc.fileURL = fileURL
        vc.completion = { [weak self] fileURL in
            self?.didSendDocument(fileURL: fileURL)
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    func didSendDocument(fileURL: URL) {
        guard let messageId = createMessageId(),
              let conversationId = conversationId,
              let name = self.title,
              let selfSender = selfSender else {
            return
        }
        
        let filePlaceholder = UIImage(systemName: "doc.fill") ?? UIImage()
        let message = Message(sender: selfSender,
                              messageId: messageId,
                              sentDate: Date(),
                              kind: .custom(["url": fileURL.absoluteString, "thumbnail": filePlaceholder]))

        DatabaseManager.shared.sendMessage(to: conversationId,
                                           otherUserEmail: otherUserEmail,
                                           name: name,
                                           newMessage: message) { [weak self] success in
            if success {
                print("📂 Dosya başarıyla gönderildi: \(fileURL)")
                DispatchQueue.main.async {
                    self?.messages.append(message)
                    self?.messagesCollectionView.reloadData()
                    self?.messagesCollectionView.scrollToLastItem()
                }
            } else {
                print("⚠️ Dosya gönderilemedi!")
            }
        }
    }
}
