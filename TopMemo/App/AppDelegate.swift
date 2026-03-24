import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var popoverCoordinator: PopoverCoordinator?
    private var globalShortcutController: GlobalShortcutController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let notesViewModel = NotesViewModel(store: NotesStore())
        let statusBarController = StatusBarController()
        let globalShortcutController = GlobalShortcutController { [weak self] in
            self?.popoverCoordinator?.showNewMemoFromShortcut()
        }
        self.globalShortcutController = globalShortcutController
        let popoverCoordinator = PopoverCoordinator(
            statusBarController: statusBarController,
            viewModel: notesViewModel,
            shortcutController: globalShortcutController
        )
        self.popoverCoordinator = popoverCoordinator

        DispatchQueue.main.async { [weak self] in
            self?.popoverCoordinator?.showNewMemoOnLaunch()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
