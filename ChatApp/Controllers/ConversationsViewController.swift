//
//  ViewController.swift
//  ChatApp
//
//  Created by Selman Kaya on 6.01.2025.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

/// Controller that shows list of conversations
final class ConversationsViewController: UIViewController{
    
    
    
    private let spinner  = JGProgressHUD(style: .dark)
    
    private var conversations = [Conversation]()
    
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.isHidden = true
        table.register(ConversationsTableViewCell.self,
                       forCellReuseIdentifier: ConversationsTableViewCell.identifier)
        return table
    }()
    
    private let noConversationsLabel: UILabel = {
        let label = UILabel()
        label.text = "No conversations found"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
    }()
    
    private var loginObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose,
                                                            target: self,
                                                            action: #selector(didTapComposeButton))
        view.addSubview(tableView)
        view.addSubview(noConversationsLabel)
        setupTableView()
        startListeningForConversations()
        
        
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification,object: nil,queue: .main,using: { [weak self] _ in
            guard let strongSelf = self else { return }
                            
            strongSelf.startListeningForConversations()
        })
        
        
    }
    
    private func startListeningForConversations(){
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else{
            return
        }
        
        if let observer = loginObserver{
            NotificationCenter.default.removeObserver(observer)
        }
        
        print("starting conversation fetchh...")
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        DatabaseManager.shared.getAllConversations(for: safeEmail, completion: {[weak self] result in
            switch result{
            case .success(let conversations):
                print("successfully fetched conversations")
                guard !conversations.isEmpty else{
                    self?.tableView.isHidden = true
                    self?.noConversationsLabel.isHidden = false

                    return
                }
                self?.noConversationsLabel.isHidden = true
                self?.tableView.isHidden = false
                self?.conversations = conversations
                
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            case .failure(let error):
                self?.tableView.isHidden = true
                self?.noConversationsLabel.isHidden = false

                print("Failed to get convos: \(error.localizedDescription)")
            }
        })
    }
    
    @objc func didTapComposeButton(){
        let vc = NewConversationViewController()
                vc.completion = { [weak self] result in
                    guard let strongSelf = self else {
                        return
                    }

                    let currentConversations = strongSelf.conversations
                    
                    if let targetConversation = currentConversations.first(where: {
                        $0.otherUserEmail == result.email
                    }) {
                        let vc = ChatViewController(with: targetConversation.otherUserEmail , id: targetConversation.id)
                        vc.isNewConversation = false
                        vc.title = targetConversation.name
                        vc.navigationItem.largeTitleDisplayMode = .never
                        strongSelf.navigationController?.pushViewController(vc, animated: true)
                    }
                    else {
                        strongSelf.createNewConversation(result: result)
                    }
                }
                let navVC = UINavigationController(rootViewController: vc)
                present(navVC, animated: true)
            }

    
    private func createNewConversation(result: SearchResult){
        let name = result.name
        let email = DatabaseManager.safeEmail(emailAddress: result.email) //sikinti cikarsa ilk buna bak
        
        //check in database if conversation with these two users exists
        // if it does, reuse conversationid
        //otherwise use existing code
        
        
        DatabaseManager.shared.conversationExist(with: email, completion: {[weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let conversationId):
                let vc = ChatViewController(with: email, id: conversationId)
                vc.isNewConversation = false
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
                
                
            case .failure(_):
                let vc = ChatViewController(with: email, id: nil)
                vc.isNewConversation = true
                vc.title = name
                vc.navigationItem.largeTitleDisplayMode = .never
                strongSelf.navigationController?.pushViewController(vc, animated: true)
                
                
            }
            
        })
        
    
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
        noConversationsLabel.frame = CGRect(x: 10,
                                            y: (view.height-100)/2,
                                            width: view.width-20,
                                            height: 100)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        validateAuth()
    }
    
    
        private func validateAuth() {
            
            if FirebaseAuth.Auth.auth().currentUser == nil {
                let vc = LoginViewController()
                let nav = UINavigationController(rootViewController: vc)
                nav.modalPresentationStyle = .fullScreen
                present(nav, animated: true)
            
        }
        
    }
    private func setupTableView(){
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    
    

}
extension ConversationsViewController : UITableViewDelegate , UITableViewDataSource{
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = conversations[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ConversationsTableViewCell.identifier,
                                                       for: indexPath) as? ConversationsTableViewCell else {
            fatalError("Could not dequeue ConversationsTableViewCell")
        }
        cell.configure(with: model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = conversations[indexPath.row]
        openConversation(model)
       
        
    }
    func openConversation(_ model: Conversation){
        
        let vc = ChatViewController(with: model.otherUserEmail, id: model.id)
        vc.title = model.name
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(vc, animated: true)
        
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete{
            //begin delete
            let conversationId = conversations[indexPath.row].id
            tableView.beginUpdates()
            self.conversations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .left)

           
            
            DatabaseManager.shared.deleteConversation(conversationId: conversationId, completion: { success in
                if !success{
                    // add model and row back and show error alert
                    print("Failed to delete conversation")
                }
            })
            
            
            tableView.endUpdates()
        }
    }
    
}
