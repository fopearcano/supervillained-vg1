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
    float px = uv.x * uInputSize.x;
    float py = uv.y * uInputSize.y;
    float tick = floor(uTime * 15.0);
    float b = uBurst;

    // 1. Vertical tearing: columns of varying width slide up and down (the main effect).
    float colW = 2.0 + floor(rand(vec2(tick, 3.7)) * 9.0);
    float column = floor(px / colW);
    float vshift = 0.0;
    if (rand(vec2(column, tick)) < b * 0.6 + uIdle * 0.03) {
        vshift = (rand(vec2(column * 1.93, tick + 5.0)) - 0.5) * (14.0 + 70.0 * b);
    }
    // The whole picture rolls a little during a burst, like a losing vertical hold.
    vshift += floor(sin(uTime * 37.0) * 3.0 * b);
    uv.y += floor(vshift) * onePx.y;

    // 2. A few horizontal tears (fewer and shorter than the vertical ones).
    float row = floor(py / 3.0);
    if (rand(vec2(row, tick + 11.0)) < b * 0.1) {
        uv.x += floor((rand(vec2(row * 1.3, tick + 2.0)) - 0.5) * 18.0 * b) * onePx.x;
    }

    // 3. Vertical RGB split (red up, blue down), wider in a burst.
    float split = floor(1.0 + uIdle + b * 4.0);
    vec4 cg = sampleAt(uv);
    float cr = sampleAt(uv - vec2(0.0, split * onePx.y)).r;
    float cb = sampleAt(uv + vec2(onePx.x * floor(b * 2.0), split * onePx.y)).b;
    vec3 col = vec3(cr, cg.g, cb);

    // 4. Corrupted blocks: tall rectangles posterized, channel-swapped or sampled from elsewhere.
    vec2 blk = floor(vec2(px / 10.0, py / 26.0));
    float rb = rand(blk + vec2(tick * 0.37, tick));
    if (rb < b * 0.09) {
        vec3 far = sampleAt(uv + vec2(0.0, (rand(blk + 9.0) - 0.5) * 0.3)).rgb;
        col = floor(far.bgr * 4.0) / 4.0;
    }

    // 5. Bright vertical bars sweeping across, and vertical scanlines.
    float sweep = mod(uTime * 70.0, uInputSize.x + 60.0) - 30.0;
    float bar = max(0.0, 1.0 - abs(px - sweep) / 3.0);
    float bar2 = (rand(vec2(floor(px / 2.0), tick + 21.0)) < b * 0.05) ? 1.0 : 0.0;
    col += (bar * (0.08 + 0.25 * b) + bar2 * 0.35) * vec3(0.8, 1.0, 0.9);
    col *= 1.0 - (0.12 + 0.1 * b) * uIdle * mod(floor(px), 2.0);

    // 6. A little static.
    col += (rand(vec2(px, py) + uTime) - 0.5) * (0.04 * uIdle + 0.12 * b);

    finalColor = vec4(clamp(col, 0.0, 1.0), cg.a);
}
`;

/**
 * The title page's background glitch: mostly vertical (columns tearing up and down, a vertical
 * RGB split, rolling, tall corrupted blocks, vertical bars and scanlines), with a few horizontal
 * tears. `burst` (0..1) is the strong effect, `idle` (0..1) the faint one in between.
 */
export class TitleGlitchFilter extends Filter {
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
      glProgram: GlProgram.from({ vertex, fragment, name: 'sv-title-glitch' }),
      resources: { titleGlitchUniforms: u },
      resolution: 1,
      antialias: 'off',
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
