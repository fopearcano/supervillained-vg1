/**
 * localStorage wrapper. Every access is guarded: storage can be unavailable (private mode,
 * WebView settings, quota) and the game must keep working.
 */
const PREFIX = 'supervillained:';

export const storage = {
  get<T>(key: string, fallback: T): T {
    try {
      const raw = globalThis.localStorage?.getItem(PREFIX + key);
      if (raw == null) return fallback;
      return JSON.parse(raw) as T;
    } catch {
      return fallback;
    }
  },

  set(key: string, value: unknown): void {
    try {
      globalThis.localStorage?.setItem(PREFIX + key, JSON.stringify(value));
    } catch {
      /* ignore */
    }
  },

  remove(key: string): void {
    try {
      globalThis.localStorage?.removeItem(PREFIX + key);
    } catch {
      /* ignore */
    }
  },
};
