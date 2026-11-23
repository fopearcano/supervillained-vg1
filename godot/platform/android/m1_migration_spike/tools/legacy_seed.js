// Evaluated ONCE in the OLD Capacitor app's page (https://localhost) through DevTools, before a
// reload. Writes representative values the way the old game's storage wrapper does
// (JSON.stringify under the supervillained: prefix, src/core/storage.ts):
//   settings  non-default audio, text speed, lives and every control value (src/core/settings.ts)
//   records   a Green Zone (level1) record {score, stars, time}
//   coins     a standalone coin value
//   story     a VERSION-1 campaign. On the reload the old game's own boot (StoryFlow ->
//             loadCampaign) migrates it: it keeps this v1 save untouched under story-v1-backup and
//             writes the migrated v2 campaign under story, so both campaign keys come from the old
//             runtime's own code path.
(() => {
  const settings = { muted: true, volume: 0.35, textSpeed: 'fast', lives: 5, controls: { swipeUp: 'bark', swipeDown: 'switch', doubleTap: 'action', run: 'toggle', switcher: false, hand: 'left' } };
  const records = { level1: { score: 4321, stars: 3, time: 187.25 } };
  const coins = 42;
  const storyV1 = {
    version: 1,
    completed: ['1.0', '1.1', '1.2', '1.3', '1.5'],
    meters: { commozione: 35, supervillain: 22, grace: 61, standing: 48 },
    flags: { pawOffered: true, longWay: false, santinaBall: true, bucketKicked: true },
    book: {
      marvels: ['THE FOUNTAIN'],
      items: ['THE FRESCO'],
      values: ['Comradeship'],
      remembered: ['AND A DOG DREAMS LECTURES.', 'THERE WAS A GATE, AND IT WAS A CHIHUAHUA.', 'AN OLD DREAM LINE'],
      shards: ['A FLEET BOUGHT ON CREDIT', 'A CITY SEEN FROM ITS WALLS'],
    },
    abilities: ['bark'],
    coins: 17,
    playTime: 1834.5,
    savedAt: 1767225600000,
  };
  const before = ['settings', 'records', 'coins', 'story', 'story-v1-backup'].map((k) => localStorage.getItem('supervillained:' + k));
  if (before.some((v) => v !== null)) throw new Error('seed refused: a supervillained key already exists');
  localStorage.setItem('supervillained:settings', JSON.stringify(settings));
  localStorage.setItem('supervillained:records', JSON.stringify(records));
  localStorage.setItem('supervillained:coins', JSON.stringify(coins));
  localStorage.setItem('supervillained:story', JSON.stringify(storyV1));
  return { written: ['settings', 'records', 'coins', 'story (version 1)'], origin: location.origin };
})()
