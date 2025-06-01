import SwiftUI

// MARK: - Keyboard Handling
extension View {
    /// Sicheres Keyboard-Handling ohne AutoLayout-Konflikte
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                          to: nil, from: nil, for: nil)
        }
    }
    
    /// Custom Keyboard-Toolbar ohne AutoLayout-Probleme
    func customKeyboardToolbar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        self.safeAreaInset(edge: .bottom, spacing: 0) {
            content()
                .background(.regularMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(uiColor: .separator)),
                    alignment: .top
                )
        }
    }
    
    /// Sichere Frame-Dimensionen die negative/ungültige Werte verhindert
    func safeFrame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        let safeWidth = width.map { max(0, $0.isFinite ? $0 : 0) }
        let safeHeight = height.map { max(0, $0.isFinite ? $0 : 0) }
        
        return self.frame(width: safeWidth, height: safeHeight, alignment: alignment)
    }
    
    /// Sichere Frame-Dimensionen mit min/max Constraints
    func safeFrame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil,
                   minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil,
                   alignment: Alignment = .center) -> some View {
        let safeMinWidth = minWidth.map { max(0, $0.isFinite ? $0 : 0) }
        let safeIdealWidth = idealWidth.map { max(0, $0.isFinite ? $0 : 0) }
        let safeMaxWidth = maxWidth.map { max(0, $0.isFinite ? $0 : 0) }
        let safeMinHeight = minHeight.map { max(0, $0.isFinite ? $0 : 0) }
        let safeIdealHeight = idealHeight.map { max(0, $0.isFinite ? $0 : 0) }
        let safeMaxHeight = maxHeight.map { max(0, $0.isFinite ? $0 : 0) }
        
        return self.frame(
            minWidth: safeMinWidth, idealWidth: safeIdealWidth, maxWidth: safeMaxWidth,
            minHeight: safeMinHeight, idealHeight: safeIdealHeight, maxHeight: safeMaxHeight,
            alignment: alignment
        )
    }
} 