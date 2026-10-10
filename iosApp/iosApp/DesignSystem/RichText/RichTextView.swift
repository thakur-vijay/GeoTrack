//
//  iOSAuthView.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//


//
//  SwiftUIView.swift
//  iOSAuthKit
//
//  Created by Vijay Thakur on 15/08/26.
//


import SwiftUI

public struct RichTextView: View {
    let configuration: RichTextConfiguration
    let action: (String)->()
    
    public init(configuration: RichTextConfiguration, action: @escaping (String) -> Void) {
        self.configuration = configuration
        self.action = action
    }
    
    
    public var body: some View {
        Text(attributedText)
            .font(configuration.font)
            .environment(\.openURL, OpenURLAction { url in
                action(url.absoluteString)
                return .handled
                
            })
    }
    
    private var attributedText: AttributedString {
        
        var attributedString = AttributedString(configuration.text)
        
        for link in configuration.links {
            
            guard
                let range = attributedString.range(of: link.text),
                let url = URL(string: link.link)
            else {
                continue
            }
            
            attributedString[range].link = url
            attributedString[range].font = configuration.linkFont
            attributedString[range].foregroundColor = configuration.linkColor
            attributedString[range].underlineStyle = .none
        }
        
        return attributedString
    }
}

public struct RichTextConfiguration {
    
    public let text: String
    
    public let links: [RichTextLink]
    
    public let linkColor: Color
    
    public let font: Font
    
    public let linkFont: Font
    
    public init(
        text: String,
        links: [RichTextLink],
        linkColor: Color,
        font: Font,
        linkFont: Font? = nil
    ) {
        self.text = text
        self.links = links
        self.linkColor = linkColor
        self.font = font
        self.linkFont = linkFont ?? font
    }
}

public struct RichTextLink: Sendable, Hashable {
    
    public let text: String
    
    public let link: String
    
    public init(
        text: String,
        link: String
    ) {
        self.text = text
        self.link = link
    }
}

