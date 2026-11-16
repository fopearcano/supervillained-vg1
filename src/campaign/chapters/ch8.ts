import { ask, branch, call, card, flash, fx, move, prof, say, shake, sound, stage } from '../../story/steps';
import { walk, type Pickup } from '../../story/walk';
import { C } from '../../ui/retro';
import { homeObject } from '../home';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';

/** Spots in the study where the relics go (8.2). */
const HOME_SPOTS = ['1', '2', '3', '5', '6', '7'];

/** Level 8 — Back to Greenzone. "He comes home with relics and nerve, and uses the nerve." */
export const CH8: ChapterDef = {
  number: 8,
  title: CHAPTER_TITLES[7],
  intro: 'HE COMES HOME WITH RELICS AND NERVE, AND USES THE NERVE.',
  cast: 'EVERYONE AS THEMSELVES AGAIN',
  theme: 'greenzone',
  music: 'chip',
  professor: {
    after: 'SG',
    text: 'HE MADE ONLY ONE MISTAKE. THE NEXT DAY HE WENT AND TOLD EVERYBODY. WHICH IS HOW I HEARD IT, AND NOW SO HAVE YOU.',
  },
  subLevels: [
    {
      id: '8.1',
      title: 'Falling to pieces',
      happens: 'THE DREAM BREAKS UP. HE RUNS THROUGH SPLINTERS OF EVERY LEVEL WHILE A VOICE ASKS WHETHER HE LIVED ALL THIS OR DREAMT IT. FAMILIAR THINGS LOOK FOREIGN.',
      source: 'BOARD: "FINALE: CADERE IN PEZZI, FRANTUMARSI, FRANTUMARE IL PENSIERO". WALTHER VON DER VOGELWEIDE ASKING WHETHER HE DREAMT HIS LIFE (SG).',
      script: () => {
        const heard = new Set<string>();
        const lines: Array<[string, string]> = [
          ['1', 'DID I LIVE ALL THIS?'],
          ['2', 'OR DID I DREAM IT?'],
          ['3', 'THE FIELDS I KNEW ARE CLEARED'],
          ['4', 'THE FRIENDS I KNEW ARE SLOW'],
          ['5', 'EVERYTHING FAMILIAR LOOKS FOREIGN'],
          ['6', 'ALAS, WHERE HAVE ALL MY YEARS GONE?'],
        ];
        return [
          call((ctx) => {
            ctx.setStage('shattered');
            ctx.addActor('w', 'watson', '1', { kind: 'idle', face: 'player' });
            ctx.addActor('d', 'doge', '2', { kind: 'idle', face: 'player' });
            ctx.addActor('k', 'king', '3', { kind: 'idle', face: 'player' });
            ctx.addActor('e', 'emir', '4', { kind: 'idle', face: 'player' });
            ctx.addActor('s', 'santina', '6', { kind: 'idle', face: 'player' });
            const h = ctx.addActor('shadow', 'hound', { x: ctx.marker('S').x, y: ctx.marker('S').y + 0.9 }, { kind: 'chase', speed: 1.55, radius: 40 });
            h.hostile = true;
          }),
          sound('glitch'),
          card('FALLING TO PIECES', 'THE DREAM BREAKS UP', { color: '#b070ff', seconds: 1.8, flash: true }),
          walk({
            objective: 'RUN THROUGH THE SPLINTERS. THE CONTROLS WILL SETTLE',
            goal: { reach: 'E' },
            scramble: true,
            caught: 'restart',
            caughtText: 'THE DREAM CAUGHT UP',
            onUpdate: (ctx) => {
              for (const [m, text] of lines) {
                if (heard.has(m)) continue;
                const p = ctx.marker(m);
                if (Math.hypot(p.x - ctx.player.gx, p.y - ctx.player.gy) < 2.6) {
                  heard.add(m);
                  ctx.say(text, { x: p.x, y: p.y }, C.cyan);
                }
              }
            },
          }),
          say('voice', 'THERE WAS A DOG, AND HE WAS WAKING UP.', { remembered: true }),
        ];
      },
    },
    {
      id: '8.2',
      title: 'Relics for the parish',
      happens: "HE WAKES UNDER THE DESK. SOMETHING CAME BACK WITH HIM: THE RAG CROSS AND A RELIC. HE SETS UP A SMALL ALTAR BESIDE THE PROFESSOR'S CHAIR.",
      source: 'CLARI BACK IN PICARDY WITH RELICS FOR HIS CHURCH (4C). JOINVILLE BUILDING AN ALTAR AFTER DREAMING THE KING HAPPY IN HIS CHAPEL (SG).',
      script: () => [
        call((ctx) => {
          ctx.setStage('study', { skin: 'plain', at: '0', face: 'SE' });
          ctx.addActor('prof', 'legs', '2', { kind: 'idle' });
          ctx.addActor('conf', 'confusione', '5', { kind: 'idle', face: 'player' });
        }),
        shake(2),
        card('UNDER THE DESK', 'HE WAKES. SOMETHING CAME BACK WITH HIM.', { color: '#f0d8a0', seconds: 2 }),
        fx({ item: 'THE RAG CROSS' }),
        fx({ item: 'A RELIC' }),
        prof('...AND CLARI WENT HOME TO PICARDY WITH RELICS FOR HIS CHURCH. THAT IS ALL HE BROUGHT BACK.'),
        call((ctx) => {
          const marvels = ctx.state.book.marvels;
          const pickups: Pickup[] = HOME_SPOTS.slice(0, Math.max(1, Math.min(HOME_SPOTS.length, marvels.length))).map((m, k) => {
            const thing = marvels[k] ? homeObject(marvels[k]!) : 'A SHELL FROM THE SEA THAT WAS NOT THERE';
            return { at: m, kind: 'relic', label: thing, text: marvels[k] ? `IT WAS ${marvels[k]}` : '', effects: { item: thing } };
          });
          const rest = Math.max(0, marvels.length - pickups.length);
          ctx.insert([
            walk({ objective: 'PLACE THE RELICS: EACH MARVEL BECOMES AN OBJECT AT HOME', pickups }),
            ...(rest > 0 ? [card(`AND ${rest} MORE`, 'ON EVERY SHELF IN THE HOUSE', { color: C.yellow, seconds: 1.8 })] : []),
          ]);
        }),
        walk({ objective: "SET UP A SMALL ALTAR BESIDE THE PROFESSOR'S CHAIR", goal: { reach: '4', label: 'ALTAR' } }),
        fx({ commozione: 10, flags: { altar: true } }),
        say('confusione', 'RELICS AND A STORY. THAT IS ALL CLARI BROUGHT BACK.'),
        say('zampano', 'THERE WAS A CHAPEL, AND IT WAS UNDER THE DESK.', { remembered: true }),
      ],
    },
    {
      id: '8.3',
      title: 'The vanguard of the lawn',
      happens: 'BAGNASKIZ, JACK AND WATSON HOLD THE GREEN AGAIN. ZAMPANO WALKS AT THEM: NO CHARGE, NO TURNING BACK. CONFUSIONE AND SBRIMBRULON FALL IN BESIDE HIM. BAGNASKIZ TURNS.',
      source: 'THE VANGUARD REPLAYED (4C). JOINVILLE AND THE COUNT OF SOISSONS HOLDING A LITTLE BRIDGE, TWO AGAINST A YELLING CROWD (JV). BOARD: THE ENDING AS "RESISTENZA".',
      script: () => {
        let joined = false;
        return [
          call((ctx) => {
            ctx.setStage('lawn', { skin: 'plain' });
            ctx.addActor('bag', 'bagnaskiz', '4', { kind: 'idle', face: 'player' });
            ctx.addActor('jack', 'jack', '6', { kind: 'idle', face: 'player' });
            ctx.addActor('watson', 'watson', '3', { kind: 'idle', face: 'player' });
            ctx.addActor('sbrim', 'sbrimbrulon', { x: ctx.player.gx - 1, y: ctx.player.gy + 0.2 }, { kind: 'idle', face: 'N' });
          }),
          say('zampano', 'WE WERE GOING TO JERUSALEM.'),
          say('sbrimbrulon', 'WE WERE.'),
          say('zampano', 'IS THIS IT?'),
          say('sbrimbrulon', 'THIS IS THE LAWN.'),
          say('zampano', 'IT WAS PASTEL.'),
          say('bagnaskiz', 'SIGNOR VILLANO. THE LAWN HAS A TOLL. YOU KNOW THE TOLL.'),
          card('NO ARMOUR', 'THE MECHANIC OF 7.3, FOR REAL', { color: C.cyan, seconds: 1.8 }),
          walk({
            objective: 'WALK AT THEM: NO CHARGE, NO TURNING BACK',
            goal: { reach: '4', radius: 1.6 },
            pace: { pressure: 0.05 },
            onUpdate: (ctx) => {
              const g = ctx.marker('4');
              const s = ctx.marker('S');
              const done = 1 - Math.hypot(g.x - ctx.player.gx, g.y - ctx.player.gy) / (Math.hypot(g.x - s.x, g.y - s.y) || 1);
              if (!joined && done > 0.3) {
                joined = true;
                ctx.addActor('conf', 'confusione', { x: ctx.player.gx + 1.2, y: ctx.player.gy + 0.8 }, { kind: 'follow', target: ctx.player, distance: 1.2, speed: 2.4, side: 0.9 });
                ctx.actor('sbrim').setBehavior({ kind: 'follow', target: ctx.player, distance: 1.2, speed: 2.4, side: -0.9 });
                ctx.notice('CONFUSIONE AND SBRIMBRULON FALL IN BESIDE HIM', C.green);
                ctx.say('THERE WERE A LOT OF THEM, AND THEY WERE SHOUTING', ctx.marker('4'), C.orange);
              }
            },
          }),
          branch(
            (s) => s.flags.oath === 'enforced',
            [
              call((ctx) => ctx.actor('bag').setBehavior({ kind: 'goto', to: ctx.marker('E'), speed: 1.6 })),
              say('bagnaskiz', '...'),
              card('BAGNASKIZ TURNS', 'AND GOES IN. NO TOOTH IS DRAWN.', { color: C.cyan, seconds: 2.2 }),
              call((ctx) => {
                ctx.actor('jack').setBehavior({ kind: 'goto', to: ctx.marker('E'), speed: 2.4, run: true });
                ctx.actor('watson').setBehavior({ kind: 'idle', face: 'player' });
              }),
              say('watson', 'MAN. HE TURNED.'),
            ],
            [
              call((ctx) => ctx.actor('bag').setBehavior({ kind: 'goto', to: ctx.marker('7'), speed: 1.2 })),
              say('bagnaskiz', 'PASS, THEN. THE ALPHA-DOG OFFER IS STILL ON THE TABLE. (HE SMILES.)'),
              say('watson', 'MAN. HE STEPPED ASIDE.'),
            ],
          ),
          fx({ supervillain: 25, value: 'Resistance', flags: { lawnHeld: true } }),
          sound('glitch'),
          flash(0xff2bd6),
          card('SUPER\nVILLAINED', '', { above: 'YOU HAVE BEEN', color: C.hotPink, seconds: 3.4, dim: 0.85, flash: true }),
          say('zampano', 'THERE WAS A LAWN, AND IT WAS MINE.', { remembered: true }),
        ];
      },
    },
    {
      id: '8.4',
      title: 'In the chambers of the ladies',
      happens: 'HE TELLS SANTINA THE WHOLE DAY. AT "AND THE LADIES SAID WE LOOKED LIKE ANGELS" SHE ASKS WHO TOLD HIM SO. HE HAS NO ANSWER.',
      source: '"BY GOD\'S COIF, WE SHALL TALK OF THIS DAY IN THE LADIES\' CHAMBERS" (JV). THE ASIDE ON WHO TOLD CLARI (4C).',
      script: () => [
        stage('lawn', [{ name: 'santina', who: 'santina', at: '7', face: 'S' }], { skin: 'plain', at: '3' }),
        move('zampano', '4', 2),
        say('zampano', 'THERE WAS A CITY, AND IT WAS MADE OF ROOFS.'),
        say('zampano', 'THERE WERE A LOT OF THEM, AND THEY WERE SHOUTING. AND WE WENT ON. AT A WALK.'),
        say('zampano', 'AND THE LADIES SAID WE LOOKED LIKE ANGELS.'),
        say('santina', 'WHO TOLD YOU SO?'),
        ask('santina', 'WHO TOLD YOU THE LADIES SAID SO?', [
          { label: 'THE LADIES.', then: [say('santina', 'WHICH LADIES?')] },
          { label: 'SBRIMBRULON. BY GOD\'S COIF.', then: [say('santina', 'HE WAS IN THE FIRST RANK. FACING THE OTHER WAY.')] },
          { label: 'I HEARD IT FROM A TENT.', then: [say('santina', 'TENTS SAY ANYTHING.')] },
          { label: 'NOBODY. I WANTED YOU TO THINK SO.', locked: 'HE CANNOT GET IT OUT' },
        ]),
        say('zampano', '...'),
        card('NO ANSWER', 'HE IS BRAVE, AND STILL TALKS LIKE A LOUT', { color: C.hotPink, seconds: 2.2 }),
        fx({ flags: { courtesy84: 'lout' } }),
        say('santina', 'TELL ME AGAIN TOMORROW, ZAMPANO.', { remembered: true }),
      ],
    },
  ],
};
