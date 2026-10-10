//
//  MainRouter.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//

import Foundation

@Observable
@MainActor
final class MainRouter {
    var activeTab: TabModel = .map
}
