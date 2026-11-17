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
uniform highp vec4 uOutputFrame;
uniform float uTime;
uniform float uBurst;
uniform float uIdle;
// Old film: grain, film fps, flicker, sepia, vignette, scratches, dust, weave (px).
uniform vec4 uFilmA;
uniform vec4 uFilmB;

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
    float grain = uFilmA.x;
    float ftick = floor(uTime * max(1.0, uFilmA.y));
    vec2 frame = max(uOutputFrame.zw, vec2(1.0));

    // 0. Gate weave: the whole picture jumps a pixel now and then, like film in a worn gate.
    float weave = uFilmB.w;
    uv += floor((vec2(rand(vec2(ftick, 41.0)), rand(vec2(ftick, 43.0))) - 0.5) * (2.0 * weave + 0.999)) * onePx * step(0.6, rand(vec2(ftick, 47.0)));

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
    col += (bar * (0.1 * uIdle + 0.25 * b) + bar2 * 0.35) * vec3(0.8, 1.0, 0.9);
    col *= 1.0 - (0.12 + 0.1 * b) * uIdle * mod(floor(px), 2.0);

    // 6. A little static.
    col += (rand(vec2(px, py) + uTime) - 0.5) * (0.04 * uIdle + 0.12 * b);

    // 7. Old dirty film. Faded warm colors...
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(col, vec3(lum * 1.08, lum * 0.96, lum * 0.78), uFilmA.w);
    // ...the brightness flickering from one film frame to the next...
    col *= 1.0 + (rand(vec2(ftick, 1.3)) - 0.5) * 2.0 * uFilmA.z;
    // ...two thin vertical scratches that stay put for a while, drift, flicker and break up...
    for (int k = 0; k < 2; k++) {
        float fk = float(k);
        float era = floor(uTime * 0.6 + fk * 0.5);
        float sx = (0.08 + 0.84 * rand(vec2(era, 17.0 + fk))) * frame.x + sin(uTime * (1.3 + fk) + fk * 4.0) * 2.0;
        float on = step(rand(vec2(ftick, 31.0 + fk)), uFilmB.y);
        float broken = step(0.3, rand(vec2(floor(py / (5.0 + fk * 3.0)), ftick + fk * 9.0)));
        float line = on * broken * step(abs(px - sx), 0.5);
        float light = step(0.5, rand(vec2(era, 23.0 + fk)));
        col = mix(col, mix(vec3(0.12, 0.1, 0.08), vec3(0.92, 0.9, 0.82), light), line * 0.55);
    }
    // ...dust and dirt specks, different on every film frame...
    vec2 cell = floor(vec2(px, py) / 22.0);
    if (rand(cell + vec2(ftick * 0.71, ftick * 1.37)) < uFilmB.z) {
        vec2 c = (cell + vec2(rand(cell + ftick + 3.1), rand(cell + ftick + 5.7))) * 22.0;
        float r = 0.6 + 1.2 * rand(cell + ftick + 8.3);
        float stretch = 1.0 + 2.0 * step(0.8, rand(cell + ftick + 9.9));
        vec2 dd = vec2(px, py) - c;
        float speck = step(length(vec2(dd.x, dd.y / stretch)), r);
        float white = step(0.75, rand(cell + ftick + 13.0));
        col = mix(col, mix(vec3(0.08, 0.07, 0.06), vec3(0.95, 0.93, 0.86), white), speck * 0.75);
    }
    // ...grain...
    col += (rand(vec2(px * 1.37, py * 0.91) + ftick * 3.17) - 0.5) * 2.0 * grain;
    // ...and darkened edges.
    vec2 q = vec2(px, py) / frame - 0.5;
    col *= 1.0 - uFilmB.x * smoothstep(0.25, 0.75, dot(q, q) * 2.0);

    finalColor = vec4(clamp(col, 0.0, 1.0), cg.a);
}
`;

/**
 * The title page's background: an old dirty film (grain, flicker, faded warm colors, vertical
 * scratches, dust specks, a vignette, a weaving gate; see `film`) with an occasional glitch,
 * mostly vertical (columns tearing up and down, a vertical RGB split, rolling, tall corrupted
 * blocks, vertical bars and scanlines), with a few horizontal tears. `burst` (0..1) is the
 * strong glitch, `idle` (0..1) the faint one in between.
 */
export class TitleGlitchFilter extends Filter {
  private readonly u: UniformGroup<{
    uTime: { value: number; type: 'f32' };
    uBurst: { value: number; type: 'f32' };
    uIdle: { value: number; type: 'f32' };
    uFilmA: { value: Float32Array; type: 'vec4<f32>' };
    uFilmB: { value: Float32Array; type: 'vec4<f32>' };
  }>;

  constructor() {
    const u = new UniformGroup({
      uTime: { value: 0, type: 'f32' },
      uBurst: { value: 0, type: 'f32' },
      uIdle: { value: 0, type: 'f32' },
      uFilmA: { value: new Float32Array(4), type: 'vec4<f32>' },
      uFilmB: { value: new Float32Array(4), type: 'vec4<f32>' },
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
  /** The old-film look (strengths 0..1, fps and weave in px): see TITLE.FILM. */
  set film(f: { GRAIN: number; FPS: number; FLICKER: number; SEPIA: number; VIGNETTE: number; SCRATCHES: number; DUST: number; WEAVE: number }) {
    this.u.uniforms.uFilmA.set([f.GRAIN, f.FPS, f.FLICKER, f.SEPIA]);
    this.u.uniforms.uFilmB.set([f.VIGNETTE, f.SCRATCHES, f.DUST, f.WEAVE]);
  }
}
