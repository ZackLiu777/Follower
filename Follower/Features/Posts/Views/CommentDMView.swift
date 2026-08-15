//
//  CommentDMView.swift
//  Follower
//
//  Premium: 评论触发私信（Comment-to-DM）— 规则配置 + 手动触发 + 统计。
//  合规：官方 Comment Private Reply（manage_comments 权限），仅响应 24h 内互动评论。
//  全部 theme 化。
//

import SwiftUI

/// 评论→私信 管理页
struct CommentDMView: View {
    @Environment(\.theme) private var theme

    @State private var viewModel: CommentDMViewModel
    @State private var newKeyword = ""
    @State private var newTemplate = ""
    @State private var showSample = false

    init(apiClient: InstagramAPIClientProtocol,
         tokenProvider: TokenProviderProtocol,
         accountId: Int64?,
         mediaID: String) {
        _viewModel = State(initialValue: CommentDMViewModel(
            apiClient: apiClient, tokenProvider: tokenProvider,
            accountId: accountId, mediaID: mediaID))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if !viewModel.hasMedia {
                        ContentUnavailableView(
                            loc(L10n.Premium.commentDMNoMedia),
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text(loc(L10n.Premium.commentDMNoMediaDesc))
                        )
                        .padding(.top, 60)
                    } else {
                        infoCard
                    addRuleCard
                    rulesCard
                    actionCard
                        complianceCard
                    }
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(loc(L10n.Premium.commentDM))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 说明

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(theme.positiveGreen)
                Text(loc(L10n.Premium.commentDMInfoTitle))
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
            }
            Text(loc(L10n.Premium.commentDMInfoDesc))
                .font(.caption)
                .foregroundColor(theme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - 添加规则

    private var addRuleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loc(L10n.Premium.commentDMAddRule)).font(.headline)

            TextField(loc(L10n.Premium.commentDMKeywordPlaceholder), text: $newKeyword)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.characters)
                .padding(10)
                .background(theme.backgroundSecondary.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundColor(theme.textPrimary)

            TextField(loc(L10n.Premium.commentDMTemplatePlaceholder), text: $newTemplate, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(2...4)
                .padding(10)
                .background(theme.backgroundSecondary.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundColor(theme.textPrimary)

            HStack {
                Button {
                    showSample.toggle()
                } label: {
                    Text(loc(L10n.Premium.commentDMSample))
                        .font(.caption)
                        .foregroundColor(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showSample) {
                    sampleSheet
                }
                Spacer()
                Button {
                    viewModel.addRule(keyword: newKeyword, template: newTemplate)
                    newKeyword = ""; newTemplate = ""
                } label: {
                    Label(loc(L10n.Premium.commentDMAddButton), systemImage: "plus")
                        .font(.subheadline)
                        .foregroundColor(theme.accentPrimary)
                }
                .buttonStyle(.plain)
                .disabled(newKeyword.isEmpty || newTemplate.isEmpty)
            }
        }
        .padding()
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var sampleSheet: some View {
        VStack(spacing: 14) {
            Text(loc(L10n.Premium.commentDMSampleTitle)).font(.headline)
            Text("评论：PRICE")
                .font(.subheadline).foregroundColor(theme.textSecondary)
            Text("私信：Hi {username}！谢谢询问 🎉 价格在这里 👉 https://my.page/price")
                .font(.subheadline)
                .foregroundColor(theme.textPrimary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.backgroundSecondary.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(loc(L10n.Premium.commentDMSampleNote))
                .font(.caption2)
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(20)
        .presentationDetents([.height(260)])
    }

    // MARK: - 规则列表

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(loc(L10n.Premium.commentDMRules)).font(.headline)
            if viewModel.rules.isEmpty {
                Text(loc(L10n.Premium.commentDMNoRules))
                    .font(.caption)
                    .foregroundColor(theme.textTertiary)
            } else {
                ForEach(viewModel.rules) { rule in
                    HStack(spacing: 10) {
                        Button {
                            viewModel.toggleRule(rule)
                        } label: {
                            Image(systemName: rule.isEnabled ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(rule.isEnabled ? theme.positiveGreen : theme.textTertiary)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(rule.keyword)
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(theme.textPrimary)
                            Text(rule.messageTemplate)
                                .font(.caption2)
                                .foregroundColor(theme.textTertiary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            viewModel.removeRule(rule)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(theme.warningOrange)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 3)
                }
                Button {
                    viewModel.resetRepliedHistory()
                } label: {
                    Text(loc(L10n.Premium.commentDMResetHistory))
                        .font(.caption)
                        .foregroundColor(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - 执行

    private var actionCard: some View {
        VStack(spacing: 10) {
            Button {
                Task { await viewModel.run() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isRunning {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(viewModel.isRunning
                        ? loc(L10n.Premium.commentDMRunning)
                        : loc(L10n.Premium.commentDMRun))
                        .font(.subheadline).fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(theme.buttonPrimaryBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isRunning || viewModel.rules.isEmpty)
            .opacity(viewModel.rules.isEmpty ? 0.4 : 1)

            if let result = viewModel.lastResult {
                HStack(spacing: 6) {
                    Text(String(format: loc(L10n.Premium.commentDMResult),
                                result.sent, result.scanned))
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - 合规说明

    private var complianceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(loc(L10n.Premium.commentDMComplianceTitle)).font(.caption).fontWeight(.semibold)
            Text(loc(L10n.Premium.commentDMComplianceDesc))
                .font(.caption2)
                .foregroundColor(theme.textTertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
