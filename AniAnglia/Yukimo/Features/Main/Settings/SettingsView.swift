//
//  SettingsView.swift
//  Yukimo settings: playback quality, auto-next, remember source,
//  notification toggle, theme, and "About" footer with explicit notes
//  about subscriptions and downloads (both blocked by the upstream
//  libanixart / Anixart limitations).
//

import SwiftUI
import Observation

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notifications = YukimoNotificationsManager.shared

    @State private var quality: Int = Int(SettingsBridge.shared().defaultQualityHeight)
    @State private var autoNext: Bool = SettingsBridge.shared().autoNextEpisode
    @State private var rememberSource: Bool = SettingsBridge.shared().rememberSource
    @State private var theme: YukimoTheme = SettingsBridge.shared().theme

    private static let qualityOptions: [(Int, String)] = [
        (0,    "Auto (рекомендуется)"),
        (240,  "240p — для медленной сети"),
        (360,  "360p"),
        (480,  "480p"),
        (720,  "720p (HD)"),
        (1080, "1080p (Full HD)"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                playbackSection
                notificationsSection
                appearanceSection
                comingSoonSection
                aboutSection
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
            }
            .task { await notifications.refresh() }
        }
    }

    // MARK: Playback

    private var playbackSection: some View {
        Section {
            Picker("Качество по умолчанию", selection: $quality) {
                ForEach(Self.qualityOptions, id: \.0) { value, label in
                    Text(label).tag(value)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: quality) { _, new in
                SettingsBridge.shared().defaultQualityHeight = new
            }

            Toggle("Авто-переход к следующей серии", isOn: $autoNext)
                .onChange(of: autoNext) { _, new in
                    SettingsBridge.shared().autoNextEpisode = new
                }

            Toggle("Запоминать выбранный плеер", isOn: $rememberSource)
                .onChange(of: rememberSource) { _, new in
                    SettingsBridge.shared().rememberSource = new
                }
        } header: {
            Text("Воспроизведение")
        } footer: {
            Text("«Auto» подбирает максимальное доступное качество, не превышая лимиты сети.")
        }
    }

    // MARK: Notifications

    private var notificationsSection: some View {
        Section {
            HStack {
                Image(systemName: notifications.state.isAllowed ? "bell.badge.fill" : "bell.slash.fill")
                    .foregroundStyle(notifications.state.isAllowed ? YukimoColor.primaryCoral : YukimoColor.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(notificationsTitle)
                        .font(YukimoTypography.body)
                        .foregroundStyle(YukimoColor.textPrimary)
                    Text(notificationsSubtitle)
                        .font(YukimoTypography.caption)
                        .foregroundStyle(YukimoColor.textTertiary)
                }
                Spacer()
                actionButton
            }
        } header: {
            Text("Уведомления")
        } footer: {
            Text("Уведомления о новых сериях по конкретному релизу пока недоступны — API Anixart не отдаёт подписки на релизы (есть только подписки на каналы/статьи). Когда поддержка появится в libanixart, мы это включим.")
        }
    }

    private var notificationsTitle: String {
        switch notifications.state {
        case .allowed, .provisional, .ephemeral: return "Разрешены"
        case .denied:                            return "Запрещены в настройках iOS"
        case .unknown:                           return "Включить уведомления"
        }
    }

    private var notificationsSubtitle: String {
        switch notifications.state {
        case .allowed, .provisional, .ephemeral:
            return "Yukimo может показать важные уведомления."
        case .denied:
            return "Откройте Настройки iOS → Yukimo → Уведомления."
        case .unknown:
            return "Спросим разрешение у iOS."
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch notifications.state {
        case .unknown:
            Button("Включить") {
                Task { await notifications.requestIfNeeded() }
            }
            .foregroundStyle(YukimoColor.primaryCoral)
        case .denied:
            Button("Открыть") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .foregroundStyle(YukimoColor.primaryCoral)
        default:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(YukimoColor.success)
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        Section("Внешний вид") {
            Picker("Тема", selection: $theme) {
                Text("Системная").tag(YukimoTheme.system)
                Text("Светлая").tag(YukimoTheme.light)
                Text("Тёмная").tag(YukimoTheme.dark)
            }
            .pickerStyle(.segmented)
            .onChange(of: theme) { _, new in
                SettingsBridge.shared().theme = new
            }
        }
    }

    // MARK: Downloads + coming-soon

    private var comingSoonSection: some View {
        Section {
            NavigationLink(destination: DownloadsView()) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(YukimoColor.primaryCoral)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Скачанные эпизоды")
                            .foregroundStyle(YukimoColor.textPrimary)
                        Text("\(YukimoDownloadsManager.shared.entries.count) в списке")
                            .font(YukimoTypography.caption)
                            .foregroundStyle(YukimoColor.textTertiary)
                    }
                    Spacer()
                }
            }
            HStack(spacing: 12) {
                Image(systemName: "bell.and.waves.left.and.right")
                    .foregroundStyle(YukimoColor.textTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Подписка на релизы")
                        .foregroundStyle(YukimoColor.textPrimary)
                    Text("Пока недоступно")
                        .font(YukimoTypography.caption)
                        .foregroundStyle(YukimoColor.textTertiary)
                }
                Spacer()
            }
        } header: {
            Text("Контент")
        } footer: {
            Text("«Скачать» в плеере запускает параллельную загрузку потока пока вы смотрите. Подписки на новые серии требуют поддержки на серверной стороне Anixart, которой сейчас нет.")
        }
    }

    private var aboutSection: some View {
        Section("О приложении") {
            HStack {
                Text("Версия")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(YukimoColor.textTertiary)
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
