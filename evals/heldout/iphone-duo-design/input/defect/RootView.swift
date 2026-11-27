import SwiftUI

struct RootView: View {
    @State private var selection: Note?
    private let notes = Note.samples

    // Decided once, when the view is first created.
    private let useTwoColumns: Bool = UIScreen.main.bounds.width > 600

    var body: some View {
        if useTwoColumns {
            HStack(spacing: 0) {
                NoteList(notes: notes, selection: $selection)
                    .frame(width: 320)
                Divider()
                NoteDetail(note: selection)
            }
        } else {
            NavigationStack {
                NoteList(notes: notes, selection: $selection)
                    .navigationDestination(item: $selection) { NoteDetail(note: $0) }
            }
        }
    }
}

struct NoteList: View {
    let notes: [Note]
    @Binding var selection: Note?
    var body: some View {
        List(notes, selection: $selection) { Text($0.title).tag($0) }
    }
}

struct NoteDetail: View {
    let note: Note?
    var body: some View {
        Text(note?.body ?? "Select a note").padding()
    }
}
