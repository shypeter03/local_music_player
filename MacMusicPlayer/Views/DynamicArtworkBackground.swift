import AppKit
import SwiftUI
import UniformTypeIdentifiers

 struct DynamicArtworkBackground: View {
    let track: Track?

    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.15

    var body: some View {
        ZStack {
            // 基础背景
            Color(nsColor: .windowBackgroundColor)

            if let track,
               let data = ArtworkLoader.artworkData(for: track),
               let image = NSImage(data: data) {

                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(scale)
                    .offset(offset)
                    .blur(radius: 70)
                    .opacity(0.28)
                    .animation(
                        .easeInOut(duration: 1.2),
                        value: track.id
                    )
            }

            // 再压一层，让背景不会太花
            Rectangle()
                .fill(.ultraThinMaterial)
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimation()
        }
        .onChange(of: track?.id) { _ in
            startAnimation()
        }
    }

    private func startAnimation() {
        offset = CGSize(
            width: CGFloat.random(in: -40...40),
            height: CGFloat.random(in: -30...30)
        )

        scale = CGFloat.random(in: 1.12...1.22)
    }
}
