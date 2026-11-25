// Module resolution hooks that let Node 24 execute the audited TypeScript sources unchanged.
// - Relative specifiers without an extension resolve to `.ts`, or to a directory's `index.ts`
//   (Vite-style imports).
// - `pixi.js` and `src/core/assets.ts` are replaced by tiny stubs: the extracted code paths only
//   construct display objects and never render, so no rendering behaviour is substituted.
// - Vite `?url` asset imports (`import x from '../../assets/a.mp3?url'`) evaluate to the asset's
//   repository-relative path, so tables of asset URLs (src/fx/audioFiles.ts) execute as written.
import { existsSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(here, '..', '..', '..');
const PIXI_STUB = pathToFileURL(path.join(here, 'stubs', 'pixi.mjs')).href;
const ASSETS_STUB = pathToFileURL(path.join(here, 'stubs', 'assets.mjs')).href;

export async function resolve(specifier, context, nextResolve) {
  if (specifier === 'pixi.js') return { url: PIXI_STUB, shortCircuit: true };
  if (context.parentURL && (specifier.startsWith('./') || specifier.startsWith('../'))) {
    const parent = fileURLToPath(context.parentURL);
    const target = path.resolve(path.dirname(parent), specifier.split('?')[0]);
    if (specifier.endsWith('?url')) {
      const rel = path.relative(REPO, target).split(path.sep).join('/');
      return { url: `data:text/javascript,export default ${encodeURIComponent(JSON.stringify(rel))};`, shortCircuit: true };
    }
    if (target.endsWith(path.join('src', 'core', 'assets'))) return { url: ASSETS_STUB, shortCircuit: true };
    if (!path.extname(target) && existsSync(target + '.ts')) {
      return { url: pathToFileURL(target + '.ts').href, shortCircuit: true };
    }
    // Vite-style directory imports (`../story/minigames` → its index.ts).
    if (!path.extname(target) && existsSync(path.join(target, 'index.ts'))) {
      return { url: pathToFileURL(path.join(target, 'index.ts')).href, shortCircuit: true };
    }
  }
  return nextResolve(specifier, context);
}
