import SwiftUI

struct RecentNoteRowView: View {
    let note: HomeRecentNote

    private let statusIconColumnWidth: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 6) {
                HomeNoteStatusIcon(isIncomplete: note.isIncomplete)
                    .frame(width: statusIconColumnWidth, alignment: .center)
                Text(note.headline)
                    .font(.caption)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("\(note.subtitle) · \(note.timeLabel)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .padding(.leading, statusIconColumnWidth + 6)
        }
    }
}

struct HomeNoteStatusIcon: View {
    let isIncomplete: Bool

    var body: some View {
        Group {
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
        .frame(height: 14, alignment: .center)
    }
}
