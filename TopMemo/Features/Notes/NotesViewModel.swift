import AppKit
import Foundation
import SwiftUI

struct MemoColorSelectionRequest: Identifiable, Equatable {
    let id = UUID()
    let color: MemoColor
}

enum NotesAlert: Identifiable, Equatable {
    case discardChanges
    case deleteMemo
    case deleteAllMemos
    case confirmRestore(fileName: String)
    case notice(title: String, message: String)
    case error(title: String, message: String)

    var id: String {
        switch self {
        case .discardChanges:
            return "discardChanges"
        case .deleteMemo:
            return "deleteMemo"
        case .deleteAllMemos:
            return "deleteAllMemos"
        case .confirmRestore(let fileName):
            return "confirmRestore-\(fileName)"
        case .notice(let title, let message):
            return "notice-\(title)-\(message)"
        case .error(let title, let message):
            return "error-\(title)-\(message)"
        }
    }
}

@MainActor
final class NotesViewModel: ObservableObject {
    @Published private(set) var notes: [MemoItem] = []
    @Published var route: TopMemoRoute = .emptyComposer
    @Published var draft: MemoDraft = .empty
    @Published var focusToken = UUID()
    @Published var activeAlert: NotesAlert?
    @Published var colorSelectionRequest: MemoColorSelectionRequest?

    private let store: NotesStore
    private var originalDraft: MemoDraft = .empty
    private var pendingRestoreURL: URL?

    init(store: NotesStore) {
        self.store = store
        loadNotes()
    }

    var canSave: Bool {
        !draft.trimmedContent.isEmpty
    }

    var hasNotes: Bool {
        !notes.isEmpty
    }

    var isEditingExistingMemo: Bool {
        draft.memoID != nil
    }

    var isDirty: Bool {
        draft.styledText != originalDraft.styledText
    }

    func handlePopoverOpened() {
        activeAlert = nil
        openDefaultComposer()
    }

    func handleShortcutTriggered() {
        activeAlert = nil

        if isDirty {
            requestFocus()
            return
        }

        startNewMemo()
    }

    func startNewMemo() {
        colorSelectionRequest = nil
        draft = .empty
        originalDraft = draft
        route = .editor(memoID: nil)
        requestFocus()
    }

    func edit(_ memo: MemoItem) {
        colorSelectionRequest = nil
        draft = .from(memo)
        originalDraft = draft
        route = .editor(memoID: memo.id)
        requestFocus()
    }

    func openSettings() {
        route = .settings
    }

    func closeSettings() {
        route = .memoList
    }

    func requestBack(closePopover: () -> Void) {
        if isDirty {
            activeAlert = .discardChanges
            return
        }

        goBack(closePopover: closePopover)
    }

    func discardChangesAndGoBack(closePopover: () -> Void) {
        restoreDraftFromSource()
        goBack(closePopover: closePopover)
    }

    func requestDelete() {
        activeAlert = .deleteMemo
    }

    func requestDeleteAllMemos() {
        activeAlert = .deleteAllMemos
    }

    func exportAllNotes() {
        do {
            let exportURL = try store.export(notes)
            NSWorkspace.shared.activateFileViewerSelecting([exportURL])
            activeAlert = .notice(
                title: "내보내기 완료",
                message: "\(exportURL.lastPathComponent)을 다운로드 폴더에 저장했고 Finder에서 바로 열었습니다."
            )
        } catch {
            activeAlert = .error(
                title: "내보내기 오류",
                message: error.localizedDescription
            )
        }
    }

    func handleRestoreFileSelection(_ result: Result<URL, Error>) {
        do {
            let restoreURL = try result.get()
            pendingRestoreURL = restoreURL
            activeAlert = .confirmRestore(fileName: restoreURL.lastPathComponent)
        } catch {
            guard !Self.isUserCancelled(error) else {
                return
            }

            activeAlert = .error(
                title: "파일 선택 오류",
                message: error.localizedDescription
            )
        }
    }

    func restorePendingMemos() {
        activeAlert = nil

        guard let restoreURL = pendingRestoreURL else {
            return
        }

        pendingRestoreURL = nil

        do {
            let restoredNotes = Self.sorted(try store.restore(from: restoreURL))
            try store.save(restoredNotes)
            applyRestoredNotes(restoredNotes)

            activeAlert = .notice(
                title: "복원 완료",
                message: "\(restoredNotes.count)개의 메모를 복원했습니다."
            )
        } catch {
            activeAlert = .error(
                title: "복원 오류",
                message: error.localizedDescription
            )
        }
    }

    func deleteCurrent() {
        activeAlert = nil

        if let memoID = draft.memoID {
            notes.removeAll { $0.id == memoID }
            persistNotes()
        }

        if notes.isEmpty {
            prepareEmptyComposer()
        } else {
            route = .memoList
        }
    }

    func deleteAllMemos() {
        activeAlert = nil
        let previousNotes = notes

        do {
            try store.save([])
            notes = []
            prepareEmptyComposer()
        } catch {
            notes = previousNotes
            activeAlert = .error(
                title: "저장 오류",
                message: error.localizedDescription
            )
        }
    }

    func saveCurrent() {
        guard canSave else {
            return
        }

        let now = Date()

        if let memoID = draft.memoID, let index = notes.firstIndex(where: { $0.id == memoID }) {
            notes[index].styledText = draft.styledText
            notes[index].updatedAt = now
        } else {
            notes.append(
                MemoItem(
                    id: UUID(),
                    styledText: draft.styledText,
                    createdAt: draft.createdAt ?? now,
                    updatedAt: now
                )
            )
        }

        persistNotes()
        draft = .empty
        originalDraft = draft
        route = .memoList
    }

    func selectColor(_ color: MemoColor) {
        draft.activeColor = color
        colorSelectionRequest = MemoColorSelectionRequest(color: color)
    }

    func updateStyledText(_ styledText: StyledText) {
        draft.styledText = styledText
    }

    func updateActiveColor(_ color: MemoColor) {
        draft.activeColor = color
    }

    func clearAlert() {
        pendingRestoreURL = nil
        activeAlert = nil
    }

    private func loadNotes() {
        do {
            notes = Self.sorted(try store.load())
            openDefaultComposer()
        } catch {
            notes = []
            route = .emptyComposer
            activeAlert = .error(
                title: "불러오기 오류",
                message: error.localizedDescription
            )
        }
    }

    private func openDefaultComposer() {
        if notes.isEmpty {
            prepareEmptyComposer()
        } else {
            startNewMemo()
        }
    }

    private func prepareEmptyComposer() {
        colorSelectionRequest = nil
        draft = .empty
        originalDraft = draft
        route = .emptyComposer
        requestFocus()
    }

    private func goBack(closePopover: () -> Void) {
        activeAlert = nil

        if notes.isEmpty {
            prepareEmptyComposer()
            closePopover()
        } else {
            route = .memoList
        }
    }

    private func restoreDraftFromSource() {
        colorSelectionRequest = nil
        if let memoID = draft.memoID, let memo = notes.first(where: { $0.id == memoID }) {
            draft = .from(memo)
            originalDraft = draft
        } else {
            draft = .empty
            originalDraft = draft
        }
    }

    private func requestFocus() {
        focusToken = UUID()
    }

    private func persistNotes() {
        notes = Self.sorted(notes)

        do {
            try store.save(notes)
        } catch {
            activeAlert = .error(
                title: "저장 오류",
                message: error.localizedDescription
            )
        }
    }

    private static func sorted(_ notes: [MemoItem]) -> [MemoItem] {
        notes.sorted {
            if $0.updatedAt == $1.updatedAt {
                return $0.createdAt > $1.createdAt
            }

            return $0.updatedAt > $1.updatedAt
        }
    }

    private func applyRestoredNotes(_ restoredNotes: [MemoItem]) {
        notes = restoredNotes
        colorSelectionRequest = nil
        draft = .empty
        originalDraft = draft

        if restoredNotes.isEmpty {
            route = .emptyComposer
            requestFocus()
        } else {
            route = .memoList
        }
    }

    private static func isUserCancelled(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }
}
