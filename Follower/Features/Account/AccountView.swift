//
//  AccountView.swift
//  Follower
//
//  账号管理页面。Beta: 全部文案本地化。

import SwiftUI

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AccountViewModel

    var body: some View {
        NavigationStack {
            Form {
                if !viewModel.accounts.isEmpty {
                    Section {
                        ForEach(viewModel.accounts, id: \.id) { account in
                            accountRow(account)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                if let id = viewModel.accounts[index].id {
                                    Task { await viewModel.deleteAccount(id) }
                                }
                            }
                        }
                    } header: {
                        Text(loc(L10n.Account.connectedAccounts))
                    }
                }
                Section {
                    if viewModel.isAddingAccount { addAccountForm }
                    else {
                        Button { viewModel.isAddingAccount = true } label: {
                            Label(loc(L10n.Account.connectNew), systemImage: "plus.circle.fill")
                        }
                    }
                } header: {
                    Text(viewModel.isAddingAccount ? loc(L10n.Account.addAccount) : loc(L10n.Account.connectNew))
                } footer: {
                    Text(loc(L10n.Account.footerHint))
                }
            }
            .navigationTitle(loc(L10n.Account.title))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.isAddingAccount {
                        Button(loc(L10n.Account.cancel)) {
                            viewModel.isAddingAccount = false
                            viewModel.username = ""
                            viewModel.displayName = ""
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isAddingAccount {
                        Button {
                            Task { await viewModel.addAccount() }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text(loc(L10n.Account.connect)).fontWeight(.semibold)
                            }
                        }
                        .disabled(viewModel.username.isEmpty || viewModel.displayName.isEmpty || viewModel.isLoading)
                    } else {
                        Button(loc(L10n.Common.done)) { dismiss() }
                    }
                }
            }
        }
        .task { await viewModel.loadAccounts() }
        .onChange(of: viewModel.shouldDismiss) { _, dismiss in
            if dismiss { self.dismiss() }
        }
    }

    @ViewBuilder
    private func accountRow(_ account: Account) -> some View {
        HStack {
            Image(systemName: account.platform == .instagram ? "camera.fill" : "play.rectangle.fill")
                .font(.title3).foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName).font(.subheadline).fontWeight(.medium)
                Text("@\(account.username)").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text((account.platform == .instagram ? loc(L10n.Account.instagram) : loc(L10n.Account.tiktok))
                + " · " + authDisplayName(account.authState))
                .font(.caption2).padding(.horizontal, 8).padding(.vertical, 4)
                .background(account.authState == .authorized ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                .foregroundColor(account.authState == .authorized ? .green : .red)
                .clipShape(Capsule())
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                if let id = account.id { Task { await viewModel.revokeAccount(id) } }
            } label: { Label(loc(L10n.Account.revoke), systemImage: "xmark.shield") }
        }
    }

    private var addAccountForm: some View {
        Group {
            Picker(loc(L10n.Account.platform), selection: $viewModel.selectedPlatform) {
                Text(loc(L10n.Account.instagram)).tag(Platform.instagram)
                Text(loc(L10n.Account.tiktok)).tag(Platform.tiktok)
            }
            TextField(loc(L10n.Account.username), text: $viewModel.username)
                .textContentType(.username).autocapitalization(.none)
            TextField(loc(L10n.Account.displayName), text: $viewModel.displayName)
                .textContentType(.name)
        }
    }

    private func authDisplayName(_ state: AuthState) -> String {
        switch state {
        case .authorized: return loc(L10n.Account.authorized)
        case .expired: return loc(L10n.Account.expired)
        case .revoked: return loc(L10n.Account.revoked)
        }
    }
}

#Preview {
    AccountView(viewModel: AccountViewModel(
        accountRepo: PreviewMocks.accountRepo,
        syncEngine: PreviewMocks.syncEngine
    ))
}

#if DEBUG
private enum PreviewMocks {
    static let db = DatabaseManager.shared
    static let accountRepo = AccountRepository(db: db)
    static let eventRepo = EventRepository(db: db)
    static let snapshotRepo = SnapshotRepository(db: db)
    static let metricRepo = MetricRepository(db: db)
    static let aggregationService = AggregationService(eventRepo: eventRepo, snapshotRepo: snapshotRepo, metricRepo: metricRepo)
    static let ingestionService = IngestionService(eventRepo: eventRepo, aggregationService: aggregationService)
    static let syncEngine = SyncEngine(eventRepo: eventRepo, accountRepo: accountRepo, ingestionService: ingestionService)
}
#endif
