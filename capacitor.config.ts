import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.zampano.supervillained',
  appName: 'SUPERVILLAINED: CRUSADER',
  webDir: 'dist',
  backgroundColor: '#000000',
  android: {
    backgroundColor: '#000000',
    // The game handles its own zoom/scroll prevention; no remote content.
    allowMixedContent: false,
  },
};

export default config;
