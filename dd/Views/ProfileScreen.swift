import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject var localization: LocalizationManager

    var body: some View {
        NavigationView {
             VStack {
                 Image(systemName: "person.circle.fill")
                     .resizable()
                     .frame(width: 100, height: 100)
                     .foregroundColor(.gray)
                     .padding()
                 
                 Text("Guest User".localized)
                     .font(.title)
                     .bold()
                 
                 Form {
                     Section(header: Text("Language".localized)) {
                         Picker("Select Language".localized, selection: $localization.language) {
                             Text("English").tag("en")
                             Text("Azərbaycan").tag("az")
                         }
                         .pickerStyle(SegmentedPickerStyle())
                     }
                 }
                 .background(Color.clear) // clean look
                 
                 Spacer()
             }
             .navigationTitle("Profile".localized)
        }
    }
}
