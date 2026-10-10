//
//  ManageGroupView.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//

import SwiftUI
import SharedLogic

struct ManageGroupView: View {
    @Environment(AppRouter.self) private var appRouter
    @Environment(\.dismiss) private var dismiss

    let selectedGroup: SharedLogic.Group
    let viewModel: GroupViewModel

    @State private var members: [User] = []
    @State private var showUsersSheet = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var currentGroup: SharedLogic.Group {
        selectedGroup
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Group") {
                    LabeledContent(
                        "Name",
                        value: currentGroup.name
                    )

                    LabeledContent(
                        "Members",
                        value: "\(members.count)"
                    )
                }

                Section {
                    Button {
                        showUsersSheet = true
                    } label: {
                        Label("Add Member", systemImage: "person.badge.plus")
                    }
                }

                Section("Members") {
                    if members.isEmpty {
                        ContentUnavailableView(
                            "No Members",
                            systemImage: "person.2",
                            description: Text("This group has no members yet.")
                        )
                    } else {
                        ForEach(members, id: \.id) { member in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(member.fullName)

                                Text(member.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Manage Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showUsersSheet) {
                NavigationStack {
                    GroupUsersView(
                        groupID: currentGroup.id,
                        viewModel: viewModel,
                        existingMemberIDs: Set(members.map(\.id))
                    ) { addedMember in
                        if !members.contains(where: { $0.id == addedMember.id }) {
                            members.append(addedMember)
                        }
                    }
                }
            }
            .alert(
                "Something Went Wrong",
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
            .onAppear {
                members = currentGroup.members
            }
        }
    }
}

// MARK: - Group Users

private struct GroupUsersView: View {
    @Environment(AppRouter.self) private var appRouter
    @Environment(\.dismiss) private var dismiss

    let groupID: String
    let viewModel: GroupViewModel
    let existingMemberIDs: Set<String>
    let onMemberAdded: (User) -> Void

    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var addingUserID: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading && users.isEmpty {
                ProgressView("Loading users...")
                    .frame(maxWidth: .infinity)
            } else if users.isEmpty {
                ContentUnavailableView(
                    "No Users Available",
                    systemImage: "person.2",
                    description: Text("There are no users available to add to this group.")
                )
            } else {
                ForEach(users, id: \.id) { user in
                    Button {
                        Task {
                            await addMember(user)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(.quaternary)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Text(
                                        String(user.fullName.prefix(1))
                                            .uppercased()
                                    )
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.fullName)
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if addingUserID == user.id {
                                ProgressView()
                            } else {
                                Image(systemName: "plus.circle")
                                    .font(.title3)
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(addingUserID != nil)
                }
            }
        }
        .navigationTitle("Add Members")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .task {
            await fetchUsers()
        }
        .alert(
            "Unable to Add Member",
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
    private func fetchUsers() async {
        do {
            guard !isLoading else { return }

            guard let accessToken = GTKeychainStore.shared.accessToken,
                  !accessToken.isEmpty else {
                errorMessage = "Your session has expired. Please log in again."
                return
            }

            isLoading = true
            defer { isLoading = false }

            let result = try await viewModel.fetchUsers(
                groupID: groupID,
                accessToken: accessToken
            )

            if result.sessionExpired {
                appRouter.logout()
                return
            }

            guard let fetchedUsers = result.data as? [User] else {
                errorMessage = result.error ?? result.message
                return
            }

            users = fetchedUsers.filter {
                !existingMemberIDs.contains($0.id)
            }
        }catch{
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func addMember(_ user: User) async {
        do {
            guard addingUserID == nil else { return }

            guard let accessToken = GTKeychainStore.shared.accessToken,
                  !accessToken.isEmpty else {
                errorMessage = "Your session has expired. Please log in again."
                return
            }

            addingUserID = user.id
            defer { addingUserID = nil }

            let result = try await viewModel.addMember(
                groupID: groupID,
                userID: user.id,
                accessToken: accessToken
            )

            if result.sessionExpired {
                appRouter.logout()
                return
            }

            guard result.data == true else {
                errorMessage = result.error ?? result.message
                return
            }

            onMemberAdded(user)
            dismiss()
        }catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    // Supply a real Group and GroupViewModel from your preview container.
    Text("Manage Group Preview")
}
