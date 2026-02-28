import SwiftUI

struct FamilyListsScreen: View {
    let familyId: String
    let familyName: String
    
    @EnvironmentObject var localization: LocalizationManager
    @State private var lists: [ShoppingList] = []
    @State private var isLoading = false
    @State private var showingCreateList = false
    @State private var newListName = ""
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            if isLoading && lists.isEmpty {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if lists.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(lists) { list in
                        NavigationLink(destination: FamilyShoppingListScreen(familyId: familyId, familyName: familyName, listId: list.id)) {
                            listRow(list)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if let index = lists.firstIndex(where: { $0.id == list.id }) {
                                    deleteList(at: IndexSet(integer: index))
                                }
                            } label: {
                                Label("Delete".localized, systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .navigationTitle(familyName) // "Family Name" Lists
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingCreateList = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Shopping List".localized, isPresented: $showingCreateList) {
            TextField("List Name".localized, text: $newListName)
            Button("Cancel".localized, role: .cancel) { newListName = "" }
            Button("Create".localized) {
                Task {
                    await createList()
                }
            }
        } message: {
            Text("Enter a name for your new list".localized)
        }
        .task {
            await loadLists()
        }
        .refreshable {
            await loadLists(showLoading: false)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No shopping lists yet".localized)
                .font(.headline)
            
            Text("Create a list to start planning your shopping".localized)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button(action: { showingCreateList = true }) {
                Text("Create New List".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 200)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    private func listRow(_ list: ShoppingList) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(list.name)
                .font(.headline)
            
            HStack {
                if list.pendingCount > 0 {
                    Text("\(list.pendingCount) " + "items needed".localized)
                        .foregroundColor(.blue)
                        .font(.caption)
                        .bold()
                } else {
                    Text("All items purchased".localized)
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                Spacer()
                
                Text(formatDate(list.createdAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func loadLists(showLoading: Bool = true) async {
        if showLoading && lists.isEmpty {
            isLoading = true
            errorMessage = nil
        }
        do {
            lists = try await APIService.shared.getShoppingLists(familyId: familyId)
        } catch {
            if (error as? URLError)?.code == .cancelled || (error as NSError).code == NSURLErrorCancelled { return }
            if lists.isEmpty {
                errorMessage = error.localizedDescription
            }
            print("Error loading lists: \(error)")
        }
        isLoading = false
    }
    
    private func createList() async {
        guard !newListName.isEmpty else { return }
        
        do {
            let newList = try await APIService.shared.createShoppingList(familyId: familyId, name: newListName)
            lists.append(newList)
            newListName = ""
        } catch {
            print("Error creating list: \(error)")
        }
    }
    
    private func deleteList(at offsets: IndexSet) {
        offsets.forEach { index in
            let list = lists[index]
            withAnimation {
                lists.remove(at: index)
            }
            Task {
                do {
                    try await APIService.shared.deleteShoppingList(listId: list.id)
                    await loadLists(showLoading: false)
                } catch {
                    print("Error deleting list: \(error)")
                    await loadLists(showLoading: false)
                }
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return ""
    }
}
