import SwiftUI

struct AmbientTranscriptView: View {
    @State private var viewModel: AmbientTranscriptViewModel

    init(noteIds: [String], patientName: String?) {
        _viewModel = State(initialValue: AmbientTranscriptViewModel(noteIds: noteIds, patientName: patientName))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ambient Transcript")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let patientName = viewModel.patientName, !patientName.isEmpty {
                        Text(patientName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text("Transcripts are available for 30 days, after which they will be removed to ensure data privacy.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else if viewModel.sections.isEmpty {
                Text("No ambient sessions for this note.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.sections) { section in
                    Section {
                        if section.isExpanded {
                            sectionBody(section)
                        }
                    } header: {
                        Button {
                            viewModel.setExpanded(!section.isExpanded, sectionID: section.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(section.title)
                                        .font(.caption)
                                    if !section.durationLabel.isEmpty {
                                        Text(section.durationLabel)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 4)
                                Image(systemName: section.isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("")
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private func sectionBody(_ section: AmbientTranscriptSection) -> some View {
        switch section.status {
        case .expired:
            Text("The transcript for this session is no longer available.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .available:
            if section.lines.isEmpty {
                Text("No transcript available.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(section.lines.enumerated()), id: \.element.id) { index, line in
                    VStack(alignment: .leading, spacing: 4) {
                        if shouldShowTimestamp(at: index, in: section.lines) {
                            Text(line.timeLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(line.text)
                            .font(.caption)
                    }
                    .padding(.vertical, 2)
                }
            }
        case .unavailable:
            Text("No transcript available.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func shouldShowTimestamp(at index: Int, in lines: [AmbientTranscriptLine]) -> Bool {
        if index == 0 { return true }
        return lines[index].timeLabel != lines[index - 1].timeLabel
    }
}
