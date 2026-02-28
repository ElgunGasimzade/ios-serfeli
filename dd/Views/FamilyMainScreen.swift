import SwiftUI

struct FamilyMainScreen: View {
    @EnvironmentObject var localization: LocalizationManager
    @StateObject var authService = AuthService.shared
    @State private var groups: [FamilyListItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Dialogs
    @State private var showCreateDialog = false
    @State private var showJoinDialog = false
    @State private var createGroupName = ""
    @State private var joinInviteCode = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 400)
                } else if groups.isEmpty {
                    noGroupsView
                } else {
                    groupsListView
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Group Shopping".localized)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showJoinDialog = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                    Button(action: { showCreateDialog = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await loadGroups(showLoading: false)
            }
            .task {
                await loadGroups()
            }
            .sheet(isPresented: $showCreateDialog) {
                CreateGroupSheet(onCreate: { name in
                    await createGroup(name: name)
                })
                .environmentObject(localization)
            }
            .sheet(isPresented: $showJoinDialog) {
                JoinGroupSheet(onJoin: { code in
                    await joinGroup(code: code)
                })
                .environmentObject(localization)
            }
        }
    }
    
    // MARK: - Groups List View
    
    private var groupsListView: some View {
        VStack(spacing: 16) {
            ForEach(groups) { group in
                GroupCard(group: group, onLeave: {
                    await leaveGroup(groupId: group.id)
                })
            }
        }
        .padding()
    }
    
    // MARK: - No Groups View
    
    private var noGroupsView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    )
                
                VStack(spacing: 8) {
                    Text("No Groups Yet".localized)
                        .font(.title2)
                        .bold()
                    Text("Create or join a group to start sharing shopping lists".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            VStack(spacing: 16) {
                Button(action: { showCreateDialog = true }) {
                    Text("Create Group".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(16)
                }
                
                Button(action: { showJoinDialog = true }) {
                    Text("Join with Code".localized)
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                }
            }
            .padding(.horizontal, 32)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Data Loading
    
    private func loadGroups(showLoading: Bool = true) async {
        guard let userId = authService.userId else {
            print("❌ LoadGroups: No userId")
            await MainActor.run {
                isLoading = false
                groups = []
            }
            return
        }
        
        print("📱 Loading groups for userId: \(userId)")
        if showLoading && groups.isEmpty {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
        }
        
        do {
            let response = try await APIService.shared.getFamilyList(userId: userId)
            print("✅ Received \(response.families.count) groups")
            for family in response.families {
                print("   - \(family.name) (\(family.role))")
            }
            await MainActor.run {
                self.groups = response.families
                self.isLoading = false
            }
        } catch {
            if (error as? URLError)?.code == .cancelled || (error as NSError).code == NSURLErrorCancelled { return }
            print("❌ Error loading groups: \(error)")
            await MainActor.run {
                // Keep existing groups on error, just stop loading
                self.isLoading = false
                // Only show error message, don't clear groups
                if self.groups.isEmpty {
                    self.errorMessage = "Failed to load groups"
                }
            }
        }
    }
    
    private func createGroup(name: String) async {
        guard let userId = authService.userId else {
            await MainActor.run {
                errorMessage = "Not logged in. Please restart the app."
            }
            print("❌ Create group failed: No userId")
            return
        }
        
        print("📱 Creating group with userId: \(userId), name: \(name)")
        errorMessage = nil
        let previousCount = groups.count
        
        do {
            let response = try await APIService.shared.createFamily(userId: userId, familyName: name)
            print("✅ Group created successfully: \(response.family?.name ?? "Unknown")")
            try? await Task.sleep(nanoseconds: 500_000_000)
            await loadGroups(showLoading: false)
        } catch {
            print("❌ Error creating group: \(error)")
            try? await Task.sleep(nanoseconds: 500_000_000)
            await loadGroups(showLoading: false)
            
            await MainActor.run {
                if self.groups.count <= previousCount {
                    self.errorMessage = "Failed to create group."
                }
            }
        }
    }
    
    private func joinGroup(code: String) async {
        guard let userId = authService.userId else { return }
        
        errorMessage = nil
        let previousCount = groups.count
        
        do {
            _ = try await APIService.shared.joinFamily(userId: userId, inviteCode: code)
            try? await Task.sleep(nanoseconds: 500_000_000)
            await loadGroups(showLoading: false)
        } catch {
            print("❌ Error joining group: \(error)")
            try? await Task.sleep(nanoseconds: 500_000_000)
            await loadGroups(showLoading: false)
            
            await MainActor.run {
                if self.groups.count <= previousCount {
                    self.errorMessage = "Failed to join. Check the code."
                }
            }
        }
    }
    
    private func leaveGroup(groupId: String) async {
        guard let userId = authService.userId else { return }
        
        let previousCount = groups.count
        
        do {
            try await APIService.shared.leaveFamily(userId: userId, familyId: groupId)
            try? await Task.sleep(nanoseconds: 500_000_000)
            await loadGroups(showLoading: false)
        } catch {
            print("❌ Error leaving group: \(error)")
            try? await Task.sleep(nanoseconds: 500_000_000)
            await loadGroups(showLoading: false)
            
            await MainActor.run {
                if self.groups.count >= previousCount {
                    self.errorMessage = "Failed to leave group."
                }
            }
        }
    }
}

// MARK: - Group Card

struct GroupCard: View {
    let group: FamilyListItem
    let onLeave: () async -> Void
    @EnvironmentObject var localization: LocalizationManager
    @State private var isExpanded = false
    @State private var showLeaveAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - Always Visible
            Button(action: {
                withAnimation { isExpanded.toggle() }
            }) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(group.role == "admin" ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: group.role == "admin" ? "crown.fill" : "person.3.fill")
                                .foregroundColor(group.role == "admin" ? .orange : .blue)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2")
                                    .font(.caption)
                                Text("\(group.memberCount)")
                                    .font(.caption).bold()
                            }
                            .foregroundColor(.gray)
                            
                            if group.pendingItemsCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "cart")
                                        .font(.caption)
                                    Text("\(group.pendingItemsCount)")
                                        .font(.caption).bold()
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
            }
            .buttonStyle(.plain)
            
            // Expanded Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                    
                    // Invite Code
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Invite Code".localized)
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(group.inviteCode)
                                .font(.system(.body, design: .monospaced))
                                .bold()
                        }
                        Spacer()
                        Button(action: {
                            UIPasteboard.general.string = group.inviteCode
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy".localized)
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons
                    VStack(spacing: 8) {
                        NavigationLink(destination: FamilyListsScreen(familyId: group.id, familyName: group.name)
                            .environmentObject(localization)) {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("Shopping Lists".localized)
                                Spacer()
                                if group.pendingItemsCount > 0 {
                                    Text("\(group.pendingItemsCount)")
                                        .font(.caption).bold()
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .foregroundColor(.primary)
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                        }
                        
                        Button(action: { showLeaveAlert = true }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Leave Group".localized)
                                Spacer()
                            }
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .alert("Leave Group?".localized, isPresented: $showLeaveAlert) {
            Button("Leave".localized, role: .destructive) {
                Task { await onLeave() }
            }
            Button("Cancel".localized, role: .cancel) { }
        } message: {
            Text("Are you sure you want to leave".localized + " \(group.name)?")
        }
    }
}

// MARK: - Create/Join Sheets

struct CreateGroupSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localization: LocalizationManager
    let onCreate: (String) async -> Void
    
    @State private var groupName = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Group Name".localized)) {
                    TextField("e.g., My Family, Roommates".localized, text: $groupName)
                        .autocapitalization(.words)
                }
                
                Section {
                    Text("Create a group to share shopping lists with family and friends".localized)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Create Group".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create".localized) {
                        Task {
                            isCreating = true
                            await onCreate(groupName)
                            isCreating = false
                            dismiss()
                        }
                    }
                    .disabled(groupName.isEmpty || isCreating)
                }
            }
        }
    }
}

struct JoinGroupSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localization: LocalizationManager
    let onJoin: (String) async -> Void
    
    @State private var inviteCode = ""
    @State private var isJoining = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Invite Code".localized)) {
                    TextField("6-digit code".localized, text: $inviteCode)
                        .keyboardType(.numberPad)
                        .autocapitalization(.none)
                }
                
                Section {
                    Text("Enter the 6-digit invite code shared by a group member".localized)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Join Group".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join".localized) {
                        Task {
                            isJoining = true
                            await onJoin(inviteCode)
                            isJoining = false
                            dismiss()
                        }
                    }
                    .disabled(inviteCode.isEmpty || isJoining)
                }
            }
        }
    }
}
