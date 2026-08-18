#include <metal_stdlib>

using namespace metal;


// ============================================================
// Uniforms
// ============================================================

struct AuroraUniforms {

    float2 resolution;

    float time;

    float padding;

    float4 color0;
    float4 color1;
    float4 color2;
    float4 color3;
    float4 color4;
    float4 color5;
};


// ============================================================
// Vertex
// ============================================================

struct VertexOut {

    float4 position [[position]];

    float2 uv;
};


vertex VertexOut auroraVertex(
    uint vertexID [[vertex_id]]
) {

    float2 positions[3] = {

        float2(-1.0, -1.0),

        float2(3.0, -1.0),

        float2(-1.0, 3.0)
    };


    VertexOut out;

    float2 position =
        positions[vertexID];


    out.position =
        float4(
            position,
            0.0,
            1.0
        );


    out.uv =
        position * 0.5 + 0.5;


    return out;
}


// ============================================================
// Hash
// ============================================================

float hash21(float2 p)
{
    p = fract(
        p * float2(
            123.34,
            456.21
        )
    );

    p += dot(
        p,
        p + 45.32
    );

    return fract(
        p.x * p.y
    );
}


// ============================================================
// Smooth Noise
// ============================================================

float noise2D(float2 p)
{
    float2 i = floor(p);

    float2 f = fract(p);

    f = f * f * (
        3.0 - 2.0 * f
    );


    float a =
        hash21(i);

    float b =
        hash21(
            i + float2(1.0, 0.0)
        );

    float c =
        hash21(
            i + float2(0.0, 1.0)
        );

    float d =
        hash21(
            i + float2(1.0, 1.0)
        );


    return mix(
        mix(a, b, f.x),
        mix(c, d, f.x),
        f.y
    );
}


// ============================================================
// FBM
// ============================================================

float fbm(float2 p)
{
    float value = 0.0;

    float amplitude = 0.5;

    float frequency = 1.0;


    value +=
        noise2D(p * frequency)
        * amplitude;

    frequency *= 2.0;
    amplitude *= 0.5;


    value +=
        noise2D(p * frequency)
        * amplitude;

    frequency *= 2.0;
    amplitude *= 0.5;


    value +=
        noise2D(p * frequency)
        * amplitude;

    frequency *= 2.0;
    amplitude *= 0.5;


    value +=
        noise2D(p * frequency)
        * amplitude;

    frequency *= 2.0;
    amplitude *= 0.5;


    value +=
        noise2D(p * frequency)
        * amplitude;


    return value;
}


// ============================================================
// Flow Field
//
// 这是这版最重要的部分
//
// 不再让粒子自己运动。
// 而是让整个颜色场沿着连续流场变形。
// ============================================================

float2 flowField(
    float2 p,
    float time
) {

    float2 q;

    q.x =
        fbm(
            p * 0.85
            + float2(
                time * 0.075,
                -time * 0.045
            )
        );

    q.y =
        fbm(
            p * 0.85
            + float2(
                -time * 0.055,
                time * 0.065
            )
        );


    float2 r;

    r.x =
        fbm(
            p * 1.15
            + q * 1.65
            + float2(
                -time * 0.035,
                time * 0.055
            )
        );

    r.y =
        fbm(
            p * 1.15
            + q * 1.65
            + float2(
                time * 0.050,
                -time * 0.030
            )
        );


    return
        p
        + (r - 0.5)
        * 1.15;
}


// ============================================================
// Large Soft Mass
//
// 大面积颜色云
// ============================================================

float softMass(
    float2 p,
    float2 center,
    float radius
) {

    float d =
        distance(
            p,
            center
        );


    return
        1.0
        -
        smoothstep(
            radius * 0.20,
            radius,
            d
        );
}


// ============================================================
// Organic Mass
//
// 给色团一个“不规则”的边缘
// ============================================================

float organicMass(
    float2 p,
    float2 center,
    float radius,
    float time,
    float seed
) {

    float2 local =
        p - center;


    float angle =
        atan2(
            local.y,
            local.x
        );


    float distanceFromCenter =
        length(local);


    float distortion =
        fbm(
            float2(
                angle * 1.8
                + seed,

                time * 0.045
                + distanceFromCenter * 1.2
            )
        );


    float dynamicRadius =
        radius
        *
        (
            0.82
            +
            distortion * 0.30
        );


    return
        1.0
        -
        smoothstep(
            dynamicRadius * 0.20,
            dynamicRadius,
            distanceFromCenter
        );
}


// ============================================================
// Fragment
// ============================================================

fragment float4 auroraFragment(

    VertexOut in [[stage_in]],

    constant AuroraUniforms& uniforms
        [[buffer(0)]]
) {

    // --------------------------------------------------------
    // UV
    // --------------------------------------------------------

    float2 uv =
        in.uv;


    // --------------------------------------------------------
    // Aspect Ratio
    // --------------------------------------------------------

    float aspect =
        uniforms.resolution.x
        /
        uniforms.resolution.y;


    float2 p =
        uv - 0.5;


    p.x *= aspect;


    // --------------------------------------------------------
    // Time
    //
    // 比之前更慢、更连续
    // --------------------------------------------------------

    float time =
        uniforms.time * 0.16;


    // --------------------------------------------------------
    // 主流场
    // --------------------------------------------------------

    float2 flow =
        flowField(
            p,
            time
        );


    // ========================================================
    // Colors
    // ========================================================

    float3 c0 =
        uniforms.color0.rgb;

    float3 c1 =
        uniforms.color1.rgb;

    float3 c2 =
        uniforms.color2.rgb;

    float3 c3 =
        uniforms.color3.rgb;

    float3 c4 =
        uniforms.color4.rgb;

    float3 c5 =
        uniforms.color5.rgb;


    // ========================================================
    // 大型色团
    //
    // 注意：
    // 不使用固定的圆形粒子。
    // 每个区域都是巨大的、有机形状。
    // ========================================================


    // 左上

    float2 center0 =
        float2(
            -0.45,
            0.18
        );


    center0.x +=
        sin(
            time * 0.32
        ) * 0.20;

    center0.y +=
        cos(
            time * 0.25
        ) * 0.18;


    // 右侧

    float2 center1 =
        float2(
            0.48,
            -0.05
        );


    center1.x +=
        cos(
            time * 0.26
        ) * 0.18;

    center1.y +=
        sin(
            time * 0.21
        ) * 0.22;


    // 底部

    float2 center2 =
        float2(
            0.10,
            0.48
        );


    center2.x +=
        sin(
            time * 0.20
        ) * 0.24;

    center2.y +=
        cos(
            time * 0.27
        ) * 0.15;


    // 左下

    float2 center3 =
        float2(
            -0.30,
            -0.38
        );


    center3.x +=
        cos(
            time * 0.18
        ) * 0.20;

    center3.y +=
        sin(
            time * 0.23
        ) * 0.18;


    // ========================================================
    // Organic Mass
    // ========================================================

    float mass0 =
        organicMass(
            flow,
            center0,
            1.10,
            time,
            1.3
        );


    float mass1 =
        organicMass(
            flow,
            center1,
            1.05,
            time,
            4.7
        );


    float mass2 =
        organicMass(
            flow,
            center2,
            0.95,
            time,
            7.4
        );


    float mass3 =
        organicMass(
            flow,
            center3,
            0.90,
            time,
            10.2
        );


    // ========================================================
    // 颜色之间的连续融合
    // ========================================================

    float total =
        mass0
        + mass1
        + mass2
        + mass3;


    // ========================================================
    // 基础颜色
    //
    // 保证整个背景永远有专辑色，
    // 不会出现大面积黑洞。
    // ========================================================

    float3 baseColor =
        (
            c0
            + c1
            + c2
            + c3
        ) * 0.25;


    // ========================================================
    // 色团颜色
    // ========================================================

    float3 blobColor =
        (
            c0 * mass0
            +
            c1 * mass1
            +
            c2 * mass2
            +
            c3 * mass3
        )
        /
        max(total, 0.001);


    // ========================================================
    // 混合
    //
    // 即使没有色团，
    // 也至少保留 65% 的基础专辑色。
    // ========================================================

    float blobPresence =
        smoothstep(
            0.0,
            1.8,
            total
        );


    float3 color =
        mix(
            baseColor,
            blobColor,
            blobPresence * 0.72
        );


    // ========================================================
    // 第二层流体噪声
    //
    // 不是粒子。
    // 是颜色内部的“流动纹理”。
    // ========================================================

    float fineFlow =
        fbm(
            flow * 2.4
            + time * 0.035
        );


    float mediumFlow =
        fbm(
            flow * 1.25
            - time * 0.025
        );


    // ========================================================
    // 用噪声在颜色之间缓慢切换
    // ========================================================

    float colorMix =
        smoothstep(
            0.34,
            0.72,
            fineFlow
        );


    color =
        mix(
            color,
            c4,
            colorMix * 0.24
        );


    color =
        mix(
            color,
            c5,
            smoothstep(
                0.15,
                0.50,
                mediumFlow
            ) * 0.20
        );


    // ========================================================
    // 柔和的内部亮度变化
    // ========================================================

    float lightVariation =
        smoothstep(
            0.25,
            0.78,
            mediumFlow
        );


    color *=
        0.88
        +
        lightVariation * 0.20;


    // ========================================================
    // 极细微的流体颗粒
    //
    // 注意：
    // 不是一颗颗粒子。
    // 是非常细的连续噪声。
    // ========================================================

    float microNoise =
        noise2D(
            flow * 8.0
            + time * 0.02
        );


    color +=
        (
            microNoise
            - 0.5
        )
        * 0.018;


    // ========================================================
    // 色彩增强
    // ========================================================

    float luminance =
        dot(
            color,
            float3(
                0.2126,
                0.7152,
                0.0722
            )
        );


    color =
        mix(
            float3(luminance),
            color,
            1.15
        );


    // ========================================================
    // 保持专辑色彩饱和度
    // 不再大面积压黑
    // ========================================================

    color *= 0.92;


    // ========================================================
    // 非常轻微的深色混合
    //
    // 只负责让文字有一点可读性，
    // 绝对不能让背景变成黑色。
    // ========================================================

    color =
        mix(
            color,
            color * 0.82,
            0.08
        );


    // ========================================================
    // Vignette
    // ========================================================

    float distanceFromCenter =
        length(
            uv - 0.5
        );


    float vignette =
        smoothstep(
            0.28,
            0.88,
            distanceFromCenter
        );


    color *=
        mix(
            1.0,
            0.52,
            vignette
        );


    // ========================================================
    // 最终输出
    // ========================================================

    return float4(
        color,
        1.0
    );
}
