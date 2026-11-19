import { Capacitor, registerPlugin } from '@capacitor/core';

/** The app's own native plugin (android/.../QuitPlugin.java, ios/App/App/AppQuitPlugin.swift). */
interface AppQuitPlugin {
  quit(): Promise<void>;
  openUrl(options: { url: string }): Promise<void>;
}

const AppQuit = registerPlugin<AppQuitPlugin>('AppQuit');

/**
 * Closes the app on Android. Returns false in a browser, which cannot close its tab, and on iOS,
 * where apps do not close themselves: the caller shows its goodbye card instead.
 */
export function quitApp(): boolean {
  if (Capacitor.getPlatform() !== 'android') return false;
  void AppQuit.quit().catch(() => {});
  return true;
}

/** Opens a web link: in the phone's browser on Android and iOS, in a new tab in a browser. */
export function openUrl(url: string): void {
  if (Capacitor.isNativePlatform()) {
    void AppQuit.openUrl({ url }).catch(() => {
      window.location.href = url;
    });
    return;
  }
  window.open(url, '_blank', 'noopener,noreferrer');
}
