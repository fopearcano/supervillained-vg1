import type { Actor } from '../../entities/actor';
import type { PropEntity } from '../../entities/prop';
import { gridToScreen } from '../../iso/projection';
import { ask, call, card, emote, flash, fx, prof, say, shake, skin, sound, stage, wait } from '../../story/steps';
import type { StoryScene } from '../../story/storyScene';
import { walk } from '../../story/walk';
import { C } from '../../ui/retro';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';
import { bark, distTo, lullWalk, patrol, placeObject, walkableNear } from './helpers';

const BEASTS = ['bear', 'leopard', 'hound'] as const;

/**
 * Level 2 — On the edge of dreams (under the desk · dream threshold). A train suitcase, a
 * medieval king's falcon and three neighborhood dogs all fit under the same desk. Each obeys the
 * logic of the person who dreamed it.
 */
export const CH2: ChapterDef = {
  number: 2,
  title: CHAPTER_TITLES[1],
  menuTitle: 'Edge of dreams',
  intro: "A TRAIN SUITCASE, A MEDIEVAL KING'S FALCON AND THREE NEIGHBORHOOD DOGS ALL FIT UNDER THE SAME DESK. EACH OBEYS THE LOGIC OF THE PERSON WHO DREAMED IT.",
  cast: 'THE BAND AS THREE BEASTS; A FALCON AND A WINGED STAG; TWO PREACHERS; TWO CLERKS; FORTUNE',
  theme: 'darkwood',
  music: 'level2',
  professor: {
    after: 'SG',
    text: 'IN THE STUDY, VOICES BROKE INTO PIECES A DOG COULD CARRY. IN THE DREAM, SHIPS, WALLS AND PEOPLE WILL BREAK APART THE SAME WAY. FOLLOW THE SOUND, EVEN WHEN THE PICTURE CHANGES.',
  },
  subLevels: [
    {
      id: '2.1',
      title: 'Three beasts on the path',
      happens:
        'THE UNDERSIDE OF THE DESK BECOMES A DARK WOOD. THE BEAR BLOCKS, THE LEOPARD DOUBLES BACK AND THE HOUND CROWDS THE GAP. WATCH THEIR FEET AND SLIP PAST WHILE THE THREE ARE LOOKING AT ONE ANOTHER: UNDER THE SKINS, THE PUG, THE CHIHUAHUA AND THE TERRIER STILL USE THEIR ROUTINE FROM THE BOWL.',
      source: 'BARBERO, IL SOGNO NEL MEDIOEVO: DANTE "SO FULL OF SLEEP"; THE THREE BEASTS OF CHARLEMAGNE\'S DREAM.',
      script: () => {
        let routine = false;
        let phaseT = 3.5;
        const lines = ['THE PAW, SIGNOR.', 'PAAARDON...', 'OOPS, MAN.'];
        const guard = (ctx: StoryScene) => {
          const [bear, leo, hound] = BEASTS.map((n) => ctx.actor(n));
          bear!.setBehavior({ kind: 'idle', face: 'player' });
          leo!.setBehavior(patrol(ctx, ['8', '3'], 2.4, 0.2));
          hound!.setBehavior({ kind: 'chase', speed: 1.6, radius: 2.4, home: { x: 7.5, y: 13.5 }, leash: 2.5 });
          for (const a of [bear!, leo!, hound!]) {
            a.hostile = true;
            a.sight = { range: 3.2, halfAngle: 0.6 };
          }
        };
        const turnInward = (ctx: StoryScene) => {
          const as = BEASTS.map((n) => ctx.actor(n));
          const cx = as.reduce((s, a) => s + a.gx, 0) / as.length;
          const cy = as.reduce((s, a) => s + a.gy, 0) / as.length;
          as.forEach((a: Actor, k) => {
            a.setBehavior({ kind: 'idle' });
            a.faceToward(cx, cy);
            a.hostile = false;
            a.sight = null;
            a.alert = 0;
            ctx.say(lines[k]!, { x: a.gx, y: a.gy }, '#f0b060');
          });
        };
        return [
          call((ctx) => {
            ctx.setStage('darkwood');
            ctx.addActor('bear', 'bear', '3', { kind: 'idle', face: 'S' });
            ctx.addActor('leopard', 'leopard', '8', { kind: 'idle', face: 'S' });
            ctx.addActor('hound', 'hound', { x: 7.5, y: 13.5 }, { kind: 'idle', face: 'S' });
            guard(ctx);
          }),
          prof('"SO FULL OF SLEEP" AT THE START OF HIS JOURNEY. DANTE, YOU UNDERSTAND. NOT THE DOG.'),
          walk({
            objective: 'SLIP PAST THE BEASTS WHILE THEY LOOK AT ONE ANOTHER',
            goal: { reach: 'E' },
            caught: 'restart',
            caughtText: 'THE BEASTS BARRED THE PATH',
            checkpoints: ['1'],
            onAction: (ctx) => {
              bark(ctx, 'WOOF?');
              ctx.notice('THEY CANNOT BE BEATEN. WATCH THEIR FEET', C.orange);
            },
            pilot: (ctx) => {
              const p = ctx.player;
              if (routine || p.gy < 9.5) return null;
              return p.gy > 15 ? { target: ctx.marker('2'), hold: true } : null;
            },
            onUpdate: (ctx, w, dt) => {
              phaseT -= dt;
              if (phaseT <= 0) {
                routine = !routine;
                phaseT = routine ? 3.2 : 4;
                if (routine) turnInward(ctx);
                else guard(ctx);
              } else if (routine) {
                const as = BEASTS.map((n) => ctx.actor(n));
                const cx = as.reduce((s, a) => s + a.gx, 0) / 3;
                const cy = as.reduce((s, a) => s + a.gy, 0) / 3;
                for (const a of as) a.faceToward(cx, cy);
              }
              ctx.hud.setMode(routine ? { label: 'THEY LOOK AT ONE ANOTHER: GO!', value: phaseT / 3.2, color: 0x4dff5a } : { label: 'WATCH THEIR FEET', value: phaseT / 4, color: 0xff7a1f });
              if (!w.data.told && w.time > 1) {
                w.data.told = true;
                ctx.notice('WAIT FOR THEIR ROUTINE, THEN SLIP PAST', C.cyan);
              }
            },
          }),
          say('zampano', 'THERE WAS A BEAR, AND HE WANTED MY PAW.', { remembered: true }),
        ];
      },
    },
    {
      id: '2.2',
      title: 'The falcon and the suitcase',
      happens:
        "CHASE THE FALCON UNTIL THE GROUND GIVES WAY UNDERFOOT. EACH TIME ZAMPANO PRESSES THE SUITCASE SHUT, A DIFFERENT SHIRT STICKS OUT. LEAVE IT OPEN. A WINGED STAG KNEELS, AND MOUNTING IT PUTS THE FALCON WITHIN REACH. THE PROFESSOR'S MISSED TRAIN WHISTLES SOMEWHERE IN CHARLES VI'S FOREST.",
      source: "BARBERO, IL SOGNO NEL MEDIOEVO: CHARLES VI'S FALCON AND FLYING STAG; THE LECTURER'S OWN TRAINS AND SUITCASES.",
      script: () => {
        let suitcase: PropEntity | null = null;
        let shut = 0;
        const shirts = ['A STRIPED SHIRT STICKS OUT', 'A SHIRT WITH A FALCON ON IT', "THE PROFESSOR'S LECTURE SHIRT", 'A SHIRT NOBODY HAS EVER SEEN'];
        let whistleT = 6;
        const whistle = (ctx: StoryScene, dt: number) => {
          whistleT -= dt;
          if (whistleT > 0) return;
          whistleT = 9;
          ctx.say('WHOOO-OOO... (A MISSED TRAIN)', { x: ctx.player.gx - 2, y: ctx.player.gy - 3 }, '#c8d0ff');
        };
        return [
          call((ctx) => {
            ctx.setStage('darkwood', { at: '1' });
            ctx.addActor('falcon', 'falcon', '2', { kind: 'fly', speed: 3.5, keepAway: 2.6, center: ctx.marker('3'), radius: 9 });
          }),
          walk({
            objective: 'CHASE THE FALCON',
            survive: 9,
            pilot: (ctx) => {
              const f = ctx.actors.get('falcon');
              return f ? { target: { x: f.gx, y: f.gy } } : null;
            },
            onUpdate: (ctx, w, dt) => {
              ctx.player.speedMul = Math.max(0.45, 1 - w.time / 16);
              whistle(ctx, dt);
            },
          }),
          shake(6),
          flash(0x2a1e14),
          card('THE GROUND GIVES WAY', 'UNDERFOOT. AND THERE IS A SUITCASE.', { color: '#c8a070', seconds: 2 }),
          call((ctx) => {
            suitcase = placeObject(ctx, 'crate', walkableNear(ctx, { x: ctx.player.gx + 1, y: ctx.player.gy - 0.6 }));
          }),
          walk({
            objective: 'THE SUITCASE WILL NOT SHUT. PRESS IT, OR LEAVE IT OPEN',
            action: 'SHUT',
            pilot: (ctx, w) => {
              if (!suitcase) return null;
              if (shut < 1) return { target: { x: suitcase.gx - 0.6, y: suitcase.gy + 0.5 }, act: distTo(ctx, { x: suitcase.gx, y: suitcase.gy }) < 1.4, hold: true };
              void w;
              // Leave it open: walk off to the farthest open spot on the path.
              const far = ['1', '2', '3', '5', 'E', 'S'].map((m) => ctx.marker(m)).sort((a, b) => Math.hypot(b.x - suitcase!.gx, b.y - suitcase!.gy) - Math.hypot(a.x - suitcase!.gx, a.y - suitcase!.gy))[0]!;
              return { target: far };
            },
            onAction: (ctx) => {
              if (!suitcase || distTo(ctx, { x: suitcase.gx, y: suitcase.gy }) > 1.6) return bark(ctx, 'WOOF?');
              ctx.game.audio.play('hit');
              ctx.shake(2);
              ctx.say(shirts[shut++ % shirts.length]!, { x: suitcase.gx, y: suitcase.gy }, '#f0d8a0');
            },
            onUpdate: (ctx, w, dt) => {
              whistle(ctx, dt);
              ctx.player.speedMul = 1;
              if (suitcase && shut > 0 && distTo(ctx, { x: suitcase.gx, y: suitcase.gy }) > 4) w.complete = true;
            },
          }),
          card('HE LEAVES IT OPEN', 'A WINGED STAG KNEELS', { color: C.cyan, seconds: 1.8 }),
          call((ctx) => ctx.addActor('stag', 'stag', walkableNear(ctx, { x: ctx.player.gx + 1.4, y: ctx.player.gy - 1 }), { kind: 'idle', face: 'player' })),
          walk({ objective: 'MOUNT THE WINGED STAG', pilot: (ctx) => ({ target: { x: ctx.actor('stag').gx, y: ctx.actor('stag').gy } }), onUpdate: (ctx, w) => {
            const s = ctx.actor('stag');
            if (distTo(ctx, { x: s.gx, y: s.gy }) < 1) w.complete = true;
          } }),
          call((ctx) => {
            ctx.removeActor('stag');
            ctx.player.z = 18;
            // Mounted, the falcon comes within reach: it circles low over open ground nearby.
            const f = ctx.actor('falcon');
            const c = walkableNear(ctx, { x: ctx.player.gx - 2, y: ctx.player.gy - 2 });
            f.setPosition(c.x, c.y);
            f.setBehavior({ kind: 'wander', center: c, radius: 0.8, speed: 0.6 });
          }),
          card('ON THE STAG', 'THE FALCON IS WITHIN REACH', { color: C.cyan, seconds: 1.6 }),
          walk({
            objective: 'CATCH THE FALCON',
            pilot: (ctx) => ({ target: { x: ctx.actor('falcon').gx, y: ctx.actor('falcon').gy } }),
            onUpdate: (ctx, w, dt) => {
              whistle(ctx, dt);
              const f = ctx.actor('falcon');
              if (distTo(ctx, { x: f.gx, y: f.gy }) < 1.5) w.complete = true;
            },
          }),
          call((ctx) => {
            ctx.player.z = 0;
            ctx.removeActor('falcon');
          }),
          sound('star'),
          fx({ flags: { rodeStag: true }, commozione: 4 }),
          say('zampano', 'THERE WAS A SUITCASE, AND IT WOULD NOT SHUT.', { remembered: true }),
        ];
      },
    },
    {
      id: '2.3',
      title: "The preacher's bees",
      happens:
        "LEUTARD'S BEES GO IN ONE END OF THE DOG AND COME OUT AT THE OTHER, GIVING HIM A FORMIDABLE SPEAKING VOICE. ACROSS THE THRESHOLD ANOTHER PREACHER, FULK OF NEUILLY, IS COLLECTING MONEY. TRY THE NEW BARK IN THE LULL BETWEEN HIS PHRASES: THE CONGREGATION TURNS AND A PATH OPENS THROUGH IT.",
      source: 'BARBERO, IL SOGNO NEL MEDIOEVO: LEUTARD. LA QUARTA CROCIATA: FULK OF NEUILLY.',
      script: () => {
        const crowd = ['1', '2', '3', '4', '5', '7'];
        return [
          call((ctx) => {
            ctx.setStage('fair', { at: 'S' });
            ctx.addActor('preacher', 'preacher', '0', { kind: 'idle', face: 'SE' });
            crowd.forEach((m, k) => ctx.addActor(`c${k}`, (['crowdA', 'crowdB', 'crowdC'] as const)[k % 3], m, { kind: 'idle', face: 'N' }));
          }),
          card('BEES', 'THEY GO IN ONE END OF THE DOG...', { color: C.yellow, seconds: 2 }),
          call((ctx) => {
            const s = gridToScreen(ctx.player.gx, ctx.player.gy);
            ctx.particles.burst(s.x, s.y - 12, { count: 26, textures: ['bee'], colors: [0xffffff], speed: [30, 80], life: [0.8, 1.6], drag: 1 });
            ctx.shake(3);
            ctx.game.audio.play('hurt');
          }),
          card('...AND COME OUT AT THE OTHER', 'A FORMIDABLE SPEAKING VOICE', { color: C.yellow, seconds: 2 }),
          fx({ unlock: 'sermon', commozione: 10 }),
          say('preacher', 'BLESSED ARE THE POOR. PASS THE BOWL. NO, THE OTHER WAY.'),
          lullWalk({
            objective: 'BARK IN THE LULL BETWEEN HIS PHRASES',
            action: 'SERMON',
            source: 'preacher',
            range: 6,
            stand: { x: 9.5, y: 10.5 },
            noise: ['BLESSED ARE THE POOR!', 'GIVE TO THE CROSS!', 'PASS THE BOWL!', 'NO, THE OTHER WAY!', 'GOD SEES YOUR PURSE!'],
            noiseLabel: 'FULK IS PREACHING',
            drowned: 'FULK DROWNS HIM OUT. WAIT FOR A LULL',
            actText: 'REPENT! AND... WOOF!',
            need: 3,
            onGood: (ctx, _w, n) => {
              // The congregation turns, two at a time, and steps aside.
              for (const k of [2 * (n - 1), 2 * (n - 1) + 1]) {
                const a = ctx.actors.get(`c${k}`);
                if (!a) continue;
                a.faceToward(ctx.player.gx, ctx.player.gy);
                a.emote('hurt', 0.8);
                ctx.say('AMEN?', { x: a.gx, y: a.gy }, C.yellow);
                a.setBehavior({ kind: 'goto', to: { x: a.gx + (k % 2 ? 2.5 : -2.5), y: a.gy }, speed: 1.6 });
              }
              ctx.apply({ commozione: 2 });
            },
          }),
          card('THE CONGREGATION TURNS', 'AND A PATH OPENS THROUGH IT', { color: C.yellow, seconds: 2 }),
          walk({ objective: 'WALK THROUGH THE OPEN PATH', goal: { reach: '0', radius: 1.4 } }),
          say('preacher', '...THAT WAS MY LULL.'),
          say('zampano', 'THERE WERE BEES, AND THEY WERE PREACHING.', { remembered: true }),
        ];
      },
    },
    {
      id: '2.4',
      title: 'Who sent this dream?',
      happens:
        "TWO CLERKS DISPUTE THE SAME OMEN. CHOOSE WHICH CLERK TO TRUST: THE ONE WHO CALLS IT A WARNING LIGHTS A DIRECT TRAIL, THE ONE WHO CALLS IT A TRICK SHOWS A SIDE DOOR. NAMING THE DEVIL COSTS A TOKEN UNDER JOINVILLE'S HOUSE RULE. BOTH PATHS LEAD TO FORTUNE.",
      source: 'BARBERO, IL SOGNO NEL MEDIOEVO: DREAMS FROM GOD OR FROM THE DEVIL. JOINVILLE E SAN LUIGI: THE HOUSEHOLD RULE ON SWEARING.',
      script: () => {
        return [
          call((ctx) => {
            ctx.setStage('fair', { at: 'S' });
            ctx.addActor('white', 'clerkB', '7', { kind: 'idle', face: 'player' });
            ctx.addActor('black', 'clerkA', '5', { kind: 'idle', face: 'player' });
            ctx.addActor('fortune', 'fortune', '9', { kind: 'idle' });
          }),
          say('clerkB', 'THIS DREAM IS A WARNING. GOD SENT IT. TAKE IT LITERALLY: GO STRAIGHT.'),
          say('clerkA', 'IT IS A TRICK. YOU KNOW WHOSE. NEVER GO WHERE A DREAM POINTS: TAKE THE SIDE DOOR.'),
          say('clerkB', 'HOUSE RULE: WHOEVER NAMES THE OTHER ONE PAYS A TOKEN.'),
          ask('clerkA', 'SO. WHICH OF US DO YOU TRUST?', [
            { label: 'THE WHITE CLERK. IT IS A WARNING.', effects: { grace: 4, flags: { omen: 'warning' } } },
            { label: 'THE BLACK CLERK. IT IS A TRICK.', effects: { flags: { omen: 'trick' } } },
            {
              label: "THE BLACK CLERK. IT IS THE DEVIL'S TRICK.",
              effects: { grace: -6, coins: -1, flags: { omen: 'trick', namedDevil: true } },
              then: [say('clerkB', 'YOU SAID HIS NAME. ONE TOKEN, PLEASE.'), card('-1 TOKEN', "JOINVILLE'S HOUSE RULE", { color: C.red, seconds: 1.4 })],
            },
          ]),
          call((ctx) => {
            if (ctx.state.flags.omen === 'warning') {
              // A direct, lit trail to Fortune.
              const a = ctx.marker('S');
              const b = ctx.marker('9');
              for (let k = 1; k < 8; k++) {
                const s = gridToScreen(a.x + ((b.x - a.x) * k) / 8, a.y + ((b.y - a.y) * k) / 8);
                ctx.particles.burst(s.x, s.y - 4, { count: 6, textures: ['sparkle'], colors: [0xffe23a], speed: [5, 15], life: [3, 4], drag: 4 });
              }
              ctx.insert([walk({ objective: 'FOLLOW THE LIT TRAIL TO FORTUNE', goal: { reach: '9', radius: 1.4, label: 'FORTUNE' } })]);
            } else {
              placeObject(ctx, 'wicket', '6');
              ctx.insert([
                walk({ objective: 'TAKE THE SIDE DOOR', goal: { reach: '6', label: 'SIDE DOOR' } }),
                walk({ objective: 'THE SIDE DOOR LEADS TO FORTUNE TOO', goal: { reach: '9', radius: 1.4, label: 'FORTUNE' } }),
              ]);
            }
          }),
          say('fortune', 'BOTH PATHS LEAD HERE. THEY ALWAYS DO.'),
          say('zampano', 'THERE WERE TWO CLERKS, AND THEY WERE BOTH RIGHT.', { remembered: true }),
        ];
      },
    },
    {
      id: '2.5',
      title: "Fortune's hands",
      happens:
        'FORTUNE TURNS THE DOG OVER TO INSPECT HIM, AS IF THE KNIGHT MIGHT BE ON THE UNDERSIDE. TAKE THE HELM IN A SQUALL. WHEN THE SHIP RIGHTS ITSELF, ZAMPANO IS ROBERT DE CLARI, POOR KNIGHT, IN A COAT OF MAIL. TRY OUT HIS CHARGE ACROSS THE TILTING DECK. A MUCH HARDER TRICK WILL BE TO WALK.',
      source: 'BARBERO, IL SOGNO NEL MEDIOEVO: CHRISTINE DE PIZAN TURNED BY FORTUNE INTO A MAN WHO CAN STEER THE SHIP.',
      script: () => {
        const tilt = (ctx: StoryScene, t: number, k = 1) => {
          ctx.player.pushX = Math.sin(t * 0.9) * 1.1 * k;
          ctx.player.pushY = Math.cos(t * 0.7) * 0.6 * k;
        };
        return [
          call((ctx) => {
            ctx.setStage('fair', { at: '9' });
            ctx.addActor('fortune', 'fortune', { x: ctx.marker('9').x - 1.2, y: ctx.marker('9').y - 1.2 }, { kind: 'idle' });
          }),
          say('fortune', 'HOLD STILL. THE KNIGHT MUST BE SOMEWHERE. PERHAPS UNDERNEATH.'),
          call((ctx) => {
            ctx.player.startAction('hurt', 0.8);
            ctx.shake(3);
          }),
          card('', 'FORTUNE TURNS THE DOG OVER TO INSPECT HIM', { color: '#f0d8a0', seconds: 1.8, dim: 0.3 }),
          say('fortune', 'NOT UNDERNEATH. VERY WELL: A SQUALL, THEN. TAKE THE HELM.'),
          sound('glitch'),
          stage('ship', [], { at: 'S' }),
          card('A SQUALL', 'TAKE THE HELM', { color: C.cyan, seconds: 1.6 }),
          walk({
            objective: 'REACH THE HELM ON THE TILTING DECK',
            goal: { reach: '3', label: 'HELM' },
            onUpdate: (ctx, w) => tilt(ctx, w.time),
          }),
          walk({
            objective: 'HOLD THE HELM UNTIL THE SHIP RIGHTS ITSELF',
            survive: 4,
            action: 'STEER',
            onAction: (ctx) => ctx.say('HOLD!', { x: ctx.player.gx, y: ctx.player.gy }, C.cyan),
            pilot: (ctx) => ({ target: ctx.marker('3'), hold: true }),
            onUpdate: (ctx, w) => {
              tilt(ctx, w.time, Math.max(0, 1 - w.time / 4));
              ctx.hud.setMode({ label: 'THE SHIP RIGHTS ITSELF', value: Math.min(1, w.time / 4), color: 0x5ac8ff });
              if (distTo(ctx, ctx.marker('3')) > 1.6) w.time = Math.max(0, w.time - 0.05);
            },
          }),
          sound('glitch'),
          call((ctx) => ctx.game.transition.play(null, 0.8, 1)),
          wait(0.4),
          fx({ unlock: 'knight', supervillain: 10 }),
          skin('zampanoKnight'),
          flash(0xfff0a0),
          card('ROBERT DE CLARI', 'POOR KNIGHT, IN A COAT OF MAIL', { color: C.cyan, seconds: 2.4 }),
          emote('zampano', 'bark'),
          say('zampano', 'WOOF. (DEEPER.)'),
          walk({
            objective: 'TRY OUT HIS CHARGE ACROSS THE TILTING DECK (HOLD RUN)',
            goal: { reach: '4', label: 'CHARGE!' },
            pilot: () => null,
            onUpdate: (ctx, w) => tilt(ctx, w.time, 0.5),
          }),
          card('A MUCH HARDER TRICK', 'WILL BE TO WALK', { color: C.yellow, seconds: 2.2 }),
          say('zampano', 'THERE WAS A LADY, AND SHE TURNED ME OVER LIKE A PANCAKE.', { remembered: true }),
        ];
      },
    },
  ],
};
