import { carry, dropCarried } from '../../story/carry';
import { call, card, fx, say } from '../../story/steps';
import { walk, type Pickup } from '../../story/walk';
import { C } from '../../ui/retro';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';
import { distTo, followLeader, lullWalk, patrol } from './helpers';

const tents = (markers: string[], who: string, amount: (k: number) => string): Pickup[] => markers.map((m, k) => ({ at: m, kind: 'coin', label: `${who}: ${amount(k)}` }));

/** The Venetians of the square, by marker. */
const SQUARE = ['8', '6', '9', '5', '1', '3'];

/**
 * Level 3 — Venice, summer 1202: the price of passage. The fleet is ready and the army is not:
 * fewer men came than the ships were built for, and the debt follows them onto the island.
 * Villehardouin supplies the contract (he signed it); Clari supplies its lived consequences
 * (the collections, the island, "no one knew the plan except the leaders").
 */
export const CH3: ChapterDef = {
  number: 3,
  title: CHAPTER_TITLES[2],
  intro: 'THE FLEET IS READY. FROM THE ISLAND OF THE LIDO, ZAMPANO CAN SEE EVERY SHIP THE VENETIANS HAVE BUILT AND ALMOST NONE OF THE MEN WHO WERE SUPPOSED TO PAY FOR THEM.',
  cast: "SBRIMBRULON AS PIERRE D'AMIENS; BAGNASKIZ AS THE MARSHAL, VILLEHARDOUIN; AN OLD, BLIND, VERY SHREWD DOG AS THE DOGE, ENRICO DANDOLO",
  theme: 'venice',
  music: 'level3',
  professor: {
    text: 'THIRTY-FOUR THOUSAND STILL OWED, SAYS THE MARSHAL. THIRTY-SIX, SAYS CLARI. TWO THOUSAND MARKS APART, AND BOTH OF THEM WERE COUNTING. ON THE ISLAND THE NUMBER THAT MATTERED WAS HOW MUCH BREAD CAME OVER.',
  },
  subLevels: [
    {
      id: '3.1',
      title: 'Look at those ships',
      happens:
        'WALK THE QUAY BEHIND SBRIMBRULON WHILE THE HARBOR BELL CLANGS LIKE THE BOWL AT HOME. LOOK AT THE GREAT SHIPS, THE GALLEYS AND THE TRANSPORTS WITH A DOOR IN THEIR SIDE FOR THE HORSES: MERAVIGLIA, THE BOOK OF MARVELS, OPENS. THEN TURN AROUND AND COUNT THE EMPTY BERTHS.',
      source:
        "CLARI XI (MUNRO): FAR FEWER CAME THAN THE FLEET WAS BUILT FOR (HIS FIGURE, ABOUT 1,000 KNIGHTS, IS A CLAIM; THE TREATY WAS FOR 4,500, VILLEHARDOUIN PP. 6-7). CLARI 13: EACH HIGH MAN HAS 'HIS OWN TRANSPORT TO CARRY HIS HORSES'. VILLEHARDOUIN PP. 13-16: MANY SAILED FROM OTHER PORTS. THE DOOR IN THE TRANSPORT'S SIDE AND THE BELL THAT CLANGS LIKE THE BOWL ARE ADAPTATION.",
      script: () => [
        call((ctx) => {
          ctx.setStage('venice', { at: 'S' });
          ctx.addActor('sbrim', 'sbrimbrulonKnight', { x: ctx.marker('S').x - 0.8, y: ctx.marker('S').y - 0.6 }, { kind: 'idle', face: 'player' });
        }),
        say('sbrimbrulon', 'STAY BEHIND ME, LITTLE ONE. AND LOOK AT THOSE SHIPS.'),
        followLeader({
          objective: 'WALK THE QUAY BEHIND SBRIMBRULON',
          leader: 'sbrim',
          path: ['3', '2', { x: 10.6, y: 8.6 }, '1'],
          onReach: (ctx, k) => {
            const lines = ['HALF A LOAF TODAY. THE COOK SAYS TOMORROW TOO.', 'THEY BUILT IT ALL FOR US. EVERY PLANK.', '', 'WE WAIT HERE UNTIL WE ARE TOLD.'];
            const s = ctx.actor('sbrim');
            if (lines[k]) ctx.say(lines[k]!, { x: s.gx, y: s.gy }, C.cyan);
          },
          onUpdate: (ctx, w, dt) => {
            w.data.t = ((w.data.t as number) ?? 0) + dt;
            if ((w.data.t as number) > 1.6) {
              w.data.t = 0;
              ctx.say('CLONG.', { x: 14.5, y: 3.5 }, '#c8d0ff');
            }
          },
        }),
        walk({
          objective: 'LOOK AT THE SHIPS',
          action: 'LOOK',
          pickups: [
            { at: '1', kind: 'marvel', label: 'THE HORSE TRANSPORTS', text: 'A DOOR IN THE SIDE. THE HORSES WALK IN; ONE DAY THE KNIGHTS WILL RIDE OUT OF IT', effects: { marvel: 'THE HORSE TRANSPORTS', commozione: 3 } },
            { at: '2', kind: 'marvel', label: 'THE GALLEYS', text: 'LONG, LOW AND ALL OARS', effects: { marvel: 'THE GALLEYS', commozione: 3 } },
            { at: '3', kind: 'marvel', label: 'THE GREAT SHIPS', text: 'TALLER THAN THE CHURCH AT HOME', effects: { marvel: 'THE GREAT SHIPS', commozione: 3 } },
          ],
          onAction: (ctx) => ctx.say('OOOH.', { x: ctx.player.gx, y: ctx.player.gy }, C.yellow),
        }),
        fx({ item: 'MERAVIGLIA, THE BOOK OF MARVELS' }),
        card('MERAVIGLIA', 'HIS BOOK OF MARVELS IS OPEN. EVERYTHING HE LOOKS AT GOES IN.', { color: C.yellow, seconds: 2.2 }),
        say('sbrimbrulon', 'NOW TURN AROUND. COUNT THE EMPTY BERTHS.'),
        walk({
          objective: 'COUNT THE EMPTY BERTHS',
          pickups: [
            { at: { x: 7.5, y: 13.5 }, kind: 'spot', label: 'AN EMPTY BERTH' },
            { at: { x: 7.5, y: 18.5 }, kind: 'spot', label: 'ANOTHER EMPTY BERTH' },
            { at: { x: 7.5, y: 6.5 }, kind: 'spot', label: 'EMPTY, EMPTY, EMPTY' },
          ],
        }),
        card('EVERY SHIP', 'AND ALMOST NONE OF THE MEN WHO WERE SUPPOSED TO PAY FOR THEM', { color: C.orange, seconds: 2.6 }),
        say('zampano', 'THERE WERE SHIPS, AND THEY WERE TALLER THAN THE CHURCH.', { remembered: true }),
      ],
    },
    {
      id: '3.2',
      title: 'The price of passage',
      happens:
        "THE MARSHAL EXPLAINS THE CONTRACT HE SIGNED: SO MUCH A HORSE, SO MUCH A MAN, 85,000 MARKS. TAKE THE COLLECTING BOWL AROUND THE CAMP TWICE: FIRST THE PILGRIMS PAY THEIR FARES, THEN THE GREAT LORDS GIVE UP THEIR PLATE. ZAMPANO KEEPS CLARI'S COUNT; THE MARSHAL KEEPS HIS OWN, AND THEY DO NOT AGREE. HAND OVER THE BOWL.",
      source:
        'VILLEHARDOUIN PP. 6-7 (THE TREATY: 4 MARKS A HORSE, 2 A MAN, 85,000 MARKS) AND PP. 15-16 (MORE THAN HALF MISSING; THE RICH GIVE THEIR PLATE; 34,000 STILL OWED). CLARI XI-XII (MUNRO): 50,000 STILL DUE AFTER THE FIRST COLLECTION, 36,000 AFTER THE SECOND. THE SCENE KEEPS BOTH COUNTS.',
      script: () => [
        call((ctx) => {
          ctx.setStage('lido');
          ctx.addActor('marshal', 'bagnaskizMarshal', '9', { kind: 'idle', face: 'player' });
        }),
        say('marshal', 'I SIGNED IT MYSELF. FOUR MARKS A HORSE, TWO A MAN, FOOD FOR NINE MONTHS. EIGHTY-FIVE THOUSAND MARKS. WE PROMISED THE WHOLE ARMY WOULD COME.'),
        say('marshal', 'THE WHOLE ARMY DID NOT COME. TAKE THE BOWL AROUND.'),
        carry('COLLECTING BOWL'),
        walk({ objective: 'ROUND ONE: THE PILGRIMS PAY THEIR FARES', pickups: tents(['1', '2', '3', '4', '5', '6'], 'A PILGRIM', () => 'WHAT HE HAS') }),
        card('50,000 STILL OWED', "BY CLARI'S COUNT", { color: C.red, seconds: 2.2 }),
        say('marshal', 'AGAIN. THIS TIME THE GREAT LORDS. THEIR PLATE, THEIR CUPS, WHATEVER SHINES.'),
        walk({ objective: 'ROUND TWO: THE GREAT LORDS GIVE UP THEIR PLATE', pickups: tents(['3', '5', '7', '8', '6'], 'A LORD', (k) => `${['HIS CUPS', 'HIS PLATE', 'HIS SPURS', 'HIS BELT', 'HIS RINGS'][k]}`) }),
        card('36,000 STILL OWED', "BY CLARI'S COUNT", { color: C.red, seconds: 2.2 }),
        walk({ objective: 'HAND THE BOWL TO THE MARSHAL', goal: { reach: '9', radius: 1.2, label: 'THE MARSHAL' } }),
        dropCarried(),
        say('marshal', 'THIRTY-FOUR THOUSAND STILL OWED.'),
        say('zampano', 'I COUNTED THIRTY-SIX.'),
        say('marshal', 'THEN ONE OF US IS WRONG, AND IT IS NOT THE ONE WHO SIGNED. THIS IS THE FAULT OF THE MEN WHO SAILED FROM OTHER PORTS.'),
        fx({ flags: { shortfall: 36000 } }),
        say('zampano', 'THERE WAS A BOWL, AND IT WAS ALWAYS EMPTY.', { remembered: true }),
      ],
    },
    {
      id: '3.3',
      title: 'The art of weeping',
      happens:
        "THE MARSHAL TELLS HOW THE ENVOYS WON THE VENETIANS A YEAR EARLIER, IN 1201. ZAMPANO WAS NOT THERE, SO HE PLAYS IT AS HE IS TOLD IT: TAKE THE MARSHAL'S PLACE AT THE FRONT, KNEEL, WAIT UNTIL THE SQUARE FALLS QUIET, THEN WEEP. THE FIRST VENETIAN WHO IS MOVED MOVES HIS NEIGHBOR. SOON THE WHOLE SQUARE ANSWERS. THE MEMORY ENDS ON THE ISLAND, WITH THE BILL.",
      source:
        "VILLEHARDOUIN PP. 7-8: THE ENVOYS ASK THE COUNCIL, THEN THE PEOPLE AT SAINT MARK'S, 1201; 'THE SIX ENVOYS KNELT AT THE FEET OF THE PEOPLE, WEEPING MANY TEARS' (P. 8). PLAYED AS THE MARSHAL'S RECOLLECTION, NOT AS SOMETHING ZAMPANO SAW; THE TRUMPETS AND THE SPREADING TEARS ARE ADAPTATION.",
      script: () => {
        let moved = 0;
        let spreadT = 0;
        return [
          card('SAINT MARK\'S, 1201', 'THE MARSHAL REMEMBERS. ZAMPANO WAS NOT THERE.', { color: '#f0d8a0', seconds: 2.4 }),
          call((ctx) => {
            ctx.setStage('venice', { at: 'S' });
            ctx.addActor('marshal', 'bagnaskizMarshal', '7', { kind: 'idle', face: 'N' });
            ctx.addActor('e1', 'knight', { x: 15.5, y: 15.5 }, { kind: 'idle', face: 'N' });
            ctx.addActor('e2', 'knight', { x: 12.5, y: 15.5 }, { kind: 'idle', face: 'N' });
            SQUARE.forEach((m, k) => ctx.addActor(`v${k}`, (['crowdA', 'crowdB', 'crowdC'] as const)[k % 3], m, { kind: 'idle', face: 'player' }));
            ctx.addActor('trumpet', 'crowdB', '4', { kind: 'idle', face: 'S' });
          }),
          say('marshal', 'I WAS AT THE FRONT. WE HAD NO MONEY, ONLY OUR CASE. YOU TELL IT. TAKE MY PLACE.'),
          walk({ objective: 'TAKE HIS PLACE AT THE FRONT OF THE ENVOYS', goal: { reach: { x: 14.5, y: 11.5 }, label: 'THE FRONT' } }),
          lullWalk({
            objective: 'KNEEL. WAIT UNTIL THE SQUARE FALLS QUIET, THEN WEEP',
            action: 'WEEP',
            source: 'trumpet',
            stand: { x: 14.5, y: 11.5 },
            range: 2.5,
            noise: ['TA-RAAA!', 'THE DOGE! THE DOGE!', 'TA-RA-RAAA!', 'MAKE WAY!'],
            noiseLabel: 'TRUMPETS',
            drowned: 'A SOB UNDER A TRUMPET GETS LOST. WAIT',
            actText: '(HE KNEELS AND WEEPS) FOR JERUSALEM...',
            need: 2,
            onGood: (ctx, _w, n) => {
              ctx.apply({ commozione: 5 });
              if (n === 1) {
                moved = 1;
                const v = ctx.actor('v0');
                v.emote('hurt', 1);
                ctx.say('SOB...', { x: v.gx, y: v.gy }, C.cyan);
                ctx.notice('THE FIRST VENETIAN IS MOVED. HIS NEIGHBOR LOOKS AT HIM', C.cyan);
              } else moved = SQUARE.length;
            },
            onUpdate: (ctx, _w, dt) => {
              spreadT -= dt;
              if (spreadT > 0 || moved < 1) return;
              spreadT = 0.5;
              for (let k = 0; k < Math.min(moved, SQUARE.length); k++) {
                const v = ctx.actors.get(`v${k}`);
                if (v && Math.random() < 0.5) ctx.say(k % 2 ? 'SOB!' : 'YES!', { x: v.gx, y: v.gy }, C.cyan);
              }
            },
          }),
          card('YES! YES!', 'THE WHOLE SQUARE ANSWERS', { color: C.cyan, seconds: 2.2 }),
          fx({ flags: { weptWell: true } }),
          say('marshal', 'THAT IS HOW IT WAS. THE SHIPS WERE PROMISED THAT DAY. SO WAS THE MONEY.'),
          card('THE ISLAND, 1202', 'THE MEMORY ENDS. THE BILL DOES NOT.', { color: '#9aa4c0', seconds: 2 }),
          say('zampano', "I WAS WEEPING VERY WELL, IN SOMEBODY ELSE'S STORY.", { remembered: true }),
        ];
      },
    },
    {
      id: '3.4',
      title: 'Nobody leaves the Lido',
      happens:
        "THE DOGE WANTS HIS MONEY AND THE ARMY IS KEPT ON THE ISLAND. A BREAD SELLER STILL SLIPS PAST THE TENTS: FOLLOW HIM, UNSEEN, TO THE COUNCIL AWNING AND OVERHEAR WHAT THE LEADERS DECIDE. IT IS WINTER SOON, NOBODY SAILS IN WINTER, AND A CITY CALLED ZARA WILL PAY FOR THE DELAY. NOBODY TELLS THE ARMY. THE OLD, BLIND DOGE TAKES THE CROSS.",
      source:
        "CLARI 10-13 (DEREMILITARI; XI-XIII IN MUNRO): THE ISLE OF SAINT NICHOLAS; THE DOGE DEMANDS THE SUM PROMISED AND THREATENS THE FOOD, WHICH STILL ARRIVES; THE DEBT TO BE PAID FROM CONQUESTS; WINTER; ZARA; 'NO ONE IN THE ARMY KNEW THIS PLAN, EXCEPT THE LEADERS'. VILLEHARDOUIN PP. 16-17: ZARA, HELD BY THE KING OF HUNGARY; THE DOGE TAKES THE CROSS AT SAINT MARK'S, SEWN ON 'A GREAT COTTON HAT' (P. 17).",
      script: () => {
        let listen = 0;
        return [
          call((ctx) => {
            ctx.setStage('lido');
            ctx.addActor('doge', 'doge', '2', { kind: 'idle', face: 'player' });
          }),
          say('doge', 'YOU ORDERED SHIPS FOR AN ARMY. I BUILT THEM. NOW PAY WHAT YOU PROMISED.'),
          say('voice', 'NOBODY LEAVES THE ISLAND. THE CAMP COUNTS ITS BREAD.'),
          call((ctx) => {
            ctx.removeActor('doge');
            ctx.addActor('seller', 'burgher', '7', { kind: 'idle', face: 'player' });
            const g = ctx.addActor('g1', 'knight', '5', patrol(ctx, ['5', '8'], 1, 1.2));
            g.sight = { range: 3, halfAngle: 0.5 };
          }),
          say('voice', 'A BREAD SELLER STILL SLIPS PAST THE TENTS. FOOD STILL ARRIVES.'),
          followLeader({
            objective: 'FOLLOW THE BREAD SELLER TO THE COUNCIL AWNING',
            leader: 'seller',
            path: ['6', '1', '2', '9'],
            speed: 1.8,
            caught: 'restart',
            caughtText: 'A GUARD SAW YOU',
          }),
          call((ctx) => {
            ctx.actor('seller').setBehavior({ kind: 'goto', to: ctx.marker('3'), speed: 2 });
            ctx.addActor('council1', 'doge', { x: ctx.marker('9').x + 1, y: ctx.marker('9').y - 0.6 }, { kind: 'idle', face: 'SW' });
            ctx.addActor('council2', 'bagnaskizMarshal', { x: ctx.marker('9').x + 1.2, y: ctx.marker('9').y + 1 }, { kind: 'idle', face: 'W' });
          }),
          walk({
            objective: 'OVERHEAR THE COUNCIL (STAY CLOSE)',
            pilot: (ctx) => ({ target: ctx.marker('9'), hold: true }),
            onUpdate: (ctx, w, dt) => {
              const close = distTo(ctx, ctx.marker('9')) < 1.8;
              if (close) listen += dt;
              ctx.hud.setMode({ label: close ? 'LISTENING...' : 'GET CLOSE TO THE AWNING', value: listen / 5, color: 0xffe23a });
              if (close && Math.random() < dt * 0.8) ctx.say(['...THE DEBT...', '...WINTER...', '...THE KING OF HUNGARY...', '...ZARA...'][Math.floor(listen) % 4]!, ctx.marker('9'), '#f0d8a0');
              if (listen >= 5) w.complete = true;
            },
          }),
          card('ZARA', '"WINTER IS COMING. HELP US TAKE BACK ZARA, AND THE DEBT CAN WAIT."', { color: C.orange }),
          fx({ flags: { zaraDeal: true } }),
          card('', 'NOBODY IN THE ARMY KNOWS THE PLAN, EXCEPT THE LEADERS', { color: '#9aa4c0', seconds: 2.4 }),
          walk({ objective: 'BACK TO THE GANGPLANK', goal: { reach: '3', label: 'GANGPLANK' } }),
          call((ctx) => ctx.addActor('doge2', 'doge', { x: ctx.player.gx - 1.2, y: ctx.player.gy - 1 }, { kind: 'idle', face: 'player' })),
          card("SAINT MARK'S", 'THE OLD, BLIND DOGE TAKES THE CROSS, SEWN ON HIS GREAT COTTON HAT', { color: '#f0d8a0', seconds: 2.4 }),
          say('doge', 'I AM OLD AND I CANNOT SEE. I WILL COME WITH YOU. SOMEBODY HAS TO STEER.'),
          say('zampano', 'WHERE ARE THE TURKS?'),
          say('voice', 'FIRST ZARA.', { remembered: true }),
        ];
      },
    },
  ],
};
