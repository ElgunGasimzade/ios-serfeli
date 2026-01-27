import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject var localization: LocalizationManager
    @StateObject var locationManager = LocationManager.shared
    @StateObject var authService = AuthService.shared
    
    @State private var isEditingUsername = false
    @State private var editUsernameText = ""
    
    @State private var isEditing = false
    @State private var editEmail = ""
    @State private var editPhone = ""
    
    var body: some View {
        NavigationView {
             VStack {
                 // Avatar
                 Image(systemName: "person.circle.fill")
                     .resizable()
                     .frame(width: 80, height: 80)
                     .foregroundColor(.gray.opacity(0.8))
                     .padding(.top)
                 
                 // User Info Display
                 if !isEditing {
                     VStack(spacing: 8) {
                         // Username with Edit Pencil
                         HStack {
                             Text(authService.user?.username ?? "User")
                                 .font(.title2)
                                 .bold()
                             
                             Button(action: {
                                 editUsernameText = authService.user?.username ?? ""
                                 isEditingUsername = true
                             }) {
                                 Image(systemName: "pencil.circle.fill")
                                     .foregroundColor(.blue)
                                     .font(.system(size: 20))
                             }
                         }
                         
                         // Email
                         if let email = authService.user?.email, !email.isEmpty {
                             Text(email)
                                 .font(.subheadline)
                                 .foregroundColor(.gray)
                         }
                         
                         // Phone
                         if let phone = authService.user?.phone, !phone.isEmpty {
                             Text(phone)
                                 .font(.subheadline)
                                 .foregroundColor(.gray)
                         } else {
                             // Only show if actually missing
                             Text("Add phone number".localized)
                                 .font(.caption)
                                 .foregroundColor(.blue)
                                 .onTapGesture {
                                     startEditing()
                                 }
                         }
                     }
                     .padding(.bottom)
                 }

                 Form {
                     // Profile Edit Section
                     Section(header: Text("Personal Info".localized)) {
                         if isEditing {
                             TextField("Email", text: $editEmail)
                                 .keyboardType(.emailAddress)
                                 .autocapitalization(.none)
                             TextField("Phone Number", text: $editPhone)
                                 .keyboardType(.phonePad)
                             
                             if let error = errorMessage {
                                 Text(error)
                                     .font(.caption)
                                     .foregroundColor(.red)
                                     .padding(.vertical, 4)
                             }
                             
                             Button(action: saveProfile) {
                                 Text("Save Changes".localized)
                                     .bold()
                                     .frame(maxWidth: .infinity)
                                     .foregroundColor(.blue)
                             }
                             
                             Button(action: cancelEdit) {
                                 Text("Cancel".localized)
                                     .font(.caption)
                                     .foregroundColor(.red)
                                     .frame(maxWidth: .infinity)
                             }
                             
                         } else {
                             Button(action: startEditing) {
                                 HStack {
                                     Text("Edit Contact Info".localized) // Changed text to differ from Username edit
                                     Spacer()
                                     Image(systemName: "pencil")
                                 }
                             }
                         }
                     }
                     
                     Section(header: Text("Language".localized)) {
                         Picker("Select Language".localized, selection: $localization.language) {
                             Text("English").tag("en")
                             Text("Azərbaycan").tag("az")
                         }
                         .pickerStyle(SegmentedPickerStyle())
                     }
                     
                     Section(header: Text("Location Settings")) {
                         Toggle("Enable Location", isOn: $locationManager.isLocationEnabled)
                         
                         if locationManager.isLocationEnabled {
                             VStack(alignment: .leading) {
                                 Text("Search Range: \(Int(locationManager.searchRangeKm)) km")
                                 Slider(value: $locationManager.searchRangeKm, in: 1...20, step: 1)
                             }
                         }
                     }
                 }
                 .background(Color(UIColor.systemGroupedBackground))
                 
                 Spacer()
             }
             .navigationTitle("Profile".localized)
             // Username Edit Alert
             .alert("Edit Username", isPresented: $isEditingUsername) {
                 TextField("Username", text: $editUsernameText)
                 Button("Save") {
                     authService.updateProfile(email: nil, phone: nil, username: editUsernameText)
                 }
                 Button("Cancel", role: .cancel) { }
             }
        }
    }
    
    @State private var errorMessage: String?
    
    // ... existing view ...
    
    private func startEditing() {
        editEmail = authService.user?.email ?? ""
        editPhone = authService.user?.phone ?? ""
        errorMessage = nil
        withAnimation { isEditing = true }
    }
    
    private func cancelEdit() {
        withAnimation { isEditing = false }
    }
    
    private func saveProfile() {
        guard isValidEmail(editEmail) else {
            errorMessage = "Invalid email format"
            return
        }
        
        guard authService.userId != nil else {
            errorMessage = "User not found. Try restarting app."
            return
        }
        
        // Only sending email/phone here. Username handled separately.
        authService.updateProfile(email: editEmail, phone: editPhone, username: nil)
        withAnimation { isEditing = false }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        if email.isEmpty { return true } // Allow empty if user clears it
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}
