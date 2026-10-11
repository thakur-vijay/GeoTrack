//
//  MapView+MembersSection.swift
//  iosApp
//
//  Created by Vijay Thakur on 11/10/26.
//

import SwiftUI
import SharedLogic

extension MapView {

    // MARK: - Members

    var membersSection: some View {
        HStack(spacing: 16) {
            membersList

            groupPicker
        }
    }

    private var membersList: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                if let selectedGroup = mapViewModel.selectedGroup.value as? SharedLogic.Group{
                    ForEach(selectedGroup.members, id: \.id) { member in
                        memberItem(
                            name: member.fullName,
                            isOnline: member.isOnline || memberLocations[member.id] != nil
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
    }

    private func memberItem(
        name: String,
        isOnline: Bool
    ) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(
                    isOnline
                    ? .green.opacity(0.2)
                    : .gray
                )
                .frame(width: 48, height: 48)
                .overlay {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.headline)
                }
                .overlay(alignment: .bottomTrailing) {
                    if isOnline {
                        Circle()
                            .fill(.green)
                            .frame(width: 12, height: 12)
                            .overlay {
                                Circle()
                                    .stroke(.background, lineWidth: 2)
                            }
                    }
                }

            Text(name)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 64)
        }
    }

    // MARK: - Group Picker

    private var groupPicker: some View {
        Picker(
            "Selected Group",
            selection: Binding(
                get: {
                    (mapViewModel.selectedGroup.value as? SharedLogic.Group)?.id
                },
                set: { newValue in
                    mapViewModel.setSelectedGroupID(value: .init(id: newValue))
                }
            )
        ) {
            ForEach(groups, id: \.id) { group in
                Text(group.name)
                    .tag(Optional(group.id))
            }
        }
        .pickerStyle(.menu)
    }
    
    private var groups: [SharedLogic.Group] {
        (mapViewModel.groups.value as? [SharedLogic.Group]) ?? []
    }
}
