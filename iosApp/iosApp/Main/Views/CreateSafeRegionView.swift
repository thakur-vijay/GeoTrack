//
//  CreateSafeRegionView.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//


import SwiftUI
import CoreLocation

struct CreateSafeRegionView: View {
    let groupID: String
    let coordinate: CLLocationCoordinate2D

    let onSave: (String, Int) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var radius = 200.0

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Safe Region") {
                    TextField("Region name", text: $name)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Radius")
                            Spacer()
                            Text("\(Int(radius)) m")
                                .monospacedDigit()
                                .fontWeight(.semibold)
                        }

                        Slider(
                            value: $radius,
                            in: 100...5000,
                            step: 100
                        )

                        HStack {
                            Text("100 m")
                            Spacer()
                            Text("5 km")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Selected Location") {
                    LabeledContent("Latitude") {
                        Text(
                            coordinate.latitude,
                            format: .number.precision(.fractionLength(6))
                        )
                    }

                    LabeledContent("Longitude") {
                        Text(
                            coordinate.longitude,
                            format: .number.precision(.fractionLength(6))
                        )
                    }
                }

                Section("Group") {
                    LabeledContent("Group ID") {
                        Text(groupID)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Create Safe Region")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            name.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ),
                            Int(radius)
                        )
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}