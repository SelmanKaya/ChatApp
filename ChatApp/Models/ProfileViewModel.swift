//
//  ProfileViewModel.swift
//  ChatApp
//
//  Created by Selman Kaya on 3.03.2025.
//

import Foundation

enum ProfileViewModelType{
    case info,logout
}

struct ProfileViewModel{
    let viewModelType: ProfileViewModelType
    let title: String
    let handler: (() -> Void)?
}
