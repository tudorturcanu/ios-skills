import SwiftUI

struct RootView: View {
    @State private var selection: Note?
    private let notes = Note.samples

    var body: some View {
        GeometryReader { proxy in
            layout(twoColumns: proxy.size.width > 600)
        }
    }

    @ViewBuilder
    private func layout(twoColumns: Bool) -> some View {
        if twoColumns {
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
