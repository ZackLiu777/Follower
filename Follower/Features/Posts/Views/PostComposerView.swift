//
//  PostComposerView.swift
//  Follower
//
//  发布助手 — 选图 + 文案 + 排期 + 三种流程（保存草稿 / 排期提醒 / 立即发布）。
//  纯 SwiftUI：PhotosPicker 选图、ShareLink 系统分享、剪贴板由服务层处理。
//

import SwiftUI
import PhotosUI

// MARK: - PostComposerView

struct PostComposerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var viewModel: PostComposerViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    /// 新选图片的 SwiftUI 预览（PhotosPicker loadTransferable）
    @State private var previewImage: Image?
    /// 立即发布确认弹层（ShareLink 流程）
    @State private var publishURL: URL?
    @State private var showShortcutsHint: Bool = false

    /// 初始化 — 从容器注入 Repository 与助手服务
    init(draftRepo: DraftPostRepositoryProtocol, assistant: PostAssistantService, editingDraft: DraftPost? = nil) {
        let vm = PostComposerViewModel(draftRepo: draftRepo, assistant: assistant)
        if let editingDraft {
            vm.load(editingDraft)
        }
        _viewModel = State(initialValue: vm)
    }

    private var currentTheme: Theme { appState.currentTheme.theme }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: 图片选择
                    imageSection

                    // MARK: 文案
                    VStack(alignment: .leading, spacing: 8) {
                        Text("文案")
                            .font(.subheadline)
                            .foregroundColor(currentTheme.textSecondary)
                        TextEditor(text: $viewModel.caption)
                            .frame(minHeight: 100)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(currentTheme.cardSurface.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                if viewModel.caption.isEmpty {
                                    Text("写下你的帖子内容…")
                                        .foregroundColor(currentTheme.textTertiary)
                                        .padding(.leading, 12)
                                        .padding(.top, 16)
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                        .allowsHitTesting(false)
                                }
                            }
                    }

                    // MARK: 排期开关
                    Toggle("排期提醒", isOn: $viewModel.isScheduled)
                        .tint(currentTheme.accentPrimary)
                        .foregroundColor(currentTheme.textPrimary)

                    if viewModel.isScheduled {
                        DatePicker(
                            "发布时间",
                            selection: $viewModel.scheduledAt,
                            in: Date()...
                        )
                        .foregroundColor(currentTheme.textPrimary)
                    }

                    // MARK: 操作区
                    VStack(spacing: 10) {
                        Button { publishNow() } label: {
                            Label("立即发布", systemImage: "paperplane.fill")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [currentTheme.chartBarGradientStart, currentTheme.chartBarGradientEnd],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!viewModel.hasImage)

                        HStack(spacing: 10) {
                            Button("保存草稿") {
                                Task { await viewModel.saveDraft() }
                            }
                            .buttonStyle(.bordered)
                            .tint(currentTheme.accentPrimary)

                            Button("排期") {
                                Task { await viewModel.scheduleDraft() }
                            }
                            .buttonStyle(.bordered)
                            .tint(currentTheme.accentPrimary)
                            .disabled(!viewModel.isScheduled)
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(currentTheme.negativeRed)
                    }

                    // MARK: 快捷指令提示
                    Button {
                        showShortcutsHint = true
                    } label: {
                        Label("如何使用快捷指令一键发布", systemImage: "s.circle")
                            .font(.caption)
                            .foregroundColor(currentTheme.accentPrimary)
                    }
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: currentTheme.backgroundGradientColors,
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle(viewModel.editingDraft == nil ? "发布助手" : "编辑草稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: viewModel.didFinish) { _, finished in
                if finished { dismiss() }
            }
            .onChange(of: selectedPhotoItem) { _, item in
                loadPhoto(item)
            }
            // 立即发布确认弹层（纯 SwiftUI ShareLink 流程）
            .sheet(isPresented: Binding(
                get: { publishURL != nil },
                set: { if !$0 { publishURL = nil } }
            )) {
                if let url = publishURL {
                    PublishActionSheet(imageURL: url, caption: viewModel.caption) { completed in
                        Task { await viewModel.finishPublishFlow(completed: completed) }
                    }
                    .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $showShortcutsHint) {
                ShortcutsHintView(assistant: appState.container.postAssistantService)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - 图片区

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("图片")
                .font(.subheadline)
                .foregroundColor(currentTheme.textSecondary)

            if hasPreviewImage {
                ZStack(alignment: .topTrailing) {
                    imagePreview
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Button {
                        viewModel.pendingImageData = nil
                        viewModel.existingImageFilename = nil
                        previewImage = nil
                        selectedPhotoItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                            .padding(8)
                    }
                }
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.title)
                            .foregroundColor(currentTheme.accentPrimary)
                        Text("选择图片")
                            .font(.subheadline)
                            .foregroundColor(currentTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(currentTheme.cardSurface.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    /// 是否有可显示的预览（新选图或已有草稿文件）
    private var hasPreviewImage: Bool {
        previewImage != nil || viewModel.existingImageFilename != nil
    }

    /// 图片预览 — 新选图用 SwiftUI Image；已有草稿文件用 AsyncImage（file://）
    @ViewBuilder
    private var imagePreview: some View {
        if let previewImage {
            previewImage
                .resizable()
                .scaledToFill()
        } else if let filename = viewModel.existingImageFilename,
                  let url = appState.container.postAssistantService.draftFileURL(filename: filename) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Rectangle()
                        .fill(currentTheme.cardSurface)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(currentTheme.textTertiary)
                        }
                }
            }
        }
    }

    // MARK: - Actions

    /// 立即发布：保存图片 → 复制文案 → 打开发布确认弹层
    private func publishNow() {
        Task {
            guard let url = await viewModel.prepareForImmediatePublish() else { return }
            publishURL = url
        }
    }

    /// PhotosPicker 选中 → 并行加载预览图（Image）与数据（Data 保存用）
    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            previewImage = try? await item.loadTransferable(type: Image.self)
        }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                viewModel.pendingImageData = data
            }
        }
    }
}

// MARK: - ShortcutsHintView

/// 快捷指令使用说明 — 文案已自动复制到剪贴板
struct ShortcutsHintView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let assistant: PostAssistantService

    private var currentTheme: Theme { appState.currentTheme.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("快捷指令一键发布")
                .font(.headline)
                .foregroundColor(currentTheme.textPrimary)

            Text("1. 在「快捷指令」App 中新建一条指令：\n   取剪贴板 → 打开 Instagram")
                .font(.subheadline)
                .foregroundColor(currentTheme.textSecondary)

            Text("2. 回到本页面点「立即发布」：\n   文案已复制，图片已保存到相册\n   （照片 App → FollowerDrafts）")
                .font(.subheadline)
                .foregroundColor(currentTheme.textSecondary)

            Text("3. 运行快捷指令，在 Instagram 中粘贴发布")
                .font(.subheadline)
                .foregroundColor(currentTheme.textSecondary)

            Button {
                // 注意：不覆盖剪贴板 — 真实文案已在「立即发布」时复制
                if let url = assistant.shortcutsAppURL {
                    openURL(url)
                }
            } label: {
                Label("打开快捷指令 App", systemImage: "arrow.up.right.square")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(currentTheme.accentPrimary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 6)

            Button("关闭") { dismiss() }
                .font(.caption)
                .foregroundColor(currentTheme.textSecondary)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(currentTheme.backgroundGradientStart)
        .environment(\.colorScheme, currentTheme.isDark ? .dark : .light)
    }
}
