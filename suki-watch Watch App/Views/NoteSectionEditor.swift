import SwiftUI

struct NoteSectionEditor: View {
    @Binding var text: String
    let sectionName: String

    @State private var isEditing = false
    @State private var draft = ""

    var body: some View {
        Button {
            draft = text
            isEditing = true
        } label: {
            Text(displayText)
                .font(.caption)
                .foregroundStyle(text.isEmpty ? .secondary : .primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: contentHeight, alignment: .topLeading)
        }
        .buttonStyle(.plain)
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
                }
            }
        }
    }

    private var displayText: String {
        text.isEmpty ? "Dictate or type" : text
    }

    private var contentHeight: CGFloat {
        let lines = max(4, text.components(separatedBy: "\n").count + 1)
        let wrapped = max(lines, (text.count / 16) + 1)
        return CGFloat(max(wrapped, 4)) * 22
    }
}

private struct NoteSectionEditSheet: View {
    let sectionName: String
    @Binding var text: String
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            TextField("Dictate or type", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .textContentType(.oneTimeCode)
                .lineLimit(12, reservesSpace: true)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .padding(8)
        }
        .navigationTitle(sectionName)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onDone()
                }
            }
        }
    }
}
