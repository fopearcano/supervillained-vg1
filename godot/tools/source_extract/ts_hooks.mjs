// Module resolution hooks that let Node 24 execute the audited TypeScript sources unchanged.
// - Relative specifiers without an extension resolve to `.ts` (Vite-style imports).
// - `pixi.js` and `src/core/assets.ts` are replaced by tiny stubs: the extracted code paths only
//   construct display objects and never render, so no rendering behaviour is substituted.
import { existsSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const PIXI_STUB = pathToFileURL(path.join(here, 'stubs', 'pixi.mjs')).href;
const ASSETS_STUB = pathToFileURL(path.join(here, 'stubs', 'assets.mjs')).href;

export async function resolve(specifier, context, nextResolve) {
  if (specifier === 'pixi.js') return { url: PIXI_STUB, shortCircuit: true };
  if (context.parentURL && (specifier.startsWith('./') || specifier.startsWith('../'))) {
    const parent = fileURLToPath(context.parentURL);
    const target = path.resolve(path.dirname(parent), specifier.split('?')[0]);
    if (target.endsWith(path.join('src', 'core', 'assets'))) return { url: ASSETS_STUB, shortCircuit: true };
    if (!path.extname(target) && existsSync(target + '.ts')) {
      return { url: pathToFileURL(target + '.ts').href, shortCircuit: true };
    }
  }
  return nextResolve(specifier, context);
}
