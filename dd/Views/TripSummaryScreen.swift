import SwiftUI

struct TripSummaryScreen: View {
    @State private var response: TripSummaryResponse?
    @State private var isLoading = true
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Summary
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "party.popper.fill")
                                .font(.title)
                                .foregroundColor(.green)
                        )
                    
                    VStack(spacing: 8) {
                        Text("TOTAL SAVINGS".localized)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                            .tracking(1)
                        
                        Text("\(String(format: "%.2f", response?.totalSavings ?? 0)) ₼")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(.green)
                        
                        Text("You spent".localized + " \(response?.timeSpent ?? "--") " + "shopping.".localized)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 64)
                .padding(.bottom, 40)
                .background(Color.white)
                .cornerRadius(40, corners: [.bottomLeft, .bottomRight])
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 24) {
                    // Lifetime Stats Card
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("Lifetime Earnings".localized)
                                .font(.headline)
                            Spacer()
                            Text("All Time".localized)
                                .font(.caption).bold()
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("\(String(format: "%.2f", response?.lifetimeEarnings ?? 0)) ₼")
                                .font(.largeTitle).bold()
                            Text("saved total".localized)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        // Simple Chart Mock
                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach(0..<8) { i in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.green)
                                    .frame(height: CGFloat([30, 45, 25, 60, 40, 75, 50, 90][i]))
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.gray.opacity(0.1))
                                            .frame(height: 100)
                                    )
                            }
                        }
                        .frame(height: 100)
                        
                        HStack {
                            ForEach(["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug"], id: \.self) { month in
                                Text(month.localized)
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.05), radius: 5)
                    
                    // Impact Metrics
                    HStack(spacing: 16) {
                        MetricCard(
                            icon: "dot.radiowaves.left.and.right",
                            color: .purple,
                            value: "\(response?.dealsScouted ?? 0)",
                            title: "Deals Scouted".localized,
                            subtitle: "Prices checked by us so you don't have to.".localized
                        )
                        
                        MetricCard(
                            icon: "timer",
                            color: .blue,
                            value: "\(String(format: "%.2f", response?.wagePerHour ?? 0)) ₼/hr",
                            title: "Your \"Wage\"".localized,
                            subtitle: "Value earned vs time spent shopping.".localized
                        )
                    }
                    
                    Button(action: {
                        // Reset to Home
                        // For now just dismiss
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Back to Home".localized)
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                .padding()
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .edgesIgnoringSafeArea(.top)
        .navigationBarHidden(true)
        .task {
            do {
                response = try await APIService.shared.getTripSummary()
            } catch {
                print("Error loading summary: \(error)")
            }
            isLoading = false
        }
    }
}

struct MetricCard: View {
    let icon: String
    let color: Color
    let value: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2).bold()
                Text(title)
                    .font(.caption).bold()
                    .foregroundColor(.gray)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// Helper for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
