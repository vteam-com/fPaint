#version 460 core
#include <flutter/runtime_effect.glsl>

// One smudge dab of the pixel brush, applied entirely on the GPU.
//
// The whole canvas is redrawn each dab (sampling the previous frame's result as
// uTexture); pixels outside the brush radius are copied through unchanged, so
// there is never a CPU readback. Smudge drags the source along the stroke
// direction, blending toward the result with a radial feather. (Blur is handled
// separately on the Dart side via ui.ImageFilter.blur, which composites
// premultiplied alpha correctly; see GpuPixelBrushStroke.dab.)

uniform vec2 uResolution;   // float slots 0,1
uniform vec2 uFromCenter;   // slots 2,3  - previous dab centre (px)
uniform vec2 uToCenter;     // slots 4,5  - current dab centre (px)
uniform float uRadius;      // slot 6     - brush radius (px)
uniform float uStrength;    // slot 7     - blend strength (0..1)
uniform sampler2D uTexture; // sampler 0  - current working image

out vec4 fragColor;

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec4 current = texture(uTexture, fragCoord / uResolution);

  float dist = length(fragCoord - uToCenter);
  if (dist > uRadius) {
    fragColor = current;
    return;
  }

  // Soft, wide tip (feather²): strength tapers smoothly from centre to rim so
  // closely-spaced dabs overlap into a seamless trail. A flat-topped profile
  // pulls too uniformly and leaves a washboard ridge at each dab's trailing
  // edge; the smoothness instead comes from fine dab spacing (see the GPU dab
  // loop), which GPU dabs can afford because each is a cheap texture blit.
  float feather = clamp(1.0 - dist / uRadius, 0.0, 1.0);
  float blend = clamp(uStrength * feather * feather, 0.0, 1.0);

  // Smudge: sample the source displaced opposite to the stroke direction.
  vec2 disp = uToCenter - uFromCenter;
  vec4 src = texture(uTexture, (fragCoord - disp) / uResolution);
  fragColor = mix(current, src, blend);
}
