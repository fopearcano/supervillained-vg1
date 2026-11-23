// Evaluated in the OLD Capacitor app's page: reloads it, so the old game boots again on the seeded
// storage (its own v1 -> v2 campaign migration runs here).
(() => { setTimeout(() => location.reload(), 100); return 'reloading'; })()
