//
//  YukimoDownloadsManager.swift
//  Offline HLS storage built on `AVAssetDownloadURLSession`. The manual
//  segment-download approach AVPlayer rejected with CoreMediaErrorDomain
//  -12865 — iOS won't read local HLS playlists from `file://` URLs.
//  AVAssetDownloadTask is the supported path: it produces a `.movpkg`
//  bundle that AVPlayer plays directly.
//
//  Each `Entry` also remembers which source/type/episode it belongs to
//  (Плеер / Озвучка / Серия N + название) so the Downloads list shows
//  exactly what the user picked at the time of download.
//

import Foundation
import AVFoundation
import Photos
import Observation

@Observable
@MainActor
final class YukimoDownloadsManager {
    static let shared = YukimoDownloadsManager()

    enum Status: String, Codable, Equatable {
        case queued
        case downloading
        case finished
        case failed
        case cancelled
    }

    struct Entry: Codable, Identifiable, Equatable {
        var id: String
        var releaseID: Int64
        var sourceID: Int64
        var sourceName: String
        var typeID: Int64
        var typeName: String
        var position: Int
        var displayNumber: Int
        var releaseTitle: String
        var episodeName: String?
        var manifestRemoteURL: String
        /// "720p", "Auto", "hls" — whatever the variant the user picked
        /// said. Stored separately because AVAssetDownloadTask sometimes
        /// downloads a different bitrate than requested.
        var qualityLabel: String = ""
        var status: Status
        var progress: Double
        var localBookmark: Data?
        /// Plain path fallback when bookmarks fail (observed under
        /// `Library/Caches/com.apple.UserManagedAssets.<UUID>/`).
        var localPath: String?
        var failureReason: String?
        var createdAt: Date
    }

    private(set) var entries: [Entry] = []

    @ObservationIgnored
    private var taskMap: [String: AVAssetDownloadTask] = [:]

    @ObservationIgnored
    private let delegateProxy = DelegateProxy()

    @ObservationIgnored
    private lazy var session: AVAssetDownloadURLSession = {
        let cfg = URLSessionConfiguration.background(withIdentifier: "yukimo.downloads.v1")
        cfg.allowsCellularAccess = true
        return AVAssetDownloadURLSession(
            configuration: cfg,
            assetDownloadDelegate: delegateProxy,
            delegateQueue: .main)
    }()

    private let stateKey = "yukimo.downloads.state.v2"

    init() {
        loadState()
        delegateProxy.owner = self
        _ = session   // resurface in-flight background tasks
    }

    // MARK: API

    static func entryID(releaseID: Int64, sourceID: Int64, position: Int) -> String {
        "\(releaseID)-\(sourceID)-\(position)"
    }

    func entry(releaseID: Int64, sourceID: Int64, position: Int) -> Entry? {
        let id = Self.entryID(releaseID: releaseID, sourceID: sourceID, position: position)
        return entries.first { $0.id == id }
    }

    func localPlaybackURL(forEntry id: String) -> URL? {
        guard let e = entries.first(where: { $0.id == id }) else {
            print("[Yukimo.localURL] entry id=\(id) not found")
            return nil
        }
        guard e.status == .finished else {
            print("[Yukimo.localURL] id=\(id) status=\(e.status.rawValue) (not finished)")
            return nil
        }
        // Prefer bookmark — survives system relocation.
        if let bookmark = e.localBookmark {
            var stale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmark,
                    options: [],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale)
                let exists = FileManager.default.fileExists(atPath: url.path)
                print("[Yukimo.localURL] id=\(id) bookmark resolved=\(url.path) stale=\(stale) exists=\(exists)")
                if exists {
                    // Belt + suspenders: persist freshly-resolved path so the
                    // next call can skip bookmark resolution entirely.
                    if e.localPath != url.path,
                       let idx = entries.firstIndex(where: { $0.id == id }) {
                        entries[idx].localPath = url.path
                        persistState()
                    }
                    return url
                }
            } catch {
                print("[Yukimo.localURL] id=\(id) bookmark resolve threw: \(error)")
            }
        } else {
            print("[Yukimo.localURL] id=\(id) no bookmark")
        }
        if let path = e.localPath {
            let url = URL(fileURLWithPath: path)
            let exists = FileManager.default.fileExists(atPath: url.path)
            print("[Yukimo.localURL] id=\(id) localPath=\(path) exists=\(exists)")
            if exists { return url }
        } else {
            print("[Yukimo.localURL] id=\(id) no localPath")
        }
        return nil
    }

    func isFinished(releaseID: Int64, sourceID: Int64, position: Int) -> Bool {
        entry(releaseID: releaseID, sourceID: sourceID, position: position)?.status == .finished
    }

    func start(releaseID: Int64,
               sourceID: Int64,
               sourceName: String,
               typeID: Int64,
               typeName: String,
               position: Int,
               displayNumber: Int,
               releaseTitle: String,
               episodeName: String?,
               manifestURL: String,
               qualityLabel: String) {
        let id = Self.entryID(releaseID: releaseID, sourceID: sourceID, position: position)
        if let existing = entries.first(where: { $0.id == id }) {
            if existing.status == .finished { return }
            if existing.status == .downloading,
               let task = taskMap[id],
               task.state == .running { return }
        }
        guard let remoteURL = URL(string: manifestURL) else {
            persistFailed(id: id, reason: "Битый URL манифеста",
                          releaseID: releaseID, sourceID: sourceID, sourceName: sourceName,
                          typeID: typeID, typeName: typeName, position: position,
                          displayNumber: displayNumber, releaseTitle: releaseTitle,
                          episodeName: episodeName, manifestURL: manifestURL)
            return
        }
        let asset = AVURLAsset(url: remoteURL)
        let title = "\(releaseTitle) — Серия \(displayNumber)"
        guard let task = session.makeAssetDownloadTask(
            asset: asset,
            assetTitle: title,
            assetArtworkData: nil,
            options: nil) else {
            persistFailed(id: id, reason: "AVAssetDownloadTask не создался",
                          releaseID: releaseID, sourceID: sourceID, sourceName: sourceName,
                          typeID: typeID, typeName: typeName, position: position,
                          displayNumber: displayNumber, releaseTitle: releaseTitle,
                          episodeName: episodeName, manifestURL: manifestURL)
            return
        }
        task.taskDescription = id
        taskMap[id] = task
        upsert(Entry(
            id: id,
            releaseID: releaseID,
            sourceID: sourceID,
            sourceName: sourceName,
            typeID: typeID,
            typeName: typeName,
            position: position,
            displayNumber: displayNumber,
            releaseTitle: releaseTitle,
            episodeName: episodeName,
            manifestRemoteURL: manifestURL,
            qualityLabel: qualityLabel,
            status: .downloading,
            progress: 0,
            localBookmark: nil,
            localPath: nil,
            failureReason: nil,
            createdAt: Date()))
        task.resume()
    }

    /// All finished downloads belonging to the same anime — used to
    /// populate the episodes sheet when the player is opened in offline
    /// mode so the user sees siblings, not an empty list.
    func finishedEntries(forReleaseID releaseID: Int64) -> [Entry] {
        entries
            .filter { $0.releaseID == releaseID && $0.status == .finished }
            .sorted { $0.displayNumber < $1.displayNumber }
    }

    // MARK: MP4 export

    enum ExportError: Error { case missingFile, exportFailed(String) }
    enum PhotosError: Error, LocalizedError {
        case denied
        case saveFailed(String)
        var errorDescription: String? {
            switch self {
            case .denied: return "Нет доступа к Фото. Откройте Настройки iOS → Yukimo → Фото."
            case .saveFailed(let msg): return msg
            }
        }
    }

    /// Saves an exported `.mp4`/`.mov` to the user's Photos library.
    /// Requests the add-only permission first. Even with our best-effort
    /// concatenated CMAF files, Photos will refuse anything it can't
    /// decode as video — that's expected, and the error message says so.
    func saveToPhotos(_ fileURL: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotosError.denied
        }
        print("[Yukimo.photos] saving \(fileURL.path)")
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            }
            print("[Yukimo.photos] saved OK")
        } catch let ns as NSError {
            print("[Yukimo.photos] FAILED domain=\(ns.domain) code=\(ns.code) info=\(ns.userInfo)")
            // PHPhotosErrorDomain code 3302 = "invalid resource" — Photos
            // validated the file and decided it's not a decodable video.
            // Our concatenated CMAF blob won't pass that check.
            let friendly: String
            if ns.domain.contains("PHPhotos") && ns.code == 3302 {
                friendly = "Photos отказался принять файл — он сейчас невалидный MP4. " +
                          "iOS не позволяет вытащить корректный init-сегмент из скачанного HLS (.movpkg). " +
                          "Чтобы получить настоящий MP4, нужно перекачать видео напрямую (не через AVAssetDownloadTask)."
            } else {
                friendly = ns.localizedDescription
            }
            throw PhotosError.saveFailed(friendly)
        }
    }

    /// Converts the downloaded .movpkg into a flat .mp4 in the caches
    /// directory and returns its URL. Subsequent calls reuse the cached
    /// file. iOS auto-clears caches under pressure.
    /// Exports a downloaded `.movpkg` to a flat container playable by
    /// most apps (Telegram, Photos, AirDrop, QuickTime). Tries `.mp4`
    /// first; if iOS reports the source HLS asset isn't `.mp4`-compatible
    /// (common for AVAssetDownloadTask output), falls through to `.mov`
    /// and `.m4v` which accept HLS sources directly. Returns the URL of
    /// whichever extension succeeded.
    func exportMP4(forEntry id: String) async throws -> URL {
        print("[Yukimo.export] start id=\(id)")
        guard let assetURL = localPlaybackURL(forEntry: id) else {
            print("[Yukimo.export] ABORT — localPlaybackURL is nil")
            throw ExportError.missingFile
        }
        print("[Yukimo.export] assetURL=\(assetURL.path)")
        let asset = AVURLAsset(url: assetURL)
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]

        // Stale-cache eviction. Previous concat attempts may have produced
        // a same-named file that *passes* size check but is in fact a
        // broken CMAF blob that Photos / Telegram reject. Wipe before we
        // start so every export attempt runs the full pipeline.
        for ext in ["mp4", "mov", "m4v", "frag", "ts"] {
            let u = cachesURL.appendingPathComponent("yukimo-\(id).\(ext)")
            if FileManager.default.fileExists(atPath: u.path) {
                try? FileManager.default.removeItem(at: u)
                print("[Yukimo.export] evicted stale cache \(u.lastPathComponent)")
            }
        }

        struct Attempt {
            let preset: String
            let fileType: AVFileType
            let ext: String
        }
        let attempts: [Attempt] = [
            // Best-of-both — H.264 in mp4 if iOS will allow it.
            Attempt(preset: AVAssetExportPresetHighestQuality, fileType: .mp4, ext: "mp4"),
            Attempt(preset: AVAssetExportPresetPassthrough,    fileType: .mp4, ext: "mp4"),
            // .mov accepts HLS sources reliably; same H.264 tracks
            // underneath, just a QuickTime container with .mov extension.
            Attempt(preset: AVAssetExportPresetHighestQuality, fileType: .mov, ext: "mov"),
            Attempt(preset: AVAssetExportPresetPassthrough,    fileType: .mov, ext: "mov"),
            // .m4v is Apple's mp4 flavour — sometimes the only one HLS
            // accepts. Plays everywhere mp4 plays.
            Attempt(preset: AVAssetExportPresetHighestQuality, fileType: .m4v, ext: "m4v"),
            // Last-ditch transcodes.
            Attempt(preset: AVAssetExportPresetMediumQuality,  fileType: .mp4, ext: "mp4"),
            Attempt(preset: AVAssetExportPresetMediumQuality,  fileType: .mov, ext: "mov"),
        ]

        var lastErr: String?
        for a in attempts {
            let outURL = cachesURL.appendingPathComponent("yukimo-\(id).\(a.ext)")
            // Skip cached if a *real* (≥1 KB) file already exists for this
            // (id, ext) combo from an earlier successful attempt.
            if FileManager.default.fileExists(atPath: outURL.path) {
                let size = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
                if size > 1024 {
                    print("[Yukimo.export] reuse cached \(outURL.path) size=\(size)")
                    return outURL
                }
                try? FileManager.default.removeItem(at: outURL)
            }
            let compatible = await AVAssetExportSession.compatibility(
                ofExportPreset: a.preset, with: asset, outputFileType: a.fileType)
            print("[Yukimo.export] preset=\(a.preset) ext=\(a.ext) compatible=\(compatible)")
            guard compatible else { continue }
            guard let export = AVAssetExportSession(asset: asset, presetName: a.preset) else {
                print("[Yukimo.export] session init failed for \(a.preset)/\(a.ext)")
                continue
            }
            export.outputURL = outURL
            export.outputFileType = a.fileType
            await export.export()
            print("[Yukimo.export] preset=\(a.preset) ext=\(a.ext) status=\(export.status.rawValue) err=\(export.error?.localizedDescription ?? "nil")")
            if export.status == .completed {
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
                print("[Yukimo.export] DONE \(outURL.path) size=\(outSize)")
                return outURL
            }
            lastErr = export.error?.localizedDescription
                ?? "Экспорт \(a.preset)/\(a.ext) завершился со статусом \(export.status.rawValue)"
            try? FileManager.default.removeItem(at: outURL)
        }
        print("[Yukimo.export] direct attempts exhausted, trying composition fallback")

        // Composition fallback. Wrapping the asset's tracks in an
        // AVMutableComposition often makes iOS forget it came from HLS
        // and lets the export session accept it.
        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)
        let composition = AVMutableComposition()
        for track in tracks {
            // `mediaType` is a sync property on AVAssetTrack in iOS 17+,
            // not a load()-able async one.
            let mediaType = track.mediaType
            guard mediaType == .video || mediaType == .audio else { continue }
            guard let compTrack = composition.addMutableTrack(
                withMediaType: mediaType,
                preferredTrackID: kCMPersistentTrackID_Invalid) else { continue }
            do {
                try compTrack.insertTimeRange(
                    CMTimeRange(start: CMTime.zero, duration: duration),
                    of: track, at: CMTime.zero)
            } catch {
                print("[Yukimo.export] composition insert failed for \(mediaType.rawValue): \(error)")
            }
        }
        print("[Yukimo.export] composition tracks=\(composition.tracks.count) duration=\(CMTimeGetSeconds(duration))")

        let compositionAttempts: [Attempt] = composition.tracks.isEmpty ? [] : [
            Attempt(preset: AVAssetExportPresetHighestQuality, fileType: .mp4, ext: "mp4"),
            Attempt(preset: AVAssetExportPresetPassthrough,    fileType: .mp4, ext: "mp4"),
            Attempt(preset: AVAssetExportPresetHighestQuality, fileType: .mov, ext: "mov"),
            Attempt(preset: AVAssetExportPresetPassthrough,    fileType: .mov, ext: "mov"),
        ]
        for a in compositionAttempts {
            let outURL = cachesURL.appendingPathComponent("yukimo-\(id).\(a.ext)")
            try? FileManager.default.removeItem(at: outURL)
            let compatible = await AVAssetExportSession.compatibility(
                ofExportPreset: a.preset, with: composition, outputFileType: a.fileType)
            print("[Yukimo.export] composition preset=\(a.preset) ext=\(a.ext) compatible=\(compatible)")
            guard compatible else { continue }
            guard let export = AVAssetExportSession(asset: composition, presetName: a.preset) else { continue }
            export.outputURL = outURL
            export.outputFileType = a.fileType
            await export.export()
            print("[Yukimo.export] composition preset=\(a.preset) ext=\(a.ext) status=\(export.status.rawValue) err=\(export.error?.localizedDescription ?? "nil")")
            if export.status == .completed {
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
                print("[Yukimo.export] DONE via composition \(outURL.path) size=\(outSize)")
                return outURL
            }
            lastErr = export.error?.localizedDescription
                ?? "Composition экспорт \(a.preset)/\(a.ext) → \(export.status.rawValue)"
            try? FileManager.default.removeItem(at: outURL)
        }

        print("[Yukimo.export] direct + composition exhausted. Walking .movpkg structure.")

        // Last-ditch: walk the .movpkg as a directory and try to find
        // playable fragments. Apple's downloaded HLS bundle keeps its
        // segments as files inside the package — typically `.frag`
        // (fragmented MP4) or `.ts` (transport stream). If we can locate
        // them, concatenating in declared order makes a passable single
        // file for sharing in most apps.
        let mediaExts: Set<String> = ["frag", "ts", "m4s", "mp4", "m4v"]
        var allFiles: [(URL, Int64)] = []
        var fragments: [(URL, Int64)] = []
        if let enumerator = FileManager.default.enumerator(
            at: assetURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]) {
            while let item = enumerator.nextObject() as? URL {
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir { continue }
                let size = Int64((try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                allFiles.append((item, size))
                if mediaExts.contains(item.pathExtension.lowercased()) {
                    fragments.append((item, size))
                }
            }
        }
        let total = allFiles.reduce(into: 0) { $0 += $1.1 }
        let nonMedia = allFiles.filter { !mediaExts.contains($0.0.pathExtension.lowercased()) }
        print("[Yukimo.export] movpkg: \(allFiles.count) files total, \(fragments.count) media fragments, \(total) bytes")
        print("[Yukimo.export] non-media files (\(nonMedia.count)):")
        for (url, size) in nonMedia.sorted(by: { $0.0.path < $1.0.path }) {
            let rel = url.path.replacingOccurrences(of: assetURL.path, with: "movpkg:")
            print("[Yukimo.export]   \(size) bytes \(rel)")
        }

        // Internal-manifest fallback. The .movpkg ships a variant `.m3u8`
        // (e.g. `0-0-XXXXX/0-XXXXX-0.m3u8`) that points at the .frag
        // fragments via relative paths. Pointing AVURLAsset at this
        // manifest sometimes makes AVAssetExportSession treat it as a
        // regular local HLS, not the sealed `.movpkg` bundle.
        let manifestCandidates = allFiles
            .filter { $0.0.pathExtension.lowercased() == "m3u8" }
            .sorted { $0.1 > $1.1 }   // largest first — usually the variant playlist
        for (manifestURL, manifestSize) in manifestCandidates {
            print("[Yukimo.export] trying internal manifest \(manifestURL.lastPathComponent) (\(manifestSize) bytes)")
            let manifestAsset = AVURLAsset(url: manifestURL)
            let manifestAttempts: [(String, AVFileType, String)] = [
                (AVAssetExportPresetHighestQuality, .mp4, "mp4"),
                (AVAssetExportPresetPassthrough,    .mp4, "mp4"),
                (AVAssetExportPresetHighestQuality, .mov, "mov"),
                (AVAssetExportPresetPassthrough,    .mov, "mov"),
            ]
            for (preset, fileType, ext) in manifestAttempts {
                let outURL = cachesURL.appendingPathComponent("yukimo-\(id).\(ext)")
                let compat = await AVAssetExportSession.compatibility(
                    ofExportPreset: preset, with: manifestAsset, outputFileType: fileType)
                print("[Yukimo.export] manifest preset=\(preset) ext=\(ext) compatible=\(compat)")
                guard compat else { continue }
                try? FileManager.default.removeItem(at: outURL)
                guard let export = AVAssetExportSession(asset: manifestAsset, presetName: preset) else { continue }
                export.outputURL = outURL
                export.outputFileType = fileType
                await export.export()
                print("[Yukimo.export] manifest preset=\(preset) ext=\(ext) status=\(export.status.rawValue) err=\(export.error?.localizedDescription ?? "nil")")
                if export.status == .completed {
                    let outSize = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
                    print("[Yukimo.export] DONE via internal manifest \(outURL.path) size=\(outSize)")
                    return outURL
                }
                try? FileManager.default.removeItem(at: outURL)
            }
        }

        // Concat is the last resort — it usually produces a file Telegram
        // and other recipients reject because Apple's CMAF segments
        // depend on init data baked into the proprietary playback path.
        // We still try; if it works, great. If not, the user gets a
        // clear error message below.
        if !fragments.isEmpty {
            // Numerical sort — fragment file names use `(NNN)_(0)_(…).frag`
            // where NNN is a 1-based sequence number. Plain lex sort puts
            // `(12)` before `(6)`, so we have to extract and compare ints.
            func sequence(_ url: URL) -> Int {
                let name = url.lastPathComponent
                guard let openIdx = name.firstIndex(of: "("),
                      let closeIdx = name.firstIndex(of: ")"),
                      openIdx < closeIdx else { return Int.max }
                let inner = name[name.index(after: openIdx)..<closeIdx]
                return Int(inner) ?? Int.max
            }
            let sorted = fragments.sorted {
                let a = sequence($0.0), b = sequence($1.0)
                if a != b { return a < b }
                return $0.0.lastPathComponent < $1.0.lastPathComponent
            }
            // Heuristics for init segment: the smallest plain-MP4 file
            // inside the bundle. CMAF init segments are usually ~5–30 KB,
            // contain `ftyp`+`moov` and have an `.mp4` extension or no
            // numeric sequence prefix.
            let initCandidate = nonMedia
                .filter { ["mp4", "m4s", "init"].contains($0.0.pathExtension.lowercased()) || $0.0.lastPathComponent.lowercased().contains("init") }
                .min(by: { $0.1 < $1.1 })
                ?? allFiles
                    .filter { sequence($0.0) == Int.max && $0.0.pathExtension.lowercased() != "plist" && $0.0.pathExtension.lowercased() != "xml" && $0.0.pathExtension.lowercased() != "key" }
                    .min(by: { $0.1 < $1.1 })

            // Output extension: if the source was .frag (Apple CMAF),
            // call it .mp4 — a concatenated init + moof/mdat boxes IS
            // a valid fragmented MP4. AVPlayer & VLC accept it.
            let firstExt = sorted.first?.0.pathExtension.lowercased() ?? "ts"
            let outExt = (firstExt == "frag" || firstExt == "m4s") ? "mp4" : firstExt
            let outURL = cachesURL.appendingPathComponent("yukimo-\(id).\(outExt)")
            try? FileManager.default.removeItem(at: outURL)
            FileManager.default.createFile(atPath: outURL.path, contents: nil)
            if let handle = try? FileHandle(forWritingTo: outURL) {
                defer { try? handle.close() }
                if let (initURL, initSize) = initCandidate,
                   let data = try? Data(contentsOf: initURL) {
                    try? handle.write(contentsOf: data)
                    print("[Yukimo.export] prepended init segment \(initURL.lastPathComponent) (\(initSize) bytes)")
                } else {
                    print("[Yukimo.export] no init segment candidate — concat may not play")
                }
                for (url, _) in sorted {
                    if let data = try? Data(contentsOf: url) {
                        try? handle.write(contentsOf: data)
                    }
                }
                let outSize = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
                if outSize > 1024 * 50 {
                    print("[Yukimo.export] CONCAT DONE \(outURL.path) size=\(outSize) ext=\(outExt) fragments=\(sorted.count)")
                    return outURL
                }
                print("[Yukimo.export] CONCAT too small (\(outSize)) — discarding")
                try? FileManager.default.removeItem(at: outURL)
            }
        }

        // Stale concat from a previous attempt — don't hand that back.
        let concatOldURLs = [
            cachesURL.appendingPathComponent("yukimo-\(id).mp4"),
            cachesURL.appendingPathComponent("yukimo-\(id).mov"),
            cachesURL.appendingPathComponent("yukimo-\(id).frag"),
            cachesURL.appendingPathComponent("yukimo-\(id).ts"),
        ]
        for u in concatOldURLs {
            if FileManager.default.fileExists(atPath: u.path) {
                try? FileManager.default.removeItem(at: u)
            }
        }
        print("[Yukimo.export] ALL ATTEMPTS FAILED lastErr=\(lastErr ?? "nil")")
        throw ExportError.exportFailed(
            "iOS не позволяет вытащить это видео в MP4. " +
            "Apple намеренно блокирует экспорт скачанного HLS (.movpkg) — " +
            "видео можно проигрывать только внутри Yukimo. " +
            "Подробности в логах: ни один пресет AVAssetExportSession не " +
            "оказался совместим с .movpkg, композиция треков пустая, " +
            "склейка CMAF-фрагментов не даёт валидный MP4 без правильного " +
            "init-сегмента.")
    }

    func cancel(id: String) {
        taskMap[id]?.cancel()
        taskMap.removeValue(forKey: id)
        if let idx = entries.firstIndex(where: { $0.id == id }),
           entries[idx].status != .finished {
            entries[idx].status = .cancelled
            persistState()
        }
    }

    func delete(id: String) {
        cancel(id: id)
        if let url = localPlaybackURL(forEntry: id) {
            try? FileManager.default.removeItem(at: url)
        }
        entries.removeAll { $0.id == id }
        persistState()
    }

    // MARK: Delegate callbacks (called from DelegateProxy via Task)

    fileprivate func ingestProgress(taskID: String, progress: Double) {
        guard let idx = entries.firstIndex(where: { $0.id == taskID }) else { return }
        entries[idx].progress = min(1.0, max(0.0, progress))
        persistState()
    }

    fileprivate func ingestFinished(taskID: String, location: URL) {
        guard let idx = entries.firstIndex(where: { $0.id == taskID }) else { return }
        let bookmark: Data?
        do {
            bookmark = try location.bookmarkData(
                options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            print("[Yukimo.download] ingestFinished taskID=\(taskID) bookmark=\(bookmark?.count ?? -1) bytes path=\(location.path)")
        } catch {
            bookmark = nil
            print("[Yukimo.download] ingestFinished bookmark threw: \(error). Will rely on path. path=\(location.path)")
        }
        entries[idx].status = .finished
        entries[idx].progress = 1.0
        entries[idx].localBookmark = bookmark
        entries[idx].localPath = location.path
        taskMap.removeValue(forKey: taskID)
        persistState()
    }

    fileprivate func ingestError(taskID: String, error: Error?) {
        guard let idx = entries.firstIndex(where: { $0.id == taskID }) else { return }
        taskMap.removeValue(forKey: taskID)
        guard entries[idx].status != .finished else { return }
        if let error = error as NSError? {
            if error.code == NSURLErrorCancelled {
                entries[idx].status = .cancelled
            } else {
                entries[idx].status = .failed
                entries[idx].failureReason = error.localizedDescription
            }
            persistState()
        }
    }

    // MARK: Helpers

    private func persistFailed(id: String, reason: String,
                               releaseID: Int64, sourceID: Int64, sourceName: String,
                               typeID: Int64, typeName: String, position: Int,
                               displayNumber: Int, releaseTitle: String,
                               episodeName: String?, manifestURL: String) {
        upsert(Entry(
            id: id, releaseID: releaseID, sourceID: sourceID, sourceName: sourceName,
            typeID: typeID, typeName: typeName, position: position,
            displayNumber: displayNumber, releaseTitle: releaseTitle,
            episodeName: episodeName, manifestRemoteURL: manifestURL,
            qualityLabel: "", status: .failed, progress: 0,
            localBookmark: nil, localPath: nil,
            failureReason: reason, createdAt: Date()))
    }

    private func upsert(_ entry: Entry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        } else {
            entries.insert(entry, at: 0)
        }
        persistState()
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: stateKey) else { return }
        guard var saved = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        // Migration: entries downloaded under earlier builds may have only
        // a `localBookmark` (which was failing to resolve on the system-
        // managed UserManagedAssets paths). If we can resolve it now,
        // snapshot the absolute path so the export path stops returning
        // `.missingFile`.
        var migrated = 0
        for i in saved.indices {
            guard saved[i].status == .finished,
                  saved[i].localPath == nil,
                  let bookmark = saved[i].localBookmark else { continue }
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &stale),
               FileManager.default.fileExists(atPath: url.path) {
                saved[i].localPath = url.path
                migrated += 1
            }
        }
        if migrated > 0 {
            print("[Yukimo.download] migrated \(migrated) entries to localPath")
        }
        self.entries = saved
        if migrated > 0 { persistState() }
    }

    private func persistState() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: stateKey)
    }
}

// MARK: - AVAssetDownloadDelegate proxy
//
// Kept as a fileprivate NSObject so the manager itself doesn't get
// auto-exposed in `AniAnglia-Swift.h` (which would force every Obj-C
// translation unit that imports the bridging header to also see
// `AVAssetDownloadDelegate` — and most don't import AVFoundation).

private final class DelegateProxy: NSObject, AVAssetDownloadDelegate {
    weak var owner: YukimoDownloadsManager?

    func urlSession(_ session: URLSession,
                    assetDownloadTask: AVAssetDownloadTask,
                    didLoad timeRange: CMTimeRange,
                    totalTimeRangesLoaded loadedTimeRanges: [NSValue],
                    timeRangeExpectedToLoad: CMTimeRange) {
        let id = assetDownloadTask.taskDescription ?? ""
        var loaded: Double = 0
        for v in loadedTimeRanges {
            loaded += CMTimeGetSeconds(v.timeRangeValue.duration)
        }
        let expected = CMTimeGetSeconds(timeRangeExpectedToLoad.duration)
        let progress = expected > 0 ? loaded / expected : 0
        Task { @MainActor [weak self] in
            self?.owner?.ingestProgress(taskID: id, progress: progress)
        }
    }

    func urlSession(_ session: URLSession,
                    assetDownloadTask: AVAssetDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let id = assetDownloadTask.taskDescription ?? ""
        Task { @MainActor [weak self] in
            self?.owner?.ingestFinished(taskID: id, location: location)
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let id = task.taskDescription else { return }
        Task { @MainActor [weak self] in
            self?.owner?.ingestError(taskID: id, error: error)
        }
    }
}
