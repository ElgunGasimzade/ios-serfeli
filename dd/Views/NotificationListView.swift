import SwiftUI

struct NotificationListView: View {
    @StateObject private var notifManager = NotificationManager.shared
    @State private var notifications: [NotificationItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var page = 1
    @State private var canLoadMore = true
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
                
                Spacer()
                
                Text("Notifications")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                
                Spacer()
                
                Button(action: {
                    Task { await markAllRead() }
                }) {
                    Text("Read All")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 20)
            
            if isLoading && notifications.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack {
                    Text(error).foregroundColor(.red)
                    Button("Retry") {
                        Task { await loadNotifications(reload: true) }
                    }
                }
            } else if notifications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("No notifications yet")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(notifications) { notif in
                            NotificationRowView(
                                notification: notif,
                                markAsRead: {
                                    if !notif.isRead { Task { await markRead(id: notif.id) } }
                                },
                                deleteAction: {
                                    Task { await deleteNotif(id: notif.id) }
                                }
                            )
                            .onAppear {
                                if notif.id == notifications.last?.id {
                                    Task { await loadNotifications(reload: false) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .task {
            await loadNotifications(reload: true)
        }
    }
    
    private func loadNotifications(reload: Bool) async {
        guard !isLoading || reload else { return }
        if reload {
            page = 1
            canLoadMore = true
        }
        guard canLoadMore else { return }
        
        isLoading = true
        do {
            let res = try await APIService.shared.getNotifications(page: page, limit: 20)
            if reload {
                notifications = res.data
            } else {
                notifications.append(contentsOf: res.data)
            }
            if res.data.isEmpty {
                canLoadMore = false
            } else {
                page += 1
            }
            notifManager.fetchUnreadCount()
        } catch {
            if reload { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }
    
    private func markRead(id: Int) async {
        do {
            try await APIService.shared.markNotificationAsRead(id: id)
            if let index = notifications.firstIndex(where: { $0.id == id }) {
                notifications[index].isRead = true
            }
            notifManager.fetchUnreadCount()
        } catch {
            print("Failed to mark read: \(error)")
        }
    }
    
    private func deleteNotif(id: Int) async {
        do {
            try await APIService.shared.deleteNotification(id: id)
            notifications.removeAll { $0.id == id }
            notifManager.fetchUnreadCount()
        } catch {
            print("Failed to delete notif: \(error)")
        }
    }
    
    private func markAllRead() async {
        do {
            try await APIService.shared.markAllNotificationsAsRead()
            for i in notifications.indices {
                notifications[i].isRead = true
            }
            notifManager.fetchUnreadCount()
        } catch {
            print("Failed to mark all read: \(error)")
        }
    }
    
    private func deleteAll() async {
        do {
            try await APIService.shared.deleteAllNotifications()
            notifications.removeAll()
            notifManager.fetchUnreadCount()
        } catch {
            print("Failed to delete all: \(error)")
        }
    }
}

struct NotificationRowView: View {
    let notification: NotificationItem
    let markAsRead: () -> Void
    let deleteAction: () -> Void
    @State private var isExpanded = false
    
    private var timeText: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: notification.createdAt)
        if date == nil {
            let backupFormatter = ISO8601DateFormatter()
            backupFormatter.formatOptions = [.withInternetDateTime]
            date = backupFormatter.date(from: notification.createdAt)
        }
        guard let validDate = date else { return "Just now" }
        let diff = Int(Date().timeIntervalSince(validDate))
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(diff / 60)m ago" }
        if diff < 86400 { return "\(diff / 3600)h ago" }
        return "\(diff / 86400)d ago"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(notification.isRead ? Color.gray.opacity(0.2) : Color.blue)
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(red: 20/255, green: 25/255, blue: 50/255))
                        
                        Spacer()
                        
                        Text(timeText)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    
                    Text(notification.body)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(red: 100/255, green: 110/255, blue: 130/255))
                        .lineLimit(isExpanded ? nil : 2)
                        .lineSpacing(2)
                }
            }
            
            if isExpanded {
                HStack {
                    Text("Tap to minimize")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Spacer()
                    Button(action: deleteAction) {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
            if !notification.isRead {
                markAsRead()
            }
        }
    }
}
