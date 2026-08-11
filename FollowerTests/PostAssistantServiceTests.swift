//
//  PostAssistantServiceTests.swift
//  FollowerTests
//
//  发布助手服务单元测试 — 沙盒图片存储（保存/读取/删除往返、
//  文件名唯一性、无扩展名防护）。通知与剪贴板依赖系统环境，不测。
//

import Testing
import Foundation
@testable import Follower

/// Unit tests for PostAssistantService — sandbox image storage round-trip
@MainActor
struct PostAssistantServiceTests {

    /// 保存图片 → 返回 .jpg 文件名，读取往返一致
    @Test
    func testSaveAndLoadImageRoundTrip() throws {
        let service = PostAssistantService()
        let data = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3, 4])
        let filename = try service.saveImageData(data)
        #expect(filename.hasSuffix(".jpg"))

        let loaded = service.loadImageData(filename: filename)
        #expect(loaded == data)
    }

    /// 两次保存 → 文件名不同（UUID 唯一）
    @Test
    func testSaveImageProducesUniqueFilenames() throws {
        let service = PostAssistantService()
        let a = try service.saveImageData(Data([1]))
        let b = try service.saveImageData(Data([1]))
        #expect(a != b)
    }

    /// 删除图片 → 再读取返回 nil
    @Test
    func testDeleteImageRemovesFile() throws {
        let service = PostAssistantService()
        let filename = try service.saveImageData(Data([9, 9, 9]))
        service.deleteImage(filename: filename)
        #expect(service.loadImageData(filename: filename) == nil)
    }

    /// 删除 nil / 不存在文件 → 不崩溃
    @Test
    func testDeleteImageNilAndMissingAreSafe() {
        let service = PostAssistantService()
        service.deleteImage(filename: nil)
        service.deleteImage(filename: "missing_\(UUID().uuidString).jpg")
    }

    /// 无扩展名文件名 → draftFileURL 返回 nil（防护目录穿越）
    @Test
    func testDraftFileURLRequiresExtension() {
        let service = PostAssistantService()
        #expect(service.draftFileURL(filename: "noextension") == nil)
        #expect(service.draftFileURL(filename: "ok.jpg") != nil)
    }
}
