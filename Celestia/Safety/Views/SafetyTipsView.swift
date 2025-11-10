//
//  SafetyTipsView.swift
//  Celestia
//
//  Safety tips and resources for users
//

import SwiftUI

struct SafetyTipsView: View {

    @StateObject private var safetyManager = SafetyManager.shared
    @State private var selectedCategory: SafetyTipCategory = .meetingSafely

    var body: some View {
        VStack(spacing: 0) {
            // Category Picker
            categoryPicker

            // Tips List
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredTips) { tip in
                        tipCard(tip)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Safety Tips")
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SafetyTipCategory.allCases, id: \.self) { category in
                    categoryButton(category)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }

    private func categoryButton(_ category: SafetyTipCategory) -> some View {
        Button(action: { selectedCategory = category }) {
            Text(category.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(selectedCategory == category ? .white : .blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedCategory == category ? Color.blue : Color.blue.opacity(0.1))
                .cornerRadius(20)
        }
    }

    // MARK: - Tips

    private var filteredTips: [SafetyTip] {
        safetyManager.getTipsByCategory(selectedCategory)
    }

    private func tipCard(_ tip: SafetyTip) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: tip.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 8) {
                Text(tip.title)
                    .font(.headline)

                Text(tip.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Check-In View

struct CheckInView: View {

    @StateObject private var checkInManager = DateCheckInManager.shared
    @State private var showingNewCheckIn = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Active Check-In
                if let activeCheckIn = checkInManager.activeCheckIn {
                    activeCheckInCard(activeCheckIn)
                } else {
                    noActiveCheckInCard
                }

                // History
                if !checkInManager.checkInHistory.isEmpty {
                    checkInHistorySection
                }

                // How it Works
                howItWorksSection
            }
            .padding()
        }
        .navigationTitle("Date Check-In")
        .sheet(isPresented: $showingNewCheckIn) {
            NewCheckInSheet()
        }
    }

    // MARK: - Active Check-In Card

    private func activeCheckInCard(_ checkIn: DateCheckIn) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: checkIn.status.icon)
                    .font(.title)
                    .foregroundColor(.orange)

                VStack(alignment: .leading) {
                    Text("Active Check-In")
                        .font(.headline)
                    Text(checkIn.status.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                infoRow(label: "Match", value: checkIn.matchName)
                infoRow(label: "Location", value: checkIn.location.name)
                infoRow(label: "Time", value: formatDate(checkIn.scheduledTime))
            }

            if checkIn.status == .inProgress {
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            try? await checkInManager.checkInDuringDate()
                        }
                    }) {
                        Text("Check In - All Good")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }

                    Button(action: {
                        Task {
                            try? await checkInManager.triggerEmergency()
                        }
                    }) {
                        Text("⚠️ Emergency")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - No Active Check-In

    private var noActiveCheckInCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("No Active Check-In")
                .font(.headline)

            Text("Create a check-in before your next date to let trusted contacts know where you are")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { showingNewCheckIn = true }) {
                Text("Create Check-In")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - History

    private var checkInHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Check-Ins")
                .font(.headline)

            ForEach(checkInManager.checkInHistory.suffix(5).reversed(), id: \.id) { checkIn in
                historyRow(checkIn)
            }
        }
    }

    private func historyRow(_ checkIn: DateCheckIn) -> some View {
        HStack {
            Image(systemName: checkIn.status.icon)
                .foregroundColor(statusColor(checkIn.status))

            VStack(alignment: .leading) {
                Text(checkIn.matchName)
                    .font(.subheadline)
                Text(formatDate(checkIn.scheduledTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(checkIn.status.displayName)
                .font(.caption)
                .foregroundColor(statusColor(checkIn.status))
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    // MARK: - How It Works

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How It Works")
                .font(.headline)

            howItWorksStep(
                number: "1",
                title: "Create Check-In",
                description: "Share your date details with emergency contacts"
            )

            howItWorksStep(
                number: "2",
                title: "Check In During Date",
                description: "Let contacts know you're safe with quick updates"
            )

            howItWorksStep(
                number: "3",
                title: "Complete Check-In",
                description: "Mark yourself as safe when you return home"
            )

            howItWorksStep(
                number: "⚠️",
                title: "Emergency Alert",
                description: "Trigger emergency alert if you feel unsafe"
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func howItWorksStep(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.blue)
                .cornerRadius(16)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func statusColor(_ status: CheckInStatus) -> Color {
        switch status {
        case .scheduled:
            return .blue
        case .inProgress:
            return .orange
        case .completed:
            return .green
        case .missed:
            return .yellow
        case .emergency:
            return .red
        }
    }
}

// MARK: - New Check-In Sheet

struct NewCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Date Details") {
                    TextField("Match Name", text: .constant(""))
                    TextField("Location", text: .constant(""))
                    DatePicker("Date & Time", selection: .constant(Date()))
                }

                Section("Duration") {
                    Picker("Expected Duration", selection: .constant(2)) {
                        Text("1 hour").tag(1)
                        Text("2 hours").tag(2)
                        Text("3 hours").tag(3)
                        Text("4 hours").tag(4)
                    }
                }

                Section {
                    Button("Create Check-In") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("New Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Emergency Contacts View

struct EmergencyContactsView: View {

    @StateObject private var emergencyContactManager = EmergencyContactManager.shared
    @State private var showingAddContact = false

    var body: some View {
        List {
            Section {
                ForEach(emergencyContactManager.contacts) { contact in
                    contactRow(contact)
                }
                .onDelete(perform: deleteContact)
            } header: {
                Text("Emergency Contacts")
            } footer: {
                Text("These contacts will be notified during date check-ins and emergencies")
            }

            if emergencyContactManager.contacts.count < 5 {
                Section {
                    Button(action: { showingAddContact = true }) {
                        Label("Add Contact", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .navigationTitle("Emergency Contacts")
        .sheet(isPresented: $showingAddContact) {
            AddContactSheet()
        }
    }

    private func contactRow(_ contact: EmergencyContact) -> some View {
        HStack {
            Image(systemName: contact.relationship.icon)
                .foregroundColor(.blue)

            VStack(alignment: .leading) {
                Text(contact.name)
                    .font(.headline)
                Text(contact.formattedPhoneNumber)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(contact.relationship.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func deleteContact(at offsets: IndexSet) {
        for index in offsets {
            let contact = emergencyContactManager.contacts[index]
            emergencyContactManager.removeContact(contact)
        }
    }
}

// MARK: - Add Contact Sheet

struct AddContactSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var relationship: ContactRelationship = .friend

    var body: some View {
        NavigationView {
            Form {
                Section("Contact Information") {
                    TextField("Name", text: $name)
                    TextField("Phone Number", text: $phoneNumber)
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
                    Button("Add Contact") {
                        dismiss()
                    }
                    .disabled(name.isEmpty || phoneNumber.isEmpty)
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
