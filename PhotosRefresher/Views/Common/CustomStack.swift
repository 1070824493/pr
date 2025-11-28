//
//  CustomStack.swift
//  SwiftUITestProject
//
//

import SwiftUI

struct CustomVStack<Content: View>: View {
    private let content: Content
    private let alignment: HorizontalAlignment
    private let spacing: CGFloat?

    init(alignment: HorizontalAlignment = .center,
         spacing: CGFloat? = nil,
         @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing ?? 0
        self.content = content()
    }

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            content
        }
    }
}

struct CustomHStack<Content: View>: View {
    private let content: Content
    private let alignment: VerticalAlignment
    private let spacing: CGFloat?

    init(alignment: VerticalAlignment = .center,
         spacing: CGFloat? = nil,
         @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing ?? 0
        self.content = content()
    }

    var body: some View {
        HStack(alignment: alignment, spacing: spacing) {
            content
        }
    }
}
