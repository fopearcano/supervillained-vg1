import { carry, dropCarried } from '../../story/carry';
import { BoatGame, mini, parade, rowing } from '../../story/minigames';
import { call, card, fx, say, stage } from '../../story/steps';
import { walk } from '../../story/walk';
import { C } from '../../ui/retro';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';
import { placeObject } from './helpers';

/**
 * Level 4 — The sea, autumn 1202: a departure with conditions. The fleet leaves Venice singing
 * (Clari 13) and crosses the Adriatic to Zara. On deck Zampanò does small practical jobs and
 * collects rumours about the destination until the marshal names the one that counts. The
 * shipboard tasks are invented connective scenes (docs/STORY.md marks them as adaptation).
 */
export const CH4: ChapterDef = {
  number: 4,
  title: CHAPTER_TITLES[3],
  intro: 'THE FLEET LEAVES VENICE IN THE AUTUMN OF 1202. EVERY SHIP IS SINGING, EVERY HORSE IS SEASICK, AND EVERY MAN ON DECK HAS HEARD A DIFFERENT NAME FOR WHERE THEY ARE GOING.',
  cast: 'WATSON AS A VENETIAN SAILOR; BAGNASKIZ AS THE MARSHAL; JACK, SPREADING RUMOURS',
  theme: 'sea',
  music: 'level4',
  professor: {
    text: 'NOT ALL THE MEN OF THE HOST KNEW OF THE PLAN, CLARI SAYS: ONLY THE MEN OF HIGHEST ESTATE. HE WRITES IT DOWN QUITE CALMLY, YOU UNDERSTAND, AS IF IT WERE THE WEATHER.',
  },
  subLevels: [
    {
      id: '4.1',
      title: 'Veni Creator',
      happens:
        'THE PRIESTS CLIMB INTO THE CASTLES OF THE SHIPS AND SING VENI CREATOR SPIRITUS; THE TRUMPETS ANSWER. WALK THE LENGTH OF THE DECK AND RAISE SHIELDS AND BANNERS ON THE BEAT. GET ONE OUT OF TIME AND THE SAILOR BESIDE ZAMPANO QUIETLY SETS HIM RIGHT. THE SAIL FILLS AND CRACKS LIKE A RAG IN THE WIND.',
      source:
        "CLARI 13 (DEREMILITARI): THE PRIESTS AND CLERKS GO UP INTO THE CASTLES OF THE SHIPS AND CHANT THE 'VENI CREATOR SPIRITUS'; SILVER TRUMPETS; BANNERS ON THE CASTLES. VILLEHARDOUIN P. 19: THE FLEET SAILS IN OCTOBER 1202. THE SAILOR AND THE RHYTHM ARE ADAPTATION.",
      script: () => [
        stage('ship', [{ name: 'watson', who: 'watson', at: '7', face: 'N' }], { at: '4' }),
        card('A FAMILIAR FACE', 'WATSON IS A VENETIAN SAILOR HERE. HE STILL SAYS "MAN".', { color: C.cyan, seconds: 2.2 }),
        call((ctx) => ctx.actor('watson').setBehavior({ kind: 'follow', target: ctx.player, distance: 1.2, speed: 2.6, side: 0.8 })),
        walk({ objective: 'WALK THE LENGTH OF THE DECK', goal: { reach: '3', label: 'THE BOW' } }),
        say('watson', 'WHEN THEY SING, MAN, YOU RAISE THE SHIELD. ON THE BEAT. I WILL BE RIGHT HERE.'),
        mini(parade, { won: { commozione: 8, marvel: 'THE FLEET LEAVING VENICE' }, lost: { commozione: 2, marvel: 'THE FLEET LEAVING VENICE' } }),
        card('THE SAIL FILLS', 'AND CRACKS LIKE A RAG IN THE WIND', { color: C.cyan, seconds: 2.2 }),
        say('zampano', 'WHERE ARE WE GOING?'),
        say('watson', 'WHERE THE DOGE STEERS, MAN.'),
        say('zampano', 'THERE WAS A SHIP, AND IT WAS SINGING.', { remembered: true }),
      ],
    },
    {
      id: '4.2',
      title: 'Horses below deck',
      happens:
        'THE HORSES ARE IN THE TRANSPORTS, SEASICK AND THIRSTY. ROW A SKIFF OF HAY AND WATER ALONGSIDE WITHOUT SWAMPING IT, THEN FEED THE HORSES BELOW DECK. NOBODY THANKS HIM. WATSON DRAGS THE WATER BUCKET JUST OUT OF REACH, EXACTLY LIKE THE BOWL AT HOME.',
      source:
        'ADAPTATION: AN INVENTED CONNECTIVE SCENE. CLARI 10 AND 13 NAME THE TRANSPORTS THAT CARRY THE HORSES (EACH GREAT MAN HAS HIS OWN); NOTHING HERE IS CLAIMED AS SOMETHING CLARI RECORDS HIMSELF DOING.',
      script: () => [
        stage('ship', [{ name: 'watson', who: 'watson', at: '5', face: 'W' }], { at: '1' }),
        say('watson', 'THE HORSES ARE THIRSTY, MAN. THE SKIFF IS ALREADY LOADED. GENTLY.'),
        mini(() => new BoatGame({ objective: 'EASE THE SKIFF ALONGSIDE THE TRANSPORT WITHOUT SWAMPING IT', bob: 'watson' }), { won: { commozione: 4 } }),
        carry('HAY AND WATER'),
        walk({
          objective: 'FEED THE HORSES BELOW DECK',
          pickups: [
            { at: '8', kind: 'spot', label: 'A GREY HORSE', text: 'HE EATS FROM THE HAND, THEN BITES IT A LITTLE' },
            { at: '2', kind: 'spot', label: 'A BAY HORSE', text: 'TOO SICK TO EAT. HE DRINKS' },
            { at: '7', kind: 'spot', label: "PIERRE'S HORSE", text: 'TALLER THAN EVERYONE. HE LOOKS DOWN AT THE DOG' },
          ],
        }),
        dropCarried(),
        call((ctx) => {
          const b = placeObject(ctx, 'bowl', { x: ctx.player.gx + 0.8, y: ctx.player.gy + 0.4 });
          ctx.insert([
            say('zampano', '(NOW HE IS THIRSTY TOO.)'),
            call((c) => {
              b.setPosition(b.gx + 1.6, b.gy + 0.8);
              c.game.audio.play('hit');
              c.say('CLONG.', { x: b.gx, y: b.gy }, '#c8d0ff');
            }),
            say('watson', '(HE DRAGS THE BUCKET JUST OUT OF REACH.) OOPS, MAN.'),
          ]);
        }),
        say('zampano', 'THERE WAS A BUCKET, AND IT WAS ALWAYS ONE STEP AWAY.', { remembered: true }),
      ],
    },
    {
      id: '4.3',
      title: 'Rumours on deck',
      happens:
        'ON A CROWDED DECK EVERY MAN HAS HEARD A DIFFERENT DESTINATION: EGYPT, ALEXANDRIA, JERUSALEM BY TUESDAY. ASK THEM ALL. THE MARSHAL, AT THE BOW, NAMES THE ONLY ONE THAT COUNTS: ZARA, A CITY THE VENETIANS WANT BACK. ROW THE FLEET INTO THE HARBOR ON THE EVE OF SAINT MARTIN.',
      source:
        "VILLEHARDOUIN P. 8 (THE LEADERS' REAL OBJECTIVE: BABYLON, THAT IS EGYPT) AND PP. 16, 19-20 (ZARA, HELD BY THE KING OF HUNGARY; ARRIVAL ON THE EVE OF SAINT MARTIN, 10 NOVEMBER 1202). CLARI 13-14: WINTER; ZARA; ARRIVAL ON THE NIGHT OF SAINT MARTIN. THE RUMOURS AND THE ROWING ARE ADAPTATION.",
      script: () => [
        stage('ship', [
          { name: 'm1', who: 'crowdA', at: '8', face: 'S' },
          { name: 'm2', who: 'crowdB', at: '1', face: 'E' },
          { name: 'jack', who: 'jack', at: '2', face: 'W' },
          { name: 'm4', who: 'knight', at: '7', face: 'N' },
          { name: 'marshal', who: 'bagnaskizMarshal', at: '3', face: 'S' },
        ], { at: 'S' }),
        say('voice', 'A CROWDED DECK. EVERYONE KNOWS WHERE THEY ARE GOING. NOBODY AGREES.'),
        walk({
          objective: 'ASK THEM WHERE THE FLEET IS GOING',
          pickups: [
            { at: { x: 8.5, y: 6.9 }, kind: 'spot', label: 'A SERGEANT', text: '"BABYLON. THAT IS EGYPT, MY COUSIN SAYS."' },
            { at: { x: 8.5, y: 9.9 }, kind: 'spot', label: 'A PILGRIM', text: '"ALEXANDRIA. THE RICHEST PORT IN THE WORLD."' },
            { at: { x: 11.5, y: 9.9 }, kind: 'spot', label: 'JACK', text: '"JERUSALEM! BY TUESDAY! I HEARD IT FROM A COOK!"' },
            { at: { x: 11.5, y: 11.9 }, kind: 'spot', label: 'A KNIGHT', text: '"NOWHERE, UNTIL THE DEBT IS PAID."' },
          ],
        }),
        walk({ objective: 'ASK THE MARSHAL AT THE BOW', goal: { reach: '3', radius: 1.1, label: 'THE MARSHAL' } }),
        say('marshal', 'ZARA. A CITY ON THIS COAST THAT THE KING OF HUNGARY TOOK FROM VENICE. WE TAKE IT BACK FOR THE DOGE, AND HE WAITS FOR HIS MONEY.'),
        say('zampano', 'AND JERUSALEM?'),
        say('marshal', 'IF THE HOST BREAKS UP, NOBODY GOES ANYWHERE. KEEP THE HOST TOGETHER. THAT IS THE WHOLE ART.'),
        fx({ flags: { heardZara: true } }),
        mini(rowing, { won: { commozione: 4 }, lost: { commozione: 1 } }),
        card('ZARA', 'THE EVE OF SAINT MARTIN, 1202', { color: C.orange, seconds: 2.2 }),
        say('zampano', 'THERE WERE FOUR DESTINATIONS, AND WE WENT TO A FIFTH.', { remembered: true }),
      ],
    },
  ],
};
