import { Filter, GlProgram, UniformGroup } from 'pixi.js';

const vertex = `in vec2 aPosition;
out vec2 vTextureCoord;

uniform vec4 uInputSize;
uniform vec4 uOutputFrame;
uniform vec4 uOutputTexture;

vec4 filterVertexPosition(void)
{
    vec2 position = aPosition * uOutputFrame.zw + uOutputFrame.xy;
    position.x = position.x * (2.0 / uOutputTexture.x) - 1.0;
    position.y = position.y * (2.0 * uOutputTexture.z / uOutputTexture.y) - uOutputTexture.z;
    return vec4(position, 0.0, 1.0);
}

vec2 filterTextureCoord(void)
{
    return aPosition * (uOutputFrame.zw * uInputSize.zw);
}

void main(void)
{
    gl_Position = filterVertexPosition();
    vTextureCoord = filterTextureCoord();
}
`;

const fragment = `in vec2 vTextureCoord;
out vec4 finalColor;

uniform sampler2D uTexture;
uniform highp vec4 uInputSize;
uniform highp vec4 uInputClamp;
uniform float uTime;
uniform float uBurst;
uniform float uIdle;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 sampleAt(vec2 uv) {
    return texture(uTexture, clamp(uv, uInputClamp.xy, uInputClamp.zw));
}

void main(void)
{
    vec2 uv = vTextureCoord;
    vec2 onePx = uInputSize.zw;
    float py = uv.y * uInputSize.y;
    float tick = floor(uTime * 20.0);
    float b = uBurst;

    // Horizontal slices of the letters jump sideways during a burst.
    float band = floor(py / (2.0 + floor(rand(vec2(tick, 5.1)) * 5.0)));
    float r = rand(vec2(band, tick));
    if (r < b * 0.55) uv.x += floor((rand(vec2(band * 1.7, tick + 3.0)) - 0.5) * 24.0 * b) * onePx.x;
    // A faint shiver between bursts.
    if (r > 1.0 - uIdle * 0.04) uv.x += (rand(vec2(band, tick + 9.0)) > 0.5 ? 1.0 : -1.0) * onePx.x;

    // RGB split: red one way, blue the other (wider in a burst).
    float split = floor(uIdle + b * 3.0 + 0.5);
    vec4 c = sampleAt(uv);
    vec4 cr = sampleAt(uv - vec2(split * onePx.x, 0.0));
    vec4 cb = sampleAt(uv + vec2(split * onePx.x, 0.0));
    float a = max(c.a, max(cr.a, cb.a));
    vec3 col = vec3(cr.r, c.g, cb.b);

    // A burst also flickers some rows of the letters bright (premultiplied: white is vec3(a), so
    // the transparent space around the letters stays untouched).
    if (rand(vec2(floor(py / 2.0), tick + 17.0)) < b * 0.12) col = mix(col, vec3(a), 0.6);

    finalColor = vec4(min(col, vec3(a)), a);
}
`;

/**
 * Glitch for the title's lettering (SUPERVILLAINED CRUSADER): in a burst, horizontal slices
 * jump sideways, the colors split and rows flicker; in between, a faint shiver. `burst` and `idle`
 * are 0..1. The filter needs `padding` so the displaced slices are not clipped.
 */
export class TextGlitchFilter extends Filter {
  private readonly u: UniformGroup<{
    uTime: { value: number; type: 'f32' };
    uBurst: { value: number; type: 'f32' };
    uIdle: { value: number; type: 'f32' };
  }>;

  constructor() {
    const u = new UniformGroup({
      uTime: { value: 0, type: 'f32' },
      uBurst: { value: 0, type: 'f32' },
      uIdle: { value: 0, type: 'f32' },
    });
    super({
      glProgram: GlProgram.from({ vertex, fragment, name: 'sv-text-glitch' }),
      resources: { textGlitchUniforms: u },
      resolution: 1,
      antialias: 'off',
      padding: 14,
    });
    this.u = u;
  }

  set time(v: number) {
    this.u.uniforms.uTime = v;
  }
  set burst(v: number) {
    this.u.uniforms.uBurst = v;
  }
  set idle(v: number) {
    this.u.uniforms.uIdle = v;
  }
}
