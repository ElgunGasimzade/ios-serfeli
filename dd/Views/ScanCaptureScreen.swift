import SwiftUI

struct ScanCaptureScreen: View {
    @State private var isScanning = true
    @State private var showResults = false
    @State private var detectedItems: [DetectedItem] = []
    @State private var scanPhase = 0.0 // Animation
    @State private var currentScanId: String? = nil
    @State private var navigateToDeals = false
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
        NavigationView {
            ZStack {
                if isScanning {
                    CameraPreview()
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                }
                
                // Overlay
                VStack {
                    // Top controls?
                    HStack {
                        Spacer()
                        if isScanning {
                             Text("SCANNING".localized)
                                .font(.caption).bold()
                                .padding(8)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                                .padding()
                        }
                    }
                    
                    Spacer()
                    
                    // Framing Box
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 300, height: 400)
                        
                        // Scan Line
                        if isScanning {
                            Rectangle()
                                .fill(LinearGradient(colors: [.blue.opacity(0), .blue.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                                .frame(width: 300, height: 200)
                                .offset(y: scanPhase - 200) // Start from top
                                .mask(RoundedRectangle(cornerRadius: 24).frame(width: 300, height: 400))
                                .onAppear {
                                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                        scanPhase = 400
                                    }
                                }
                        }
                    }
                    
                    Spacer()
                    
                    // Helper Text
                    Text(isScanning ? "Hold steady. Scanning items...".localized : "Scan Complete!".localized)
                        .font(.subheadline).bold()
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .foregroundColor(.white)
                    
                    Spacer().frame(height: 50)
                }
                
                // Bottom Sheet mechanism
                if showResults {
                    VStack {
                        Spacer()
                        ResultsSheet(items: $detectedItems) {
                            Task {
                                // Confirm items before navigating
                                if let scanId = currentScanId {
                                    do {
                                        _ = try await APIService.shared.confirmScan(scanId: scanId, items: detectedItems)
                                        // Navigate to deals with scanId
                                        navigateToDeals = true
                                    } catch {
                                        print("Error confirming scan: \(error)")
                                        // Fallback navigate anyway
                                        navigateToDeals = true
                                    }
                                }
                            }
                        }
                        .transition(.move(edge: .bottom))
                    }
                    .zIndex(1)
                } else if !isScanning && detectedItems.isEmpty {
                     // Error state or empty
                     VStack {
                        Text("No items detected".localized)
                            .foregroundColor(.white)
                        Button("Try Again".localized) {
                            isScanning = true
                            scanPhase = 0
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                     }
                }
                
                // Navigation Link (Hidden)
                NavigationLink(destination: BrandSelectionScreen(scanId: currentScanId), isActive: $navigateToDeals) {
                    EmptyView()
                }
            }
            .navigationBarHidden(true)
            .task {
                // Simulate scan delay then fetch
                if isScanning {
                    try? await Task.sleep(nanoseconds: 3 * 1_000_000_000) // 3 sec scan
                    do {
                        // Pass dummy data, mock service handles it
                        let response = try await APIService.shared.processScan(imageData: Data())
                        detectedItems = response.detectedItems
                        currentScanId = response.scanId
                        isScanning = false
                        withAnimation {
                            showResults = true
                        }
                    } catch {
                        print("Error scanning: \(error)")
                        isScanning = false
                        // Show retry UI implemented above
                    }
                }
            }
        }
    }
}

struct ResultsSheet: View {
    @Binding var items: [DetectedItem]
    let onFindDeals: () -> Void
    @State private var isExpanded = true // Simplified for now
    @State private var showingAddItem = false
    @State private var newItemName = ""
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Drag handle
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            
            HStack {
                Text("Detected Items".localized).font(.title2).bold()
                Text("(\(items.count))").font(.title2).bold().foregroundColor(.blue)
                Spacer()
                Button(action: { showingAddItem = true }) {
                    Label("Add Item".localized, systemImage: "plus")
                }
            }
            .padding(.horizontal)
            .alert("Add Item".localized, isPresented: $showingAddItem) {
                TextField("Item Name".localized, text: $newItemName)
                Button("Cancel".localized, role: .cancel) { newItemName = "" }
                Button("Add".localized) {
                    if !newItemName.isEmpty {
                        let newItem = DetectedItem(
                            id: UUID().uuidString,
                            name: newItemName,
                            confidence: 1.0,
                            boundingBox: nil,
                            dealAvailable: true, // Optimistic
                            imageUrl: nil
                        )
                        items.append(newItem)
                        newItemName = ""
                    }
                }
            }
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        DetectedItemRow(item: item) {
                             if let index = items.firstIndex(where: { $0.id == item.id }) {
                                 items.remove(at: index)
                             }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 300)
            
            Button(action: onFindDeals) {
                HStack {
                    Text("Find Best Deals".localized).bold()
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding()
        }
        .background(Color.white)
        .cornerRadius(24)
        .shadow(radius: 10)
    }
}

struct DetectedItemRow: View {
    let item: DetectedItem
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            // Icon or Image
            if let url = item.imageUrl {
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.1)
                }
                .frame(width: 40, height: 40)
                .cornerRadius(8)
                .clipped()
            } else {
                Image(systemName: item.dealAvailable ? "checkmark.circle" : "questionmark.circle")
                    .foregroundColor(item.dealAvailable ? .blue : .gray)
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Text(item.name).font(.body)
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark").foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
