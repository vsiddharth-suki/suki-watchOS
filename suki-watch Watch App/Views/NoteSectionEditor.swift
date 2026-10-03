import SwiftUI

struct NoteSectionEditor: View {
    @Binding var text: String
    let sectionName: String
    var isEditable: Bool = true
    var onCommit: () -> Void = {}

    @State private var isEditing = false
    @State private var draft = ""

    var body: some View {
        Group {
            if isEditable {
                Button {
                    draft = text
                    isEditing = true
                } label: {
                    sectionBody(text: displayText, placeholder: text.isEmpty)
                }
                .buttonStyle(.plain)
            } else {
                sectionBody(text: displayText, placeholder: text.isEmpty)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: 0.22))
        )
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                NoteSectionEditSheet(sectionName: sectionName, text: $draft) {
                    text = draft
                    isEditing = false
                    onCommit()
                }
            }
        }
    }

    private var displayText: String {
        text.isEmpty ? "Dictate or type" : text
    }

    @ViewBuilder
    private func sectionBody(text: String, placeholder: Bool) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(placeholder ? .secondary : .primary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: contentHeight(for: self.text), alignment: .topLeading)
    }

    private func contentHeight(for value: String) -> CGFloat {
        let lines = max(4, value.components(separatedBy: "\n").count + 1)
        let wrapped = max(lines, (value.count / 16) + 1)
        return CGFloat(max(wrapped, 4)) * 22
    }
}

private struct NoteSectionEditSheet: View {
    let sectionName: String
    @Binding var text: String
    let onDone: () -> Void

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    Text(text.isEmpty ? "Dictate or type" : text)
                        .font(.caption)
                        .foregroundStyle(text.isEmpty ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: contentMinHeight, alignment: .topLeading)
                        .allowsHitTesting(false)

                    // Full-size field captures taps/dictation; Text underneath shows the full multiline body.
                    TextField("Dictate or type", text: $text, axis: .vertical)
                        .font(.caption)
                        .foregroundStyle(.clear)
                        .tint(.white)
                        .multilineTextAlignment(.leading)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .textContentType(.oneTimeCode)
                        .lineLimit(1...500)
                        .focused($isFieldFocused)
                        .frame(maxWidth: .infinity, minHeight: contentMinHeight, alignment: .topLeading)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(white: 0.22))
                )
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 4)
        }
        .defaultScrollAnchor(.top)
        .navigationTitle(sectionName)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onDone()
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isFieldFocused = true
            }
        }
    }

    private var contentMinHeight: CGFloat {
        let lines = max(4, text.components(separatedBy: "\n").count + 1)
        let wrapped = max(lines, (text.count / 16) + 1)
        return CGFloat(max(wrapped, 4)) * 22
    }
}
