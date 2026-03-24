import SwiftUI

struct NotesRootView: View {
    @ObservedObject var viewModel: NotesViewModel
    @ObservedObject var shortcutController: GlobalShortcutController
    let closePopover: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            Group {
                switch viewModel.route {
                case .memoList:
                    NotesListView(viewModel: viewModel)
                case .settings:
                    NotesSettingsView(
                        viewModel: viewModel,
                        shortcutController: shortcutController
                    )
                case .emptyComposer, .editor:
                    MemoEditorView(viewModel: viewModel, closePopover: closePopover)
                }
            }
            .padding(12)
        }
        .frame(width: AppTheme.popoverSize.width, height: AppTheme.popoverSize.height)
        .alert(item: $viewModel.activeAlert, content: alert)
    }

    private func alert(for alert: NotesAlert) -> Alert {
        switch alert {
        case .discardChanges:
            return Alert(
                title: Text("변경 사항을 버릴까요?"),
                message: Text("저장하지 않은 내용은 사라집니다."),
                primaryButton: .destructive(Text("버리기")) {
                    viewModel.discardChangesAndGoBack(closePopover: closePopover)
                },
                secondaryButton: .cancel {
                    viewModel.clearAlert()
                }
            )
        case .deleteMemo:
            return Alert(
                title: Text("메모를 삭제할까요?"),
                message: Text(
                    viewModel.isEditingExistingMemo
                        ? "삭제한 메모는 되돌릴 수 없습니다."
                        : "작성 중인 내용이 사라집니다."
                ),
                primaryButton: .destructive(Text("삭제")) {
                    viewModel.deleteCurrent()
                },
                secondaryButton: .cancel {
                    viewModel.clearAlert()
                }
            )
        case .deleteAllMemos:
            return Alert(
                title: Text("모든 메모를 삭제할까요?"),
                message: Text("저장된 메모가 모두 제거되며 되돌릴 수 없습니다."),
                primaryButton: .destructive(Text("모두 삭제")) {
                    viewModel.deleteAllMemos()
                },
                secondaryButton: .cancel {
                    viewModel.clearAlert()
                }
            )
        case .confirmRestore(let fileName):
            return Alert(
                title: Text("메모를 복원할까요?"),
                message: Text("현재 메모가 \(fileName) 내용으로 교체됩니다."),
                primaryButton: .default(Text("복원")) {
                    viewModel.restorePendingMemos()
                },
                secondaryButton: .cancel {
                    viewModel.clearAlert()
                }
            )
        case .notice(let title, let message):
            return Alert(
                title: Text(title),
                message: Text(message),
                dismissButton: .default(Text("확인")) {
                    viewModel.clearAlert()
                }
            )
        case .error(let title, let message):
            return Alert(
                title: Text(title),
                message: Text(message),
                dismissButton: .default(Text("확인")) {
                    viewModel.clearAlert()
                }
            )
        }
    }
}
