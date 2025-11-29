//
//  View+Extension.swift
//  OverseasSwiftExtensions
//
//

import SwiftUI
import Combine

public extension View {
    
    // 类似 iOS 17 支持的 onChange，仅在监听值变化时触发
    func onReceiveChange<Value: Equatable>(
        _ publisher: Value,
        immediately: Bool = true,
        perform action: @escaping (Value?, Value) -> Void
    ) -> some View {
        self.modifier(OnReceiveChangeModifier(publisher: Just(publisher), immediately: immediately, action: action))
    }
    
    func onReceiveChange<Publisher: Combine.Publisher, Value: Equatable>(
        _ publisher: Publisher,
        immediately: Bool = true,
        perform action: @escaping (Value?, Value) -> Void
    ) -> some View where Publisher.Output == Value, Publisher.Failure == Never {
        self.modifier(OnReceiveChangeModifier(publisher: publisher, immediately: immediately, action: action))
    }
    
    // 绘制圆角
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    // 测量View尺寸
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometry.size)
                    .onAppear {
                        onChange(geometry.size)
                    }
                    .onChange(of: geometry.frame(in: .global)) { _ in
                        onChange(geometry.size)
                    }
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
    
    // 统计View的曝光时长
    func trackViewDuration(onDurationRecorded: @escaping (TimeInterval) -> Void) -> some View {
        self.modifier(ViewDurationTrackerModifier(onDurationRecorded: onDurationRecorded))
    }
    
    // 文字描边
    func customeStrok(
        color: Color,
        width: CGFloat,
        filter: GraphicsContext.Filter = .alphaThreshold(min: 0.01)
    ) -> some View {
        self.modifier(StrokeModifier(strokeSize: width, strokeColor: color, filter: filter))
    }
    
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = 12
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

public extension View {
    
    // View监听值回调：View展示时默认回调一次，每当有新的监听值时再回调
    func onAppearAndOnChange<V>(of value: V, perform action: @escaping (_ newValue: V) -> Void) -> some View where V: Equatable {
        onReceive(Just(value), perform: action)
    }
    
    @ViewBuilder
    func conditionalSafeArea(_ ignore: Bool) -> some View {
        if ignore {
            self.ignoresSafeArea(.all)
        } else {
            self
        }
    }
    
    func eraser() -> AnyView { AnyView(self) }
}

public extension View {
    @ViewBuilder
    func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide {
            self.hidden()
        } else {
            self
        }
    }
    
    @ViewBuilder
    func `if`<Transformed: View>(
        _ condition: Bool,
        transform: (Self) -> Transformed
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

