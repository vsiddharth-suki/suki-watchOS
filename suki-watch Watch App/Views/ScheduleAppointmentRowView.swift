import SwiftUI

struct ScheduleAppointmentRowView: View {
    let appointment: Appointment
    var noteStatus: String?

    private let statusIconColumnWidth: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 6) {
                ScheduleNoteStatusIcon(status: noteStatus)
                    .frame(width: statusIconColumnWidth, alignment: .center)
                Text(appointment.patient?.displayName ?? "Patient")
                    .font(.caption)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(DateRangeFormatter.appointmentTimeLabel(iso: appointment.startsAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, statusIconColumnWidth + 6)
        }
    }
}

struct ScheduleNoteStatusIcon: View {
    let status: String?

    var body: some View {
        Group {
            switch AppointmentNoteStatusPresentation.from(raw: status) {
            case .loading:
                ProgressView()
                    .scaleEffect(0.55)
            case .hidden:
                Color.clear
                    .frame(width: 8, height: 14)
            case .incomplete:
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange)
            case .submitted:
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .frame(height: 14, alignment: .center)
    }
}
