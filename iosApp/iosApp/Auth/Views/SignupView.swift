//
//  SignupView.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//

import SwiftUI
import SharedLogic

struct SignupView: View {
    var router: AuthRouter
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    let viewModel: AuthViewModel
    init(
        router: AuthRouter,
        viewModel: AuthViewModel
    ) {
        self.router = router
        self.viewModel = viewModel
    }
    var body: some View {
        List {
            Section {
                GTTextfield(
                    placeholder: "Enter name...",
                    value: $name,
                    textContentType: .name,
                    keyboardType: .namePhonePad
                )
            } header: {
                Text("Name")
            }
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
                    textContentType: .newPassword,
                    isSecure: true
                )
            } header: {
                Text("Password")
            } footer: {
                Text("Password must be at least 8 characters long.")
            }
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .listSectionSpacing(.compact)
        .navigationTitle("Create Account")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                GTButton("Create Account") {
                    submitSignup()
                }
                .disabled(isLoading)
                if isLoading {
                    ProgressView()
                }
                RichTextView(
                    configuration: .init(
                        text: "Already have an account? Log in",
                        links: [.init(text: "Log in", link: "/login")],
                        linkColor: .blue,
                        font: .subheadline,
                        linkFont: .subheadline.bold()
                    )
                ) { _ in
                    router.pop()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .onAppear {
            viewModel.observeState { state in
                DispatchQueue.main.async {
                    isLoading = state.isLoading
                    errorMessage = state.error
                }
            }
        }
    }
    private func submitSignup() {
        Task {
            do {
                errorMessage = nil
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !password.isEmpty else {
                    errorMessage = "Please fill in all fields."
                    return
                }
                guard password.count >= 8 else {
                    errorMessage = "Password must be at least 8 characters long."
                    return
                }
                guard let response = try await viewModel.signUp(
                    name: name,
                    email: email,
                    password: password
                ) else {
                    throw URLError(.badServerResponse)
                }
                GTKeychainStore.shared.store(
                    accessToken: response.data.accessToken,
                    refreshToken: response.data.refreshToken
                )
                GTKeychainStore.shared.save(userId: response.data.user.id)
                router.push(.createGroup)
            }catch {
                print(error.localizedDescription)
            }
        }
    }
    
}
