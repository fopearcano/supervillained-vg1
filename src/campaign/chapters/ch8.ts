import type { Point } from '../../entities/actor';
import type { PropEntity } from '../../entities/prop';
import { gridToScreen } from '../../iso/projection';
import { ask, branch, call, card, flash, fx, move, prof, say, shake, sound, wait } from '../../story/steps';
import type { StoryScene } from '../../story/storyScene';
import { walk, type Pickup } from '../../story/walk';
import { C } from '../../ui/retro';
import { homeObject } from '../home';
import { graceTier } from '../state';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';
import { distTo, placeObject, sounder } from './helpers';

const SHIP_MARVELS = ['THE GREAT SHIPS', 'THE HORSE TRANSPORTS', 'THE GALLEYS', 'THE FLEET LEAVING VENICE'];
const CITY_MARVELS = ['THE GREAT WALLS', 'THE CITY OF ROOFS', 'THE GOLDEN DOMES', "THE PALACE OF THE LION'S MOUTH", 'THE CARVED COLUMN', 'THE BRONZE HERCULES', 'A LAMP IN A COURTYARD', 'THE GREAT CHURCH', 'THE HIPPODROME'];

/** 8.2: the study objects the dream borrowed, by the marvel that borrowed them. */
const STUDY_SPOTS: Array<{ marvel: string; at: Point; plain: string }> = [
  { marvel: 'THE CARVED COLUMN', at: { x: 4.5, y: 3.5 }, plain: 'THE CHAIR LEG. HE HAS CHEWED IT.' },
  { marvel: 'THE GOLDEN DOMES', at: { x: 10.5, y: 4.5 }, plain: 'THE LAMPSHADE. IT IS DUSTY.' },
  { marvel: 'THE HIPPODROME', at: { x: 6.5, y: 9.5 }, plain: 'THE RUG. IT HAS A STAIN.' },
  { marvel: 'A LAMP IN A COURTYARD', at: { x: 3.5, y: 9.5 }, plain: 'THE DESK LAMP. IT IS OFF.' },
];

/**
 * Level 8 — Back to the Greenzone: what he can tell. Waking is a small bodily continuation of the
 * dream; nothing physical comes back from it. Under the desk he finds the ordinary objects the
 * dream borrowed, tells the oath honestly (his own words, or somebody else's), walks the direct
 * path to the bowl beside his friends and finally gives Santina her ball back.
 */
export const CH8: ChapterDef = {
  number: 8,
  title: CHAPTER_TITLES[7],
  menuTitle: 'Back to Greenzone',
  intro: "THE ARMOUR COMES OFF UNDER THE PROFESSOR'S DESK. THROUGH THE OPEN DOOR ZAMPANO CAN SEE THE BOWL EXACTLY WHERE WATSON LEFT IT.",
  cast: 'EVERYONE AS THEMSELVES AGAIN',
  theme: 'greenzone',
  music: 'greenzone',
  professor: {
    text: 'CLARI ENDS BY SWEARING THAT HE HAS TOLD THE STRICT TRUTH. HE PROBABLY BELIEVED IT, YOU UNDERSTAND. THAT IS WHAT MAKES HIM WORTH READING.',
  },
  subLevels: [
    {
      id: '8.1',
      title: 'Falling to pieces',
      happens:
        'THE HELMET, THE WALLS AND THE PURPLE CUSHION OF THE COURTYARD BREAK INTO SCRAPS. HIS LEGS DO NOT DO WHAT HE TELLS THEM. FOLLOW THE KNOCKING AND THE SMELL OF HIS OWN CUSHION TO THE FAMILIAR CHAIR LEG. MOVEMENT STEADIES AS THE STUDY FLOOR RETURNS. JERUSALEM, ALWAYS ONE STEP AWAY, NEVER COMES INTO REACH.',
      source: 'DREAM EXIT (ADAPTATION): BOARD, THE FINAL SHATTERING (11:55:10). THE KNOCK IS THE STUDY RADIATOR, THE PURPLE IS HIS CUSHION; WAKING CONTINUES THE DREAM IN THE BODY. NOTHING HISTORICAL IS CLAIMED.',
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
          card('FALLING TO PIECES', 'THE HELMET, THE WALLS AND THE PURPLE CUSHION BREAK INTO SCRAPS', { color: '#b070ff', seconds: 2.2, flash: true }),
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
      title: 'What he can tell',
      happens:
        'UNDER THE DESK THE ARMOUR IS A RAG AGAIN, AND NOTHING CAME BACK WITH HIM. LOOK AROUND THE STUDY: THE CHAIR LEG, THE LAMPSHADE, THE RUG AND THE DESK LAMP ARE ONLY THEMSELVES, UNLESS HE SAW WHAT THE DREAM MADE OF THEM. CONFUSIONE WANTS THE STORY FROM THE BEGINNING. TELL THE OATH THE WAY IT HAPPENED, THEN LEAVE ONE DRAWING UNDER THE DESK.',
      source:
        "ADAPTATION, REPLACING THE OLD RELIC ALTAR AND CHAPEL: ORDINARY OBJECTS, MEMORIES AND A DRAWING; NOTHING MEDIEVAL IS BROUGHT INTO REALITY. MERAVIGLIA'S MARVELS MAP TO THE STUDY'S OBJECTS (CAMPAIGN/HOME.TS). CLARI 120: HIS CLAIM TO HAVE TOLD 'THE STRICT TRUTH'.",
      script: () => [
        call((ctx) => {
          ctx.setStage('study', { skin: 'plain', at: '0', face: 'SE' });
          ctx.addActor('prof', 'legs', '2', { kind: 'idle' });
          ctx.addActor('conf', 'confusione', '5', { kind: 'idle', face: 'player' });
        }),
        shake(2),
        card('UNDER THE DESK', 'THE ARMOUR IS A RAG AGAIN. NOTHING CAME BACK WITH HIM, EXCEPT THE STORY.', { color: '#f0d8a0', seconds: 2.4 }),
        fx({ item: 'THE RAG CROSS' }),
        call((ctx) => {
          // The study's own objects: each is a marvel's furniture only if he saw that marvel.
          const book = ctx.state.book;
          const pickups: Pickup[] = STUDY_SPOTS.map((s) => {
            const seen = book.marvels.includes(s.marvel);
            return { at: s.at, kind: 'spot', label: seen ? s.marvel : s.plain.split('.')[0]!, text: seen ? `${homeObject(s.marvel)}. HE KNOWS EXACTLY WHAT IT WAS.` : s.plain };
          });
          ctx.insert([walk({ objective: 'LOOK AROUND THE STUDY', action: 'LOOK', pickups, onAction: (c) => c.say('...', { x: c.player.gx, y: c.player.gy }) })]);
        }),
        prof('...AND CLARI WENT HOME TO PICARDY AND WROTE IT ALL DOWN. HIS WAY.'),
        say('confusione', 'SO. TELL IT. FROM THE BEGINNING. AND THE OATH: WHO SAID WHAT?'),
        branch(
          (s) => s.flags.oath === 'enforced',
          [say('zampano', '"NO HAND ON A WOMAN! YOU SWORE!"'), say('zampano', 'I SAID THAT. IN THE LULL. IN MY OWN WORDS.'), say('confusione', 'I HEARD YOU AT THE TIME.')],
          [
            say('zampano', '"YOU SWORE AN OATH! LET HER GO!"'),
            say('zampano', '...THAT WAS NIKETAS. IT WAS HIS DOORWAY. I SAID NOTHING.'),
            say('confusione', 'THEN THAT IS THE STORY. TELL IT THAT WAY.'),
          ],
        ),
        branch((s) => s.flags.lamp === 'kept', [say('zampano', 'I KEPT A LAMP UNDER MY CLOAK. IT IS NOT HERE. IT WAS NEVER MINE.')]),
        branch((s) => s.flags.lamp === 'declared', [say('zampano', 'I CARRIED A LAMP TO A PILE. I DO NOT KNOW WHOSE HOUSE IT IS IN NOW.')]),
        call((ctx) => {
          const b = ctx.state.book;
          const ship = b.marvels.some((m) => SHIP_MARVELS.includes(m));
          const city = b.marvels.some((m) => CITY_MARVELS.includes(m));
          const pedestal = b.marvels.includes('AN EMPTY PEDESTAL');
          ctx.insert([
            ask('confusione', 'AND WHAT GOES UNDER THE DESK, FOR TOMORROW?', [
              { label: 'A DRAWING OF THE SHIPS.', locked: ship ? undefined : 'HE NEVER LOOKED AT THE SHIPS', effects: { item: 'A DRAWING OF THE SHIPS', flags: { drawing: 'ships' } } },
              { label: 'A DRAWING OF THE CITY.', locked: city ? undefined : 'HE NEVER LOOKED AT THE CITY', effects: { item: 'A DRAWING OF THE CITY', flags: { drawing: 'city' } } },
              { label: 'A DRAWING OF AN EMPTY PEDESTAL.', locked: pedestal ? undefined : 'HE NEVER SAW IT EMPTY', effects: { item: 'A DRAWING OF AN EMPTY PEDESTAL', flags: { drawing: 'pedestal' } } },
              { label: 'A DRAWING OF THE BOWL.', effects: { item: 'A DRAWING OF THE BOWL', flags: { drawing: 'bowl' } } },
            ]),
          ]);
        }),
        fx({ commozione: 10, flags: { told: true } }),
        // Grace: how faithfully he kept the forms he swore to shows in how he tells it.
        call((ctx) => {
          const tier = graceTier(ctx.state);
          const [big, small] =
            tier === 'high'
              ? ['HE TELLS IT STRAIGHT', 'EVEN THE PARTS WHERE HE IS VERY SMALL']
              : tier === 'mid'
                ? ['HE TELLS IT MOSTLY STRAIGHT', 'AND A LITTLE TALLER THAN HE WAS']
                : ['HE TELLS IT BEAUTIFULLY', 'IT IS NOT QUITE WHAT HAPPENED, AND HE KNOWS IT'];
          ctx.apply({ flags: { tellingTier: tier } });
          if (tier === 'high') {
            const s = gridToScreen(ctx.marker('4').x, ctx.marker('4').y);
            ctx.particles.burst(s.x, s.y - 14, { count: 18, textures: ['sparkle', 'pixel'], colors: [0xffffff, 0xffe23a], speed: [20, 60], life: [0.8, 1.6], drag: 2 });
          }
          ctx.insert([card(big, small, { color: tier === 'high' ? C.yellow : tier === 'mid' ? '#f0d8a0' : '#c8a070', seconds: 2.6 })]);
        }),
        call((ctx) => ctx.actor('conf').setBehavior({ kind: 'goto', to: ctx.marker('S'), speed: 1.6 })),
        wait(1.2),
        card('THE DOOR', 'THE CAT HOLDS IT OPEN', { color: C.green, seconds: 1.8 }),
        say('zampano', 'THERE WAS A STORY, AND I WAS IN IT, SMALLER THAN I THOUGHT.', { remembered: true }),
      ],
    },
    {
      id: '8.3',
      title: 'The vanguard of the lawn',
      happens:
        'WALK FROM THE STUDY TO THE BOWL BY THE DIRECT PATH. BAGNASKIZ ASKS FOR THE PAW, JACK STARTS THE IMITATION, WATSON LEANS IN TO TAKE THE BOWL. KEEP PACE AS SBRIMBRULON AND CONFUSIONE FALL IN BESIDE ZAMPANO; IF HE FLINCHES, THEY WAIT FOR HIM. BAGNASKIZ STEPS ASIDE. ZAMPANO DRINKS AND LEAVES THE BOWL WHERE THE NEXT DOG CAN REACH IT.',
      source: "ORIGINAL GREENZONE SCENE: THE TITLE CARD (BOARD, 11:52:06). PIERRE'S WALK OF 7.3 REPLAYED ON THE LAWN, WITH HIS FRIENDS AS THEMSELVES.",
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
        'BACK AT THE GATE, ZAMPANO TAKES UP HIS BEST KNIGHTLY POSE BESIDE THE RED BALL. SHE ASKS HOW HIS DAY WENT, AND THIS TIME HE STAYS TO TELL HER, ALL THE WAY TO THE LADIES ON THE WALLS WHO THOUGHT HE LOOKED LIKE AN ANGEL. SHE ASKS WHO HEARD THEM. THEN PUSH THE BALL THROUGH THE BARS WITH YOUR NOSE.',
      source: 'ORIGINAL GREENZONE SCENE, ANSWERING 1.4: SHE ONLY EVER WANTED THE BALL. HIS STORY OF THE WOMEN ON THE WALLS IS HIS VERSION OF CLARI 47; WHAT SHE THINKS STAYS HER OWN.',
      script: () => {
        let ball: PropEntity | null = null;
        return [
          call((ctx) => {
            ctx.setStage('neighborhood', { skin: 'plain', at: { x: 19.5, y: 3.5 }, face: 'E' });
            ctx.addActor('santina', 'santina', '9', { kind: 'idle', face: 'W' });
            ball = placeObject(ctx, 'ball', { x: 21.4, y: 4.2 }, 0xff4040);
          }),
          move('zampano', { x: 20.6, y: 3.9 }, 1.8),
          say('voice', '(HIS BEST KNIGHTLY POSE. ONE PAW NEAR THE RED BALL.)'),
          say('santina', 'ZAMPANO. HOW WAS YOUR DAY?'),
          say('zampano', 'THERE WAS A CITY, AND IT WAS MADE OF ROOFS.'),
          branch((s) => s.flags.vanguard === true, [say('zampano', 'THERE WERE A LOT OF THEM, AND THEY WERE SHOUTING. AND WE WENT ON. AT A WALK.')]),
          say('zampano', 'AND THE LADIES ON THE WALLS... THEY THOUGHT I LOOKED LIKE AN ANGEL.'),
          say('santina', 'WHO HEARD THEM?'),
          walk({
            objective: 'PUSH THE BALL THROUGH THE BARS',
            action: 'PUSH',
            pilot: (ctx) => (ball ? { target: { x: ball.gx - 0.6, y: ball.gy }, hold: true, act: distTo(ctx, { x: ball.gx, y: ball.gy }) < 1.2 } : null),
            onAction: (ctx, w) => {
              if (!ball || distTo(ctx, { x: ball.gx, y: ball.gy }) > 1.4) {
                ctx.say('(HE STRIKES A POSE INSTEAD.)', { x: ctx.player.gx, y: ctx.player.gy }, C.hotPink);
                return;
              }
              ctx.player.startAction('eat', 0.5);
              ball.setPosition(22.4, 3.9);
              ctx.game.audio.play('ball');
              w.complete = true;
            },
          }),
          wait(0.3),
          call(() => ball?.setPosition(23.1, 3.7)),
          wait(1.2),
          card('', 'THE BALL ROLLS THROUGH THE BARS TO HER AT LAST. HE PUSHED IT HIMSELF.', { color: C.hotPink, seconds: 2.2 }),
          say('santina', 'THANK YOU, ZAMPANO.'),
          say('zampano', '(HE STRAIGHTENS UP. IT WAS QUITE A PUSH.)'),
          say('santina', 'AND WHO TOLD YOU THEY SAID THAT?'),
          call((ctx) => {
            ctx.addActor('dog', 'crowdC', { x: 9.5, y: 3.5 }, { kind: 'goto', to: { x: 12.6, y: 3.5 }, speed: 1.6 });
            ctx.player.startAction('bark', 0.4);
          }),
          say('voice', '(ZAMPANO OPENS HIS MOUTH. BEHIND HIM, ANOTHER DOG CROSSES THE LAWN AND TAKES A DRINK. SANTINA RESTS A PAW ON THE BALL AND WAITS.)'),
          fx({ flags: { ballReturned: true, courtesy84: 'unanswered' } }),
          card('CUT.', '', { color: '#ffffff', seconds: 1.6, dim: 1 }),
          call((ctx) => ctx.apply({ remembered: 'WHO TOLD YOU THEY SAID THAT?' })),
        ];
      },
    },
  ],
};
