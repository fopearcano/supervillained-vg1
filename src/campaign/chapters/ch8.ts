import type { Point } from '../../entities/actor';
import type { PropEntity } from '../../entities/prop';
import { gridToScreen } from '../../iso/projection';
import { carry, dropCarried } from '../../story/carry';
import { ask, branch, call, card, flash, fx, move, prof, say, shake, sound, wait } from '../../story/steps';
import type { StoryScene } from '../../story/storyScene';
import { walk } from '../../story/walk';
import { C } from '../../ui/retro';
import { graceTier } from '../state';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';
import { distTo, placeObject, sounder } from './helpers';

const SHIP_MARVELS = ['THE DROMONS', 'THE HORSE TRANSPORTS', 'THE GALLEYS', 'THE FLEET LEAVING VENICE'];
const CITY_MARVELS = ['THE GREAT WALLS', 'THE CITY OF ROOFS', 'THE GOLDEN DOMES', 'THE GOLDEN PALACE', 'THE GREAT CHURCH', 'THE HIPPODROME', 'THE STATUES', 'THE CHAPEL OF RELICS'];

/**
 * Level 8 — Back to the Greenzone (Homeland · the return walk). The armor comes off under the
 * Professor's desk. Through the open door Zampanò can see the bowl exactly where Watson left it.
 */
export const CH8: ChapterDef = {
  number: 8,
  title: CHAPTER_TITLES[7],
  menuTitle: 'Back to Greenzone',
  intro: "THE ARMOR COMES OFF UNDER THE PROFESSOR'S DESK. THROUGH THE OPEN DOOR ZAMPANO CAN SEE THE BOWL EXACTLY WHERE WATSON LEFT IT.",
  cast: 'EVERYONE AS THEMSELVES AGAIN',
  theme: 'greenzone',
  music: 'greenzone',
  professor: {
    after: 'SG',
    text: 'HE MADE ONLY ONE MISTAKE. THE NEXT DAY HE WENT AND TOLD EVERYBODY. WHICH IS HOW I HEARD IT, AND NOW SO HAVE YOU.',
  },
  subLevels: [
    {
      id: '8.1',
      title: 'Falling to pieces',
      happens:
        'THE HELM, THE PARAPET AND THE PURPLE CUSHION BREAK INTO SCRAPS. FOLLOW THE KNOCKING FROM THE GALLEY AND THE SMELL OF THE CUSHION TO THE FAMILIAR CHAIR LEG. MOVEMENT STEADIES AS THE STUDY FLOOR RETURNS. JERUSALEM, ALWAYS ONE STEP AWAY IN THE FIRST DREAM, NEVER COMES INTO REACH.',
      source: 'BOARD: THE FINAL SHATTERING (11:55:10). BARBERO, IL SOGNO NEL MEDIOEVO: WALTHER\'S RETURN.',
      script: () => {
        const knock = sounder('KNOCK.', C.yellow, 1.3);
        let smellT = 0;
        let jerusalem: Point = { x: 7.5, y: 24.5 };
        let jT = 0;
        const smell = (ctx: StoryScene, dt: number) => {
          smellT -= dt;
          if (smellT > 0) return;
          smellT = 0.5;
          const at = ctx.marker('5');
          const s = gridToScreen(at.x, at.y);
          ctx.particles.burst(s.x, s.y - 6, { count: 5, textures: ['pixel'], colors: [0xa050e0, 0x7a2ab0], speed: [8, 20], life: [0.8, 1.4], drag: 2 });
        };
        return [
          call((ctx) => ctx.setStage('shattered')),
          sound('glitch'),
          card('FALLING TO PIECES', 'THE HELM, THE PARAPET AND THE PURPLE CUSHION BREAK INTO SCRAPS', { color: '#b070ff', seconds: 2.2, flash: true }),
          walk({
            objective: 'FOLLOW THE KNOCKING AND THE SMELL OF THE CUSHION',
            goal: { reach: 'E', label: 'THE CHAIR LEG' },
            scramble: true,
            onUpdate: (ctx, _w, dt) => {
              const p = ctx.player;
              knock(ctx, p.gy > 18 ? ctx.marker('2') : ctx.marker('4'), dt);
              smell(ctx, dt);
              // Jerusalem: always one step away, never in reach.
              jT -= dt;
              if (distTo(ctx, jerusalem) < 2.2) {
                jerusalem = { x: p.gx < 8 ? 10.5 : 5.5, y: Math.max(4.5, p.gy - 4) };
                ctx.notice('JERUSALEM MOVES ONE STEP AWAY', '#f6c0e0');
              }
              if (jT <= 0) {
                jT = 1.6;
                ctx.say('JERUSALEM', jerusalem, '#f6c0e0');
              }
            },
          }),
          card('THE STUDY FLOOR', 'MOVEMENT STEADIES. THE CHAIR LEG.', { color: '#f0d8a0', seconds: 2 }),
          say('voice', 'THERE WAS A DOG, AND HE WAS WAKING UP.', { remembered: true }),
        ];
      },
    },
    {
      id: '8.2',
      title: 'Relics for the parish',
      happens:
        'PLACE THE RAG CROSS AND A RELIC BY THE CHAIR. FROM THE PAGES COLLECTED IN MERAVIGLIA, FURNISH THE LITTLE ALTAR WITH A PAPER SHIP, A PICTURE OF THE FLOATING SAILOR OR A DRAWING OF THE CITY. READ THE OATH ENTRY ALOUD: CONFUSIONE HEARS EITHER ZAMPANO\'S OWN WORDS OR HIS ADMISSION THAT SOMEBODY ELSE SPOKE. THEN THE CAT HOLDS OPEN THE DOOR.',
      source: "BARBERO, LA QUARTA CROCIATA: CLARI'S RELICS. IL SOGNO NEL MEDIOEVO: JOINVILLE'S CHAPEL.",
      script: () => [
        call((ctx) => {
          ctx.setStage('study', { skin: 'plain', at: '0', face: 'SE' });
          ctx.addActor('prof', 'legs', '2', { kind: 'idle' });
          ctx.addActor('conf', 'confusione', '5', { kind: 'idle', face: 'player' });
        }),
        shake(2),
        card('UNDER THE DESK', 'THE ARMOR COMES OFF. SOMETHING CAME BACK WITH HIM.', { color: '#f0d8a0', seconds: 2 }),
        carry('THE RAG CROSS'),
        walk({ objective: 'PLACE THE RAG CROSS BY THE CHAIR', goal: { reach: '4', label: 'THE CHAIR' } }),
        dropCarried(),
        fx({ item: 'THE RAG CROSS' }),
        walk({ objective: 'FETCH THE RELIC', pickups: [{ at: '7', kind: 'relic', label: 'A RELIC' }] }),
        carry('A RELIC'),
        walk({ objective: 'PLACE THE RELIC BY THE CHAIR', goal: { reach: '4', label: 'THE CHAIR' } }),
        dropCarried(),
        call((ctx) => placeObject(ctx, 'relic', { x: ctx.marker('4').x - 0.4, y: ctx.marker('4').y })),
        fx({ item: 'A RELIC' }),
        prof('...AND CLARI WENT HOME TO PICARDY WITH RELICS FOR HIS CHURCH. THAT IS ALL HE BROUGHT BACK.'),
        call((ctx) => {
          const b = ctx.state.book;
          const ship = b.marvels.some((m) => SHIP_MARVELS.includes(m));
          const sailor = b.items.includes('A LITTLE PICTURE OF THE RESCUE');
          const city = b.marvels.some((m) => CITY_MARVELS.includes(m));
          // Never a dead end: with an empty book, a paper ship can always be folded.
          const anyShip = ship || (!sailor && !city);
          ctx.insert([
            ask('confusione', 'MERAVIGLIA IS FULL OF PAGES. WHAT GOES ON THE LITTLE ALTAR?', [
              { label: 'A PAPER SHIP.', locked: anyShip ? undefined : 'NO SHIP IN MERAVIGLIA', effects: { item: 'A PAPER SHIP ON THE ALTAR', flags: { altarPiece: 'ship' } } },
              { label: 'A PICTURE OF THE FLOATING SAILOR.', locked: sailor ? undefined : 'NO PICTURE OF THE RESCUE', effects: { item: 'A PICTURE OF THE FLOATING SAILOR', flags: { altarPiece: 'sailor' } } },
              { label: 'A DRAWING OF THE CITY.', locked: city ? undefined : 'NO CITY IN MERAVIGLIA', effects: { item: 'A DRAWING OF THE CITY', flags: { altarPiece: 'city' } } },
            ]),
          ]);
        }),
        fx({ commozione: 10, flags: { altar: true } }),
        // Grace shows on the altar.
        call((ctx) => {
          const tier = graceTier(ctx.state);
          const [big, small, item] =
            tier === 'high'
              ? ['THE ALTAR GLOWS', 'HE KEPT THE FORMS, EVEN WHEN EVERYONE FORGAVE HIM', 'A SMALL ALTAR THAT GLOWS']
              : tier === 'mid'
                ? ['A SMALL ALTAR', 'A LITTLE CROOKED, LIKE HIM', 'A SMALL CROOKED ALTAR']
                : ['AN ALTAR OF CHEW TOYS', 'IT WILL DO. GOD IS NOT FUSSY. THE BURGHER IS.', 'AN ALTAR OF CHEW TOYS'];
          ctx.apply({ item, flags: { altarTier: tier } });
          if (tier === 'high') {
            const s = gridToScreen(ctx.marker('4').x, ctx.marker('4').y);
            ctx.particles.burst(s.x, s.y - 14, { count: 24, textures: ['sparkle', 'pixel'], colors: [0xffffff, 0xffe23a], speed: [20, 60], life: [0.8, 1.6], drag: 2 });
          }
          ctx.insert([card(big, small, { color: tier === 'high' ? C.yellow : tier === 'mid' ? '#f0d8a0' : '#c8a070', seconds: 2.6 })]);
        }),
        say('confusione', 'NOW READ THE OATH ENTRY. ALOUD.'),
        branch(
          (s) => s.flags.oath === 'enforced',
          [say('zampano', '"NO WOMAN TOUCHED! YOU SWORE!"'), say('zampano', 'I SAID THAT. IN THE LULL.'), say('confusione', 'YOUR OWN WORDS. I HEARD THEM AT THE TIME.')],
          [
            say('zampano', '"YOU SWORE AN OATH! LET HER GO!"'),
            say('zampano', '...THAT WAS NIKETAS. I SAID NOTHING. SOMEBODY ELSE SPOKE.'),
            say('confusione', 'THEN THAT IS THE STORY. TELL IT THAT WAY.'),
          ],
        ),
        call((ctx) => ctx.actor('conf').setBehavior({ kind: 'goto', to: ctx.marker('S'), speed: 1.6 })),
        wait(1.2),
        card('THE DOOR', 'THE CAT HOLDS IT OPEN', { color: C.green, seconds: 1.8 }),
        say('zampano', 'THERE WAS A CHAPEL, AND IT WAS UNDER THE DESK.', { remembered: true }),
      ],
    },
    {
      id: '8.3',
      title: 'The vanguard of the lawn',
      happens:
        'WALK FROM THE STUDY TO THE BOWL BY THE DIRECT PATH. BAGNASKIZ REQUESTS A PAW, JACK STARTS THE IMITATION, WATSON LEANS IN TO TAKE THE BOWL. KEEP PACE AS SBRIMBRULON AND CONFUSIONE FALL IN BESIDE ZAMPANO; IF HE FLINCHES, THEY WAIT FOR HIM. BAGNASKIZ STEPS ASIDE. ZAMPANO DRINKS AND LEAVES THE BOWL WHERE THE NEXT DOG CAN REACH IT. THE LANE STAYS OPEN.',
      source: 'BOARD: THE TITLE CARD (11:52:06). BARBERO, JOINVILLE E SAN LUIGI: SOISSONS AND THE LITTLE BRIDGE.',
      script: () => {
        let bowl: PropEntity | null = null;
        let flinchT = 0;
        const beside = (ctx: StoryScene, waitUp: boolean) => {
          const p = ctx.player;
          for (const [n, side] of [['sbrim', -0.9], ['conf', 0.9]] as const) {
            const a = ctx.actor(n);
            if (waitUp) a.setBehavior({ kind: 'idle', face: 'player' });
            else if (a.behavior.kind !== 'follow') a.setBehavior({ kind: 'follow', target: p, distance: 1, speed: 3.6, side });
          }
        };
        return [
          call((ctx) => {
            ctx.setStage('neighborhood', { skin: 'plain', at: 'S', face: 'E' });
            bowl = placeObject(ctx, 'bowl', { x: 14.6, y: 2.4 });
            ctx.addActor('bag', 'bagnaskiz', { x: 13.5, y: 3.4 }, { kind: 'idle', face: 'player' });
            ctx.addActor('jack', 'jack', { x: 12.5, y: 2.4 }, { kind: 'idle', face: 'player' });
            ctx.addActor('watson', 'watson', { x: 15.3, y: 2.6 }, { kind: 'idle', face: 'W' });
            ctx.addActor('sbrim', 'sbrimbrulon', { x: 3.4, y: 4.4 }, { kind: 'idle', face: 'E' });
            ctx.addActor('conf', 'confusione', { x: 3.4, y: 2.4 }, { kind: 'idle', face: 'E' });
          }),
          say('voice', 'THROUGH THE OPEN DOOR, THE BOWL. EXACTLY WHERE WATSON LEFT IT.'),
          say('bagnaskiz', 'SIGNOR VILLANO. THE PAW. YOU KNOW THE TOLL.'),
          say('jack', '(OFFERING A PAW, VERY SLOWLY) PAAARDON...'),
          say('watson', '(LEANING IN TO TAKE THE BOWL) OOPS, MAN...'),
          call((ctx) => beside(ctx, false)),
          card('THE DIRECT PATH', 'NO ARMOUR. AT A WALK.', { color: C.cyan, seconds: 1.6 }),
          walk({
            objective: 'WALK TO THE BOWL BY THE DIRECT PATH. KEEP PACE',
            goal: { reach: { x: 12.4, y: 3.5 }, label: 'THE BOWL' },
            noRun: true,
            onUpdate: (ctx, w, dt) => {
              const p = ctx.player;
              // A flinch (stopping, or stepping back) and the friends wait for him.
              const flinch = Math.hypot(p.vx, p.vy) < 0.25 || p.vx < -0.3;
              flinchT = flinch ? flinchT + dt : 0;
              if (flinchT > 0.6 && !w.data.waiting) {
                w.data.waiting = true;
                beside(ctx, true);
                ctx.notice('HE FLINCHES. THEY WAIT FOR HIM', C.orange);
              } else if (!flinch && w.data.waiting) {
                w.data.waiting = false;
                beside(ctx, false);
              }
              if (!w.data.said && p.gx > 7.5) {
                w.data.said = true;
                ctx.notice('SBRIMBRULON AND CONFUSIONE FALL IN BESIDE HIM', C.green);
              }
            },
          }),
          call((ctx) => ctx.actor('bag').setBehavior({ kind: 'goto', to: { x: 14.5, y: 4.6 }, speed: 1.4 })),
          say('bagnaskiz', '...'),
          card('BAGNASKIZ STEPS ASIDE', 'NO TOOTH IS DRAWN', { color: C.cyan, seconds: 2 }),
          say('watson', 'MAN. HE STEPPED ASIDE.'),
          walk({
            objective: 'DRINK. THEN LEAVE THE BOWL WHERE THE NEXT DOG CAN REACH IT',
            action: 'DRINK',
            pilot: (ctx) => (bowl ? { target: { x: bowl.gx - 0.6, y: bowl.gy + 0.6 }, hold: true, act: distTo(ctx, { x: bowl.gx, y: bowl.gy }) < 1.4 } : null),
            onAction: (ctx, w) => {
              if (!bowl || distTo(ctx, { x: bowl.gx, y: bowl.gy }) > 1.6) return;
              ctx.player.startAction('eat', 0.8);
              ctx.game.audio.play('drink');
              bowl.setPosition(13.5, 3.5);
              ctx.say('(HE DRINKS, AND PUSHES THE BOWL BACK ONTO THE LANE)', { x: 13.5, y: 3.5 }, C.cyan);
              w.complete = true;
            },
          }),
          fx({ supervillain: 25, value: 'Resistance', flags: { lawnHeld: true } }),
          say('voice', 'THE LANE STAYS OPEN.'),
          sound('glitch'),
          flash(0xff2bd6),
          card('SUPER\nVILLAINED', '', { above: 'YOU HAVE BEEN', color: C.hotPink, seconds: 3.4, dim: 0.85, flash: true }),
          say('zampano', 'THERE WAS A BOWL, AND ANY DOG COULD REACH IT.', { remembered: true }),
        ];
      },
    },
    {
      id: '8.4',
      title: "At Santina's gate, again",
      happens:
        'BACK IN FRONT OF THE GATE, ZAMPANO TAKES UP HIS BEST KNIGHTLY POSE AND PLANTS A PAW ON THE RED BALL. SHE ASKS HOW HIS DAY WENT. THIS TIME HE STAYS TO TELL HER, GETS ALL THE WAY TO THE LADIES AT THE WINDOWS AND SAYS THEY THOUGHT HE LOOKED LIKE AN ANGEL. SHE ASKS WHO HEARD THEM. HE LIFTS HIS PAW TO MAKE HIS POINT. THE BALL ROLLS THROUGH THE BARS TO HER AT LAST.',
      source: 'BARBERO, LA QUARTA CROCIATA: CLARI AND THE LADIES. JOINVILLE E SAN LUIGI: SOISSONS AND THE LADIES\' CHAMBERS.',
      script: () => {
        let ball: PropEntity | null = null;
        return [
          call((ctx) => {
            ctx.setStage('neighborhood', { skin: 'plain', at: { x: 19.5, y: 3.5 }, face: 'E' });
            ctx.addActor('santina', 'santina', '9', { kind: 'idle', face: 'W' });
            ball = placeObject(ctx, 'ball', { x: 21.4, y: 4.2 }, 0xff4040);
          }),
          move('zampano', { x: 20.9, y: 3.9 }, 1.8),
          say('voice', '(HIS BEST KNIGHTLY POSE. A PAW PLANTED ON THE RED BALL.)'),
          say('santina', 'ZAMPANO. HOW WAS YOUR DAY?'),
          say('zampano', 'THERE WAS A CITY, AND IT WAS MADE OF ROOFS.'),
          branch((s) => s.flags.vanguard === true, [say('zampano', 'THERE WERE A LOT OF THEM, AND THEY WERE SHOUTING. AND WE WENT ON. AT A WALK.')]),
          say('zampano', 'AND THE LADIES AT THE WINDOWS... THEY THOUGHT I LOOKED LIKE AN ANGEL.'),
          say('santina', 'WHO HEARD THEM?'),
          call((ctx) => ctx.player.startAction('bark', 0.6)),
          say('voice', '(HE LIFTS HIS PAW TO MAKE HIS POINT.)'),
          call((ctx) => {
            // The ball rolls through the bars to her at last.
            ball?.setPosition(22.4, 3.7);
            ctx.game.audio.play('ball');
          }),
          wait(0.3),
          call(() => ball?.setPosition(23.1, 3.7)),
          wait(1.4),
          card('', 'THE BALL ROLLS THROUGH THE BARS TO HER AT LAST', { color: C.hotPink, seconds: 2 }),
          say('santina', 'WHO TOLD YOU THEY SAID THAT?'),
          call((ctx) => {
            ctx.addActor('dog', 'crowdC', { x: 9.5, y: 3.5 }, { kind: 'goto', to: { x: 12.6, y: 3.5 }, speed: 1.6 });
            ctx.player.startAction('bark', 0.4);
          }),
          say('voice', '(ZAMPANO OPENS HIS MOUTH. BEHIND HIM, ANOTHER DOG CROSSES THE LAWN AND TAKES A DRINK. SANTINA RESTS A PAW ON THE BALL AND WAITS.)'),
          fx({ flags: { courtesy84: 'unanswered' } }),
          card('CUT.', '', { color: '#ffffff', seconds: 1.6, dim: 1 }),
          call((ctx) => ctx.apply({ remembered: 'WHO TOLD YOU THEY SAID THAT?' })),
        ];
      },
    },
  ],
};
