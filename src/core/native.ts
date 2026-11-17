import { Capacitor, registerPlugin } from '@capacitor/core';

/** The app's own native plugin (android/.../QuitPlugin.java). */
interface AppQuitPlugin {
  quit(): Promise<void>;
  openUrl(options: { url: string }): Promise<void>;
}

const AppQuit = registerPlugin<AppQuitPlugin>('AppQuit');

/** Closes the app when running natively (Android). Returns false in a browser, which cannot close its tab. */
export function quitApp(): boolean {
  if (!Capacitor.isNativePlatform()) return false;
  void AppQuit.quit().catch(() => {});
  return true;
}

/** Opens a web link: in the phone's browser on Android, in a new tab in a browser. */
export function openUrl(url: string): void {
  if (Capacitor.isNativePlatform()) {
    void AppQuit.openUrl({ url }).catch(() => {
      window.location.href = url;
    });
    return;
  }
  window.open(url, '_blank', 'noopener,noreferrer');
}
