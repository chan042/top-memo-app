import Carbon
import Combine
import Foundation

@MainActor
final class GlobalShortcutController: ObservableObject {
    private enum Constants {
        static let signature: OSType = 0x544D4D4D
        static let identifier = UInt32(1)
        static let storageKey = "TopMemo.globalShortcut"
    }

    @Published private(set) var shortcut: GlobalShortcut

    private let onShortcut: @MainActor () -> Void
    private let userDefaults: UserDefaults
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(
        onShortcut: @escaping @MainActor () -> Void,
        userDefaults: UserDefaults = .standard
    ) {
        self.onShortcut = onShortcut
        self.userDefaults = userDefaults
        self.shortcut = Self.loadShortcut(from: userDefaults)
        installEventHandler()
        do {
            try registerShortcut(shortcut)
        } catch {
            NSLog("Failed to register initial global shortcut: %@", error.localizedDescription)
        }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func updateShortcut(_ shortcut: GlobalShortcut) throws {
        guard let normalizedShortcut = shortcut.normalizedShortcut else {
            throw GlobalShortcutValidationError()
        }

        let previousShortcut = self.shortcut
        unregisterShortcut()

        do {
            try registerShortcut(normalizedShortcut)
            self.shortcut = normalizedShortcut
            saveShortcut(normalizedShortcut)
        } catch {
            do {
                try registerShortcut(previousShortcut)
            } catch {
                NSLog("Failed to restore previous global shortcut: %@", error.localizedDescription)
            }

            throw error
        }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let callback: EventHandlerUPP = { _, event, userData in
            guard let userData else {
                return noErr
            }

            let controller = Unmanaged<GlobalShortcutController>
                .fromOpaque(userData)
                .takeUnretainedValue()
            controller.handleHotKeyEvent(event)
            return noErr
        }

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )

        if status != noErr {
            NSLog("Failed to install global shortcut handler: %d", status)
        }
    }

    private func registerShortcut(_ shortcut: GlobalShortcut) throws {
        let hotKeyID = EventHotKeyID(
            signature: Constants.signature,
            id: Constants.identifier
        )
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            hotKeyRef = nil
            throw GlobalShortcutRegistrationError(status: status)
        }
    }

    private func unregisterShortcut() {
        guard let hotKeyRef else {
            return
        }

        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    private func handleHotKeyEvent(_ event: EventRef?) {
        guard let event else {
            return
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr,
              hotKeyID.signature == Constants.signature,
              hotKeyID.id == Constants.identifier else {
            return
        }

        Task { @MainActor in
            onShortcut()
        }
    }

    private func saveShortcut(_ shortcut: GlobalShortcut) {
        guard let data = try? JSONEncoder().encode(shortcut) else {
            return
        }

        userDefaults.set(data, forKey: Constants.storageKey)
    }

    private static func loadShortcut(from userDefaults: UserDefaults) -> GlobalShortcut {
        guard let data = userDefaults.data(forKey: Constants.storageKey),
              let shortcut = try? JSONDecoder().decode(GlobalShortcut.self, from: data),
              let normalizedShortcut = shortcut.normalizedShortcut else {
            return .default
        }

        return normalizedShortcut
    }
}

private struct GlobalShortcutValidationError: LocalizedError {
    var errorDescription: String? {
        "단축키는 커맨드, 옵션, 컨트롤 중 하나와 Shift, 영문 1자만 사용할 수 있습니다."
    }
}

private struct GlobalShortcutRegistrationError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        switch status {
        case OSStatus(eventHotKeyExistsErr):
            return "이미 사용 중인 조합이라 등록할 수 없습니다. 다른 키 조합으로 다시 시도해 주세요."
        case OSStatus(paramErr):
            return "이 조합은 전역 단축키로 사용할 수 없습니다."
        default:
            return "단축키를 등록하지 못했습니다. 다른 조합으로 다시 시도해 주세요."
        }
    }
}
