//
//  ProfilePromptsEditorView.swift
//  Celestia
//
//  Editor for selecting and answering profile prompts
//

import SwiftUI

struct ProfilePromptsEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var prompts: [ProfilePrompt]

    @State private var selectedCategory: String = "All"
    @State private var showingPromptPicker = false
    @State private var editingPromptIndex: Int?
    @State private var searchText = ""

    // Answer entry state
    @State private var showingAnswerEntry = false
    @State private var selectedQuestion: String = ""
    @State private var answerText: String = ""

    let maxPrompts = 3
    let categories = ["All"] + PromptLibrary.categories.keys.sorted()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header info
                    headerCard

                    // Current prompts
                    if prompts.isEmpty {
                        emptyPromptsCard
                    } else {
                        ForEach(Array(prompts.enumerated()), id: \.element.id) { index, prompt in
                            promptCard(prompt: prompt, index: index)
                        }
                    }

                    // Add prompt button
                    if prompts.count < maxPrompts {
                        addPromptButton
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile Prompts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.impact(.medium)
                        dismiss()
                    }
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingPromptPicker) {
                promptPickerView
            }
            .sheet(isPresented: $showingAnswerEntry) {
                answerEntryView
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "quote.bubble.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Show Your Personality")
                    .font(.headline)
            }

            Text("Answer up to 3 prompts to help others get to know you better. Profiles with prompts get 2x more matches!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.08), Color.pink.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Empty State

    private var emptyPromptsCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("No Prompts Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Add prompts to make your profile stand out and give others great conversation starters!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Prompt Card

    private func promptCard(prompt: ProfilePrompt, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question
            Text(prompt.question)
                .font(.headline)
                .foregroundColor(.purple)

            // Answer
            Text(prompt.answer)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Actions
            HStack(spacing: 16) {
                Button {
                    editingPromptIndex = index
                    showingPromptPicker = true
                    HapticManager.shared.impact(.light)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.purple)
                }

                Spacer()

                Button {
                    withAnimation {
                        prompts.remove(at: index)
                    }
                    HapticManager.shared.impact(.light)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                }
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Add Prompt Button

    private var addPromptButton: some View {
        Button {
            editingPromptIndex = nil
            showingPromptPicker = true
            HapticManager.shared.impact(.medium)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("Add Prompt")
                    .fontWeight(.semibold)
                Spacer()
                Text("\(prompts.count)/\(maxPrompts)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.purple)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }

    // MARK: - Prompt Picker View

    private var promptPickerView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search prompts...", text: $searchText)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()

                // Category tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            categoryButton(category)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)

                Divider()

                // Prompts list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredPrompts, id: \.self) { question in
                            promptSelectionCard(question: question)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Choose a Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingPromptPicker = false
                    }
                }
            }
        }
    }

    private func categoryButton(_ category: String) -> some View {
        Button {
            withAnimation {
                selectedCategory = category
            }
            HapticManager.shared.impact(.light)
        } label: {
            Text(category)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(selectedCategory == category ? .white : .purple)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    selectedCategory == category ?
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [Color(.systemGray6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
                .cornerRadius(20)
        }
    }

    private func promptSelectionCard(question: String) -> some View {
        Button {
            selectPrompt(question)
        } label: {
            HStack {
                Text(question)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Answer Entry View

    private var answerEntryView: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Question display
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Prompt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    Text(selectedQuestion)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.08), Color.pink.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)

                // Answer text editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Answer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    TextEditor(text: $answerText)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                        )

                    HStack {
                        Text("\(answerText.count)/150 characters")
                            .font(.caption)
                            .foregroundColor(answerText.count > 150 ? .red : .secondary)

                        Spacer()

                        if answerText.count > 150 {
                            Text("Too long!")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Save button
                Button {
                    saveAnswer()
                } label: {
                    Text("Save Answer")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || answerText.count > 150 ? [.gray] : [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
                .disabled(answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || answerText.count > 150)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Write Your Answer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingAnswerEntry = false
                        answerText = ""
                    }
                    .foregroundColor(.purple)
                }
            }
        }
    }

    // MARK: - Helpers

    private var filteredPrompts: [String] {
        var availablePrompts: [String]

        if selectedCategory == "All" {
            availablePrompts = PromptLibrary.allPrompts
        } else if let categoryPrompts = PromptLibrary.categories[selectedCategory] {
            availablePrompts = categoryPrompts
        } else {
            availablePrompts = []
        }

        if searchText.isEmpty {
            return availablePrompts
        } else {
            return availablePrompts.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func selectPrompt(_ question: String) {
        selectedQuestion = question

        // Pre-fill answer if editing existing prompt
        if let index = editingPromptIndex {
            answerText = prompts[index].answer
        } else {
            answerText = ""
        }

        showingPromptPicker = false

        // Show answer entry after a brief delay to allow prompt picker to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingAnswerEntry = true
        }
    }

    private func saveAnswer() {
        let trimmedAnswer = String(answerText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(150))

        guard !trimmedAnswer.isEmpty else { return }

        if let index = editingPromptIndex {
            // Edit existing prompt
            prompts[index] = ProfilePrompt(
                id: prompts[index].id,
                question: selectedQuestion,
                answer: trimmedAnswer
            )
        } else {
            // Add new prompt
            let newPrompt = ProfilePrompt(question: selectedQuestion, answer: trimmedAnswer)
            prompts.append(newPrompt)
        }

        HapticManager.shared.notification(.success)
        showingAnswerEntry = false
        answerText = ""
        editingPromptIndex = nil
    }
}

#Preview {
    ProfilePromptsEditorView(prompts: .constant([
        ProfilePrompt(question: "My ideal Sunday is...", answer: "Brunch with friends, a long walk in the park, and ending the day with a good book and wine."),
        ProfilePrompt(question: "I'm looking for someone who...", answer: "Can make me laugh, loves adventures, and isn't afraid to be vulnerable.")
    ]))
}
