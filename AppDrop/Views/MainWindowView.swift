import SwiftData
import SwiftUI
import SharedKit
import UniformTypeIdentifiers

enum SidebarItem: String, CaseIterable, Identifiable {
    case wishlist
    case todayDrops
    case historicalLows
    case settings

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .wishlist: return "sidebar.wishlist"
        case .todayDrops: return "sidebar.todayDrops"
        case .historicalLows: return "sidebar.historicalLows"
        case .settings: return "sidebar.settings"
        }
    }

    var systemImage: String {
        switch self {
        case .wishlist: return "heart"
        case .todayDrops: return "arrow.down.right.circle"
        case .historicalLows: return "chart.line.downtrend.xyaxis"
        case .settings: return "gearshape"
        }
    }
}

enum SortMode: String, CaseIterable, Identifiable {
    case name
    case lastChecked
    case discount

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .name: return "sort.name"
        case .lastChecked: return "sort.lastChecked"
        case .discount: return "sort.discount"
        }
    }
}

enum LayoutMode: String, CaseIterable {
    case grid
    case list
}

struct MainWindowView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.modelContext) private var modelContext

    @State private var selection: SidebarItem = .wishlist
    @State private var searchText = ""
    @State private var regionFilter = ""
    @State private var sortMode: SortMode = .name
    @State private var layoutMode: LayoutMode = .grid
    @State private var showingAddSheet = false
    @State private var showingImporter = false
    @State private var exportDocument: WishdropDocument?
    @State private var showingExporter = false
    @State private var alertMessage: String?
    @State private var importInProgress = false
    @State private var isSelectMode = false
    @State private var selectedAppIDs: Set<UUID> = []
    @State private var confirmingBatchDelete = false
    @State private var deletingSingleApp: TrackedApp? = nil
    @State private var confirmingSingleDelete = false

    @Query(sort: [SortDescriptor(\TrackedApp.createdAt)])
    private var trackedApps: [TrackedApp]

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SidebarItem.allCases) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.systemImage)
                            .frame(width: 18, alignment: .center)
                        Text(AppStrings.string(item.titleKey))
                    }
                    .tag(item)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            NavigationStack {
                content
                    .navigationDestination(for: UUID.self) { appID in
                        if let app = trackedApps.first(where: { $0.id == appID }) {
                            AppDetailView(app: app)
                        } else {
                            EmptyView()
                        }
                    }
            }
        }
        .toolbar { toolbarContent }
        .searchable(text: $searchText, placement: .toolbar, prompt: Text(AppStrings.string("toolbar.search")))
        .sheet(isPresented: $showingAddSheet) {
            AddAppView()
        }
        .sheet(item: $environment.pendingImportSummary) { summary in
            ImportSummaryView(summary: summary) {
                environment.pendingImportSummary = nil
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.wishdrop]
        ) { result in
            handleImportResult(result)
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .wishdrop,
            defaultFilename: AppStrings.string("export.fileName")
        ) { result in
            if case .failure(let error) = result {
                alertMessage = AppStrings.format("export.errorFormat", error.localizedDescription)
            }
        }
        .alert(
            "AppDrop",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button(AppStrings.string("common.ok")) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .overlay(alignment: .bottom) {
            if importInProgress {
                Text(AppStrings.string("import.inProgress"))
                    .padding(8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 12)
            }
        }
        .confirmationDialog(
            AppStrings.string("batchDelete.confirmTitle"),
            isPresented: $confirmingBatchDelete,
            titleVisibility: .visible
        ) {
            Button(
                AppStrings.format("batchDelete.confirmAction", selectedAppIDs.count),
                role: .destructive
            ) {
                deleteSelectedApps()
            }
            Button(AppStrings.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(AppStrings.format("batchDelete.confirmMessage", selectedAppIDs.count))
        }
        .confirmationDialog(
            AppStrings.string("detail.deleteConfirmTitle"),
            isPresented: $confirmingSingleDelete,
            titleVisibility: .visible
        ) {
            Button(AppStrings.string("detail.delete"), role: .destructive) {
                if let deletingSingleApp {
                    deleteApp(deletingSingleApp.id)
                }
            }
            Button(AppStrings.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(AppStrings.string("detail.deleteConfirmMessage"))
        }
        .onChange(of: selection) { _, _ in
            isSelectMode = false
            selectedAppIDs.removeAll()
        }
    }

    @ViewBuilder
    private var content: some View {
        if selection == .settings {
            SettingsView()
        } else if filteredApps.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                if isSelectMode {
                    selectionBanner
                }
                switch layoutMode {
                case .grid:
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                            ForEach(filteredApps) { app in
                                if isSelectMode {
                                    Button {
                                        toggleSelection(app.id)
                                    } label: {
                                        TrackedAppCardView(
                                            app: app,
                                            isSelectMode: true,
                                            isSelected: selectedAppIDs.contains(app.id)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    NavigationLink(value: app.id) {
                                        TrackedAppCardView(app: app)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        appContextMenu(for: app)
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                case .list:
                    List {
                        ForEach(filteredApps) { app in
                            if isSelectMode {
                                Button {
                                    toggleSelection(app.id)
                                } label: {
                                    TrackedAppRowView(
                                        app: app,
                                        isSelectMode: true,
                                        isSelected: selectedAppIDs.contains(app.id)
                                    )
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink(value: app.id) {
                                    TrackedAppRowView(app: app)
                                }
                                .contextMenu {
                                    appContextMenu(for: app)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 38))
                .foregroundStyle(.tertiary)
            Text(AppStrings.string(emptyTitleKey))
                .font(.title3)
            Text(AppStrings.string(emptyMessageKey))
                .foregroundStyle(.secondary)
            if selection == .wishlist {
                Button(AppStrings.string("toolbar.add")) {
                    showingAddSheet = true
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(AppStrings.string(selection.titleKey))
    }

    private var emptyStateIcon: String {
        switch selection {
        case .wishlist: return "heart"
        case .todayDrops: return "arrow.down.right.circle"
        case .historicalLows: return "chart.line.downtrend.xyaxis"
        case .settings: return "gearshape"
        }
    }

    private var emptyTitleKey: String {
        switch selection {
        case .wishlist: return "empty.wishlist.title"
        case .todayDrops: return "empty.todayDrops.title"
        case .historicalLows: return "empty.lows.title"
        case .settings: return "settings.title"
        }
    }

    private var emptyMessageKey: String {
        switch selection {
        case .wishlist: return "empty.wishlist.message"
        case .todayDrops: return "empty.todayDrops.message"
        case .historicalLows: return "empty.lows.message"
        case .settings: return "settings.defaultRegionCaption"
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            if selection != .settings && !filteredApps.isEmpty {
                Button {
                    isSelectMode.toggle()
                    if !isSelectMode {
                        selectedAppIDs.removeAll()
                    }
                } label: {
                    Label(
                        isSelectMode ? AppStrings.string("common.done") : AppStrings.string("toolbar.select"),
                        systemImage: isSelectMode ? "checkmark" : "checklist"
                    )
                }
            }
            Button {
                showingAddSheet = true
            } label: {
                Label(AppStrings.string("toolbar.add"), systemImage: "plus")
            }
            Button {
                showingImporter = true
            } label: {
                Label(AppStrings.string("toolbar.import"), systemImage: "square.and.arrow.down")
            }
            Button {
                exportWishlist()
            } label: {
                Label(AppStrings.string("toolbar.export"), systemImage: "square.and.arrow.up")
            }
            Button {
                Task { await environment.refreshAll() }
            } label: {
                Label(AppStrings.string("toolbar.refresh"), systemImage: "arrow.clockwise")
            }
            .disabled(environment.refresh?.isRefreshing == true)
            if environment.refresh?.isRefreshing == true {
                ProgressView().controlSize(.small)
            }
        }
        ToolbarItemGroup {
            Picker(AppStrings.string("toolbar.sort"), selection: $sortMode) {
                ForEach(SortMode.allCases) { mode in
                    Text(AppStrings.string(mode.titleKey)).tag(mode)
                }
            }
            .pickerStyle(.menu)
            Picker(AppStrings.string("toolbar.region"), selection: $regionFilter) {
                Text(AppStrings.string("filter.allRegions")).tag("")
                ForEach(SharedConstants.supportedCountryCodes, id: \.self) { code in
                    Text(AppStrings.regionLabel(code)).tag(code)
                }
            }
            .pickerStyle(.menu)
            Picker(AppStrings.string("toolbar.layout"), selection: $layoutMode) {
                Image(systemName: "square.grid.2x2").tag(LayoutMode.grid)
                Image(systemName: "list.bullet").tag(LayoutMode.list)
            }
            .pickerStyle(.segmented)
            .frame(width: 82)
        }
    }

    private var filteredApps: [TrackedApp] {
        var apps = trackedApps
        switch selection {
        case .todayDrops:
            apps = apps.filter { app in
                guard let lastDecrease = app.lastDecreaseAt else { return false }
                return Calendar.current.isDateInToday(lastDecrease)
            }
        case .historicalLows:
            apps = apps.filter(\.isAtHistoricalLow)
        case .wishlist, .settings:
            break
        }
        if !regionFilter.isEmpty {
            apps = apps.filter { $0.countryCode == regionFilter }
        }
        if !searchText.isEmpty {
            apps = apps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.trackId.contains(searchText)
                    || (StoreCountry.displayCode(for: $0.countryCode)).localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortMode {
        case .name:
            apps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .lastChecked:
            apps.sort { ($0.lastCheckedAt ?? .distantPast) > ($1.lastCheckedAt ?? .distantPast) }
        case .discount:
            apps.sort { $0.discountRate > $1.discountRate }
        }
        return apps
    }

    private func exportWishlist() {
        Task {
            switch await environment.exportWishdropData() {
            case .success(let data):
                exportDocument = WishdropDocument(data: data)
                showingExporter = true
            case .failure(let error):
                alertMessage = AppStrings.format("export.errorFormat", error.localizedDescription)
            }
        }
    }

    private func handleImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                importInProgress = true
                Task {
                    environment.pendingImportSummary = await environment.importWishdrop(data: data, fileName: url.lastPathComponent)
                    importInProgress = false
                }
            } catch {
                environment.pendingImportSummary = WishdropImportSummary(
                    fileName: url.lastPathComponent,
                    addedCount: 0,
                    existingCount: 0,
                    invalidCount: 0,
                    issues: [],
                    errorMessage: error.localizedDescription
                )
            }
        case .failure(let error):
            environment.pendingImportSummary = WishdropImportSummary(
                fileName: "",
                addedCount: 0,
                existingCount: 0,
                invalidCount: 0,
                issues: [],
                errorMessage: error.localizedDescription
            )
        }
    }

    private var selectionBanner: some View {
        HStack(spacing: 12) {
            Button {
                if selectedAppIDs.count == filteredApps.count {
                    selectedAppIDs.removeAll()
                } else {
                    selectedAppIDs = Set(filteredApps.map(\.id))
                }
            } label: {
                Label(
                    selectedAppIDs.count == filteredApps.count
                        ? AppStrings.string("toolbar.deselectAll")
                        : AppStrings.string("toolbar.selectAll"),
                    systemImage: selectedAppIDs.count == filteredApps.count ? "xmark.circle" : "checkmark.circle"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text(AppStrings.format("toolbar.selectedCount", selectedAppIDs.count))
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button(role: .destructive) {
                confirmingBatchDelete = true
            } label: {
                Label(AppStrings.string("toolbar.deleteSelected"), systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.small)
            .disabled(selectedAppIDs.isEmpty)

            Button(AppStrings.string("common.done")) {
                isSelectMode = false
                selectedAppIDs.removeAll()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
    }

    private func toggleSelection(_ id: UUID) {
        if selectedAppIDs.contains(id) {
            selectedAppIDs.remove(id)
        } else {
            selectedAppIDs.insert(id)
        }
    }

    @ViewBuilder
    private func appContextMenu(for app: TrackedApp) -> some View {
        if let urlString = app.appStoreURL ?? canonicalURLString(for: app),
           let url = URL(string: urlString) {
            Link(AppStrings.string("contextMenu.openInStore"), destination: url)
            Button(AppStrings.string("contextMenu.copyLink")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            }
        }
        Divider()
        Button(role: .destructive) {
            deletingSingleApp = app
            confirmingSingleDelete = true
        } label: {
            Label(AppStrings.string("contextMenu.delete"), systemImage: "trash")
        }
    }

    private func canonicalURLString(for app: TrackedApp) -> String? {
        "https://apps.apple.com/\(app.countryCode)/app/id\(app.trackId)"
    }

    private func deleteSelectedApps() {
        let toDelete = selectedAppIDs
        Task {
            if let error = await environment.delete(appIDs: toDelete) {
                alertMessage = error
            } else {
                selectedAppIDs.removeAll()
                isSelectMode = false
            }
        }
    }

    private func deleteApp(_ appID: UUID) {
        Task {
            if let error = await environment.delete(appID: appID) {
                alertMessage = error
            }
        }
    }
}

