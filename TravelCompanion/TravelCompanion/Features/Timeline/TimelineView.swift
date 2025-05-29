import SwiftUI
import CoreData

/// Placeholder Timeline View
struct TimelineView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "clock")
                    .font(.system(size: 60))
                    .foregroundColor(.blue.opacity(0.6))
                
                VStack(spacing: 12) {
                    Text("Timeline")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Hier werden alle deine Memories chronologisch angezeigt.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Timeline")
        }
    }
}

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineView()
    }
} 