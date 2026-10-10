//
//  LoginView.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//

import SwiftUI
import SharedLogic

struct LoginView: View {
    @Bindable var router: AuthRouter
    let viewModel: AuthViewModel
    let groupViewModel: GroupViewModel
    @Environment(AppRouter.self) private var appRouter

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack(path: $router.path) {
            List {
                Section {
                    GTTextfield(
                        placeholder: "Enter email...",
                        value: $email,
                        textContentType: .emailAddress,
                        keyboardType: .emailAddress
                    )
                } header: {
                    Text("Email")
                }

                Section {
                    GTTextfield(
                        placeholder: "Enter password...",
                        value: $password,
                        textContentType: .password,
                        isSecure: true
                    )
                } header: {
                    Text("Password")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .listSectionSpacing(.compact)
            .navigationTitle("Login")
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 16) {
                    GTButton("Login") {
                        Task {
                            await login()
                        }
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)

                    if isLoading {
                        ProgressView()
                    }

                    RichTextView(
                        configuration: .init(
                            text: "Don't have an account? Sign up",
                            links: [
                                .init(text: "Sign up", link: "/signup")
                            ],
                            linkColor: .blue,
                            font: .subheadline,
                            linkFont: .subheadline.bold()
                        )
                    ) { _ in
                        router.push(.signup)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .signup:
                    SignupView(
                        router: router,
                        viewModel: viewModel
                    )
                case .createGroup:
                    CreateGroupView(viewModel: groupViewModel) { _ in
                        appRouter.login()
                    }
                }
            }
        }
    }

    @MainActor
    private func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            guard let response = try await viewModel.login(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            ) else {
                throw URLError(.badServerResponse)
            }

            GTKeychainStore.shared.store(
                accessToken: response.data.accessToken,
                refreshToken: response.data.refreshToken
            )

            GTKeychainStore.shared.save(
                userId: response.data.user.id
            )

            appRouter.initial()

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
