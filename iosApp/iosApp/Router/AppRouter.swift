//
//  AppRouter.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//

import SwiftUI

@Observable
@MainActor
final class AppRouter {
    var authRouter: AuthRouter = .init()
    var mainRouter: MainRouter = .init()
    var appState: AppState = .auth
    
    func login() {
        self.appState = .main
        self.authRouter = .init()
    }
    
    func logout() {
        self.appState = .auth
        self.mainRouter = .init()
    }
    
    func initial(){
        let accessToken = GTKeychainStore.shared.accessToken
        let refreshToken = GTKeychainStore.shared.refreshToken
        let userId = GTKeychainStore.shared.userId
        
        guard accessToken != nil, refreshToken != nil, userId != nil else {
            self.appState = .auth
            return
        }
        
        self.appState = .main
    }
}
