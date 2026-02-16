import SwiftUI

struct ShoppingPlanScreen: View {
    var selectedIds: [String] = []
    @State private var response: OptimizeResponse?
    @State private var isLoading = true
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("We found ways".localized + "\n" + "to complete your list.".localized)
                        .font(.title)
                        .bold()
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Choose the option that fits your schedule.".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.top, 24)
                .padding(.bottom, 24)
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let options = response?.options {
                    VStack(spacing: 24) {
                        ForEach(options) { option in
                             RouteOptionCard(option: option)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                } else {
                    Text("No routes calculated.".localized)
                        .padding()
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                response = try await APIService.shared.getRouteOptions(ids: selectedIds)
            } catch {
                print("Error loading plan: \(error)")
            }
            isLoading = false
        }
    }
}

struct RouteOptionCard: View {
    let option: RouteOption
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
        cardContent
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            
            if let desc = option.description {
                Text(localizeDescription(desc))
                    .font(.body)
                    .foregroundColor(.gray)
            }
            
            stopsSection
            
            Divider()
            
            HStack {
                Image(systemName: "car.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(option.totalDistance) " + "total".localized)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Replace NavigationLink with Button for custom logic
                Button(action: {
                    selectRoute(option: option)
                }) {
                     Text("Select Route".localized)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(option.type == "MAX_SAVINGS" ? .white : .black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(option.type == "MAX_SAVINGS" ? Color.green : Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: option.type == "MAX_SAVINGS" ? 0 : 1)
                        )
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(option.type == "MAX_SAVINGS" ? Color.green : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if option.type == "MAX_SAVINGS" {
                Text("MAX SAVINGS".localized)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(10, corners: [.bottomLeft])
            }
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(option.type == "MAX_SAVINGS" ? "OPTION A".localized : "OPTION B".localized)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Text("\("Save".localized) \(String(format: "%.2f", option.totalSavings)) ₼")
                    .font(.title2)
                    .bold()
            }
            Spacer()
            
            Image(systemName: option.type == "MAX_SAVINGS" ? "basket.fill" : "clock.fill")
                .foregroundColor(option.type == "MAX_SAVINGS" ? .green : .blue)
                .frame(width: 40, height: 40)
                .background(option.type == "MAX_SAVINGS" ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                .clipShape(Circle())
        }
    }
    
    private var stopsSection: some View {
        Group {
            if option.type == "MAX_SAVINGS" {
                multiStopView
            } else {
                singleStopView
            }
        }
    }
    
    private var multiStopView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(option.stops.enumerated()), id: \.element.id) { index, stop in
                HStack(alignment: .top, spacing: 12) {
                    stopIndicator(index: index)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.store).bold()
                        Text(stop.summary)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, index < option.stops.count - 1 ? 24 : 0)
                }
            }
        }
        .padding(.leading, 8)
        .padding(.vertical, 8)
    }
    
    private func stopIndicator(index: Int) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.black)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle().stroke(Color.white, lineWidth: 2)
                )
            if index < option.stops.count - 1 {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 16)
    }
    
    private var singleStopView: some View {
        HStack {
            Image(systemName: "building.2")
                .foregroundColor(.gray)
                .frame(width: 40, height: 40)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
            
            VStack(alignment: .leading) {
                Text(option.stops.first?.store ?? "Store".localized)
                    .bold()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func selectRoute(option: RouteOption) {
        Task {
            do {
                let details = try await APIService.shared.getRouteDetails(optionId: option.id)
                await RouteCacheService.shared.saveRoute(details)
                DispatchQueue.main.async {
                     NotificationCenter.default.post(name: NSNotification.Name("SwitchToPFM"), object: nil)
                }
            } catch {
                print("Error caching route: \(error)")
            }
        }
    }
    
    private func localizeDescription(_ desc: String) -> String {
        if desc == "Save more by visiting multiple stores." {
            return "Save more by visiting multiple stores.".localized
        } else if desc == "No single store has these items." {
            return "No single store has these items.".localized
        } else if desc.hasPrefix("Get everything at ") {
            let store = String(desc.dropFirst("Get everything at ".count).dropLast(1)) // Remove prefix and trailing dot
            return "Get everything at".localized + " " + store
        }
        return desc.localized
    }
}
