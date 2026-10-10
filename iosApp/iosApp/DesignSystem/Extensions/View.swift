//
//  View.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//

import SwiftUI

public extension View {
    
    @ViewBuilder
    func disabledWithOpacity(_ isDisabled: Bool)-> some View {
        self
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1)
    }
    
    @ViewBuilder
    nonisolated func optionalGlassEffect<S: Shape & Sendable>(_ shape: S, isInteractive: Bool = false)-> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.interactive(isInteractive), in: shape)
        } else {
           self
                .background(.ultraThinMaterial, in: shape)
        }
    }
    
    @ViewBuilder
    func clearListStyle()-> some View {
        self
            .listStyle(.plain)
            .listRowInsets(.init())
            .listRowSeparator(.hidden)
            .listRowBackground(EmptyView())
            .frame(maxWidth: .infinity)
    }
}
