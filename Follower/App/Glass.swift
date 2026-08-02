//
//  Glass.swift
//  Follower
//

import SwiftUI

// MARK: - 数据模型
struct Chord: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let notes: String
    let isMajor: Bool
}

struct ExplorePackage: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let iconName: String
}

// MARK: - 带边缘光晕折射的 Liquid Glass 修饰器
struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            // 1. 基础毛玻璃材质
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // 2. 玻璃微弱渐变
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.09),
                                Color.white.opacity(0.01)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            // 3. 【光晕层】模拟光线照射在玻璃边缘的溢出光线 (Edge Specular Blur)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.65), location: 0.0), // 顶部高光光晕
                                .init(color: .clear, location: 0.25),
                                .init(color: .clear, location: 0.75),
                                .init(color: Color.white.opacity(0.30), location: 1.0) // 底部次级光晕
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                    .blur(radius: 2) // 核心：通过羽化创造真实光效
            )
            // 4. 【实线层】玻璃切边的物理高光锐利边框
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.55), location: 0.0),
                                .init(color: Color.white.opacity(0.02), location: 0.18),
                                .init(color: Color.white.opacity(0.02), location: 0.82),
                                .init(color: Color.white.opacity(0.28), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            )
            // 5. 悬浮阴影
            .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func liquidGlassEffect(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - 和弦列表卡片 (作为 NavigationLink 的 Label)
struct ChordCardView: View {
    let chord: Chord

    var body: some View {
        HStack(spacing: 12) {
            // 左侧和弦指法图占位
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                    .frame(width: 44, height: 50)
                
                Image(systemName: chord.isMajor ? "guitars.fill" : "guitars")
                    .font(.caption)
                    .foregroundStyle(chord.isMajor ? .pink : .cyan)
            }

            // 右侧文本
            VStack(alignment: .leading, spacing: 4) {
                Text(chord.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(chord.notes)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(height: 74)
        .liquidGlassEffect(cornerRadius: 16)
    }
}

// MARK: - 探索包卡片
struct ExploreCardView: View {
    let package: ExplorePackage

    var body: some View {
        HStack {
            if !package.iconName.isEmpty {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: package.iconName)
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            
            Text(package.name)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(16)
        .frame(height: 110, alignment: .topLeading)
        .liquidGlassEffect(cornerRadius: 20)
    }
}

// MARK: - 详情页 (iOS 18 目标视图)
struct ChordDetailView: View {
    let chord: Chord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // 背景深色
            Color(red: 0.04, green: 0.04, blue: 0.07)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                // Header (关闭按钮)
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(10)
                            .liquidGlassEffect(cornerRadius: 20)
                    }
                }

                // 标题信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(chord.name)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("音符构成：\(chord.notes)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))

                // 展示主体图表/图标区域
                VStack(spacing: 16) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 120, height: 120)
                            .blur(radius: 10)
                        
                        Image(systemName: chord.isMajor ? "guitars.fill" : "guitars")
                            .font(.system(size: 56))
                            .foregroundStyle(chord.isMajor ? .pink : .cyan)
                    }
                    
                    Text("和弦练习与指法分析表")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("系统原生 Zoom 缩放转场能够完美接管卡片层次，支持天然手势侧滑与拖拽返回。")
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .liquidGlassEffect(cornerRadius: 20)

                // 底部播放操作按钮
                Button(action: {}) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("播放示范音效")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(chord.isMajor ? Color.pink.opacity(0.8) : Color.cyan.opacity(0.8))
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
        .navigationBarBackButtonHidden(true) // 隐藏系统默认 Back 按钮，使用自定义玻璃关闭按钮
    }
}

// MARK: - 主视图 (iOS 18+ 原生 Zoom 架构)
struct ChordListView: View {
    // 1. 定义 iOS 18+ Transition 命名空间
    @Namespace private var heroZoomNamespace

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    let firstChords: [Chord] = [
        Chord(name: "C major", notes: "C, E, G", isMajor: true),
        Chord(name: "G major", notes: "G, B, D", isMajor: true),
        Chord(name: "D major", notes: "D, F#, A", isMajor: true),
        Chord(name: "A major", notes: "A, C#, E", isMajor: true),
        Chord(name: "E major", notes: "E, G#, B", isMajor: true),
        Chord(name: "A minor", notes: "A, C, E", isMajor: false),
        Chord(name: "E minor", notes: "E, G, B", isMajor: false),
        Chord(name: "D minor", notes: "D, F, A", isMajor: false),
        Chord(name: "E7", notes: "E, G#, B, D", isMajor: false),
        Chord(name: "G7", notes: "G, B, D, F", isMajor: false)
    ]

    let explorePackages: [ExplorePackage] = [
        ExplorePackage(name: "音乐包", iconName: "house.fill"),
        ExplorePackage(name: "爵士和弦集", iconName: "")
    ]

    var body: some View {
        // 2. 必须包裹在 NavigationStack 中
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.07)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // 顶部 Header
                        HStack {
                            Spacer()
                            Text("家")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .overlay(
                            HStack(spacing: 12) {
                                Spacer()
                                Button {} label: {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 15))
                                        .padding(9)
                                        .liquidGlassEffect(cornerRadius: 20)
                                }
                                Button {} label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 15))
                                        .padding(9)
                                        .liquidGlassEffect(cornerRadius: 20)
                                }
                            }
                            .foregroundColor(.white)
                        )
                        .padding(.top, 8)

                        // 第一部分：第一个和弦
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("第一个和弦")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("对于刚开始学习吉他和弦的人来说")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                
                                Spacer()
                                
                                Button {} label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(10)
                                        .liquidGlassEffect(cornerRadius: 20)
                                }
                            }

                            // 双列网格 (结合 NavigationLink & zoom 动画)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(firstChords) { chord in
                                    NavigationLink {
                                        ChordDetailView(chord: chord)
                                            // 关键配置 1：给目标页面指定 .zoom 转场，并关联 sourceID
                                            .navigationTransition(
                                                .zoom(sourceID: chord.id, in: heroZoomNamespace)
                                            )
                                    } label: {
                                        ChordCardView(chord: chord)
                                    }
                                    .buttonStyle(PlainButtonStyle()) // 保持原本样式，防止被 NavigationLink 蓝字化
                                    // 关键配置 2：标记当前卡片为动画触发的源 (Source Tag)
                                    .matchedTransitionSource(id: chord.id, in: heroZoomNamespace)
                                }
                            }
                        }

                        // 第二部分：探索和弦包
                        VStack(alignment: .leading, spacing: 14) {
                            Text("探索和弦包")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(explorePackages) { package in
                                    ExploreCardView(package: package)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ChordListView()
}
