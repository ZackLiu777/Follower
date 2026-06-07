//
//  PostListView.swift
//  Follower
//
//  Lambda: 完整帖子列表。

import SwiftUI

struct PostListView: View {
    let posts: [MockPost]

    var body: some View {
        List(posts) { post in
            NavigationLink { PostDetailView(post: post) } label: {
                PostRowView(post: post)
            }
        }
        .navigationTitle("All Posts")
    }
}
