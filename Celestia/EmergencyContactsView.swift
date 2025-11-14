//
//  EmergencyContactsView.swift
//  Celestia
//
//  Manage emergency contacts for date safety
//

import SwiftUI
import FirebaseFirestore

struct EmergencyContactsView: View {
    @StateObject private var viewModel = EmergencyContactsViewModel()
    @State private var showAddContact = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.contacts.isEmpty {
                    emptyStateView
                } else {
                    contactsList
                }
            }
        }
        .navigationTitle("Emergency Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddContact = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddContact) {
            AddEmergencyContactView { contact in
                await viewModel.addContact(contact)
            }
        }
        .task {
            await viewModel.loadContacts()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.badge.gearshape.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 12) {
                Text("No Emergency Contacts")
                    .font(.title2.bold())

                Text("Add trusted friends or family who can check on you during dates.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                showAddContact = true
            } label: {
                Text("Add Contact")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Contacts List

    private var contactsList: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Info Card
                infoCard

                // Contacts
                VStack(spacing: 12) {
                    ForEach(viewModel.contacts) { contact in
                        EmergencyContactCard(
                            contact: contact,
                            onDelete: {
                                await viewModel.deleteContact(contact)
                            },
                            onEdit: { updatedContact in
                                await viewModel.updateContact(updatedContact)
                            },
                            onToggleDateUpdates: {
                                await viewModel.toggleDateUpdates(contact)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("About Emergency Contacts")
                    .font(.headline)
            }

            Text("These contacts can receive your date details and check-in notifications. They won't see your normal app activity.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Emergency Contact Card

struct EmergencyContactCard: View {
    let contact: EmergencyContact
    let onDelete: () async -> Void
    let onEdit: (EmergencyContact) async -> Void
    let onToggleDateUpdates: () async -> Void

    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Profile
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Text(contact.name.prefix(1))
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.name)
                        .font(.headline)

                    Text(contact.phoneNumber)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(contact.relationship.displayName)
                        .font(.caption)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(4)
                }

                Spacer()

                // Menu
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .padding(8)
                }
            }

            Divider()

            // Date Updates Toggle
            Toggle(isOn: Binding(
                get: { contact.notificationPreferences.receiveScheduledDateAlerts },
                set: { _ in
                    Task {
                        await onToggleDateUpdates()
                    }
                }
            )) {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.blue)
                    Text("Receive Date Updates")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        .confirmationDialog(
            "Delete Contact?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await onDelete()
                }
            }
        } message: {
            Text("Are you sure you want to remove \(contact.name) from your emergency contacts?")
        }
        .sheet(isPresented: $showEditSheet) {
            EditEmergencyContactView(contact: contact, onUpdate: onEdit)
        }
    }
}

// MARK: - Add Contact View

struct AddEmergencyContactView: View {
    let onAdd: (EmergencyContact) async -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var relationship: ContactRelationship = .friend

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Information") {
                    TextField("Name", text: $name)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section("Relationship") {
                    Picker("Relationship", selection: $relationship) {
                        ForEach(ContactRelationship.allCases, id: \.self) { rel in
                            Text(rel.displayName).tag(rel)
                        }
                    }
                }

                Section {
                    Toggle("Can receive date updates", isOn: .constant(true))
                } footer: {
                    Text("This contact will be able to receive your date details and check-in notifications.")
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        Task {
                            let contact = EmergencyContact(
                                id: UUID().uuidString,
                                name: name,
                                phoneNumber: phone,
                                email: nil,
                                relationship: relationship,
                                addedAt: Date(),
                                notificationPreferences: EmergencyNotificationPreferences()
                            )
                            await onAdd(contact)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || phone.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Emergency Contact View

struct EditEmergencyContactView: View {
    let contact: EmergencyContact
    let onUpdate: (EmergencyContact) async -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var phone: String
    @State private var relationship: ContactRelationship

    init(contact: EmergencyContact, onUpdate: @escaping (EmergencyContact) async -> Void) {
        self.contact = contact
        self.onUpdate = onUpdate
        _name = State(initialValue: contact.name)
        _phone = State(initialValue: contact.phoneNumber)
        _relationship = State(initialValue: contact.relationship)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Information") {
                    TextField("Name", text: $name)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section("Relationship") {
                    Picker("Relationship", selection: $relationship) {
                        ForEach(ContactRelationship.allCases, id: \.self) { rel in
                            Text(rel.displayName).tag(rel)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Added")
                        Spacer()
                        Text(contact.addedAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    Text("Emergency contact information is securely stored and only shared when you explicitly share your date details.")
                }
            }
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            var updatedContact = contact
                            updatedContact.name = name
                            updatedContact.phoneNumber = phone
                            updatedContact.relationship = relationship
                            await onUpdate(updatedContact)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || phone.isEmpty)
                    .bold()
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class EmergencyContactsViewModel: ObservableObject {
    @Published var contacts: [EmergencyContact] = []

    private let db = Firestore.firestore()

    func loadContacts() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }

        do {
            let snapshot = try await db.collection("emergency_contacts")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()

            contacts = snapshot.documents.compactMap { doc in
                try? doc.data(as: EmergencyContact.self)
            }

            Logger.shared.info("Loaded \(contacts.count) emergency contacts", category: .general)
        } catch {
            Logger.shared.error("Error loading emergency contacts", category: .general, error: error)
        }
    }

    func addContact(_ contact: EmergencyContact) async {
        guard let userId = AuthService.shared.currentUser?.id else { return }

        do {
            var contactData = contact
            try await db.collection("emergency_contacts")
                .document(contact.id)
                .setData([
                    "userId": userId,
                    "id": contact.id,
                    "name": contact.name,
                    "phoneNumber": contact.phoneNumber,
                    "email": contact.email as Any,
                    "relationship": contact.relationship.rawValue,
                    "addedAt": Timestamp(date: contact.addedAt),
                    "notificationPreferences": [
                        "receiveScheduledDateAlerts": contact.notificationPreferences.receiveScheduledDateAlerts,
                        "receiveCheckInAlerts": contact.notificationPreferences.receiveCheckInAlerts,
                        "receiveEmergencyAlerts": contact.notificationPreferences.receiveEmergencyAlerts,
                        "receiveMissedCheckInAlerts": contact.notificationPreferences.receiveMissedCheckInAlerts
                    ],
                    "createdAt": Timestamp(date: Date())
                ])

            contacts.append(contactData)

            AnalyticsServiceEnhanced.shared.trackEvent(
                .emergencyContactAdded,
                properties: ["relationship": contact.relationship.rawValue]
            )

            Logger.shared.info("Emergency contact added: \(contact.name)", category: .general)
        } catch {
            Logger.shared.error("Error adding emergency contact", category: .general, error: error)
        }
    }

    func deleteContact(_ contact: EmergencyContact) async {
        do {
            try await db.collection("emergency_contacts")
                .document(contact.id)
                .delete()

            contacts.removeAll { $0.id == contact.id }

            AnalyticsServiceEnhanced.shared.trackEvent(
                .emergencyContactRemoved,
                properties: ["contactId": contact.id]
            )

            Logger.shared.info("Emergency contact deleted: \(contact.name)", category: .general)
        } catch {
            Logger.shared.error("Error deleting emergency contact", category: .general, error: error)
        }
    }

    func toggleDateUpdates(_ contact: EmergencyContact) async {
        guard let index = contacts.firstIndex(where: { $0.id == contact.id }) else { return }

        var updatedContact = contact
        updatedContact.notificationPreferences.receiveScheduledDateAlerts.toggle()

        do {
            try await db.collection("emergency_contacts")
                .document(contact.id)
                .updateData([
                    "notificationPreferences.receiveScheduledDateAlerts": updatedContact.notificationPreferences.receiveScheduledDateAlerts
                ])

            contacts[index] = updatedContact

            Logger.shared.info("Updated date updates for \(contact.name)", category: .general)
        } catch {
            Logger.shared.error("Error updating contact", category: .general, error: error)
        }
    }

    func updateContact(_ contact: EmergencyContact) async {
        guard let index = contacts.firstIndex(where: { $0.id == contact.id }) else { return }

        do {
            try await db.collection("emergency_contacts")
                .document(contact.id)
                .updateData([
                    "name": contact.name,
                    "phoneNumber": contact.phoneNumber,
                    "relationship": contact.relationship.rawValue,
                    "updatedAt": Timestamp(date: Date())
                ])

            contacts[index] = contact

            AnalyticsManager.shared.logEvent(.emergencyContactEdited, parameters: [
                "contactId": contact.id,
                "relationship": contact.relationship.rawValue
            ])

            Logger.shared.info("Emergency contact updated: \(contact.name)", category: .general)
        } catch {
            Logger.shared.error("Error updating emergency contact", category: .general, error: error)
        }
    }
}

#Preview {
    NavigationStack {
        EmergencyContactsView()
    }
}
