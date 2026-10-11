//
//  SettingsView.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//

import SwiftUI
import SharedLogic

struct SettingsView: View {
    let viewModel: UsersViewModel
    let authViewModel: AuthViewModel
    let socketManager: SocketManager
    let groupID: String?
    @State private var fullName = ""
    @State private var email = ""
    @State private var errorMessage: String?

    @Environment(AppRouter.self) private var appRouter
    var body: some View {
        NavigationStack {
            List {
                Section("Full Name") {
                    Text(fullName.isEmpty ? "Loading..." : fullName)
                }

                Section("Email") {
                    Text(email.isEmpty ? "Loading..." : email)
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            let accessToken = GTKeychainStore.shared.accessToken ?? ""
                            defer {
                                GTKeychainStore.shared.clearTokens()
                                appRouter.logout()
                            }
                            if !accessToken.isEmpty {
                                do {
                                    try await socketManager.disconnect()
                                    try await authViewModel.logout(
                                        accessToken: accessToken,
                                        groupId: groupID ?? ""
                                    )
                                } catch {
                                    print("Backend logout failed: \(error.localizedDescription)")
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Logout")
                            Spacer()
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .task {
            do {
                guard let response = try await viewModel.getUser(
                    id: GTKeychainStore.shared.userId ?? "",
                    accessToken: GTKeychainStore.shared.accessToken ?? ""
                ) else {
                    throw URLError(.badServerResponse)
                }
                fullName = response.data.fullName
                email = response.data.email
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
