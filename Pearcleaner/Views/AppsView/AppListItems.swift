//
//  AppListDetails.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/10/23.
//

import AlinFoundation
import AppKit
import CoreFoundation
import Foundation
import SwiftUI

struct AppListItems: View {
    @EnvironmentObject var appState: AppState
    @Binding var search: String
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.general.glass") private var glass: Bool = true
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.interface.minimalist") private var minimalEnabled: Bool = true
    @AppStorage("settings.interface.multiSelect") private var multiSelect: Bool = false
    @EnvironmentObject var locations: Locations
    let itemId = UUID()
    let appInfo: AppInfo
    var isSelected: Bool { appState.appInfo.path == appInfo.path }
    @State private var hoveredItemPath: URL? = nil
    @State private var resetCandidates: [URL] = []
    @State private var showResetConfirmation = false
    @State private var showResetResult = false
    @State private var resetResultMessage = ""
    @Namespace var appItemNamespace

    var body: some View {

        HStack {

            if multiSelect {
                Button {
                    let isChecked = self.appState.externalPaths.contains(self.appInfo.path)

                    if !isChecked {
                        if !self.appState.externalPaths.contains(self.appInfo.path) {
                            let wasEmpty = self.appState.externalPaths.isEmpty
                            self.appState.externalPaths.append(self.appInfo.path)

                            if wasEmpty && appState.currentView != .files {
                                appState.multiMode = true
                                showAppInFiles(
                                    appInfo: appInfo, appState: appState,
                                    locations: locations)
                            }
                        }
                    } else {
                        self.appState.externalPaths.removeAll { $0 == self.appInfo.path }

                        if self.appState.externalPaths.isEmpty {
                            appState.multiMode = false
                        }
                    }
                } label: {
                    EmptyView()
                }
                .buttonStyle(CircleCheckboxButtonStyle(isSelected: self.appState.externalPaths.contains(self.appInfo.path)))
                .padding(.leading)
            }

            Button(action: {
                if !isSelected {
                    showAppInFiles(appInfo: appInfo, appState: appState, locations: locations)
                } else {
                    // Closing the same item
                    updateOnMain {
                        appState.appInfo = .empty
                        appState.selectedItems = []
                        appState.currentView = .empty
                    }
                }

            }) {
                VStack {

                    HStack(alignment: .center) {

                        if let appIcon = appInfo.appIcon {
                            ZStack {
                                Image(nsImage: appIcon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .matchedGeometryEffect(
                                        id: "icon-\(appInfo.path.path)", in: appItemNamespace)
                            }

                        }

                        if minimalEnabled {
                            Text(verbatim: appInfo.appName)
                                .font(.system(size: (isSelected) ? 14 : 12))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            VStack(alignment: .center, spacing: 2) {
                                HStack {
                                    Text(verbatim: appInfo.appName)
                                        .font(.system(size: (isSelected) ? 14 : 12))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Spacer()
                                }

                                HStack(spacing: 5) {
                                    Text(verbatim: "v\(appInfo.appVersion)")
                                        .font(.footnote)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .opacity(0.5)
                                    Text(verbatim: "•").font(.footnote).opacity(0.5)

                                    Text(
                                        appInfo.bundleSize == 0
                                            ? String(localized: "calculating")
                                            : "\(formatByte(size: appInfo.bundleSize).human)"
                                    )
                                    .font(.footnote)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .opacity(0.5)
                                    .frame(minWidth: 60, alignment: .leading)
                                    Spacer()
                                }

                            }
                        }

                        if minimalEnabled {
                            Spacer()
                        }

                        if minimalEnabled && !isSelected {
                            Text(
                                appInfo.bundleSize == 0
                                    ? ""
                                    : formatByte(size: appInfo.bundleSize).human
                            )
                            .font(.system(size: 10))
                            .foregroundStyle(
                                ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5))
                            .frame(minWidth: 60, alignment: .trailing)
                        }
                    }

                }
                .frame(height: 35)
                .background(Color.white.opacity(0.000000001))
                .padding(.trailing)
                .padding(.vertical, 5)
            }
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
            .padding(.leading, multiSelect ? 0 : 10)
            .onHover { hovering in
                withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.20 : 0)) {
                    self.isHovered = hovering
                    self.hoveredItemPath = isHovered ? appInfo.path : nil
                }
            }

        }
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected && !glass ? ThemeColors.shared(for: colorScheme).secondaryBG : .clear
                )
        }
        .overlay {
            if isHovered || isSelected {
                HStack {
                    Spacer()
                    ZStack {
                        // Morphing shape that animates between rectangle and square
                        RoundedRectangle(cornerRadius: isSelected ? 6 : 50)
                            .fill(
                                isSelected
                                    ? ThemeColors.shared(for: colorScheme).accent
                                    : ThemeColors.shared(for: colorScheme).primaryText.opacity(0.5)
                            )
                            .frame(width: isSelected ? 20 : 2, height: isSelected ? 20 : 25)

                        if isSelected {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white)
                                .opacity(isSelected ? 1 : 0)
                        }
                    }
                    //                    .animation(animationEnabled ? .spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0) : .linear(duration: 0), value: isSelected)
                    .padding(.trailing, 7)
                }
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            if appInfo.bundleSize == 0 {
                appState.getBundleSize(for: appInfo) { size in
                    //                    printOS("Getting size for: \(appInfo.appName)")
                    //                    appInfo.bundleSize = size
                }
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                prepareAppStateReset()
            } label: {
                Label("Reset App State…", systemImage: "arrow.counterclockwise")
            }
            .disabled(appInfo.system)
        }
        .confirmationDialog(
            "Reset \(appInfo.appName) State?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move Data to Trash and Reset", role: .destructive) {
                performAppStateReset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(resetConfirmationMessage)
        }
        .alert("Reset App State", isPresented: $showResetResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetResultMessage)
        }

    }

    private var resetConfirmationMessage: String {
        let paths = resetCandidates.map { "• \($0.path)" }.joined(separator: "\n")
        let summary = paths.isEmpty
            ? "No matching files or folders were found."
            : "The following app-specific items will be moved to Trash:\n\n\(paths)"
        return "\(summary)\n\nThe preferences domain (\(appInfo.bundleIdentifier)) will also be cleared. Shared Group Containers, Keychain items, and cloud-synced data are left untouched."
    }

    private func prepareAppStateReset() {
        guard !appInfo.bundleIdentifier.isEmpty else {
            resetResultMessage = "The app does not expose a valid bundle identifier."
            showResetResult = true
            return
        }
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: appInfo.bundleIdentifier
        ).contains { !$0.isTerminated }
        guard !running else {
            resetResultMessage = "Quit \(appInfo.appName) completely, then choose Reset App State again."
            showResetResult = true
            return
        }

        resetCandidates = AppStateResetPlanner.targets(for: appInfo)
        let preferences = UserDefaults.standard.persistentDomain(forName: appInfo.bundleIdentifier)
        guard !resetCandidates.isEmpty || !(preferences?.isEmpty ?? true) else {
            resetResultMessage = "No matching app-specific state was found in your user Library."
            showResetResult = true
            return
        }
        showResetConfirmation = true
    }

    private func performAppStateReset() {
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: appInfo.bundleIdentifier
        ).contains { !$0.isTerminated }
        guard !running else {
            resetResultMessage = "The app started running again. Quit it completely and retry."
            showResetResult = true
            return
        }
        resetResultMessage = AppStateResetPlanner.reset(
            bundleIdentifier: appInfo.bundleIdentifier,
            targets: resetCandidates
        )
        showResetResult = true
    }
}

// MARK: - App State Reset

/// Identifies app-specific state in the current user's Library. Avoids shared containers,
/// Keychain items, system-wide Library locations, and cloud-synced data.
private enum AppStateResetPlanner {
    static func targets(for appInfo: AppInfo) -> [URL] {
        let bundleID = appInfo.bundleIdentifier
        guard !bundleID.isEmpty, !bundleID.contains("/") else { return [] }
        let fileManager = FileManager.default
        let library = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)

        var candidates: [URL] = [
            library.appendingPathComponent("Containers/\(bundleID)", isDirectory: true),
            library.appendingPathComponent("Application Scripts/\(bundleID)", isDirectory: true),
            library.appendingPathComponent("Application Support/\(bundleID)", isDirectory: true),
            library.appendingPathComponent("Caches/\(bundleID)", isDirectory: true),
            library.appendingPathComponent("HTTPStorages/\(bundleID)", isDirectory: true),
            library.appendingPathComponent("WebKit/\(bundleID)", isDirectory: true),
            library.appendingPathComponent("Preferences/\(bundleID).plist"),
            library.appendingPathComponent("Saved Application State/\(bundleID).savedState", isDirectory: true)
        ]

        let byHost = library.appendingPathComponent("Preferences/ByHost", isDirectory: true)
        if let items = try? fileManager.contentsOfDirectory(
            at: byHost, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) {
            candidates.append(contentsOf: items.filter {
                $0.lastPathComponent.hasPrefix("\(bundleID).") && $0.pathExtension == "plist"
            })
        }

        var seen = Set<String>()
        return candidates
            .filter { fileManager.fileExists(atPath: $0.path) }
            .map { $0.standardizedFileURL }
            .filter { seen.insert($0.path).inserted }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    static func reset(bundleIdentifier: String, targets: [URL]) -> String {
        let existing = targets.filter { FileManager.default.fileExists(atPath: $0.path) }
        let filesMoved = existing.isEmpty || FileManagerUndo.shared.deleteFiles(at: existing)
        UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        _ = CFPreferencesAppSynchronize(bundleIdentifier as CFString)

        if filesMoved {
            return "Reset attempt completed. \(existing.count) item(s) were sent to Trash and the preferences domain was cleared. Reopen the app to test its first-launch experience."
        }
        return "Preferences were cleared, but some files could not be moved to Trash. Check Pearcleaner's console and permissions."
    }
}
