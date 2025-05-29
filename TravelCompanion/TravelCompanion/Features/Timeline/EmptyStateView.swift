import SwiftUI

/// Ansprechende Empty State View für die Timeline wenn keine Memories vorhanden sind
struct EmptyStateView: View {
    let hasFilters: Bool
    let onCreateFirstMemory: () -> Void
    let onClearFilters: (() -> Void)?
    
    init(hasFilters: Bool = false, 
         onCreateFirstMemory: @escaping () -> Void, 
         onClearFilters: (() -> Void)? = nil) {
        self.hasFilters = hasFilters
        self.onCreateFirstMemory = onCreateFirstMemory
        self.onClearFilters = onClearFilters
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Illustration
            illustrationView
            
            // Text Content
            textContent
            
            // Action Buttons
            actionButtons
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Illustration View
    @ViewBuilder
    private var illustrationView: some View {
        ZStack {
            // Background Circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
            
            // Icon
            Image(systemName: hasFilters ? "magnifyingglass" : "camera.viewfinder")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(hasFilters ? .orange : .blue)
        }
    }
    
    // MARK: - Text Content
    @ViewBuilder
    private var textContent: some View {
        VStack(spacing: 12) {
            // Titel
            Text(hasFilters ? "Keine Ergebnisse" : "Deine Timeline ist leer")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Beschreibung
            Text(hasFilters ? filterEmptyDescription : firstTimeEmptyDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
    }
    
    // MARK: - Action Buttons
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 16) {
            if hasFilters {
                // Clear Filters Button
                Button(action: {
                    onClearFilters?()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Filter zurücksetzen")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.orange)
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Create Memory Button
            Button(action: onCreateFirstMemory) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(hasFilters ? "Neue Erinnerung erstellen" : "Erste Erinnerung erstellen")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Text Content Descriptions
    
    private var firstTimeEmptyDescription: String {
        """
        Beginne deine Reise-Dokumentation! 
        
        Erstelle deine erste Erinnerung und halte besondere Momente fest. Mit GPS-Tracking, Fotos und persönlichen Notizen wird jeder Ort zu einer wertvollen Erinnerung.
        """
    }
    
    private var filterEmptyDescription: String {
        """
        Für deine aktuellen Filter wurden keine Erinnerungen gefunden.
        
        Versuche andere Suchbegriffe oder setze die Filter zurück, um alle deine Memories zu sehen.
        """
    }
}

// MARK: - Empty State Variations
extension EmptyStateView {
    
    /// Empty State für Suche ohne Ergebnisse
    static func searchEmpty(searchText: String, onCreateMemory: @escaping () -> Void, onClearSearch: @escaping () -> Void) -> some View {
        VStack(spacing: 24) {
            // Search Icon
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 35, weight: .light))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 12) {
                Text("Keine Treffer für \"\(searchText)\"")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Versuche andere Suchbegriffe oder erstelle eine neue Erinnerung.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                Button("Suche löschen") {
                    onClearSearch()
                }
                .buttonStyle(.bordered)
                
                Button("Neue Erinnerung") {
                    onCreateMemory()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 32)
    }
    
    /// Empty State für Trip-Filter ohne Ergebnisse
    static func tripFilterEmpty(tripName: String, onCreateMemory: @escaping () -> Void, onClearFilter: @escaping () -> Void) -> some View {
        VStack(spacing: 24) {
            // Trip Icon
            ZStack {
                Circle()
                    .fill(.green.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "suitcase.fill")
                    .font(.system(size: 35, weight: .light))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 12) {
                Text("Keine Erinnerungen für \"\(tripName)\"")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("Erstelle deine erste Erinnerung für diese Reise!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button("Erinnerung hinzufügen") {
                    onCreateMemory()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Alle Reisen anzeigen") {
                    onClearFilter()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Preview
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Standard Empty State
            EmptyStateView(
                hasFilters: false,
                onCreateFirstMemory: {}
            )
            .previewDisplayName("Erste Benutzung")
            
            // Filtered Empty State
            EmptyStateView(
                hasFilters: true,
                onCreateFirstMemory: {},
                onClearFilters: {}
            )
            .previewDisplayName("Filter aktiv")
            
            // Search Empty State
            EmptyStateView.searchEmpty(
                searchText: "Rom",
                onCreateMemory: {},
                onClearSearch: {}
            )
            .previewDisplayName("Suche leer")
            
            // Trip Filter Empty State
            EmptyStateView.tripFilterEmpty(
                tripName: "Italien Reise",
                onCreateMemory: {},
                onClearFilter: {}
            )
            .previewDisplayName("Trip Filter leer")
        }
    }
} 