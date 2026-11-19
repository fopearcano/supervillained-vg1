import { carry, dropCarried } from '../../story/carry';
import { ask, call, card, fx, say } from '../../story/steps';
import type { Step } from '../../story/step';
import { walk, type Pickup } from '../../story/walk';
import { C } from '../../ui/retro';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';
import { distTo, followLeader, lullWalk, patrol } from './helpers';

const tents = (markers: string[], who: string, amount: (k: number) => string): Pickup[] => markers.map((m, k) => ({ at: m, kind: 'coin', label: `${who}: ${amount(k)}` }));

/** "What is this one for?": match a vessel to its job (wrong answers get corrected kindly). */
function vessel(name: string, marvel: string, right: string, wrong: string[]): Step {
  const options = [right, ...wrong].sort();
  return ask('sbrimbrulon', `${name}. WHAT IS THIS ONE FOR?`, options.map((o) => (o === right ? { label: o, effects: { marvel, commozione: 3 } } : { label: o, then: [say('sbrimbrulon', `NO, LITTLE ONE. IT IS FOR ${right.replace(/^FOR /, '')}`), fx({ marvel })] })));
}

/** The Venetians of the square, by marker. */
const SQUARE = ['8', '6', '9', '5', '1', '3'];

/**
 * Level 3 — Venice (Fourth Crusade, 1202). The fleet is ready. From the Lido, Zampanò can see
 * every ship the Venetians have built and almost none of the men who were supposed to pay for
 * them. Cast: Sbrimbrulon; Bagnaskiz as the marshal Villehardouin; the old, blind Doge.
 */
export const CH3: ChapterDef = {
  number: 3,
  title: CHAPTER_TITLES[2],
  intro: 'THE FLEET IS READY. FROM THE LIDO, ZAMPANO CAN SEE EVERY SHIP THE VENETIANS HAVE BUILT AND ALMOST NONE OF THE MEN WHO WERE SUPPOSED TO PAY FOR THEM.',
  cast: 'SBRIMBRULON; BAGNASKIZ AS THE MARSHAL VILLEHARDOUIN; AN OLD, BLIND, VERY SHREWD DOG AS THE DOGE',
  theme: 'venice',
  music: 'level3',
  professor: {
    after: '4C',
    text: 'A SOB HEARD ACROSS A QUIET SQUARE GETS SOMEONE TO STAND. ONE HEARD UNDER A TRUMPET GETS LOST. REMEMBER THAT: THE OATH WILL ASK FOR IT AGAIN.',
  },
  subLevels: [
    {
      id: '3.1',
      title: 'Look at those ships',
      happens:
        'WALK THE QUAY BEHIND SBRIMBRULON. WATCH A HORSE ENTER A TRANSPORT AND FOLLOW THE BEAT OF THE OARS TO A GALLEY. MATCH EACH VESSEL TO ITS JOB TO OPEN MERAVIGLIA, THE POOR KNIGHT\'S BOOK OF MARVELS. TURN BACK TOWARDS THE TENTS AND COUNT THE EMPTY BERTHS.',
      source: "BARBERO, LA QUARTA CROCIATA: CLARI'S CATALOGUE OF SHIPS.",
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
            const lines = ['A HORSE WALKS INTO A SHIP, THROUGH A DOOR IN ITS SIDE.', 'DUM... DUM... THE OARS KEEP A BEAT.', '', 'THE BEAT LEADS TO A GALLEY.'];
            const s = ctx.actor('sbrim');
            if (lines[k]) ctx.say(lines[k]!, { x: s.gx, y: s.gy }, C.cyan);
          },
          onUpdate: (ctx, w, dt) => {
            w.data.t = ((w.data.t as number) ?? 0) + dt;
            if ((w.data.t as number) > 1.3) {
              w.data.t = 0;
              ctx.say('DUM.', ctx.marker('1'), '#9ab4d8');
            }
          },
        }),
        vessel('THE SHIP WITH A DOOR IN ITS SIDE', 'THE HORSE TRANSPORTS', 'FOR HORSES', ['FOR FISH', 'FOR THE DOGE']),
        vessel('THE LONG ONE, ALL OARS', 'THE GALLEYS', 'FOR FIGHTING, ROWED', ['FOR SLEEPING', 'FOR HORSES']),
        vessel('THE GREAT ROUND ONE, TALLER THAN A HOUSE', 'THE DROMONS', 'FOR MEN AND STORES', ['FOR FIGHTING, ROWED', 'FOR LOOKING AT']),
        fx({ item: 'MERAVIGLIA, THE BOOK OF MARVELS' }),
        card('MERAVIGLIA', "THE POOR KNIGHT'S BOOK OF MARVELS IS OPEN", { color: C.yellow, seconds: 2.2 }),
        say('sbrimbrulon', 'NOW TURN AROUND. LOOK AT THE TENTS. COUNT THE EMPTY BERTHS.'),
        walk({
          objective: 'COUNT THE EMPTY BERTHS',
          pickups: [
            { at: { x: 7.5, y: 12.5 }, kind: 'spot', label: 'AN EMPTY BERTH' },
            { at: { x: 7.5, y: 18.5 }, kind: 'spot', label: 'ANOTHER EMPTY BERTH' },
            { at: { x: 7.5, y: 5.5 }, kind: 'spot', label: 'EMPTY, EMPTY, EMPTY' },
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
        "TAKE THE COLLECTING BOWL AROUND THE CAMP TWICE: FIRST THE PILGRIMS PAY THEIR FARES, THEN THE GREAT LORDS BRING OUT THEIR OWN SILVER. IN CLARI'S RECKONING THE SHORTFALL FALLS FROM 50,000 MARKS TO 36,000. THE CONTRACT WAS FOR 85,000. HAND THE BOWL TO THE MARSHAL; HE BLAMES THE MEN WHO SAILED FROM OTHER PORTS.",
      source: 'BARBERO, LA QUARTA CROCIATA: THE LIDO COLLECTIONS (CLARI); VILLEHARDOUIN ON THE OTHER PORTS.',
      script: () => [
        call((ctx) => {
          ctx.setStage('lido');
          ctx.addActor('marshal', 'bagnaskizMarshal', '9', { kind: 'idle', face: 'player' });
        }),
        say('marshal', 'FOUR MARKS A HORSE, TWO A MAN. EIGHTY-FIVE THOUSAND. TAKE THE BOWL AROUND.'),
        carry('COLLECTING BOWL'),
        walk({ objective: 'ROUND ONE: THE PILGRIMS PAY THEIR FARES', pickups: tents(['1', '2', '3', '4', '5', '6'], 'A PILGRIM', () => 'TWO MARKS') }),
        card('50,000 SHORT', 'THE PILGRIMS HAVE PAID WHAT THEY HAD', { color: C.red, seconds: 2.2 }),
        say('marshal', 'AGAIN. THIS TIME THE GREAT LORDS.'),
        walk({ objective: 'ROUND TWO: THE GREAT LORDS BRING OUT THEIR SILVER', pickups: tents(['3', '5', '7', '8', '6'], 'A LORD', (k) => `${['HIS CUPS', 'HIS PLATE', 'HIS SPURS', 'HIS BELT', 'HIS RINGS'][k]}`) }),
        card('36,000 SHORT', 'OF 85,000. CLARI DID THE SUM', { color: C.red, seconds: 2.4 }),
        walk({ objective: 'HAND THE BOWL TO THE MARSHAL', goal: { reach: '9', radius: 1.2, label: 'THE MARSHAL' } }),
        dropCarried(),
        say('marshal', 'THIS IS THE FAULT OF THE MEN WHO SAILED FROM OTHER PORTS. TRAITORS. ALL OF THEM.'),
        fx({ flags: { shortfall: 36000 } }),
        say('zampano', 'THERE WAS A BOWL, AND IT WAS ALWAYS EMPTY.', { remembered: true }),
      ],
    },
    {
      id: '3.3',
      title: 'The art of weeping',
      happens:
        "THE MARSHAL REMEMBERS THE ENVOYS' VISIT TO SAN MARCO A YEAR EARLIER. TAKE HIS PLACE AT THE FRONT OF THE ENVOYS. KNEEL, WAIT UNTIL THE SQUARE FALLS QUIET, THEN APPEAL TO THE CROWD. THE FIRST VENETIAN WHO WEEPS MOVES THEIR NEIGHBOR. SOON THE WHOLE SQUARE ANSWERS. BACK IN ZAMPANO'S OWN SUMMER, THE BLIND DOGE TAKES THE CROSS.",
      source: "BARBERO, LA QUARTA CROCIATA: THE ENVOYS AT SAN MARCO (VILLEHARDOUIN), PLAYED AS A MEMORY OF 1201; DANDOLO'S BARGAIN.",
      script: () => {
        let weeping = 0;
        let spreadT = 0;
        return [
          card('SAN MARCO, 1201', 'THE MARSHAL REMEMBERS', { color: '#f0d8a0', seconds: 2 }),
          call((ctx) => {
            ctx.setStage('venice', { at: 'S' });
            ctx.addActor('marshal', 'bagnaskizMarshal', '7', { kind: 'idle', face: 'N' });
            ctx.addActor('e1', 'knight', { x: 15.5, y: 15.5 }, { kind: 'idle', face: 'N' });
            ctx.addActor('e2', 'knight', { x: 12.5, y: 15.5 }, { kind: 'idle', face: 'N' });
            SQUARE.forEach((m, k) => ctx.addActor(`v${k}`, (['crowdA', 'crowdB', 'crowdC'] as const)[k % 3], m, { kind: 'idle', face: 'player' }));
            ctx.addActor('trumpet', 'crowdB', '4', { kind: 'idle', face: 'S' });
          }),
          say('marshal', 'I WAS AT THE FRONT. NOW YOU ARE. TAKE MY PLACE.'),
          walk({ objective: 'TAKE HIS PLACE AT THE FRONT OF THE ENVOYS', goal: { reach: { x: 14.5, y: 11.5 }, label: 'THE FRONT' } }),
          lullWalk({
            objective: 'KNEEL. WAIT UNTIL THE SQUARE FALLS QUIET, THEN APPEAL',
            action: 'WEEP',
            source: 'trumpet',
            stand: { x: 14.5, y: 11.5 },
            range: 2.5,
            noise: ['TA-RAAA!', 'THE DOGE! THE DOGE!', 'TA-RA-RAAA!', 'MAKE WAY!'],
            noiseLabel: 'TRUMPETS',
            drowned: 'A SOB UNDER A TRUMPET GETS LOST. WAIT',
            actText: '(HE KNEELS AND WEEPS)',
            need: 2,
            onGood: (ctx, _w, n) => {
              ctx.apply({ commozione: 5 });
              if (n === 1) {
                weeping = 1;
                const v = ctx.actor('v0');
                v.emote('hurt', 1);
                ctx.say('SOB...', { x: v.gx, y: v.gy }, C.cyan);
                ctx.notice('THE FIRST VENETIAN WEEPS. HIS NEIGHBOR LOOKS AT HIM', C.cyan);
              } else weeping = SQUARE.length;
            },
            onUpdate: (ctx, _w, dt) => {
              spreadT -= dt;
              if (spreadT > 0 || weeping < 1) return;
              spreadT = 0.5;
              for (let k = 0; k < Math.min(weeping, SQUARE.length); k++) {
                const v = ctx.actors.get(`v${k}`);
                if (v && Math.random() < 0.5) ctx.say(k % 2 ? 'SOB!' : 'YES!', { x: v.gx, y: v.gy }, C.cyan);
              }
            },
          }),
          card('YES! YES!', 'THE WHOLE SQUARE ANSWERS', { color: C.cyan, seconds: 2.2 }),
          fx({ flags: { weptWell: true } }),
          call((ctx) => ctx.addActor('doge', 'doge', '4', { kind: 'idle', face: 'player' })),
          card('ZAMPANO\'S OWN SUMMER', 'THE BLIND DOGE TAKES THE CROSS', { color: '#f0d8a0', seconds: 2 }),
          say('doge', 'I AM OLD AND BLIND. I WILL TAKE THE CROSS. SOMEBODY HAS TO STEER.'),
          say('voice', 'NOW HE, TOO, IS SAILING.'),
          say('zampano', 'I WAS WEEPING VERY WELL.', { remembered: true }),
        ];
      },
    },
    {
      id: '3.4',
      title: 'Nobody leaves the Lido',
      happens:
        'THE DOGE THREATENS TO CLOSE THE MARKET UNTIL THE DEBT IS PAID. A BREAD SELLER STILL SLIPS PAST THE TENTS. FOLLOW THE SELLER TO THE COUNCIL AWNING AND OVERHEAR THE NAME OF THE NEXT PORT: ZARA. OFFERING TO HELP VENICE RECOVER THE CITY BUYS THE PILGRIMS TIME. ZAMPANO GETS BACK TO THE GANGPLANK BEFORE ANYBODY THINKS TO TELL HIM THE PLAN.',
      source: "BARBERO, LA QUARTA CROCIATA: THE DOGE'S ULTIMATUM, CLARI ON THE FOOD, DANDOLO'S ZARA BARGAIN.",
      script: () => {
        let listen = 0;
        return [
          call((ctx) => {
            ctx.setStage('lido');
            ctx.addActor('doge', 'doge', '2', { kind: 'idle', face: 'player' });
          }),
          say('doge', 'NOBODY LEAVES THE LIDO. THE MARKET CLOSES UNTIL THE DEBT IS PAID.'),
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
              if (close && Math.random() < dt * 0.8) ctx.say(['...THE DEBT...', '...A CITY...', '...THE KING OF HUNGARY...', '...ZARA...'][Math.floor(listen) % 4]!, ctx.marker('9'), '#f0d8a0');
              if (listen >= 5) w.complete = true;
            },
          }),
          card('ZARA', '"HELP US RECOVER ZARA, AND THE DEBT CAN WAIT." IT BUYS THE PILGRIMS TIME.', { color: C.orange }),
          fx({ flags: { zaraDeal: true } }),
          walk({ objective: 'BACK TO THE GANGPLANK', goal: { reach: '3', label: 'GANGPLANK' } }),
          card('', 'NOBODY HAS THOUGHT TO TELL HIM THE PLAN', { color: '#9aa4c0', seconds: 2 }),
          say('zampano', 'WHERE ARE THE TURKS?'),
          say('voice', 'FIRST ZARA.', { remembered: true }),
        ];
      },
    },
  ],
};

