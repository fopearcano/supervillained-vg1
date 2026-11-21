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
uniform float uGlitch;
uniform float uRgb;
uniform float uSepia;
uniform float uScanlines;
uniform float uFlash;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main(void)
{
    vec2 uv = vTextureCoord;
    vec2 onePx = uInputSize.zw;
    float py = uv.y * uInputSize.y;

    // Horizontal slice displacement (blocky, changes ~12 times per second).
    float tick = floor(uTime * 12.0);
    float band = floor(py / 5.0);
    float r = rand(vec2(band, tick));
    float shift = 0.0;
    if (r < uGlitch * 0.4) {
        shift = floor((rand(vec2(band * 1.7, tick + 3.1)) - 0.5) * 30.0 * uGlitch);
    }
    uv.x += shift * onePx.x;

    // RGB split.
    float split = floor(uRgb + 0.5) * onePx.x;
    vec4 cg = texture(uTexture, clamp(uv, uInputClamp.xy, uInputClamp.zw));
    float cr = texture(uTexture, clamp(uv + vec2(split, 0.0), uInputClamp.xy, uInputClamp.zw)).r;
    float cb = texture(uTexture, clamp(uv - vec2(split, 0.0), uInputClamp.xy, uInputClamp.zw)).b;
    vec3 col = vec3(cr, cg.g, cb);

    // Palette shift toward brown / sepia (the "under attack" look).
    vec3 sep = vec3(
        dot(col, vec3(0.393, 0.769, 0.189)),
        dot(col, vec3(0.349, 0.686, 0.168)),
        dot(col, vec3(0.272, 0.534, 0.131))
    ) * vec3(1.08, 0.82, 0.55);
    col = mix(col, sep, uSepia);

    // Scanlines (every other logical row).
    col *= 1.0 - uScanlines * 0.28 * mod(floor(py), 2.0);

    // White flash.
    col = mix(col, vec3(cg.a), uFlash);

    finalColor = vec4(col, cg.a);
}
`;

/**
 * Retro glitch / CRT post effect: horizontal slices, RGB split, scanlines, sepia palette shift
 * and a white flash. Only attached while needed (transitions, "under attack").
 */
export class GlitchFilter extends Filter {
  private readonly u: UniformGroup<{
    uTime: { value: number; type: 'f32' };
    uGlitch: { value: number; type: 'f32' };
    uRgb: { value: number; type: 'f32' };
    uSepia: { value: number; type: 'f32' };
    uScanlines: { value: number; type: 'f32' };
    uFlash: { value: number; type: 'f32' };
  }>;

  constructor() {
    const u = new UniformGroup({
      uTime: { value: 0, type: 'f32' },
      uGlitch: { value: 0, type: 'f32' },
      uRgb: { value: 0, type: 'f32' },
      uSepia: { value: 0, type: 'f32' },
      uScanlines: { value: 0, type: 'f32' },
      uFlash: { value: 0, type: 'f32' },
    });
    super({
      glProgram: GlProgram.from({ vertex, fragment, name: 'sv-glitch' }),
      resources: { glitchUniforms: u },
      resolution: 1,
      antialias: 'off',
    });
    this.u = u;
  }

  set time(v: number) {
    this.u.uniforms.uTime = v;
  }
  set glitch(v: number) {
    this.u.uniforms.uGlitch = v;
  }
  set rgb(v: number) {
    this.u.uniforms.uRgb = v;
  }
  set sepia(v: number) {
    this.u.uniforms.uSepia = v;
  }
  set scanlines(v: number) {
    this.u.uniforms.uScanlines = v;
  }
  set flash(v: number) {
    this.u.uniforms.uFlash = v;
  }

  /** True if any effect is non-zero (otherwise the filter can be detached). */
  get active(): boolean {
    const u = this.u.uniforms;
    return u.uGlitch > 0.001 || u.uRgb > 0.5 || u.uSepia > 0.001 || u.uScanlines > 0.001 || u.uFlash > 0.001;
  }
}
