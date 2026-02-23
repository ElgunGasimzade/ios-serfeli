import SwiftUI
import CoreLocation

struct FamilyShoppingListScreen: View {
    let familyId: String
    let familyName: String
    var listId: Int? = nil // Optional listId for multi-list support
    
    @EnvironmentObject var localization: LocalizationManager
    @StateObject var authService = AuthService.shared
    @StateObject var locationManager = LocationManager.shared
    
    @State private var items: [FamilyShoppingItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Selection Mode
    @State private var isSelectionMode = false
    @State private var selectedItemIds: Set<String> = []
    
    // Add Items Flow
    @State private var showAddItemsScreen = false
    @State private var editingItem: FamilyShoppingItem? // For inline editing
    @State private var selectingBrandForItem: FamilyShoppingItem? // For re-selecting brand/store
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 400)
            } else if items.isEmpty {
                emptyStateView
            } else {
                shoppingListView
            }
        }
        .navigationTitle(familyName)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if !isSelectionMode {
                        Button(action: { showAddItemsScreen = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            // Add a delete button in toolbar if items selected?
            if isSelectionMode && !selectedItemIds.isEmpty {
                 ToolbarItem(placement: .bottomBar) {
                     Button("Delete Selected") {
                         Task {
                             await deleteSelectedItems()
                         }
                     }
                     .foregroundColor(.red)
                 }
            }
        }
        .sheet(isPresented: $showAddItemsScreen) {
            AddItemsToFamilyListScreen(familyId: familyId, listId: listId) {
                await loadShoppingList()
            }
            .environmentObject(localization)
        }
        .sheet(item: $editingItem) { item in
            EditFamilyItemScreen(item: item) { quantity, notes in
                await updateItem(item, quantity: quantity, notes: notes)
            }
        }
        .sheet(item: $selectingBrandForItem) { item in
            BrandSelectionForFamilyScreen(
                items: [item.itemName],
                onCommit: { selectedItems in
                    if let first = selectedItems.first {
                        Task {
                            await updateItemBrand(item, brand: first.brand, store: first.store, price: first.price, originalPrice: first.originalPrice, productId: first.productId)
                        }
                    }
                }
            )
        }
        .task {
            await loadShoppingList()
        }
        .refreshable {
            await loadShoppingList()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Items Yet")
                    .font(.title3)
                    .bold()
                Text("Add items to start your family shopping list")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showAddItemsScreen = true }) {
                Label("Add Items", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Shopping List View
    
    private var shoppingListView: some View {
        List {
            // Header Stats
            Section {
                if !isSelectionMode {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(items.count) Items")
                                .font(.title2)
                                .bold()
                            Text("\(pendingCount) pending • \(purchasedCount) purchased")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // Total Cost Display
                        if totalPendingCost > 0 {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Total Estimate")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(String(format: "%.2f ₼", totalPendingCost))
                                    .font(.headline)
                                    .bold()
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                } else {
                    Text("\(selectedItemIds.count) selected")
                        .font(.headline)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(Color.clear)
                }
            }
            
            // Items
            ForEach(items) { item in
                FamilyShoppingItemCard(
                    item: item,
                    isSelectionMode: isSelectionMode,
                    isSelected: selectedItemIds.contains(item.id),
                    onToggle: {
                        if isSelectionMode {
                            if selectedItemIds.contains(item.id) {
                                selectedItemIds.remove(item.id)
                            } else {
                                selectedItemIds.insert(item.id)
                            }
                        } else {
                            await toggleItemStatus(item)
                        }
                    },
                    onEdit: {
                        if !isSelectionMode {
                             // Open Brand Selection to re-choose deal
                             selectingBrandForItem = item
                        }
                    },
                    onDelete: {
                       // Handled by swipe
                    },
                    onQuantityChange: { delta in
                        if !isSelectionMode {
                            Task {
                                let newQuantity = max(1, item.quantity + delta)
                                await updateItem(item, quantity: newQuantity, notes: item.notes)
                            }
                        }
                    }
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if !isSelectionMode {
                        Button(role: .destructive) {
                            Task { await deleteItem(item) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            selectingBrandForItem = item
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // ... existing helper methods ...
    
    // Updated updateItemBrand to handle price/originalPrice
    private func updateItemBrand(_ item: FamilyShoppingItem, brand: String?, store: String?, price: Double?, originalPrice: Double?, productId: String?) async {
        do {
            try await APIService.shared.updateFamilyShoppingItem(
                itemId: item.id,
                brandName: brand,
                storeName: store,
                price: price,
                originalPrice: originalPrice,
                productId: productId
            )
            await loadShoppingList(showLoading: false)
        } catch {
            print("Error updating item brand: \(error)")
        }
    }
    
    // MARK: - Computed Properties
    
    private var pendingCount: Int {
        items.filter { $0.status == "pending" }.count
    }
    
    private var purchasedCount: Int {
        items.filter { $0.status == "purchased" }.count
    }
    
    private var totalPendingCost: Double {
        items.filter { $0.status == "pending" }
             .reduce(0) { sum, item in
                 let cost = (item.price ?? 0) * Double(item.quantity)
                 return sum + cost
             }
    }
    
    // MARK: - API Actions
    
    private func loadShoppingList(showLoading: Bool = true) async {
        if showLoading && items.isEmpty {
            isLoading = true
        }
        do {
            let response = try await APIService.shared.getFamilyShoppingList(familyId: familyId, listId: listId)
            withAnimation {
                self.items = response.items
            }
        } catch {
            print("Error loading list: \(error)")
            if items.isEmpty {
                errorMessage = "Failed to load items"
            }
        }
        isLoading = false
    }
    
    private func updateItem(_ item: FamilyShoppingItem, quantity: Int? = nil, notes: String? = nil) async {
        do {
            try await APIService.shared.updateFamilyShoppingItem(
                itemId: item.id,
                quantity: quantity,
                notes: notes
            )
            await loadShoppingList(showLoading: false)
        } catch {
            print("Error updating item: \(error)")
        }
    }
    
    private func toggleItemStatus(_ item: FamilyShoppingItem) async {
        let newStatus = item.status == "pending" ? "purchased" : "pending"
        do {
            // Optimistic update
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                withAnimation {
                    // Update local state immediately for UI responsiveness
                    // We can't easily mutate the struct in array, but we can reload.
                    // Or create a modified copy.
                     // items[index] = ... (simulated)
                }
            }
            
            try await APIService.shared.updateFamilyShoppingItem(
                itemId: item.id,
                status: newStatus,
                purchasedBy: newStatus == "purchased" ? authService.userId : nil
            )
            await loadShoppingList(showLoading: false)
        } catch {
            print("Error toggling status: \(error)")
        }
    }
    
    private func deleteItem(_ item: FamilyShoppingItem) async {
        withAnimation {
            items.removeAll { $0.id == item.id }
        }
        do {
            try await APIService.shared.deleteFamilyShoppingItem(itemId: item.id)
            await loadShoppingList(showLoading: false)
        } catch {
             print("Error deleting item: \(error)")
             await loadShoppingList(showLoading: false)
        }
    }
    
    private func deleteSelectedItems() async {
        let idsToDelete = selectedItemIds
        withAnimation {
            items.removeAll { idsToDelete.contains($0.id) }
        }
        for id in idsToDelete {
             do {
                 try await APIService.shared.deleteFamilyShoppingItem(itemId: id)
             } catch {
                 print("Error deleting item \(id): \(error)")
             }
        }
        selectedItemIds.removeAll()
        isSelectionMode = false
        await loadShoppingList(showLoading: false)
    }
}

// MARK: - Item Card Component

struct FamilyShoppingItemCard: View {
    let item: FamilyShoppingItem
    var isSelectionMode: Bool
    var isSelected: Bool = false
    let onToggle: () async -> Void
    let onEdit: () -> Void
    let onDelete: () async -> Void
    var onQuantityChange: ((Int) -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button(action: {
                Task { await onToggle() }
            }) {
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .gray)
                } else {
                    Image(systemName: item.status == "purchased" ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(item.status == "purchased" ? .green : .gray)
                }
            }
            .padding(.top, 4)
            .buttonStyle(PlainButtonStyle()) // Important for List interaction
            
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(item.itemName)
                    .font(.headline)
                    .strikethrough(item.status == "purchased")
                    .foregroundColor(item.status == "purchased" ? .gray : .primary)
                
                // Brand / Store
                if let brand = item.brandName {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                if let store = item.storeName {
                    HStack {
                        Image(systemName: "cart.fill")
                            .font(.caption2)
                        Text(store)
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                
                // Price Display
                if let price = item.price {
                    HStack(spacing: 8) {
                        Text(String(format: "%.2f ₼", price))
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.green)
                        
                        if let original = item.originalPrice, original > price {
                            Text(String(format: "%.2f ₼", original))
                                .font(.caption)
                                .strikethrough()
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                     // Debug: Show if no price
                }
                
                // Notes and Added By
                HStack {
                    if let notes = item.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .italic()
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text("Added by \(item.addedBy.username)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Quantity Control
            if !isSelectionMode && item.status == "pending" {
                VStack(spacing: 8) {
                    // Only Quantity here, Edit is via swipe or tap (maybe tap cell to edit?)
                    // User asked for "Edit button directs to brand selection".
                    // But if we remove the visual Edit button from the card, how do they edit?
                    // User said "remove delete button make it shown when slide to left".
                    // They didn't explicitly say remove Edit button.
                    // But usually swipe has Edit too. 
                    // Let's keep a small edit button or rely on swipe?
                    // "when click edit button then save this occur" -> implies there IS an edit button.
                    // I'll keep the ellipsis menu but REMOVE "Delete" from it, and CHANGE "Edit" to "Re-select Brand".
                    
                    Menu {
                        Button(action: onEdit) {
                            Label("Change Brand/Deal", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.gray)
                            .padding(8)
                    }
                    .highPriorityGesture(TapGesture()) // Prevent List selection
                    
                    // Quantity
                    HStack(spacing: 0) {
                        Button(action: { onQuantityChange?(-1) }) {
                            Image(systemName: "minus")
                                .font(.caption)
                                .frame(width: 24, height: 24)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text("\(item.quantity)")
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 24)
                            .multilineTextAlignment(.center)
                        
                        Button(action: { onQuantityChange?(1) }) {
                            Image(systemName: "plus")
                                .font(.caption)
                                .frame(width: 24, height: 24)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct EditFamilyItemScreen: View {
    @Environment(\.dismiss) var dismiss
    
    let item: FamilyShoppingItem
    let onSave: (Int, String?) async -> Void
    
    @State private var quantity: Int
    @State private var notes: String
    
    init(item: FamilyShoppingItem, onSave: @escaping (Int, String?) async -> Void) {
        self.item = item
        self.onSave = onSave
        _quantity = State(initialValue: item.quantity)
        _notes = State(initialValue: item.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    Text(item.itemName)
                        .font(.headline)
                    
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                    
                    TextField("Notes (optional)", text: $notes)
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await onSave(quantity, notes.isEmpty ? nil : notes)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
