import { gridToScreen } from '../../iso/projection';
import { spend } from '../state';
import { STORY } from '../../config';
import { ask, behave, call, card, emote, flash, fx, prof, say, skin, sound, wait } from '../../story/steps';
import { walk } from '../../story/walk';
import { C } from '../../ui/retro';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';
import { bark, patrol } from './helpers';

/** Level 2 — On the edge of dreams. Cast: the band as three beasts; Fortune; a star preacher. */
export const CH2: ChapterDef = {
  number: 2,
  title: CHAPTER_TITLES[1],
  menuTitle: 'Edge of dreams',
  intro: 'FALLING ASLEEP IS A LEVEL OF ITS OWN: IT TEACHES THE RULES OF THE DREAM BEFORE THE CRUSADE STARTS.',
  cast: 'THE BAND AS THREE BEASTS; FORTUNE AS A TALL LADY; A STAR PREACHER',
  theme: 'darkwood',
  music: 'medieval',
  professor: {
    after: 'SG',
    text: 'NOBODY KNOWS WHY WE TELL DREAMS IN THE IMPERFECT. "THERE WAS A PUG, AND HE WAS SAYING." THEY DID IT TOO.',
  },
  subLevels: [
    {
      id: '2.1',
      title: 'Full of sleep',
      happens: 'UNDER THE DESK THE LECTURE BLURS INTO A DARK WOOD. THREE BEASTS BAR THE PATH: A PUG, A CHIHUAHUA AND A TERRIER WEARING A BEAR, A LEOPARD AND A HOUND.',
      source: 'DANTE "SO FULL OF SLEEP"; CHARLEMAGNE\'S DREAM OF THREE BEASTS IN THE CHANSON DE ROLAND (SG).',
      script: () => [
        call((ctx) => {
          ctx.setStage('darkwood');
          const bear = ctx.addActor('bear', 'bear', '2', { kind: 'chase', speed: 1.7, radius: 3.2, home: ctx.marker('2'), leash: 5 });
          bear.hostile = true;
          const leo = ctx.addActor('leopard', 'leopard', '3', patrol(ctx, ['3', '8', '3'], 2.6, 0.2));
          leo.hostile = true;
          leo.sight = { range: 3, halfAngle: 0.5 };
          const hound = ctx.addActor('hound', 'hound', '4', { kind: 'chase', speed: 1.5, radius: 2.6, home: ctx.marker('4'), leash: 4 });
          hound.hostile = true;
        }),
        prof('"SO FULL OF SLEEP" AT THE START OF HIS JOURNEY. DANTE, YOU UNDERSTAND. NOT THE DOG.'),
        walk({
          objective: 'GET THROUGH THE DARK WOOD. THE BEASTS CANNOT BE BEATEN',
          goal: { reach: 'E' },
          caught: 'restart',
          caughtText: 'THE BEASTS BARRED THE PATH',
          checkpoints: ['1', '5'],
          onAction: (ctx) => {
            bark(ctx, 'WOOF?');
            for (const a of ctx.actors.values()) a.emote('bark');
            ctx.notice('THEY CANNOT BE BEATEN. EVADE THEM', C.orange);
          },
        }),
        say('zampano', 'THERE WAS A BEAR, AND HE WAS A PUG.', { remembered: true }),
      ],
    },
    {
      id: '2.2',
      title: 'The falcon and the suitcase',
      happens: 'HE CHASES A FALCON HE CAN NEVER REACH, AND THE GROUND BOGS DOWN. A WINGED STAG LANDS. HE RIDES IT.',
      source: "CHARLES VI'S DREAM OF THE FALCON AND THE FLYING STAG; THE LECTURER'S OWN TRAIN AND THE SUITCASES THAT NEVER CLOSE (SG). BOARD: ESCAPE \"LIKE ALICE\".",
      script: () => {
        let asked = false;
        let rode = false;
        return [
          call((ctx) => {
            ctx.setStage('darkwood', { at: '1' });
            ctx.addActor('falcon', 'falcon', '2', { kind: 'fly', speed: 3.5, keepAway: 2.6, center: ctx.marker('3'), radius: 9 });
          }),
          walk({
            objective: 'CATCH THE FALCON',
            pilot: (ctx) => {
              const f = ctx.actors.get('falcon');
              return f ? { target: { x: f.gx, y: f.gy } } : null;
            },
            onUpdate: (ctx, w) => {
              ctx.player.speedMul = Math.max(0.35, 1 - w.time / 30);
              if (w.time > 3 && Math.floor(w.time) % 6 === 0 && Math.random() < 0.02) ctx.notice('THE GROUND BOGS DOWN', '#8a6a40');
              if (!asked && w.time > 16) {
                asked = true;
                ctx.addActor('stag', 'stag', { x: ctx.player.gx + 1.5, y: ctx.player.gy - 1 }, { kind: 'idle', face: 'player' });
                ctx.interrupt([
                  card('A WINGED STAG LANDS', '', { color: C.cyan, seconds: 1.6, dim: 0.2 }),
                  ask('voice', 'THE FALCON IS ALWAYS ONE TREE AWAY. THE SUITCASE WILL NOT CLOSE.', [
                    { label: 'KEEP RUNNING AFTER THE FALCON.', then: [say('voice', 'IT WAS ALWAYS ONE TREE AWAY.')] },
                    { label: 'RIDE THE WINGED STAG.', effects: { flags: { rodeStag: true } }, then: [call(() => (rode = true))] },
                  ]),
                  call(() => {
                    if (!rode) asked = false;
                  }),
                ]);
              }
              if (rode) w.complete = true;
            },
          }),
          call((ctx) => {
            ctx.removeActor('stag');
            ctx.player.z = 0;
          }),
          flash(0xffffff),
          card('LIKE ALICE', 'THE STAG CARRIED HIM OUT OF THE BOG', { color: C.cyan, seconds: 2.2 }),
          say('zampano', 'THERE WAS A SUITCASE, AND IT WAS FLYING.', { remembered: true }),
        ];
      },
    },
    {
      id: '2.3',
      title: "The preacher's bees",
      happens: 'A SWARM ENTERS HIM FROM THE WRONG END AND LEAVES BY THE MOUTH. NOW HE CAN PREACH. ON A STAGE A STAR PREACHER TALKS OF POVERTY AND PASSES THE HAT.',
      source: "LEUTARD'S BEES (SG). FULK OF NEUILLY, PREACHER OF POVERTY TURNED FUNDRAISER, AND THE GOSSIP ABOUT THE MONEY (4C).",
      script: () => {
        const crowd = ['1', '2', '3', '4', '5', '6', '7', '9'];
        const moved = new Set<string>();
        return [
          call((ctx) => {
            ctx.setStage('fair', { at: 'S' });
            ctx.addActor('preacher', 'preacher', '0', { kind: 'idle', face: 'SE' });
            crowd.forEach((m, k) => ctx.addActor(`c${k}`, (['crowdA', 'crowdB', 'crowdC'] as const)[k % 3], m, { kind: 'wander', center: ctx.marker(m), radius: 1.2, speed: 0.6 }));
          }),
          card('BEES', 'A SWARM ENTERS HIM FROM THE WRONG END...', { color: C.yellow, seconds: 2 }),
          call((ctx) => {
            const s = gridToScreen(ctx.player.gx, ctx.player.gy);
            ctx.particles.burst(s.x, s.y - 12, { count: 26, textures: ['bee'], colors: [0xffffff], speed: [30, 80], life: [0.8, 1.6], drag: 1 });
            ctx.shake(3);
            ctx.game.audio.play('hurt');
          }),
          card('...AND LEAVES BY THE MOUTH', 'NOW HE CAN PREACH', { color: C.yellow, seconds: 2 }),
          fx({ unlock: 'sermon', commozione: 20 }),
          say('preacher', 'BLESSED ARE THE POOR. PASS THE HAT. NO, THE OTHER WAY.'),
          walk({
            objective: 'SERMON BARK THE CROWD (0/5). IT SPENDS COMMOZIONE',
            action: 'SERMON',
            need: 5,
            pilot: (ctx) => {
              let best: { x: number; y: number } | null = null;
              let bd = Infinity;
              for (const [name, a] of ctx.actors) {
                if (name === 'preacher' || moved.has(name)) continue;
                const d = Math.hypot(a.gx - ctx.player.gx, a.gy - ctx.player.gy);
                if (d < bd) [best, bd] = [{ x: a.gx, y: a.gy }, d];
              }
              return best ? { target: best, act: bd < 2.2, hold: bd < 1.6 } : null;
            },
            onAction: (ctx) => {
              if (!spend(ctx.state, 'commozione', STORY.COST.SERMON)) {
                ctx.notice('UNMOVED: HE CANNOT ACT', C.red);
                ctx.game.audio.play('empty');
                return;
              }
              bark(ctx, 'REPENT! ALSO, COINS!');
              for (const [name, a] of ctx.actors) {
                if (name === 'preacher' || moved.has(name)) continue;
                if (Math.hypot(a.gx - ctx.player.gx, a.gy - ctx.player.gy) > 2.6) continue;
                moved.add(name);
                a.setBehavior({ kind: 'idle', face: 'player' });
                a.emote('hurt', 0.8);
                ctx.say('AMEN!', { x: a.gx, y: a.gy }, C.yellow);
              }
            },
            onUpdate: (ctx, w) => {
              w.collected = moved.size;
              ctx.hud.setObjective(`SERMON BARK THE CROWD (${moved.size}/5). IT SPENDS COMMOZIONE`);
              if (ctx.state.meters.commozione < STORY.COST.SERMON) ctx.apply({ commozione: 10 });
            },
          }),
          fx({ coins: 12 }),
          card('FIRST COINS', 'NOBODY KNOWS WHERE THEY GO', { color: C.yellow, seconds: 2.4 }),
          fx({ coins: -12 }),
          say('zampano', 'THERE WERE BEES, AND THEY WERE PREACHING.', { remembered: true }),
        ];
      },
    },
    {
      id: '2.4',
      title: 'Who sent this dream?',
      happens: 'A GATE WITH TWO CLERKS. ONE SAYS GOD SENT THE DREAM AS A WARNING. THE OTHER SAYS IT IS THE DEVIL\'S TRAP. NAMING THE DEVIL COSTS A FORFEIT.',
      source: 'DREAMS COME FROM OUTSIDE, FROM GOD OR FROM THE DEVIL (SG). JOINVILLE\'S HOUSE RULE ON NAMING THE DEVIL (JV). BOARD: "DIO SI, IL DIAVOLO NO".',
      script: () => [
        call((ctx) => {
          ctx.setStage('darkwood', { at: '5' });
          ctx.addActor('black', 'clerkA', '8', { kind: 'idle', face: 'player' });
          ctx.addActor('white', 'clerkB', { x: ctx.marker('8').x + 1.6, y: ctx.marker('8').y + 0.6 }, { kind: 'idle', face: 'player' });
        }),
        say('clerkB', 'GOD SENT THIS DREAM. IT IS A WARNING. TAKE IT LITERALLY.'),
        say('clerkA', 'IT IS A TRAP. YOU KNOW WHOSE.'),
        say('clerkB', 'MANY SAY DREAMS ARE FABLES AND LIES. HOUSE RULE: WHOEVER NAMES THE OTHER ONE PAYS A FORFEIT.'),
        ask('clerkA', 'SO. WHO SENT IT?', [
          { label: 'GOD SENT IT. EVERY OMEN COUNTS.', effects: { grace: 5, flags: { omens: 'literal' } } },
          { label: 'THE DEVIL SENT IT.', effects: { grace: -10, flags: { omens: 'trap', namedDevil: true } }, then: [say('clerkB', 'FORFEIT! YOU SAID HIS NAME.')] },
          { label: 'DREAMS ARE FABLES AND LIES.', effects: { flags: { omens: 'fable' } }, then: [say('clerkA', 'THEN WHY ARE YOU STILL IN ONE?')] },
        ]),
        say('clerkB', 'FROM NOW ON: GOD, YES. THE OTHER ONE, NO. IT COSTS GRACE.'),
        say('zampano', 'THERE WAS A GATE, AND IT WAS ARGUING.', { remembered: true }),
      ],
    },
    {
      id: '2.5',
      title: "Fortune's hands",
      happens: 'FORTUNE APPEARS AND HANDLES HIS LIMBS. HE WAKES INSIDE THE DREAM LIGHTER, STRONGER, WITH A DEEPER BARK: A KNIGHT.',
      source: "CHRISTINE DE PIZAN'S DREAM OF FORTUNE TURNING HER INTO A MAN WHO CAN STEER THE SHIP (SG).",
      script: () => [
        call((ctx) => {
          ctx.setStage('darkwood', { at: '4' });
          ctx.addActor('fortune', 'fortune', { x: ctx.marker('4').x - 1.2, y: ctx.marker('4').y - 1.2 }, { kind: 'idle' });
        }),
        say('fortune', 'HOLD STILL. THIS WILL FEEL LIKE BEING A DIFFERENT SIZE.'),
        ask('fortune', 'GIVE ME YOUR PAWS.', [{ label: '(LET FORTUNE TURN HIM)' }]),
        sound('glitch'),
        call((ctx) => ctx.game.transition.play(null, 0.8, 1)),
        wait(0.5),
        fx({ unlock: 'knight', supervillain: 10 }),
        skin('zampanoKnight'),
        flash(0xfff0a0),
        card('A KNIGHT', 'LIGHTER, STRONGER, WITH A DEEPER BARK', { color: C.cyan, seconds: 2.4 }),
        emote('zampano', 'bark'),
        sound('bark'),
        say('zampano', 'WOOF. (DEEPER.)'),
        say('fortune', 'NOW YOU CAN STEER THE SHIP. TRY NOT TO SINK IT.'),
        behave('fortune', { kind: 'idle' }),
        say('zampano', 'THERE WAS A LADY, AND SHE WAS TURNING ME OVER LIKE A PANCAKE.', { remembered: true }),
      ],
    },
  ],
};
