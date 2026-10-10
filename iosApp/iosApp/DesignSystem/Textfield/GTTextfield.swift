//
//  GTTextfield.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//


import SwiftUI

public struct GTTextfield: View {
    let placeholder: String
    let textContentType: UITextContentType?
    let keyboardType: UIKeyboardType
    let isSecure: Bool

    @Binding var value: String

    @State private var isPasswordVisible = false

    public init(
        placeholder: String,
        value: Binding<String>,
        textContentType: UITextContentType? = nil,
        keyboardType: UIKeyboardType = .default,
        isSecure: Bool = false
    ) {
        self.placeholder = placeholder
        self._value = value
        self.textContentType = textContentType
        self.keyboardType = keyboardType
        self.isSecure = isSecure
    }

    public var body: some View {
        HStack(spacing: 8) {
            Group {
                if isSecure && !isPasswordVisible {
                    SecureField(
                        placeholder,
                        text: $value
                    )
                } else {
                    TextField(
                        placeholder,
                        text: $value
                    )
                }
            }
            .font(.callout)
            .foregroundStyle(.primary)
            .textContentType(textContentType)
            .keyboardType(keyboardType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if isSecure {
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(
                        systemName: isPasswordVisible
                            ? "eye.slash"
                            : "eye"
                    )
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isPasswordVisible
                        ? "Hide password"
                        : "Show password"
                )
            }
        }
    }
}
