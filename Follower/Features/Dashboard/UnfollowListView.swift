//
//  UnfollowListView.swift
//  Follower
//
//  Lambda: Premium 详情 — 取关列表。

import SwiftUI

struct UnfollowListView: View {
    let followers: [MockFollower]

    var body: some View {
        List(followers) { f in
            HStack {
                ZStack {
                    Circle().fill(Color(hex: f.avatarColor) ?? .gray).frame(width: 44, height: 44)
                    Text(String(f.displayName.prefix(1))).font(.headline).foregroundColor(.white)
                }
                VStack(alignment: .leading) {
                    Text(f.displayName).font(.subheadline).fontWeight(.medium)
                    Text("@\(f.username)").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(f.date.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.caption).foregroundColor(.secondary)
                    Text("Unfollowed").font(.caption2).foregroundColor(.red)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Who Unfollowed You")
    }
}
