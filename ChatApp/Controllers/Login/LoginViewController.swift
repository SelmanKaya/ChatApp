//
//  LoginViewController.swift
//  ChatApp
//
//  Created by Selman Kaya on 6.01.2025.
//

import UIKit
import FirebaseAuth
import GoogleSignIn

class LoginViewController: UIViewController {
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .white
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()


    
    private let emailField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email Adress..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .white
        return field
    }()
    private let passwordField: UITextField = {
        let field = UITextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Password..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .white
        field.isSecureTextEntry = true
        return field
    }()
    
    
    private let loginButton : UIButton = {
        let button  = UIButton()
        button.setTitle("Log In", for: .normal)
        button.backgroundColor = .link
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        return button
    }()
        
    private let googleLogInButton : GIDSignInButton = GIDSignInButton()
    
    private var loginObserver: NSObjectProtocol?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification,object: nil,queue: .main,using: { [weak self] _ in
            guard let strongSelf = self else { return }
                            
            strongSelf.navigationController?.dismiss(animated: true)
        })
        
        //GIDSignIn.sharedInstance()?.presentingViewController = self
        googleLogInButton.addTarget(self, action: #selector(googleSignInButtonTapped), for: .touchUpInside)

        
        title = "Login"
        view.backgroundColor = .white
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Register",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(didTapRegister))
        
        loginButton.addTarget(self,
                              action: #selector(loginButtonTapped),
                              for: .touchUpInside)
        
        emailField.delegate = self
        passwordField.delegate = self
        
        view.addSubview(scrollView)

        scrollView.addSubview(emailField)
        scrollView.addSubview(imageView)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        scrollView.addSubview(googleLogInButton)


        
    }
    deinit{
        if let observer = loginObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    @objc private func googleSignInButtonTapped() {
            // GIDSignIn'ın sign-in işlemini başlat
            GIDSignIn.sharedInstance.signIn(withPresenting: self) { [weak self] signInResult, error in
                guard let result = signInResult else {
                    print("Google Sign-In failed: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                print("Did sign in with google: \(result.user)")
                
                guard let email = result.user.profile?.email,
                      let firstName = result.user.profile?.givenName,
                      let lastName = result.user.profile?.familyName
                    else{return}
                
                DatabaseManager.shared.userExists(with: email, completion: { exists in
                    if !exists {
                        DatabaseManager.shared.insertUser(with: ChatAppUser(firstName: firstName,
                                                                            lastName: lastName,
                                                                            emailAddress: email))
                    }
                    
                })
                // Kullanıcıyı al
                let user = result.user
                print("User signed in: \(user.profile?.email ?? "No Email")")

                // Firebase Authentication işlemi
                guard let idToken = user.idToken?.tokenString else {
                    print("Missing auth object off of google user")
                    return }
                let accessToken = user.accessToken.tokenString
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

                Auth.auth().signIn(with: credential) { authResult, error in
                    if let error = error {
                        print("Firebase authentication failed: \(error.localizedDescription)")
                    } else {
                        print("Firebase sign-in successful for: \(authResult?.user.email ?? "")")
                        NotificationCenter.default.post(name: .didLogInNotification, object: nil)
                    }
                }
            }
        }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // ScrollView'un tüm ekranı kapsadığından emin olun
        scrollView.frame = view.bounds
        scrollView.contentSize = CGSize(width: view.width, height: loginButton.frame.maxY + 20)

        // ImageView'in boyutunu ve konumunu ayarlayın
        let size = scrollView.width / 3
        imageView.frame = CGRect(x: (scrollView.width - size) / 2,
                                 y: 20,
                                 width: size,
                                 height: size)
        
        // Email alanının konumunu ve boyutunu ayarlayın
        emailField.frame = CGRect(x: 30,
                                  y: imageView.frame.maxY + 10,
                                  width: scrollView.width - 60,
                                  height: 52)
        
        // Password alanının konumunu ve boyutunu ayarlayın
        passwordField.frame = CGRect(x: 30,
                                     y: emailField.frame.maxY + 10,
                                     width: scrollView.width - 60,
                                     height: 52)
        
        // Login butonunun konumunu ve boyutunu ayarlayın
        loginButton.frame = CGRect(x: 30,
                                   y: passwordField.frame.maxY + 10,
                                   width: scrollView.width - 60,
                                   height: 52)
        
        googleLogInButton.frame = CGRect(x: 30,
                                         y: loginButton.bottom+10,
                                         width: scrollView.width-60,
                                         height: 52)
    }

    
    @objc private func loginButtonTapped() {
        
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()

        guard let email = emailField.text, let password = passwordField.text ,
              !email.isEmpty, !password.isEmpty, password.count >= 6 else{
            alertUserLoginError()
            return
        }
        // Firebase login
        
        DatabaseManager.shared.userExists(with: email, completion: {[weak self] exist in
            guard let strongSelf = self else { return }

            guard !exist else {
                strongSelf.alertUserLoginError(message: "Looks like a user account for email address already exists.")
                return
            }
            
            FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password, completion:{authResult,error in
                guard let result = authResult, error == nil else {
                    print("Failed to log in user with email : \(email)")
                    return
                }
                let user = result.user
                print("Logged in user : \(user)")
                strongSelf.navigationController?.dismiss(animated: true)
            })
        })
        
    }
    func alertUserLoginError(message: String = "Please enter all information to login") {
        let alert = UIAlertController(title: "Error",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func didTapRegister() {
        let vc = RegisterViewController()
        vc.title = "Register"
        navigationController?.pushViewController(vc, animated: true)
    }


}

extension LoginViewController: UITextFieldDelegate {
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if textField == emailField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            loginButtonTapped()
        }
        return true
    }
}
