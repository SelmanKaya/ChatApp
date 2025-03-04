//
//  StorageManager.swift
//  ChatApp
//
//  Created by Selman Kaya on 27.01.2025.
//

import Foundation
import FirebaseStorage

final class StorageManager {
    static let shared = StorageManager()
    
    private init(){}
    
    private let storage = Storage.storage().reference()
    
    public typealias UploadPictureCompletion = (Result<String , Error>) -> Void
    
    /// Upload picture to firebase storage and returns completion with url string to download
    public func uploadProfilePicture(with data : Data , fileName : String ,completion: @escaping UploadPictureCompletion){
        storage.child("images/\(fileName)").putData(data, metadata: nil, completion: {[weak self] metadata,error in
            guard let strongSelf = self else { return }
            
            guard error == nil else {
                print("failed to upload data to firebase for picture")
                completion(.failure(StorageError.failedToUpload))
                return
            }
            
            strongSelf.storage.child("images/\(fileName)").downloadURL { url, error in
                guard let url = url else {
                    print("Failed to get download url")
                    completion(.failure(StorageError.failedToGetDownloadUrl))
                    return
                }
                
                let urlString = url.absoluteString
                print("download url returned : \(urlString)")
                completion(.success(urlString))
            }
        })
    }
    
    /// Upload image that will be sent in a conversation message
    public func uploadMessagePhoto(with data : Data , fileName : String ,completion: @escaping UploadPictureCompletion){
        storage.child("message_images/\(fileName)").putData(data, metadata: nil, completion: {[weak self] metadata,error in
            guard error == nil else {
                print("failed to upload data to firebase for picture")
                completion(.failure(StorageError.failedToUpload))
                return
            }
            
            self?.storage.child("message_images/\(fileName)").downloadURL { url, error in
                guard let url = url else {
                    print("Failed to get download url")
                    completion(.failure(StorageError.failedToGetDownloadUrl))
                    return
                }
                
                let urlString = url.absoluteString
                print("download url returned : \(urlString)")
                completion(.success(urlString))
            }
        })
    }
    /// Upload video that will be sent in a conversation message
    public func uploadMessageVideo(with fileUrl : URL , fileName : String ,completion: @escaping UploadPictureCompletion){
        storage.child("message_videos/\(fileName)").putFile(from: fileUrl, metadata: nil, completion: {[weak self] metadata,error in
            guard error == nil else {
                print("failed to upload video file to firebase for picture")
                completion(.failure(StorageError.failedToUpload))
                return
            }
            
            self?.storage.child("message_videos/\(fileName)").downloadURL { url, error in
                guard let url = url else {
                    print("Failed to get download url")
                    completion(.failure(StorageError.failedToGetDownloadUrl))
                    return
                }
                
                let urlString = url.absoluteString
                print("download url returned : \(urlString)")
                completion(.success(urlString))
            }
        })
    }
    
    
    public enum StorageError : Error {
        case failedToUpload
        case failedToGetDownloadUrl
    }
    private var isFetchingURL = false

    func downloadURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard !isFetchingURL else {
            print("An ongoing request is already running for this path.")
            return
        }
        
        isFetchingURL = true
        let reference = storage.child(path)
        reference.downloadURL { [weak self] url, error in
            defer { self?.isFetchingURL = false } // İşlem tamamlanınca sıfırla
            if let error = error {
                print("Failed to get download URL: \(error.localizedDescription)")
                completion(.failure(StorageError.failedToGetDownloadUrl))
            } else if let url = url {
                print("Successfully retrieved URL: \(url)")
                completion(.success(url))
            }
        }
    }

}
