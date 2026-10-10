//
//  CreateGroupView.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//

import SwiftUI
import SharedLogic

struct CreateGroupView: View {
    @Environment(AppRouter.self) private var appRouter
    @Environment(\.dismiss) private var dismiss

    let viewModel: GroupViewModel
    let onGroupCreation: (SharedLogic.Group) -> Void

    @State private var groupName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                GTTextfield(
                    placeholder: "Enter group name...",
                    value: $groupName,
                    textContentType: .name,
                    keyboardType: .default
                )
            } header: {
                Text("Group Name")
            } footer: {
                Text("Choose a name for your group. You can add friends and family members after creating it.")
            }
        }
        .navigationTitle("Create Your Group")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                GTButton("Create Group") {
                    Task {
                        await createGroup()
                    }
                }
                .disabled(
                    groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || isLoading
                )

                if isLoading {
                    ProgressView()
                }

                Text("You can add friends and family members immediately after creating your group.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.background)
        }
        .alert(
            "Unable to Create Group",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @MainActor
    private func createGroup() async {
        do {
            let name = groupName.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !name.isEmpty, !isLoading else { return }

            guard let accessToken = GTKeychainStore.shared.accessToken,
                  !accessToken.isEmpty else {
                errorMessage = "Your session has expired. Please log in again."
                return
            }

            isLoading = true
            defer { isLoading = false }

            let result = try await viewModel.createGroup(
                name: name,
                accessToken: accessToken
            )

            if result.sessionExpired {
                appRouter.logout()
                return
            }

            guard let group = result.data else {
                errorMessage = result.error ?? result.message
                return
            }

            onGroupCreation(group)
            dismiss()
        }catch {
            errorMessage = error.localizedDescription
        }
    }
}
