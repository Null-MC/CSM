#if defined IRIS_FEATURE_SSBO && defined RENDER_FRAG
    layout(std430, binding = 1) buffer shadowDiskData {
        vec2 pcfDiskOffset[32];     // 256
        vec2 pcssDiskOffset[32];    // 256
    };
#endif
