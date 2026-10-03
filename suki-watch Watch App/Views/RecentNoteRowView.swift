import SwiftUI

struct RecentNoteRowView: View {
    let note: HomeRecentNote

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            HomeNoteStatusIcon(isIncomplete: note.isIncomplete)
            VStack(alignment: .leading, spacing: 2) {
                Text(note.headline)
                    .font(.caption)
                    .lineLimit(2)
                Text("\(note.subtitle) · \(note.timeLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

struct HomeNoteStatusIcon: View {
    let isIncomplete: Bool

    var body: some View {
        if isIncomplete {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(.orange)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        }
    }
}
