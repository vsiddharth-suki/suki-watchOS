import SwiftUI

struct ScheduleView: View {
    @Binding var path: [AppRoute]
    @State private var viewModel = ScheduleViewModel()

    private static let selectableDateRange: ClosedRange<Date> = {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1)) ?? .distantPast
        let end = calendar.date(from: DateComponents(year: 2026, month: 12, day: 31)) ?? .distantFuture
        return start ... end
    }()

    var body: some View {
        List {
            Section {
                WatchAlignedDatePicker(
                    date: $viewModel.selectedDate,
                    range: Self.selectableDateRange
                )
                .onChange(of: viewModel.selectedDate) { _, _ in
                    Task { await viewModel.load(forceEMRRefresh: viewModel.showsEMRRefresh) }
                }

                if viewModel.showsEMRRefresh {
                    Button {
                        Task { await viewModel.load(forceEMRRefresh: true) }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isRefreshing || !viewModel.hasCompletedInitialLoad)
                }
            }

            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                Text(error).font(.caption2).foregroundStyle(.red)
            } else if viewModel.appointments.isEmpty {
                Text("No appointments")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.appointments, id: \.id) { appointment in
                    Button {
                        guard let patientId = appointment.patient?.id else { return }
                        path.append(.patientProfile(
                            patientId: patientId,
                            patientName: appointment.patient?.displayName ?? "Patient",
                            appointmentId: appointment.id
                        ))
                    } label: {
                        ScheduleAppointmentRowView(
                            appointment: appointment,
                            noteStatus: viewModel.noteStatus(for: appointment.id)
                        )
                    }
                }
            }
        }
        .navigationTitle("Schedule")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    path.append(.search)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search patients")
            }
        }
        .task { await viewModel.load() }
    }
}
