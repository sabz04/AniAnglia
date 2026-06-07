//
//  DownloadsView.swift
//  Lists downloaded episodes grouped by anime title. Tapping a finished
//  entry opens YukimoPlayerView in offline mode with the local m3u8 —
//  no libanixart round-trip, no network.
//

import SwiftUI
import UIKit

struct DownloadsView: View {
    @State private var manager = YukimoDownloadsManager.shared
    @State private var playerSession: OfflinePlayerSession?
    @State private var shareItem: ShareItem?
    @State private var exportingID: String?
    @State private var exportError: String?
    @State private var savingID: String?
    @State private var saveMessage: String?
    @State private var saveIsError: Bool = false

    private struct OfflinePlayerSession: Identifiable {
        let entry: YukimoDownloadsManager.Entry
        let manifestURL: URL
        var id: String { entry.id }
    }

    private struct ShareItem: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    private var groups: [(title: String, entries: [YukimoDownloadsManager.Entry])] {
        // Stable order: newest entry per group decides the section order.
        let byTitle = Dictionary(grouping: manager.entries) { $0.releaseTitle }
        return byTitle
            .map { (title: $0.key, entries: $0.value.sorted { $0.displayNumber < $1.displayNumber }) }
            .sorted { lhs, rhs in
                let lhsLatest = lhs.entries.map(\.createdAt).max() ?? .distantPast
                let rhsLatest = rhs.entries.map(\.createdAt).max() ?? .distantPast
                return lhsLatest > rhsLatest
            }
    }

    var body: some View {
        Group {
            if manager.entries.isEmpty {
                emptyState
            } else {
                groupedList
            }
        }
        .navigationTitle("Скачанное")
        .navigationBarTitleDisplayMode(.large)
        .background(YukimoColor.background.ignoresSafeArea())
        .fullScreenCover(item: $playerSession) { session in
            YukimoPlayerView(
                releaseID: session.entry.releaseID,
                releaseTitle: session.entry.releaseTitle,
                initialTypeID: session.entry.typeID,
                initialSourceID: session.entry.sourceID,
                initialPosition: session.entry.position,
                initialEpisodes: [],
                initialTypes: [],
                initialSources: [],
                forcedLocalManifest: session.manifestURL,
                offlineEntries: manager.finishedEntries(forReleaseID: session.entry.releaseID))
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url)
        }
        .alert("Не удалось экспортировать", isPresented: errorBinding) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
        .alert(saveIsError ? "Не удалось сохранить" : "Сохранено в Фото",
               isPresented: saveBinding) {
            Button("OK") { saveMessage = nil }
        } message: {
            Text(saveMessage ?? "")
        }
    }

    private var saveBinding: Binding<Bool> {
        Binding(get: { saveMessage != nil }, set: { if !$0 { saveMessage = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })
    }

    private func exportAndShare(_ entry: YukimoDownloadsManager.Entry) {
        guard entry.status == .finished, exportingID == nil else { return }
        Task {
            exportingID = entry.id
            defer { exportingID = nil }
            do {
                let url = try await manager.exportMP4(forEntry: entry.id)
                shareItem = ShareItem(url: url)
            } catch {
                exportError = error.localizedDescription
            }
        }
    }

    private func exportAndSaveToPhotos(_ entry: YukimoDownloadsManager.Entry) {
        guard entry.status == .finished, savingID == nil else { return }
        Task {
            savingID = entry.id
            defer { savingID = nil }
            do {
                let url = try await manager.exportMP4(forEntry: entry.id)
                try await manager.saveToPhotos(url)
                saveIsError = false
                saveMessage = "«\(entry.releaseTitle) — Серия \(entry.displayNumber)» добавлено в галерею."
            } catch {
                saveIsError = true
                saveMessage = error.localizedDescription
            }
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: YukimoSpacing.md) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(YukimoColor.primaryCoralLight)
            Text("Пока ничего нет")
                .font(YukimoTypography.title3)
                .foregroundStyle(YukimoColor.textPrimary)
            Text("Откройте любой эпизод и нажмите «Скачать» в плеере — мы соберём поток локально, пока вы смотрите.")
                .font(YukimoTypography.body)
                .foregroundStyle(YukimoColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, YukimoSpacing.xxl)
        }
        .padding(.top, YukimoSpacing.huge)
    }

    // MARK: Grouped list

    private var groupedList: some View {
        List {
            ForEach(groups, id: \.title) { group in
                Section {
                    ForEach(group.entries) { entry in
                        row(entry)
                    }
                    .onDelete { idx in
                        for i in idx {
                            manager.delete(id: group.entries[i].id)
                        }
                    }
                } header: {
                    Text(group.title)
                        .font(YukimoTypography.bodyEmph)
                        .foregroundStyle(YukimoColor.textPrimary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func row(_ entry: YukimoDownloadsManager.Entry) -> some View {
        Button {
            tap(entry)
        } label: {
            HStack(spacing: YukimoSpacing.md) {
                numberBadge(entry)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Серия \(entry.displayNumber)")
                        .font(YukimoTypography.body)
                        .foregroundStyle(YukimoColor.textPrimary)

                    metadataLine(entry)
                    statusLine(entry)

                    if entry.status == .downloading || entry.status == .queued {
                        ProgressView(value: entry.progress)
                            .tint(YukimoColor.primaryCoral)
                    }
                }

                Spacer()

                if entry.status == .finished {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if entry.status == .finished {
                Button {
                    exportAndShare(entry)
                } label: {
                    Label(exportingID == entry.id ? "Готовим MP4…" : "Поделиться (MP4)",
                          systemImage: "square.and.arrow.up")
                }
                .disabled(exportingID == entry.id)

                Button {
                    exportAndSaveToPhotos(entry)
                } label: {
                    Label(savingID == entry.id ? "Сохраняем…" : "Сохранить в Фото",
                          systemImage: "photo.on.rectangle.angled")
                }
                .disabled(savingID == entry.id)
            }
            if entry.status == .downloading || entry.status == .queued {
                Button("Отменить", role: .destructive) {
                    manager.cancel(id: entry.id)
                }
            }
            Button("Удалить", role: .destructive) {
                manager.delete(id: entry.id)
            }
        }
        .swipeActions(edge: .trailing) {
            if entry.status == .finished {
                Button {
                    exportAndShare(entry)
                } label: {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                }
                .tint(YukimoColor.primaryCoral)
                Button {
                    exportAndSaveToPhotos(entry)
                } label: {
                    Label("В Фото", systemImage: "photo.on.rectangle.angled")
                }
                .tint(.purple)
            }
        }
    }

    /// `UIActivityViewController` wrapper so we can drop the share sheet
    /// straight into `.sheet(item:)`.
    private struct ShareSheet: UIViewControllerRepresentable {
        let url: URL
        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: [url], applicationActivities: nil)
        }
        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }

    private func tap(_ entry: YukimoDownloadsManager.Entry) {
        guard entry.status == .finished,
              let url = manager.localPlaybackURL(forEntry: entry.id) else { return }
        playerSession = OfflinePlayerSession(entry: entry, manifestURL: url)
    }

    /// Voice (Озвучка) / player (Плеер) / episode name — captured at
    /// download time so the row reflects what the user actually saved.
    @ViewBuilder
    private func metadataLine(_ entry: YukimoDownloadsManager.Entry) -> some View {
        let text = metadataString(entry)
        if !text.isEmpty {
            Text(text)
                .font(YukimoTypography.footnote)
                .foregroundStyle(YukimoColor.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func metadataString(_ entry: YukimoDownloadsManager.Entry) -> String {
        var parts: [String] = []
        if !entry.typeName.isEmpty   { parts.append("Озвучка: \(entry.typeName)") }
        if !entry.sourceName.isEmpty { parts.append("Плеер: \(entry.sourceName)") }
        if let name = entry.episodeName, !name.isEmpty { parts.append(name) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func numberBadge(_ entry: YukimoDownloadsManager.Entry) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: YukimoRadius.sm, style: .continuous)
                .fill(entry.status == .finished ? YukimoColor.success.opacity(0.20) : YukimoColor.softPink)
                .frame(width: 44, height: 44)
            Text("\(entry.displayNumber)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(entry.status == .finished ? YukimoColor.success : YukimoColor.primaryCoralDark)
        }
    }

    @ViewBuilder
    private func statusLine(_ entry: YukimoDownloadsManager.Entry) -> some View {
        switch entry.status {
        case .finished:
            Label("Скачано", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(YukimoTypography.caption)
                .foregroundStyle(YukimoColor.success)
        case .downloading:
            Text("Качается · \(Int((entry.progress * 100).rounded()))%")
                .font(YukimoTypography.caption)
                .foregroundStyle(YukimoColor.primaryCoral)
                .monospacedDigit()
        case .queued:
            Label("В очереди", systemImage: "hourglass")
                .labelStyle(.titleAndIcon)
                .font(YukimoTypography.caption)
                .foregroundStyle(YukimoColor.textTertiary)
        case .failed:
            Label(entry.failureReason ?? "Ошибка", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.titleAndIcon)
                .font(YukimoTypography.caption)
                .foregroundStyle(YukimoColor.danger)
        case .cancelled:
            Label("Отменено", systemImage: "xmark.circle")
                .labelStyle(.titleAndIcon)
                .font(YukimoTypography.caption)
                .foregroundStyle(YukimoColor.textTertiary)
        }
    }
}
