import SwiftUI

struct MapSelectionSheet: View {
    @Binding var isPresented: Bool
    let apps: [MapApp]
    let onSelect: (MapApp) -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if isPresented {
                // Dimmed Background
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }
                    .transition(.opacity)
                
                // Sheet Content
                VStack(spacing: 16) {
                    // Handle Bar
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 10)
                    
                    Text("Directions".localized)
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    ForEach(apps) { app in
                        Button(action: {
                            onSelect(app)
                            withAnimation {
                                isPresented = false
                            }
                        }) {
                            HStack {
                                Image(systemName: iconName(for: app))
                                    .font(.title2)
                                    .frame(width: 30)
                                    .foregroundColor(.blue)
                                
                                Text(app.localizedName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    
                    Button(action: {
                        withAnimation {
                            isPresented = false
                        }
                    }) {
                        Text("Cancel".localized)
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .shadow(radius: 20)
                .transition(.move(edge: .bottom))
                .padding(.bottom, 0) // Align to very bottom
            }
        }
        .zIndex(100) // Ensure it sits on top
    }
    
    func iconName(for app: MapApp) -> String {
        switch app {
        case .appleMaps: return "map"
        case .googleMaps: return "map.fill"
        case .waze: return "car.fill"
        }
    }
}
