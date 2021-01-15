//
//  HistoryView.swift
//  Simple Desktops
//
//  Created by Jiaxin Shou on 2021/1/15.
//

import SDWebImageSwiftUI
import SwiftUI

struct HistoryView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @FetchRequest(fetchRequest: Wallpaper.fetchRequest(.all)) var wallpapers: FetchedResults<Wallpaper>

    @Binding var currentView: PopoverView.ViewState

    @State private var hoveringItem: Wallpaper?

    var body: some View {
        VStack {
            HStack {
                backButton
                    .padding(imageButtonPadding)

                Spacer()
            }

            ScrollView {
                Spacer(minLength: highlighLineWidth)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(historyImageWidth), spacing: historyImageSpacing), count: 2)) {
                    ForEach(wallpapers) { wallpaper in
                        ZStack {
                            Rectangle()
                                .stroke(lineWidth: hoveringItem == wallpaper ? highlighLineWidth : 0)
                                .foregroundColor(.accentColor)

                            WebImage(url: wallpaper.previewUrl)
                                .resizable()
                                .aspectRatio(historyImageAspectRatio, contentMode: .fill)
                                .onHover { _ in
                                    self.hoveringItem = wallpaper
                                }
                        }
                    }
                }

                Spacer(minLength: highlighLineWidth)
            }
        }
    }

    private var backButton: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                currentView = .preview
            }
        }) {
            Image(systemName: "chevron.backward")
                .font(Font.system(size: imageButtonIconSize, weight: .bold))
                .frame(width: imageButtonSize, height: imageButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Draw Constants

    private let historyImageWidth: CGFloat = 176
    private let historyImageAspectRatio: CGFloat = 1.6
    private let historyImageSpacing: CGFloat = 16
    private let imageButtonIconSize: CGFloat = 16
    private let imageButtonSize: CGFloat = 32
    private let imageButtonPadding: CGFloat = 6
    private let highlighLineWidth: CGFloat = 6
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let viewContext = PersistenceController().container.viewContext

        HistoryView(currentView: .constant(.history))
            .environment(\.managedObjectContext, viewContext)
            .previewLayout(.fixed(width: 400, height: 358))
    }
}
