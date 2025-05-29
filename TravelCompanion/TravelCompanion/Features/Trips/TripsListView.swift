import SwiftUI

/// Placeholder Trips List View
struct TripsListView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "suitcase")
                    .font(.system(size: 60))
                    .foregroundColor(.green.opacity(0.6))
                
                VStack(spacing: 12) {
                    Text("Reisen")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Hier verwaltest du alle deine Reisen und kannst neue erstellen.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reisen")
        }
    }
}

struct TripsListView_Previews: PreviewProvider {
    static var previews: some View {
        TripsListView()
    }
} 