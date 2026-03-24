import AppKit
import Carbon
import Foundation

struct GlobalShortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String
    let modifierSymbols: [String]

    static let `default` = GlobalShortcut(primaryModifier: .command, letter: "M")!

    init(
        keyCode: UInt32,
        modifiers: UInt32,
        keyLabel: String,
        modifierSymbols: [String]
    ) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
        self.modifierSymbols = modifierSymbols
    }

    init?(primaryModifier: ShortcutModifier, letter: String) {
        guard ShortcutModifier.primaryModifiers.contains(primaryModifier),
              let normalizedLetter = ShortcutLetter.normalized(letter),
              let keyCode = ShortcutLetter.keyCode(for: normalizedLetter) else {
            return nil
        }

        self.init(
            keyCode: keyCode,
            modifiers: primaryModifier.carbonFlag | ShortcutModifier.shift.carbonFlag,
            keyLabel: normalizedLetter,
            modifierSymbols: [primaryModifier.symbol, ShortcutModifier.shift.symbol]
        )
    }

    var displayText: String {
        (modifierSymbols + [keyLabel]).joined(separator: " ")
    }

    var primaryModifier: ShortcutModifier? {
        let selectedPrimaryModifiers = ShortcutModifier.primaryModifiers.filter { modifier in
            modifiers & modifier.carbonFlag != 0
        }

        guard selectedPrimaryModifiers.count == 1 else {
            return nil
        }

        return selectedPrimaryModifiers[0]
    }

    var letter: String? {
        ShortcutLetter.letter(for: keyCode)
    }

    var normalizedShortcut: GlobalShortcut? {
        guard let primaryModifier,
              modifiers == (primaryModifier.carbonFlag | ShortcutModifier.shift.carbonFlag),
              let letter else {
            return nil
        }

        return GlobalShortcut(primaryModifier: primaryModifier, letter: letter)
    }
}

enum ShortcutModifier: CaseIterable, Hashable {
    case command
    case shift
    case option
    case control

    static let primaryModifiers: [ShortcutModifier] = [.command, .option, .control]

    var eventFlag: NSEvent.ModifierFlags {
        switch self {
        case .command:
            return .command
        case .shift:
            return .shift
        case .option:
            return .option
        case .control:
            return .control
        }
    }

    var carbonFlag: UInt32 {
        switch self {
        case .command:
            return UInt32(cmdKey)
        case .shift:
            return UInt32(shiftKey)
        case .option:
            return UInt32(optionKey)
        case .control:
            return UInt32(controlKey)
        }
    }

    var symbol: String {
        switch self {
        case .command:
            return "⌘"
        case .shift:
            return "⇧"
        case .option:
            return "⌥"
        case .control:
            return "⌃"
        }
    }

    var selectionTitle: String {
        switch self {
        case .command:
            return "커맨드"
        case .shift:
            return "쉬프트"
        case .option:
            return "옵션"
        case .control:
            return "컨트롤"
        }
    }

    static func relevantFlags(from flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        let trackedFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        return flags.intersection(trackedFlags)
    }

    static func newlyPressed(
        previous: NSEvent.ModifierFlags,
        current: NSEvent.ModifierFlags
    ) -> [ShortcutModifier] {
        allCases.filter { modifier in
            !previous.contains(modifier.eventFlag) && current.contains(modifier.eventFlag)
        }
    }

    static func orderedSymbols(from flags: NSEvent.ModifierFlags) -> [String] {
        allCases
            .filter { flags.contains($0.eventFlag) }
            .map(\.symbol)
    }

    static func carbonFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
        allCases.reduce(into: UInt32(0)) { result, modifier in
            if flags.contains(modifier.eventFlag) {
                result |= modifier.carbonFlag
            }
        }
    }
}

enum ShortcutLetter {
    static let all = [
        "A", "B", "C", "D", "E", "F", "G",
        "H", "I", "J", "K", "L", "M", "N",
        "O", "P", "Q", "R", "S", "T", "U",
        "V", "W", "X", "Y", "Z"
    ]

    private static let keyCodeByLetter: [String: UInt32] = [
        "A": UInt32(kVK_ANSI_A),
        "B": UInt32(kVK_ANSI_B),
        "C": UInt32(kVK_ANSI_C),
        "D": UInt32(kVK_ANSI_D),
        "E": UInt32(kVK_ANSI_E),
        "F": UInt32(kVK_ANSI_F),
        "G": UInt32(kVK_ANSI_G),
        "H": UInt32(kVK_ANSI_H),
        "I": UInt32(kVK_ANSI_I),
        "J": UInt32(kVK_ANSI_J),
        "K": UInt32(kVK_ANSI_K),
        "L": UInt32(kVK_ANSI_L),
        "M": UInt32(kVK_ANSI_M),
        "N": UInt32(kVK_ANSI_N),
        "O": UInt32(kVK_ANSI_O),
        "P": UInt32(kVK_ANSI_P),
        "Q": UInt32(kVK_ANSI_Q),
        "R": UInt32(kVK_ANSI_R),
        "S": UInt32(kVK_ANSI_S),
        "T": UInt32(kVK_ANSI_T),
        "U": UInt32(kVK_ANSI_U),
        "V": UInt32(kVK_ANSI_V),
        "W": UInt32(kVK_ANSI_W),
        "X": UInt32(kVK_ANSI_X),
        "Y": UInt32(kVK_ANSI_Y),
        "Z": UInt32(kVK_ANSI_Z)
    ]

    private static let letterByKeyCode = Dictionary(
        uniqueKeysWithValues: keyCodeByLetter.map { ($0.value, $0.key) }
    )

    static func normalized(_ value: String) -> String? {
        let filtered = value.uppercased().filter { character in
            character.unicodeScalars.allSatisfy { scalar in
                scalar.value >= 65 && scalar.value <= 90
            }
        }

        guard let letter = filtered.first else {
            return nil
        }

        return String(letter)
    }

    static func keyCode(for letter: String) -> UInt32? {
        guard let normalizedLetter = normalized(letter) else {
            return nil
        }

        return keyCodeByLetter[normalizedLetter]
    }

    static func letter(for keyCode: UInt32) -> String? {
        letterByKeyCode[keyCode]
    }
}

enum ShortcutKeyLabel {
    static func label(for event: NSEvent) -> String? {
        switch Int(event.keyCode) {
        case kVK_Return:
            return "Return"
        case kVK_Tab:
            return "Tab"
        case kVK_Space:
            return "Space"
        case kVK_Delete:
            return "Delete"
        case kVK_ForwardDelete:
            return "Forward Delete"
        case kVK_Help:
            return "Help"
        case kVK_Home:
            return "Home"
        case kVK_End:
            return "End"
        case kVK_PageUp:
            return "Page Up"
        case kVK_PageDown:
            return "Page Down"
        case kVK_LeftArrow:
            return "Left"
        case kVK_RightArrow:
            return "Right"
        case kVK_UpArrow:
            return "Up"
        case kVK_DownArrow:
            return "Down"
        case kVK_F1:
            return "F1"
        case kVK_F2:
            return "F2"
        case kVK_F3:
            return "F3"
        case kVK_F4:
            return "F4"
        case kVK_F5:
            return "F5"
        case kVK_F6:
            return "F6"
        case kVK_F7:
            return "F7"
        case kVK_F8:
            return "F8"
        case kVK_F9:
            return "F9"
        case kVK_F10:
            return "F10"
        case kVK_F11:
            return "F11"
        case kVK_F12:
            return "F12"
        default:
            guard let characters = event.charactersIgnoringModifiers,
                  !characters.isEmpty else {
                return nil
            }

            return characters.uppercased()
        }
    }
}
