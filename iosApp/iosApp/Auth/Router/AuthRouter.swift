//
//  AuthRouter.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//

import SwiftUI

@Observable
@MainActor
final class AuthRouter {
    var path: [AuthRoute] = .init()
    
    func push(_ to: AuthRoute) {
        path.append(to)
    }
    
    func pop() {
        path.removeLast()
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
}
