import { mini, weeping } from '../../story/minigames';
import { call, card, fx, say, stage } from '../../story/steps';
import { walk, type Pickup } from '../../story/walk';
import { C } from '../../ui/retro';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';
import { patrol } from './helpers';

const tents = (markers: string[], round: number): Pickup[] =>
  markers.map((m, k) => ({ at: m, kind: 'coin', label: `+${(round === 1 ? 7 : 4) + (k % 3)},000 MARKS` }));

/** Level 3 — Venice. Cast: Bagnaskiz as the marshal Villehardouin; an old, blind, very shrewd Doge. */
export const CH3: ChapterDef = {
  number: 3,
  title: CHAPTER_TITLES[2],
  intro: 'VENICE IS WHERE THE PILGRIM LEARNS THAT A CRUSADE IS A CONTRACT.',
  cast: 'BAGNASKIZ AS THE MARSHAL VILLEHARDOUIN; AN OLD, BLIND, VERY SHREWD DOG AS THE DOGE',
  theme: 'venice',
  music: 'medieval',
  professor: {
    after: '4C',
    text: 'EIGHTY-FIVE THOUSAND MARKS. MORE THAN TWENTY TONNES OF SILVER. AND THEY ARE A LITTLE SHORT. BUT THIS IS A CONTRACT, BOYS: YOU SIGNED IT.',
  },
  subLevels: [
    {
      id: '3.1',
      title: 'The marvel of the lagoon',
      happens: 'THE POOR KNIGHT HAS NEVER SEEN VENICE. DROMONS, HORSE TRANSPORTS AND GALLEYS FILL THE WATER.',
      source: "CLARI'S ARRIVAL AND HIS CATALOGUE OF SHIPS (4C).",
      script: () => [
        stage('venice'),
        say('voice', 'NEWS: JACK THE GENERAL IS COMING WITH AN ARMY FROM THE EAST.'),
        say('zampano', 'WHERE ARE THE TURKS?'),
        say('voice', 'NOT HERE. LOOK AT THE SHIPS.'),
        walk({
          objective: 'FIND AND NAME THE MARVELS (FILLS THE MERAVIGLIA BOOK)',
          action: 'LOOK',
          pickups: [
            { at: '1', kind: 'marvel', label: 'THE DROMONS', text: 'GREAT ROUND SHIPS, TALLER THAN HOUSES', effects: { marvel: 'THE DROMONS', commozione: 3 } },
            { at: '2', kind: 'marvel', label: 'THE HORSE TRANSPORTS', text: 'SHIPS WITH DOORS IN THE SIDE, FOR HORSES', effects: { marvel: 'THE HORSE TRANSPORTS', commozione: 3 } },
            { at: '3', kind: 'marvel', label: 'THE GALLEYS', text: 'FIFTY OF THEM, ALL OARS AND BANNERS', effects: { marvel: 'THE GALLEYS', commozione: 3 } },
            { at: '4', kind: 'marvel', label: 'THE COLUMNS OF SAN MARCO', text: 'THE LION ON ONE, THE SAINT ON THE OTHER', effects: { marvel: 'THE COLUMNS OF SAN MARCO', commozione: 3 } },
            { at: '5', kind: 'marvel', label: 'THE FOUNTAIN', text: 'WATER THAT IS NOT SEA, IN THE MIDDLE OF THE SEA', effects: { marvel: 'THE FOUNTAIN OF VENICE', commozione: 3 } },
          ],
          onAction: (ctx) => ctx.say('OOOH.', { x: ctx.player.gx, y: ctx.player.gy }, C.yellow),
        }),
        say('zampano', 'THERE WERE SHIPS, AND THEY WERE TALLER THAN THE CHURCH.', { remembered: true }),
      ],
    },
    {
      id: '3.2',
      title: 'The price of the ticket',
      happens: 'FOUR MARKS A HORSE, TWO A MAN, 85,000 IN ALL, FOR 4,500 KNIGHTS. ABOUT 1,000 TURN UP. THE MARSHAL BLAMES THOSE WHO SAILED FROM OTHER PORTS.',
      source: "THE CONTRACT, THE SHORTFALL AND THE TWO COLLECTIONS; VILLEHARDOUIN'S \"TRAITORS\" (4C).",
      script: () => [
        call((ctx) => {
          ctx.setStage('lido');
          ctx.addActor('marshal', 'bagnaskizMarshal', '9', { kind: 'idle', face: 'player' });
        }),
        say('marshal', 'FOUR MARKS A HORSE, TWO A MAN. EIGHTY-FIVE THOUSAND. PASS THE HAT THROUGH THE TENTS.'),
        walk({ objective: 'PASS THE HAT THROUGH THE TENTS (1/2)', pickups: tents(['1', '2', '3', '4', '5', '6'], 1) }),
        card('50,000 SHORT', 'IT IS NEVER ENOUGH', { color: C.red, seconds: 2.4 }),
        say('marshal', 'AGAIN. EVERY TENT. EVERY PURSE.'),
        walk({ objective: 'PASS THE HAT THROUGH THE TENTS (2/2)', pickups: tents(['3', '4', '5', '6', '7', '8'], 2) }),
        card('36,000 SHORT', 'STILL NOT ENOUGH', { color: C.red, seconds: 2.4 }),
        say('marshal', 'THIS IS THE FAULT OF THOSE WHO SAILED FROM OTHER PORTS. TRAITORS. ALL OF THEM.'),
        fx({ flags: { shortfall: 36000 } }),
        say('zampano', 'THERE WAS A HAT, AND IT WAS ALWAYS EMPTY.', { remembered: true }),
      ],
    },
    {
      id: '3.3',
      title: 'The art of weeping',
      happens: 'IN SAN MARCO THE ENVOYS KNEEL AND WEEP. TEN THOUSAND VENETIANS WEEP BACK AND SHOUT YES. LATER THE BLIND DOGE TAKES THE CROSS, AND EVERYONE WEEPS AGAIN.',
      source: 'THE ENVOYS\' PLEA AND THE DOGE\'S SPEECH (4C). BOARD: "APPELLO EMOTIVO: PIANTO / ONORE, ONTA, VERGOGNA, VENDETTA".',
      script: () => [
        call((ctx) => {
          ctx.setStage('venice', { at: '7' });
          ctx.addActor('doge', 'doge', '4', { kind: 'idle', face: 'player' });
          ['8', '6', '9'].forEach((m, k) => ctx.addActor(`v${k}`, (['crowdA', 'crowdB', 'crowdC'] as const)[k], m, { kind: 'idle', face: 'player' }));
        }),
        say('voice', 'FEELING MAKES ACTION. TEARS FIRST, THE DECISION AFTER.'),
        mini(() => weeping(1), { won: { commozione: 6 }, lost: { commozione: 2 } }),
        card('YES! YES!', 'TEN THOUSAND VENETIANS WEEP BACK AND SHOUT', { color: C.cyan, seconds: 2.2 }),
        say('doge', 'I AM OLD AND BLIND. I WILL TAKE THE CROSS. SOMEBODY HAS TO STEER.'),
        mini(() => weeping(2), { won: { commozione: 6, flags: { weptWell: true } }, lost: { commozione: 2 } }),
        say('zampano', 'I WAS WEEPING VERY WELL.', { remembered: true }),
      ],
    },
    {
      id: '3.4',
      title: 'Nobody leaves this island',
      happens: 'THE DOGE WANTS HIS MONEY, AND NOBODY LEAVES THE LIDO UNTIL HE HAS IT. FOOD STILL ARRIVES. THEN THE OFFER: HELP US RETAKE ZARA. THE POOR KNIGHTS ARE NOT TOLD.',
      source: "THE DOGE'S ULTIMATUM, CLARI'S ASIDE ON THE FOOD, THE ZARA DEAL, THE ARMY KEPT IN THE DARK (4C).",
      script: () => {
        let listen = 0;
        return [
          call((ctx) => {
            ctx.setStage('lido');
            const g1 = ctx.addActor('g1', 'knight', '4', patrol(ctx, ['4', '1', '2', '5'], 1.1, 1));
            g1.sight = { range: 3.6, halfAngle: 0.55 };
            const g2 = ctx.addActor('g2', 'knight', '8', patrol(ctx, ['8', '7', '6', '3'], 1.2, 1));
            g2.sight = { range: 3.6, halfAngle: 0.55 };
            ctx.addActor('marshal', 'bagnaskizMarshal', { x: ctx.marker('9').x - 1.6, y: ctx.marker('9').y - 0.4 }, { kind: 'idle', face: 'E' });
          }),
          say('voice', 'NOBODY LEAVES THIS ISLAND UNTIL THE DOGE HAS HIS MONEY. FOOD STILL ARRIVES: HE IS A DECENT MAN.'),
          walk({
            objective: "LISTEN AT THE BARONS' TENT UNSEEN",
            caught: 'restart',
            pilot: (ctx) => ({ target: ctx.marker('9'), hold: true }),
            caughtText: 'A GUARD SAW YOU',
            onUpdate: (ctx, w, dt) => {
              const t = ctx.marker('9');
              const close = Math.hypot(t.x - ctx.player.gx, t.y - ctx.player.gy) < 1.5;
              if (close) listen += dt;
              ctx.hud.setMode({ label: close ? 'LISTENING...' : 'GET CLOSE TO THE TENT', value: listen / 6, color: 0xffe23a });
              if (listen >= 6) w.complete = true;
            },
          }),
          card('ZARA', '"HELP US RETAKE ZARA, AND THE DEBT CAN WAIT." THE POOR KNIGHTS ARE NOT TOLD.', { color: C.orange }),
          call((ctx) => ctx.addActor('doge', 'doge', { x: ctx.player.gx - 1.2, y: ctx.player.gy - 0.8 }, { kind: 'idle', face: 'player' })),
          say('doge', 'WE WERE BUILDING SHIPS. YOU WERE WEEPING. IT WAS GOING WELL.'),
          say('zampano', 'I WAS WEEPING VERY WELL.'),
          say('doge', 'HALF OF EVERYTHING, THEN. ADVISE ME WHETHER THAT SUITS YOU.'),
          say('zampano', 'WHERE ARE THE TURKS?'),
          say('doge', 'FIRST ZARA.', { remembered: true }),
          fx({ flags: { zaraDeal: true } }),
        ];
      },
    },
  ],
};
