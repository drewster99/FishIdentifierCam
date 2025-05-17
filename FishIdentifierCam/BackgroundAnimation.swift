import Foundation
import SwiftUI
import MetalKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// A beautiful animated background using Metal shaders
public struct BackgroundAnimation: View {

    public var body: some View {
#if os(macOS)
        MetalViewRepresentable()
#else
        MetalViewRepresentable()
            .ignoresSafeArea()
#endif
    }
}

// MARK: - Metal Implementation

private final class MetalView: MTKView {
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var vertices: MTLBuffer?
    private var time: Float = 0
    private var speed: Float = 0.15 // was 1.4
    private var lastFrameTime: CFTimeInterval = 0

    init() {
        super.init(frame: .zero, device: MTLCreateSystemDefaultDevice())

        guard let device = device else { return }

        commandQueue = device.makeCommandQueue()

        // Create vertex buffer
        let vertexData: [Float] = [
            -1, -1,
             1, -1,
             -1,  1,
             1,  1,
        ]
        vertices = device.makeBuffer(
            bytes: vertexData,
            length: vertexData.count * MemoryLayout<Float>.size,
            options: []
        )

        // Create metal library from source code at runtime

        let mixyShader = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut vertex_shader(uint vertexID [[vertex_id]],
                               constant float2 *vertices [[buffer(0)]]) {
    VertexOut out;
    out.position = float4(vertices[vertexID], 0.0, 1.0);
    out.uv = (vertices[vertexID] + 1.0) * 0.5;
    return out;
}

// Hash and noise helpers
float2 hash2(float2 p) {
    float2 f = fract(sin(float2(dot(p, float2(127.1, 311.7)),
                                dot(p, float2(269.5, 183.3)))) * 43758.5453);
    return f * 2.0 - 1.0;
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(dot(hash2(i + float2(0.0, 0.0)), f - float2(0.0, 0.0)),
            dot(hash2(i + float2(1.0, 0.0)), f - float2(1.0, 0.0)), u.x),
        mix(dot(hash2(i + float2(0.0, 1.0)), f - float2(0.0, 1.0)),
            dot(hash2(i + float2(1.0, 1.0)), f - float2(1.0, 1.0)), u.x),
        u.y);
}

float3 rgb_from_hsv(float3 c) {
    float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Fragment Shader
fragment float4 fragment_shader(VertexOut in [[stage_in]],
                                constant float &time [[buffer(0)]],
                                constant float &speed [[buffer(1)]]) {
    float2 uv = in.uv;
    float2 centered = uv * 2.0 - 1.0;
    float TAU = 6.28318530718;

    // --------------------
    // Shader A: Turbulence Water
    // --------------------
    float2 p = fmod(uv * TAU, TAU) - 250.0;
    float2 i = p;
    float c = 1.0;
    float inten = 0.005;
    float localTime = time * 0.5 + 23.0;
    for (int n = 0; n < 5; n++) {
        float t = localTime * (1.0 - (3.5 / float(n + 1)));
        i = p + float2(
            cos(t - i.x) + sin(t + i.y),
            sin(t - i.y) + cos(t + i.x)
        );
        float denomX = sin(i.x + t) / inten;
        float denomY = cos(i.y + t) / inten;
        c += 1.0 / length(float2(p.x / denomX, p.y / denomY));
    }
    c /= 5.0;
    c = 1.17 - pow(c, 1.4);
    float3 colorA = pow(abs(c), 8.0) * float3(1.0);
    colorA = clamp(colorA + float3(0.0, 0.31, 0.7), 0.0, 1.0);
    colorA *= 0.85;

    // --------------------
    // Shader B: Swirling Simplex-style Noise
    // --------------------
    float2 swirlUV = centered * 1.5;
    float v = 0.0;
    float2 warp = swirlUV;
    for (int i = 0; i < 5; ++i) {
        float2 offset = float2(
            sin(warp.y * 3.0 + time * 0.7) * 0.2,
            cos(warp.x * 3.0 - time * 0.4) * 0.2
        );
        warp += offset;
        v += noise(warp * (1.5 + float(i))) / pow(2.0, float(i));
    }
    float swirl = noise(swirlUV * 2.5 + float2(
        sin(centered.y * 2.0 + time * 1.3) * 0.15,
        cos(centered.x * 2.0 - time * 1.1) * 0.15
    ) + time);

    float pattern = sin(v * 3.0 + swirl * 4.0 + time);
    float hue = 0.555 + 0.035 * sin(time * 0.5 + pattern);
    float sat = 0.7;
    float val = 0.65 + 0.1 * sin(time * 0.3 + pattern * 0.5);
    float3 colorB = rgb_from_hsv(float3(hue, sat, val));
    float glow = exp(-length(centered) * 2.5);
    colorB += float3(0.02, 0.04, 0.08) * glow;

    // --------------------
    // Mix both shaders
    // --------------------

//    float edgeBlend = 1.0 - smoothstep(0.0, 0.8, length(centered));
//    float blend = 0.3 + 0.7 * edgeBlend;

    //float blend = 0.4 + 0.4 * sin(time * 0.2); // oscillating blend factor

    float blend = 0.5 + 0.5 * noise(centered * 2.0 + time * 0.2);
    float3 finalColor = mix(colorA, colorB, blend);

    return float4(finalColor, 1.0);
}
"""


/// This one is actually quite cool.  Very movement, smooth, with highlights.  Vary 'speed' (in
/// Swift code, above, to adjust the speed of animation.
///
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 uv;
        };

        vertex VertexOut vertex_shader(uint vertexID [[vertex_id]],
                                       constant float2 *vertices [[buffer(0)]]) {
            VertexOut out;
            out.position = float4(vertices[vertexID], 0.0, 1.0);
            out.uv = (vertices[vertexID] + 1.0) * 0.5;
            return out;
        }

        // Simple noise approximation using hash
        float2 hash2(float2 p) {
            float2 f = fract(sin(float2(dot(p, float2(127.1, 311.7)),
                                        dot(p, float2(269.5, 183.3)))) * 43758.5453);
            return f * 2.0 - 1.0;
        }

        float noise(float2 p) {
            float2 i = floor(p);
            float2 f = fract(p);
            float2 u = f * f * (3.0 - 2.0 * f);

            return mix(
                mix(dot(hash2(i + float2(0.0, 0.0)), f - float2(0.0, 0.0)),
                    dot(hash2(i + float2(1.0, 0.0)), f - float2(1.0, 0.0)), u.x),
                mix(dot(hash2(i + float2(0.0, 1.0)), f - float2(0.0, 1.0)),
                    dot(hash2(i + float2(1.0, 1.0)), f - float2(1.0, 1.0)), u.x),
                u.y);
        }

        float3 rgb_from_hsv(float3 c) {
            float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
            float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
            return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
        }

              fragment float4 fragment_shader(VertexOut in [[stage_in]],
                                constant float &time [[buffer(0)]],
                                constant float &speed [[buffer(1)]]) {
        float2 uv = in.uv;
        float2 resolution = float2(1.0, 1.0); // normalized already
        
        float TAU = 6.28318530718;
        const int MAX_ITER = 5;
        
        float localTime = time * 0.5 + 23.0;
        
        float2 p = fmod(uv * TAU, TAU) - 250.0;
        float2 i = p;
        
        float c = 1.0;
        float inten = 0.005;
        
        for (int n = 0; n < MAX_ITER; n++) {
        float t = localTime * (1.0 - (3.5 / float(n + 1)));
        i = p + float2(
            cos(t - i.x) + sin(t + i.y),
            sin(t - i.y) + cos(t + i.x)
        );
        float denomX = sin(i.x + t) / inten;
        float denomY = cos(i.y + t) / inten;
        c += 1.0 / length(float2(p.x / denomX, p.y / denomY));
        }
        
        c /= float(MAX_ITER);
        c = 1.17 - pow(c, 1.4);
        float3 color = pow(abs(c), 8.0) * float3(1.0);
        color = clamp(color + float3(0.0, 0.31, 0.7), 0.0, 1.0);
        color *= 0.85;
        return float4(color, 1.0);
        }
        """

        //        let shaderSource = """
        //        / Found this on GLSL sandbox. I really liked it, changed a few things and made it tileable.
        //        // :)
        //        // by David Hoskins.
        //        // Original water turbulence effect by joltz0r
        //
        //
        //        // Redefine below to see the tiling...
        //        //#define SHOW_TILING
        //
        //        #define TAU 6.28318530718
        //        #define MAX_ITER 5
        //
        //        void mainImage( out vec4 fragColor, in vec2 fragCoord )
        //        {
        //        float time = iTime * .5+23.0;
        //        // uv should be the 0-1 uv of texture...
        //        vec2 uv = fragCoord.xy / iResolution.xy;
        //
        //        #ifdef SHOW_TILING
        //        vec2 p = mod(uv*TAU*2.0, TAU)-250.0;
        //        #else
        //        vec2 p = mod(uv*TAU, TAU)-250.0;
        //        #endif
        //        vec2 i = vec2(p);
        //        float c = 1.0;
        //        float inten = .005;
        //
        //        for (int n = 0; n < MAX_ITER; n++)
        //        {
        //        float t = time * (1.0 - (3.5 / float(n+1)));
        //        i = p + vec2(cos(t - i.x) + sin(t + i.y), sin(t - i.y) + cos(t + i.x));
        //        c += 1.0/length(vec2(p.x / (sin(i.x+t)/inten),p.y / (cos(i.y+t)/inten)));
        //        }
        //        c /= float(MAX_ITER);
        //        c = 1.17-pow(c, 1.4);
        //        vec3 colour = vec3(pow(abs(c), 8.0));
        //        colour = clamp(colour + vec3(0.0, 0.35, 0.5), 0.0, 1.0);
        //
        //        #ifdef SHOW_TILING
        //        // Flash tile borders...
        //        vec2 pixel = 2.0 / iResolution.xy;
        //        uv *= 2.0;
        //        float f = floor(mod(iTime*.5, 2.0));     // Flash value.
        //        vec2 first = step(pixel, uv) * f;               // Rule out first screen pixels and flash.
        //        uv  = step(fract(uv), pixel);                // Add one line of pixels per tile.
        //        colour = mix(colour, vec3(1.0, 1.0, 0.0), (uv.x + uv.y) * first.x * first.y); // Yellow line
        //        #endif
        //
        //        fragColor = vec4(colour, 1.0);
        //        }
//        """

        /// This one is a pretty good blue/green swirl
//        let shaderSource = """
//        #include <metal_stdlib>
//        using namespace metal;
//
//        struct VertexOut {
//            float4 position [[position]];
//            float2 uv;
//        };
//
//        vertex VertexOut vertex_shader(uint vertexID [[vertex_id]],
//                                       constant float2 *vertices [[buffer(0)]]) {
//            VertexOut out;
//            out.position = float4(vertices[vertexID], 0.0, 1.0);
//            out.uv = (vertices[vertexID] + 1.0) * 0.5;
//            return out;
//        }
//
//        // Simple noise approximation using hash
//        float2 hash2(float2 p) {
//            float2 f = fract(sin(float2(dot(p, float2(127.1, 311.7)),
//                                        dot(p, float2(269.5, 183.3)))) * 43758.5453);
//            return f * 2.0 - 1.0;
//        }
//
//        float noise(float2 p) {
//            float2 i = floor(p);
//            float2 f = fract(p);
//            float2 u = f * f * (3.0 - 2.0 * f);
//
//            return mix(
//                mix(dot(hash2(i + float2(0.0, 0.0)), f - float2(0.0, 0.0)),
//                    dot(hash2(i + float2(1.0, 0.0)), f - float2(1.0, 0.0)), u.x),
//                mix(dot(hash2(i + float2(0.0, 1.0)), f - float2(0.0, 1.0)),
//                    dot(hash2(i + float2(1.0, 1.0)), f - float2(1.0, 1.0)), u.x),
//                u.y);
//        }
//
//        float3 rgb_from_hsv(float3 c) {
//            float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
//            float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
//            return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
//        }
//
//        fragment float4 fragment_shader(VertexOut in [[stage_in]],
//                                constant float &time [[buffer(0)]],
//                                constant float &speed [[buffer(1)]]) {
//        float2 uv = in.uv * 2.0 - 1.0;
//        float2 p = uv * 1.5;
//        float t = time * 0.2;
//        
//        float v = 0.0;
//        float2 warp = p;
//        
//        for (int i = 0; i < 5; ++i) {
//        float2 offset = float2(
//            sin(warp.y * 3.0 + t * 0.7) * 0.2,
//            cos(warp.x * 3.0 - t * 0.4) * 0.2
//        );
//        warp += offset;
//        v += noise(warp * (1.5 + float(i))) / pow(2.0, float(i));
//        }
//        
//        float2 flow = float2(
//        sin(p.y * 2.0 + t * 1.3) * 0.15,
//        cos(p.x * 2.0 - t * 1.1) * 0.15
//        );
//        float swirl = noise(p * 2.5 + flow + t);
//        
//        float pattern = sin(v * 3.0 + swirl * 4.0 + t);
//        
//        // Narrowed hue to deep blue <-> teal
//        float hue = 0.555 + 0.035 * sin(t * 0.5 + pattern); // teal-blue only
//        float sat = 0.7;
//        float val = 0.65 + 0.1 * sin(t * 0.3 + pattern * 0.5); // slight brightness wave
//        
//        float3 baseColor = rgb_from_hsv(float3(hue, sat, val));
//        float glow = exp(-length(uv) * 2.5);
//        baseColor += float3(0.02, 0.04, 0.08) * glow;
//        
//        return float4(baseColor, 1.0);
//        }
//        """

//        let shaderSource = """
//        / Found this on GLSL sandbox. I really liked it, changed a few things and made it tileable.
//        // :)
//        // by David Hoskins.
//        // Original water turbulence effect by joltz0r
//        
//        
//        // Redefine below to see the tiling...
//        //#define SHOW_TILING
//        
//        #define TAU 6.28318530718
//        #define MAX_ITER 5
//        
//        void mainImage( out vec4 fragColor, in vec2 fragCoord ) 
//        {
//        float time = iTime * .5+23.0;
//        // uv should be the 0-1 uv of texture...
//        vec2 uv = fragCoord.xy / iResolution.xy;
//        
//        #ifdef SHOW_TILING
//        vec2 p = mod(uv*TAU*2.0, TAU)-250.0;
//        #else
//        vec2 p = mod(uv*TAU, TAU)-250.0;
//        #endif
//        vec2 i = vec2(p);
//        float c = 1.0;
//        float inten = .005;
//        
//        for (int n = 0; n < MAX_ITER; n++) 
//        {
//        float t = time * (1.0 - (3.5 / float(n+1)));
//        i = p + vec2(cos(t - i.x) + sin(t + i.y), sin(t - i.y) + cos(t + i.x));
//        c += 1.0/length(vec2(p.x / (sin(i.x+t)/inten),p.y / (cos(i.y+t)/inten)));
//        }
//        c /= float(MAX_ITER);
//        c = 1.17-pow(c, 1.4);
//        vec3 colour = vec3(pow(abs(c), 8.0));
//        colour = clamp(colour + vec3(0.0, 0.35, 0.5), 0.0, 1.0);
//        
//        #ifdef SHOW_TILING
//        // Flash tile borders...
//        vec2 pixel = 2.0 / iResolution.xy;
//        uv *= 2.0;
//        float f = floor(mod(iTime*.5, 2.0));     // Flash value.
//        vec2 first = step(pixel, uv) * f;               // Rule out first screen pixels and flash.
//        uv  = step(fract(uv), pixel);                // Add one line of pixels per tile.
//        colour = mix(colour, vec3(1.0, 1.0, 0.0), (uv.x + uv.y) * first.x * first.y); // Yellow line
//        #endif
//        
//        fragColor = vec4(colour, 1.0);
//        }
//        """
        // Create metal library from source code at runtime
        let library: any MTLLibrary
        do {
            library = try device.makeLibrary(source: shaderSource, options: nil)
        } catch {
            print("❌ Library creation failed: \(error)")
            return
        }

        let vertexFunction = library.makeFunction(name: "vertex_shader")
        let fragmentFunction = library.makeFunction(name: "fragment_shader")

        // Create pipeline state
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("❌ Pipeline creation failed: \(error)")
            return
        }
        // Configure view
        framebufferOnly = false
        enableSetNeedsDisplay = true
        isPaused = false
        preferredFramesPerSecond = 60
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        // Set up draw loop
        lastFrameTime = CACurrentMediaTime()

        // Continuous drawing handled by the framework
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #if os(macOS)
    typealias PlatformRect = NSRect
    #else
    typealias PlatformRect = CGRect
    #endif
    override func draw(_ dirtyRect: PlatformRect) {
        guard let pipelineState = pipelineState else {
            print("pipeline state")
            return
        }
        guard let drawable = currentDrawable else {
            print("drawwable")
            return
        }
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else {
            print("command buffer")
            return
        }

        guard    let renderPassDescriptor = currentRenderPassDescriptor else {
            print("render pass descriptor")
            return
        }
        guard    let renderEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor
        ) else {
            print("render command encoder")
            return
        }

        // Update time
        let currentTime = CACurrentMediaTime()
        let deltaTime = Float(currentTime - lastFrameTime)
        time += deltaTime * speed
        lastFrameTime = currentTime

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertices, offset: 0, index: 0)
        renderEncoder.setFragmentBytes(&time, length: MemoryLayout<Float>.size, index: 0)
        renderEncoder.setFragmentBytes(&speed, length: MemoryLayout<Float>.size, index: 1)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - SwiftUI Bridge

#if os(macOS)
private struct MetalViewRepresentable: NSViewRepresentable {

    func makeNSView(context: Context) -> MetalView {
        MetalView()
    }

    func updateNSView(_ uiView: MetalView, context: Context) {
        // No updates needed, Metal view handles its own updates
    }
}

#else
private struct MetalViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> MetalView {
        MetalView()
    }

    func updateUIView(_ uiView: MetalView, context: Context) {
        // No updates needed, Metal view handles its own updates
    }
}
#endif

