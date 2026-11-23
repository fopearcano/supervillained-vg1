// Evaluated in the OLD Capacitor app's page (https://localhost) through DevTools: read-only.
// Returns the five approved keys' raw strings (null when absent) and the names of the keys with
// the supervillained: prefix (no other storage is read or reported).
(() => {
  const keys = ['settings', 'records', 'coins', 'story', 'story-v1-backup'];
  const out = { origin: location.origin, href: location.href, keys: {}, prefixed_keys: [] };
  for (const k of keys) out.keys[k] = localStorage.getItem('supervillained:' + k);
  for (let i = 0; i < localStorage.length; i++) {
    const name = localStorage.key(i);
    if (name !== null && name.startsWith('supervillained:')) out.prefixed_keys.push(name);
  }
  out.prefixed_keys.sort();
  return out;
})()
