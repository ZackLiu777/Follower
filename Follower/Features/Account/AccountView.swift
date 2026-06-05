//
//  AccountView.swift
//  Follower
//
//  账号管理页面。Alpha 阶段使用模拟登录。

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
                        Text("Connected Accounts")
                    }
                }

                Section {
                    if viewModel.isAddingAccount {
                        addAccountForm
                    } else {
                        Button { viewModel.isAddingAccount = true } label: {
                            Label("Connect New Account", systemImage: "plus.circle.fill")
                        }
                    }
                } header: {
                    Text(viewModel.isAddingAccount ? "New Account" : "Add Account")
                } footer: {
                    Text("Alpha version uses simulated data. Enter any username to create a demo account.")
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.loadAccounts()
        }
    }

    @ViewBuilder
    private func accountRow(_ account: Account) -> some View {
        HStack {
            Image(systemName: account.platform == .instagram ? "camera.fill" : "play.rectangle.fill")
                .font(.title3)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName).font(.subheadline).fontWeight(.medium)
                Text("@\(account.username)").font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            Text(account.authState.rawValue.capitalized)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(account.authState == .authorized ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                .foregroundColor(account.authState == .authorized ? .green : .red)
                .clipShape(Capsule())
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                if let id = account.id {
                    Task { await viewModel.revokeAccount(id) }
                }
            } label: {
                Label("Revoke", systemImage: "xmark.shield")
            }
        }
    }

    private var addAccountForm: some View {
        Group {
            Picker("Platform", selection: $viewModel.selectedPlatform) {
                ForEach([Platform.instagram, Platform.tiktok], id: \.self) { platform in
                    Text(platform.rawValue.capitalized).tag(platform)
                }
            }

            TextField("Username", text: $viewModel.username)
                .textContentType(.username)
                .autocapitalization(.none)

            TextField("Display Name", text: $viewModel.displayName)
                .textContentType(.name)

            HStack {
                Button(role: .cancel) {
                    viewModel.isAddingAccount = false
                    viewModel.username = ""
                    viewModel.displayName = ""
                } label: { Text("Cancel") }

                Spacer()

                Button {
                    Task { await viewModel.addAccount() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Connect").fontWeight(.semibold)
                    }
                }
                .disabled(viewModel.username.isEmpty || viewModel.displayName.isEmpty || viewModel.isLoading)
            }
        }
    }
}

// MARK: - Preview

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
