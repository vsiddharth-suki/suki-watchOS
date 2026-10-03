import SwiftUI

struct HomeView: View {
    @Binding var path: [AppRoute]
    @Bindable private var session = SessionStore.shared
    @State private var viewModel = HomeViewModel()

    var body: some View {
        List {
            Section {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(session.welcomeDoctorLabel)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Button {
                        path.append(.search)
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text(error).font(.caption2).foregroundStyle(.red)
                } else if viewModel.appointments.isEmpty {
                    Text("No appointments today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.appointments, id: \.id) { appointment in
                        Button {
                            openPatient(from: appointment)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appointment.patient?.displayName ?? "Patient")
                                    .font(.caption)
                                Text(DateRangeFormatter.appointmentTimeLabel(iso: appointment.startsAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Button {
                    path.append(.schedule)
                } label: {
                    Text("View All")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } header: {
                Text("Today's schedule")
            }

            Section {
                if viewModel.isLoadingRecentNotes && viewModel.recentNotes.isEmpty {
                    ProgressView()
                } else if let error = viewModel.recentNotesError {
                    Text(error).font(.caption2).foregroundStyle(.red)
                } else if viewModel.recentNotes.isEmpty {
                    Text("None").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.recentNotes) { note in
                        Button {
                            openRecentNote(note)
                        } label: {
                            RecentNoteRowView(note: note)
                        }
                    }
                }

                Button {
                    path.append(.unfinishedNotes)
                } label: {
                    Text("View All")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } header: {
                Text("Recent notes")
            }

            Section {
                Button {
                    path.append(.ambient(AmbientLaunchContext(
                        patientId: nil,
                        patientName: nil,
                        appointmentId: nil,
                        noteId: nil,
                        startWithoutPatient: true
                    )))
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start a visit")
                            .font(.caption)
                        Text("Start ambient and add patient details later.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Log Out", role: .destructive) {
                    session.signOut()
                }
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Image("SukiStageLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .accessibilityLabel("Suki")
            }
        }
        .task { await viewModel.loadToday() }
        .refreshable { await viewModel.loadToday() }
    }

    private func openPatient(from appointment: Appointment) {
        guard let patientId = appointment.patient?.id else { return }
        path.append(.patientProfile(
            patientId: patientId,
            patientName: appointment.patient?.displayName ?? "Patient",
            appointmentId: appointment.id
        ))
    }

    private func openRecentNote(_ note: HomeRecentNote) {
        if let noteId = note.noteId, !noteId.isEmpty {
            path.append(.note(
                noteId: noteId,
                patientId: note.patientId,
                patientName: note.patientName
            ))
            return
        }
        guard let patientId = note.patientId else { return }
        path.append(.patientProfile(
            patientId: patientId,
            patientName: note.patientName ?? "Patient",
            appointmentId: nil
        ))
    }
}
