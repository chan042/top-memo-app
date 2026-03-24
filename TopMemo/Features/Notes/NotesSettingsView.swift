import SwiftUI
import UniformTypeIdentifiers

struct NotesSettingsView: View {
    @ObservedObject var viewModel: NotesViewModel
    @ObservedObject var shortcutController: GlobalShortcutController
    @State private var isShowingRestorePicker = false
    @State private var isShowingShortcutCapture = false

    var body: some View {
        ZStack {
            // Refined Backdrop
            AppTheme.background
                .ignoresSafeArea()
            
            // Subtle ambient glow
            Circle()
                .fill(AppTheme.actionYellow.opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 50)
                .offset(x: 150, y: -200)

            VStack(spacing: 0) {
                header
                
                Divider()
                    .overlay(AppTheme.subtleBorder)
                    .padding(.horizontal, 20)

                ScrollView {
                    VStack(spacing: 24) {
                        shortcutStudioCard
                        libraryVaultCard
                        dangerZoneCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .scrollIndicators(.never)
            }
            .frame(maxWidth: .infinity, alignment: .top)

            if isShowingShortcutCapture {
                ShortcutCaptureOverlay(
                    currentShortcut: shortcutController.shortcut,
                    onCancel: {
                        isShowingShortcutCapture = false
                    },
                    onSave: { shortcut in
                        applyShortcut(shortcut)
                    }
                )
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isShowingShortcutCapture)
        .fileImporter(
            isPresented: $isShowingRestorePicker,
            allowedContentTypes: [.json]
        ) { result in
            viewModel.handleRestoreFileSelection(result)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                viewModel.closeSettings()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.elevatedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.memoRowBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text("설정")
                    .font(.system(size: 22, weight: .bold))
                
                Text("빠른 실행과 백업을 설정합니다.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.subduedText)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var shortcutStudioCard: some View {
        settingsSection(
            eyebrow: "Quick Launch",
            title: "단축키",
            subtitle: "실행 단축키를 바꿉니다.",
            icon: "keyboard"
        ) {
            VStack(spacing: 16) {
                HStack(alignment: .center) {
                    Text("현재 단축키")
                        .font(.system(size: 11, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundColor(AppTheme.subduedText)
                    Spacer()
                    shortcutTokenDisplay
                }
                .padding(16)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.subtleBorder, lineWidth: 1)
                )

                Button {
                    isShowingShortcutCapture = true
                } label: {
                    HStack {
                        Spacer()
                        Text("단축키 다시 지정")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(AppTheme.actionYellow.opacity(0.2))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppTheme.actionYellow.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var shortcutTokenDisplay: some View {
        HStack(spacing: 6) {
            let tokens = shortcutController.shortcut.modifierSymbols + [shortcutController.shortcut.keyLabel]
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                Text(token)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.elevatedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.memoRowBorder, lineWidth: 1)
                    )
            }
        }
    }

    private var libraryVaultCard: some View {
        settingsSection(
            eyebrow: "Library",
            title: "백업",
            subtitle: "메모를 내보내거나 복원합니다.",
            icon: "externaldrive"
        ) {
            VStack(spacing: 12) {
                actionRow(
                    title: "모든 메모 내보내기",
                    subtitle: "JSON 백업을 저장합니다.",
                    icon: "square.and.arrow.down",
                    accent: .blue,
                    action: { viewModel.exportAllNotes() }
                )
                .disabled(!viewModel.hasNotes)
                .opacity(viewModel.hasNotes ? 1.0 : 0.5)

                actionRow(
                    title: "복원 파일 선택",
                    subtitle: "백업 파일로 복원합니다.",
                    icon: "arrow.clockwise.circle",
                    accent: .green,
                    action: { isShowingRestorePicker = true }
                )
            }
        }
    }

    private var dangerZoneCard: some View {
        Button {
            viewModel.requestDeleteAllMemos()
        } label: {
            Text("모든 메모 삭제")
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .foregroundColor(viewModel.hasNotes ? .red : AppTheme.subduedText)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.red.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.hasNotes)
        .opacity(viewModel.hasNotes ? 1.0 : 0.5)
    }

    private func settingsSection<Content: View>(
        eyebrow: String,
        title: String,
        subtitle: String,
        icon: String,
        isDanger: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isDanger ? .red : .primary)
                    .frame(width: 42, height: 42)
                    .background((isDanger ? Color.red : Color.primary).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow)
                        .font(.system(size: 11, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundColor(isDanger ? .red.opacity(0.8) : AppTheme.subduedText)
                    
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(isDanger ? .red : .primary)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.subduedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            content()
        }
        .padding(20)
        .background(AppTheme.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(isDanger ? Color.red.opacity(0.3) : AppTheme.subtleBorder, lineWidth: 1)
        )
    }

    private func actionRow(title: String, subtitle: String, icon: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(accent)
                    .frame(width: 44, height: 44)
                    .background(accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.subduedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.subduedText.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppTheme.subtleBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func applyShortcut(_ shortcut: GlobalShortcut) {
        do {
            try shortcutController.updateShortcut(shortcut)
            isShowingShortcutCapture = false
        } catch {
            viewModel.activeAlert = .error(
                title: "단축키 변경 오류",
                message: error.localizedDescription
            )
        }
    }
}
