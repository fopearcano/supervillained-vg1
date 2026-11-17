import { Capacitor, registerPlugin } from '@capacitor/core';

/** The app's own native plugin (android/.../QuitPlugin.java). */
interface AppQuitPlugin {
  quit(): Promise<void>;
}

const AppQuit = registerPlugin<AppQuitPlugin>('AppQuit');

/** Closes the app when running natively (Android). Returns false in a browser, which cannot close its tab. */
export function quitApp(): boolean {
  if (!Capacitor.isNativePlatform()) return false;
  void AppQuit.quit().catch(() => {});
  return true;
}
