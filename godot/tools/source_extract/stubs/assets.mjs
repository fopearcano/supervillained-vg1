// Stand-in for src/core/assets.ts: a registry that hands out opaque texture tokens.
export const textures = { get: (name) => ({ name }), has: () => true, set() {} };
export function packAtlas() { return []; }
export function subTexture() { return {}; }
export async function tryLoadTexture() { return null; }
