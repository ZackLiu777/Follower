//
//  PostQueueView.swift
//  Follower
//
//  发布队列 — 草稿 / 排期中 / 已发布 / 已取消 分组列表。
//  到期草稿高亮「待发布」状态，可立即发布或标记完成。
//

import SwiftUI

// MARK: - PostQueueView

struct PostQueueView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: PostQueueViewModel
    /// 编辑草稿（sheet 装载进 Composer）
    @State private var editingDraft: DraftPost?
    /// 到期草稿立即发布：分享面板
    @State private var pendingPublishURL: URL?
    @State private var pendingPublishDraft: DraftPost?

    init(draftRepo: DraftPostRepositoryProtocol, assistant: PostAssistantService) {
        _viewModel = State(initialValue: PostQueueViewModel(draftRepo: draftRepo, assistant: assistant))
    }

    private var currentTheme: Theme { appState.currentTheme.theme }

    private var draftSection: [DraftPost] { viewModel.drafts.filter { $0.status == .draft } }
    private var scheduledSection: [DraftPost] { viewModel.drafts.filter { $0.status == .scheduled } }
    private var publishedSection: [DraftPost] { viewModel.drafts.filter { $0.status == .published } }
    private var failedSection: [DraftPost] { viewModel.drafts.filter { $0.status == .failed } }

    var body: some View {
        List {
            if viewModel.drafts.isEmpty {
                ContentUnavailableView(
                    "没有草稿",
                    systemImage: "square.and.pencil",
                    description: Text("在发布助手中新建内容后会显示在这里")
                )
            } else {
                if !scheduledSection.isEmpty {
                    Section("排期中") {
                        ForEach(scheduledSection) { draft in
                            queueRow(draft)
                        }
                    }
                }
                if !draftSection.isEmpty {
                    Section("草稿") {
                        ForEach(draftSection) { draft in
                            queueRow(draft)
                        }
                    }
                }
                if !publishedSection.isEmpty {
                    Section("已发布") {
                        ForEach(publishedSection) { draft in
                            queueRow(draft)
                        }
                    }
                }
                if !failedSection.isEmpty {
                    Section("已取消") {
                        ForEach(failedSection) { draft in
                            queueRow(draft)
                        }
                    }
                }
            }
        }
        .navigationTitle("发布队列")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .background(
            LinearGradient(
                colors: currentTheme.backgroundGradientColors,
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .scrollContentBackground(.hidden)
        // 编辑草稿：装载进 Composer
        .sheet(item: $editingDraft) { draft in
            PostComposerView(
                draftRepo: appState.container.draftPostRepository,
                assistant: appState.container.postAssistantService,
                editingDraft: draft
            )
        }
        // 到期草稿立即发布：ShareLink 流程 + 结果确认
        .sheet(isPresented: Binding(
            get: { pendingPublishURL != nil },
            set: { if !$0 { pendingPublishURL = nil } }
        )) {
            if let url = pendingPublishURL {
                PublishActionSheet(imageURL: url, caption: pendingPublishDraft?.caption ?? "") { completed in
                    if completed, let draft = pendingPublishDraft {
                        Task { await viewModel.markPublished(draft) }
                    }
                    pendingPublishURL = nil
                    pendingPublishDraft = nil
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Row

    private func queueRow(_ draft: DraftPost) -> some View {
        HStack(spacing: 12) {
            // 缩略图
            thumbnail(draft)

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.caption.isEmpty ? "（无文案）" : draft.caption)
                    .font(.subheadline)
                    .foregroundColor(currentTheme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let at = draft.scheduledAt, draft.status == .scheduled {
                        Label(at.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(draft.isDue ? currentTheme.negativeRed : currentTheme.textTertiary)
                    }
                    if draft.isDue {
                        Text("待发布")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(currentTheme.warningOrange)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // 操作
            Menu {
                if draft.status == .scheduled || draft.status == .draft {
                    Button("编辑") { editingDraft = draft }
                }
                if draft.status == .scheduled && draft.isDue {
                    Button("立即发布", systemImage: "paperplane.fill") { publishDraft(draft) }
                }
                Button("标记已发布", systemImage: "checkmark.circle") {
                    Task { await viewModel.markPublished(draft) }
                }
                if draft.status == .scheduled {
                    Button("标记已取消", systemImage: "xmark.circle") {
                        Task { await viewModel.markFailed(draft) }
                    }
                }
                Button("删除", systemImage: "trash", role: .destructive) {
                    Task { await viewModel.delete(draft) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(currentTheme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func thumbnail(_ draft: DraftPost) -> some View {
        Group {
            if let filename = draft.imageFilename,
               let url = appState.container.postAssistantService.draftFileURL(filename: filename) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(currentTheme.cardSurface)
            .frame(width: 48, height: 48)
            .overlay {
                Image(systemName: "photo")
                    .foregroundColor(currentTheme.textTertiary)
            }
    }

    // MARK: - Actions

    /// 到期草稿立即发布：复制文案 + 分享图片文件，完成后标记已发布
    private func publishDraft(_ draft: DraftPost) {
        guard let filename = draft.imageFilename,
              let url = appState.container.postAssistantService.draftFileURL(filename: filename) else { return }
        appState.container.postAssistantService.copyCaption(draft.caption)
        pendingPublishURL = url
        pendingPublishDraft = draft
    }
}
