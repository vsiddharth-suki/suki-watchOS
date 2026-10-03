import Foundation

struct AmbientTranscriptLine: Identifiable, Hashable {
    let id = UUID()
    var timeLabel: String
    var text: String
}

struct AmbientTranscriptSection: Identifiable, Hashable {
    let id: String
    var title: String
    var durationLabel: String
    var sessionStartISO: String
    var status: AmbientTranscriptStatus
    var isExpanded: Bool
    var lines: [AmbientTranscriptLine]
}

@Observable
@MainActor
final class AmbientTranscriptViewModel {
    let noteIds: [String]
    let patientName: String?

    var sections: [AmbientTranscriptSection] = []
    var isLoading = false
    var errorMessage: String?

    private let service = AmbientTranscriptService()

    init(noteIds: [String], patientName: String?) {
        self.noteIds = noteIds
        self.patientName = patientName
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let sessions = try await service.fetchSessions(forNoteIds: noteIds)
            let eligible = sessions.filter { $0.transcriptStatus != .unavailable }
            var built: [AmbientTranscriptSection] = []

            for session in eligible {
                guard let sessionId = session.ambientSessionId, !sessionId.isEmpty else { continue }
                let status = session.transcriptStatus ?? .unavailable
                var lines: [AmbientTranscriptLine] = []

                if status == .available {
                    let response = try await service.fetchTranscript(ambientSessionId: sessionId)
                    for result in response.transcriptResults {
                        let timeLabel = AmbientTranscriptFormatting.timeLabel(result.startTime)
                        for entry in result.transcripts {
                            lines.append(AmbientTranscriptLine(timeLabel: timeLabel, text: entry.text))
                        }
                    }
                }

                let title = DateRangeFormatter.ambientSessionTimestamp(iso: session.startTime)
                let duration = AmbientTranscriptFormatting.durationLabel(seconds: session.totalDurationSeconds)
                let isExpanded = eligible.count == 1
                built.append(
                    AmbientTranscriptSection(
                        id: sessionId,
                        title: title,
                        durationLabel: duration,
                        sessionStartISO: session.startTime ?? "",
                        status: status,
                        isExpanded: isExpanded,
                        lines: lines
                    )
                )
            }

            built.sort { lhs, rhs in
                let left = NoteDateClassification.parseCreatedAt(lhs.sessionStartISO) ?? .distantPast
                let right = NoteDateClassification.parseCreatedAt(rhs.sessionStartISO) ?? .distantPast
                return left < right
            }
            sections = built
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setExpanded(_ expanded: Bool, sectionID: String) {
        guard let index = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        sections[index].isExpanded = expanded
    }
}

enum AmbientTranscriptFormatting {
    static func timeLabel(_ raw: String) -> String {
        if let seconds = Int(raw) {
            let minutes = seconds / 60
            let remainder = seconds % 60
            return String(format: "%d:%02d", minutes, remainder)
        }
        return raw
    }

    static func durationLabel(seconds: Int) -> String {
        guard seconds > 0 else { return "" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes > 0 {
            return "Duration: \(minutes)m \(remainder)s"
        }
        return "Duration: \(remainder)s"
    }
}
