import SwiftUI
import MetalKit
import AppKit


// MARK: - Player Background

struct PlayerBackground: View {

    let currentArtwork: NSImage?

    var body: some View {
        MetalAuroraView(
            currentArtwork: currentArtwork
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}


// MARK: - Metal View

private struct MetalAuroraView: NSViewRepresentable {

    let currentArtwork: NSImage?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(
        context: Context
    ) -> MTKView {

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this Mac.")
        }

        let view = MTKView(
            frame: .zero,
            device: device
        )

        view.device = device

        view.colorPixelFormat = .bgra8Unorm

        view.clearColor = MTLClearColor(
            red: 0.015,
            green: 0.015,
            blue: 0.02,
            alpha: 1
        )

        view.framebufferOnly = true

        // 持续渲染
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false

        let renderer = AuroraRenderer(
            device: device,
            artwork: currentArtwork
        )

        view.delegate = renderer

        context.coordinator.renderer = renderer

        return view
    }

    func updateNSView(
        _ nsView: MTKView,
        context: Context
    ) {
        context.coordinator.renderer?.updateArtwork(
            currentArtwork
        )
    }


    final class Coordinator {

        var renderer: AuroraRenderer?
    }
}


// MARK: - Renderer

private final class AuroraRenderer: NSObject, MTKViewDelegate {

    private let device: MTLDevice

    private let commandQueue: MTLCommandQueue

    private let pipelineState: MTLRenderPipelineState

    private let startTime = CACurrentMediaTime()

    // 当前 6 个主色
    private var palette: [SIMD4<Float>] = [
        SIMD4<Float>(0.10, 0.12, 0.13, 1),
        SIMD4<Float>(0.20, 0.30, 0.30, 1),
        SIMD4<Float>(0.35, 0.45, 0.44, 1),
        SIMD4<Float>(0.55, 0.58, 0.50, 1),
        SIMD4<Float>(0.15, 0.20, 0.20, 1),
        SIMD4<Float>(0.05, 0.07, 0.08, 1)
    ]

    // 避免同一 NSImage 重复提取颜色
    private var artworkIdentifier: ObjectIdentifier?


    init(
        device: MTLDevice,
        artwork: NSImage?
    ) {

        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            fatalError(
                "Failed to create Metal command queue."
            )
        }

        self.commandQueue = commandQueue


        // ----------------------------------------------------
        // Metal Library
        // ----------------------------------------------------

        guard
            let libraryURL = Bundle.main.url(
                forResource: "AuroraBackground",
                withExtension: "metallib"
            )
        else {
            fatalError(
                "AuroraBackground.metallib was not found."
            )
        }

        print(
            "🔥 Metal library:",
            libraryURL.path
        )


        guard
            let library = try? device.makeLibrary(
                filepath: libraryURL.path
            )
        else {
            fatalError(
                "Failed to load AuroraBackground.metallib."
            )
        }


        guard
            let vertexFunction = library.makeFunction(
                name: "auroraVertex"
            ),
            let fragmentFunction = library.makeFunction(
                name: "auroraFragment"
            )
        else {
            fatalError(
                "auroraVertex / auroraFragment not found."
            )
        }


        // ----------------------------------------------------
        // Pipeline
        // ----------------------------------------------------

        let descriptor =
            MTLRenderPipelineDescriptor()

        descriptor.vertexFunction =
            vertexFunction

        descriptor.fragmentFunction =
            fragmentFunction

        descriptor.colorAttachments[0]
            .pixelFormat = .bgra8Unorm


        guard
            let pipeline =
                try? device.makeRenderPipelineState(
                    descriptor: descriptor
                )
        else {
            fatalError(
                "Failed to create render pipeline."
            )
        }

        self.pipelineState = pipeline

        super.init()


        // 初始颜色
        updateArtwork(artwork)
    }


    // MARK: - Artwork → Palette

    func updateArtwork(
        _ artwork: NSImage?
    ) {

        guard let artwork else {

            artworkIdentifier = nil

            palette = PaletteExtractor.defaultPalette

            return
        }


        let identifier =
            ObjectIdentifier(artwork)


        // 相同图片不重复计算
        if artworkIdentifier == identifier {
            return
        }


        artworkIdentifier = identifier


        let newPalette =
            PaletteExtractor.extract(
                from: artwork
            )


        if newPalette.count >= 6 {

            palette = newPalette

            print("🎨 New palette:")

            for color in newPalette {
                print(
                    String(
                        format:
                            "  RGB %.2f %.2f %.2f",
                        color.x,
                        color.y,
                        color.z
                    )
                )
            }
        }
    }


    // MARK: - Draw

    func draw(
        in view: MTKView
    ) {

        guard
            let drawable =
                view.currentDrawable,

            let renderPassDescriptor =
                view.currentRenderPassDescriptor,

            let commandBuffer =
                commandQueue.makeCommandBuffer()
        else {
            return
        }


        let elapsed =
            Float(
                CACurrentMediaTime()
                - startTime
            )


        // ----------------------------------------------------
        // Uniforms
        // ----------------------------------------------------

        var uniforms = AuroraUniforms(

            resolution: SIMD2<Float>(
                Float(view.drawableSize.width),
                Float(view.drawableSize.height)
            ),

            time: elapsed,

            color0: palette[0],
            color1: palette[1],
            color2: palette[2],
            color3: palette[3],
            color4: palette[4],
            color5: palette[5]
        )


        guard
            let buffer =
                device.makeBuffer(
                    bytes: &uniforms,
                    length:
                        MemoryLayout<
                            AuroraUniforms
                        >.stride,
                    options: .storageModeShared
                )
        else {
            return
        }


        // ----------------------------------------------------
        // Encoder
        // ----------------------------------------------------

        guard
            let encoder =
                commandBuffer.makeRenderCommandEncoder(
                    descriptor:
                        renderPassDescriptor
                )
        else {
            return
        }


        encoder.setRenderPipelineState(
            pipelineState
        )


        // Uniforms
        encoder.setVertexBuffer(
            buffer,
            offset: 0,
            index: 0
        )

        encoder.setFragmentBuffer(
            buffer,
            offset: 0,
            index: 0
        )


        // ----------------------------------------------------
        // Full Screen Triangle
        // ----------------------------------------------------

        encoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: 3
        )


        encoder.endEncoding()


        commandBuffer.present(
            drawable
        )

        commandBuffer.commit()
    }


    func mtkView(
        _ view: MTKView,
        drawableSizeWillChange size: CGSize
    ) {
    }
}


// MARK: - Uniforms

private struct AuroraUniforms {

    var resolution: SIMD2<Float>

    var time: Float

    var padding: Float = 0

    var color0: SIMD4<Float>
    var color1: SIMD4<Float>
    var color2: SIMD4<Float>
    var color3: SIMD4<Float>
    var color4: SIMD4<Float>
    var color5: SIMD4<Float>
}


// MARK: - Palette Extractor

private enum PaletteExtractor {

    static let defaultPalette: [
        SIMD4<Float>
    ] = [

        SIMD4<Float>(
            0.10,
            0.12,
            0.14,
            1
        ),

        SIMD4<Float>(
            0.18,
            0.24,
            0.28,
            1
        ),

        SIMD4<Float>(
            0.30,
            0.38,
            0.40,
            1
        ),

        SIMD4<Float>(
            0.48,
            0.48,
            0.44,
            1
        ),

        SIMD4<Float>(
            0.12,
            0.18,
            0.20,
            1
        ),

        SIMD4<Float>(
            0.035,
            0.045,
            0.055,
            1
        )
    ]


    static func extract(
        from image: NSImage
    ) -> [
        SIMD4<Float>
    ] {

        guard
            let cgImage =
                image.cgImage(
                    forProposedRect: nil,
                    context: nil,
                    hints: nil
                )
        else {
            return defaultPalette
        }


        // ----------------------------------------------------
        // 缩小图片
        //
        // 只需要颜色，不需要高清图片
        // ----------------------------------------------------

        let targetWidth = 48
        let targetHeight = 48


        guard
            let context = CGContext(
                data: nil,

                width: targetWidth,
                height: targetHeight,

                bitsPerComponent: 8,

                bytesPerRow:
                    targetWidth * 4,

                space: CGColorSpaceCreateDeviceRGB(),

                bitmapInfo:
                    CGImageAlphaInfo.premultipliedLast
                    .rawValue
            )
        else {
            return defaultPalette
        }


        context.interpolationQuality = .medium


        context.draw(
            cgImage,
            in: CGRect(
                x: 0,
                y: 0,
                width: targetWidth,
                height: targetHeight
            )
        )


        guard
            let data = context.data
        else {
            return defaultPalette
        }


        let pointer =
            data.assumingMemoryBound(
                to: UInt8.self
            )


        // ----------------------------------------------------
        // 颜色直方图
        //
        // 32 × 32 × 32 = 32768 色桶
        // ----------------------------------------------------

        struct Bucket {

            var count: Int = 0

            var r: Float = 0
            var g: Float = 0
            var b: Float = 0
        }


        var buckets = Array(
            repeating: Bucket(),
            count: 32 * 32 * 32
        )


        for y in 0..<targetHeight {

            for x in 0..<targetWidth {

                let index =
                    (
                        y * targetWidth
                        + x
                    ) * 4


                let r =
                    Float(pointer[index])
                    / 255.0

                let g =
                    Float(pointer[index + 1])
                    / 255.0

                let b =
                    Float(pointer[index + 2])
                    / 255.0


                // 太暗的像素减少权重
                let brightness =
                    max(
                        r,
                        max(g, b)
                    )


                if brightness < 0.025 {
                    continue
                }


                let ri =
                    min(
                        31,
                        Int(r * 31)
                    )

                let gi =
                    min(
                        31,
                        Int(g * 31)
                    )

                let bi =
                    min(
                        31,
                        Int(b * 31)
                    )


                let bucketIndex =
                    (
                        ri * 32
                        + gi
                    ) * 32
                    + bi


                buckets[bucketIndex].count += 1

                buckets[bucketIndex].r += r
                buckets[bucketIndex].g += g
                buckets[bucketIndex].b += b
            }
        }


        // ----------------------------------------------------
        // 排序
        // ----------------------------------------------------

        let candidates =
            buckets
                .enumerated()
                .filter {
                    $0.element.count > 0
                }
                .sorted {
                    $0.element.count
                    >
                    $1.element.count
                }


        var result:
            [SIMD4<Float>] = []


        // ----------------------------------------------------
        // 选 6 个“既常见又彼此不同”的颜色
        // ----------------------------------------------------

        for candidate in candidates {

            let bucket =
                candidate.element


            let count =
                Float(bucket.count)


            let color =
                SIMD3<Float>(
                    bucket.r / count,
                    bucket.g / count,
                    bucket.b / count
                )


            // 不要选太灰、太暗的重复颜色
            var valid = true


            for existing in result {

                let existingColor =
                    SIMD3<Float>(
                        existing.x,
                        existing.y,
                        existing.z
                    )


                let distance =
                    simd_distance(
                        color,
                        existingColor
                    )


                if distance < 0.12 {

                    valid = false

                    break
                }
            }


            if valid {

                result.append(
                    SIMD4<Float>(
                        color.x,
                        color.y,
                        color.z,
                        1
                    )
                )
            }


            if result.count == 6 {
                break
            }
        }


        // 不足 6 个颜色就补默认色
        while result.count < 6 {

            result.append(
                defaultPalette[
                    result.count
                ]
            )
        }


        return result
    }
}
