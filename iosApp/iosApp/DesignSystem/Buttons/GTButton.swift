//
//  SVButton.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//


import SwiftUI

public struct GTButton: View {

    // MARK: - Variant

    public enum Variant {
        case primary
        case secondary
        case destructive
        case plain
    }

    // MARK: - Size

    public enum Size {
        case small
        case medium
        case large

        var height: CGFloat {
            switch self {
            case .small: 36
            case .medium: 44
            case .large: 50
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: 12
            case .medium: 16
            case .large: 18
            }
        }

        var font: Font {
            switch self {
            case .small: .subheadline
            case .medium: .callout
            case .large: .callout
            }
        }
    }

    // MARK: - Width

    public enum Width {
        case flexible
        case intrinsic
    }

    // MARK: - Shape

    public enum GTShape {
        case capsule
        case rounded(_ cornerRadius: CGFloat)
        
        fileprivate var shape: AnyShape {
            switch self {
            case .capsule: return AnyShape(.capsule)
            case .rounded(let cornerRadius): return AnyShape(.rect(cornerRadius: cornerRadius))
            }
        }
    }

    // MARK: - Properties

    private let title: String
    private let systemImage: String?
    private let variant: Variant
    private let size: Size
    private let width: Width
    private let shape: GTShape
    private let action: () -> Void

    // MARK: - Init

    public init(
        _ title: String,
        systemImage: String? = nil,
        variant: Variant = .primary,
        size: Size = .large,
        width: Width = .flexible,
        shape: GTShape = .capsule,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.size = size
        self.width = width
        self.shape = shape
        self.action = action
    }

    // MARK: - Body

    public var body: some View {
        Button(action: action) {
            label
        }
        .optionalGlassEffect(shape.shape, isInteractive: true)
    }

    // MARK: - Label

    @ViewBuilder
    private var label: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
            }

            Text(title)
        }
        .font(size.font)
        .fontWeight(.semibold)
        .frame(
            maxWidth: width == .flexible ? .infinity : nil
        )
        .frame(height: size.height)
        .padding(.horizontal, size.horizontalPadding)
        .foregroundStyle(foregroundColor)
        .background(background)
        .clipShape(shape.shape)
    }

    // MARK: - Styling

    private var foregroundColor: Color {
        switch variant {
        case .primary, .destructive:
            .white

        case .secondary:
            .primary

        case .plain:
            .accentColor
        }
    }

//    @ViewBuilder
    private var background: AnyGradient {
        switch variant {
        case .primary:
            Color.accentColor.gradient

        case .secondary:
            Color.secondary.opacity(0.12).gradient

        case .destructive:
            Color.red.gradient

        case .plain:
            Color.clear.gradient
        }
    }
}
