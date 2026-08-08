//
//  PostAssistantService.swift
//  Follower
//
//  发布助手服务 — 准备发布内容并交给系统分享面板 / 快捷指令：
//  - 图片存储：App 沙盒 Documents/FollowerDrafts/
//  - 文案：复制到系统剪贴板
//  - 排期：本地通知提醒（App 无法后台准点发布，由用户确认完成）
//

import UIKit   // 仅 UIPasteboard（iOS 无纯 SwiftUI 剪贴板 API）
import UserNotifications

// MARK: - PostAssistantService

/// 发布助手服务 — 内容准备（图片/剪贴板/通知/快捷指令引导）
@MainActor
final class PostAssistantService {

    /// 草稿图片存储目录名（Documents 下，本地优先）
    static let draftsDirectoryName = "FollowerDrafts"

    // MARK: - 图片存储

    /// 保存图片数据到沙盒，返回相对文件名
    func saveImageData(_ data: Data) throws -> String {
        let filename = "\(UUID().uuidString).jpg"
        let url = try Self.draftsDirectory().appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return filename
    }

    /// 删除草稿图片文件（草稿删除时调用，避免沙盒残留）
    func deleteImage(filename: String?) {
        guard let filename,
              let url = Self.draftFileURL(filename: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// 取草稿图片文件 URL（供 ShareLink 分享）
    func draftFileURL(filename: String) -> URL? {
        guard filename.contains(".") else { return nil }
        return try? Self.draftsDirectory().appendingPathComponent(filename)
    }

    /// 取草稿图片数据（供 SwiftUI 预览解码）
    func loadImageData(filename: String) -> Data? {
        guard let url = draftFileURL(filename: filename) else { return nil }
        return try? Data(contentsOf: url)
    }

    // MARK: - 剪贴板

    /// 复制文案到系统剪贴板（用户进入 Instagram 后直接粘贴）
    func copyCaption(_ caption: String) {
        UIPasteboard.general.string = caption
    }

    // MARK: - 排期提醒（本地通知）

    /// 请求通知权限
    func requestNotificationAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    /// 调度排期提醒 — draftID 存入通知 payload，点通知可回到对应草稿
    func scheduleReminder(draftID: Int64, caption: String, at date: Date) async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "发布提醒"
        content.body = caption.isEmpty ? "该发布你的帖子了" : "「\(caption.prefix(40))」该发布了"
        content.sound = .default
        content.userInfo = ["draftID": draftID]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "postReminder_\(draftID)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    /// 取消排期提醒（删除/标记草稿时清理）
    func cancelReminder(draftID: Int64) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["postReminder_\(draftID)"])
    }

    // MARK: - 快捷指令引导

    /// 打开快捷指令 App（引导用户运行自定义「发布到 Instagram」快捷指令）
    var shortcutsAppURL: URL? {
        URL(string: "shortcuts://")
    }

    // MARK: - Private

    /// 草稿图片目录（不存在则创建）
    private static func draftsDirectory() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = documents.appendingPathComponent(draftsDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 草稿文件绝对 URL（校验目录归属）
    private static func draftFileURL(filename: String) -> URL? {
        guard let dir = try? draftsDirectory() else { return nil }
        return dir.appendingPathComponent(filename)
    }
}
