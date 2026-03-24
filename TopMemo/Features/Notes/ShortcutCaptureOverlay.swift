import AppKit
import Carbon
import SwiftUI

struct ShortcutCaptureOverlay: View {
    let currentShortcut: GlobalShortcut
    let onCancel: () -> Void
    let onSave: (GlobalShortcut) -> Void

    @StateObject private var recorder = ShortcutRecorder()

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.elevatedBackground)
                .overlay {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("단축키 변경")
                                .font(.system(size: 18, weight: .bold, design: .serif))

                            Text("현재 \(currentShortcut.displayText)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.subduedText)
                        }

                        captureCard

                        Text(recorder.helperText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.subduedText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("순서: 보조키 1개 -> Shift -> 영문 1자")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.subduedText.opacity(0.9))

                        HStack(spacing: 10) {
                            Button("취소") {
                                onCancel()
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AppTheme.background.opacity(0.78))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppTheme.memoRowBorder, lineWidth: 1)
                            }

                            Button("저장") {
                                guard let shortcut = recorder.candidateShortcut else {
                                    return
                                }

                                onSave(shortcut)
                            }
                            .buttonStyle(.plain)
                            .disabled(recorder.candidateShortcut == nil)
                            .foregroundStyle(
                                recorder.candidateShortcut == nil
                                    ? AppTheme.subduedText
                                    : Color.primary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AppTheme.actionYellow.opacity(0.82))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(AppTheme.actionYellow.opacity(0.28), lineWidth: 1)
                            }
                        }
                    }
                    .padding(18)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.subtleBorder, lineWidth: 1)
                }
                .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .onAppear {
            recorder.start()
        }
        .onDisappear {
            recorder.stop()
        }
    }

    private var captureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("입력 중")
                .font(.system(size: 11, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.subduedText)

            Group {
                if recorder.displayTokens.isEmpty {
                    Text("대기 중")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.subduedText)
                } else {
                    HStack(spacing: 6) {
                        ForEach(recorder.displayTokens, id: \.self) { token in
                            tokenView(token)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.background.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.memoRowBorder, lineWidth: 1)
        }
    }

    private func tokenView(_ token: String) -> some View {
        Text(token)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.elevatedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.memoRowBorder, lineWidth: 1)
            }
    }
}

@MainActor
private final class ShortcutRecorder: ObservableObject {
    @Published private(set) var primaryModifier: ShortcutModifier?
    @Published private(set) var isShiftCaptured = false
    @Published private(set) var capturedLetter: String?

    var candidateShortcut: GlobalShortcut? {
        guard let primaryModifier,
              isShiftCaptured,
              let capturedLetter else {
            return nil
        }

        return GlobalShortcut(primaryModifier: primaryModifier, letter: capturedLetter)
    }

    var displayTokens: [String] {
        var tokens: [String] = []

        if let primaryModifier {
            tokens.append(primaryModifier.symbol)
        }

        if isShiftCaptured {
            tokens.append(ShortcutModifier.shift.symbol)
        }

        if let capturedLetter {
            tokens.append(capturedLetter)
        }

        return tokens
    }

    var helperText: String {
        if primaryModifier == nil {
            return "커맨드, 옵션, 컨트롤 중 하나를 누르세요."
        }

        if !isShiftCaptured {
            return "이제 Shift를 누르세요."
        }

        if capturedLetter == nil {
            return "마지막으로 영문 한 글자를 누르세요."
        }

        return "저장 버튼이 활성화되었습니다. Delete를 누르면 다시 입력합니다."
    }

    private var eventMonitor: Any?

    func start() {
        reset()
        stop()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self else {
                return event
            }

            switch event.type {
            case .flagsChanged:
                return handleFlagsChanged(event)
            case .keyDown:
                return handleKeyDown(event)
            default:
                return event
            }
        }
    }

    func stop() {
        guard let eventMonitor else {
            return
        }

        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }

    private func handleFlagsChanged(_ event: NSEvent) -> NSEvent? {
        let flags = ShortcutModifier.relevantFlags(from: event.modifierFlags)

        guard !flags.isEmpty else {
            return nil
        }

        let primaryModifiers = ShortcutModifier.primaryModifiers.filter { flags.contains($0.eventFlag) }

        if primaryModifiers.count > 1 {
            reset()
            return nil
        }

        if let primaryModifier = primaryModifiers.first, !flags.contains(.shift) {
            registerPrimaryModifier(primaryModifier)
            return nil
        }

        if flags.contains(.shift), primaryModifier != nil {
            isShiftCaptured = true
            capturedLetter = nil
            return nil
        }

        return nil
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        if event.isARepeat {
            return nil
        }

        switch Int(event.keyCode) {
        case kVK_Delete, kVK_ForwardDelete:
            reset()
            return nil
        case kVK_Escape:
            return nil
        default:
            break
        }

        guard let primaryModifier,
              isShiftCaptured,
              let letter = ShortcutLetter.letter(for: UInt32(event.keyCode)) else {
            return nil
        }

        self.primaryModifier = primaryModifier
        capturedLetter = letter
        return nil
    }

    private func registerPrimaryModifier(_ modifier: ShortcutModifier) {
        primaryModifier = modifier
        isShiftCaptured = false
        capturedLetter = nil
    }

    private func reset() {
        primaryModifier = nil
        isShiftCaptured = false
        capturedLetter = nil
    }
}
