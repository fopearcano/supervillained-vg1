import { STORY } from '../../config';
import type { Point } from '../../entities/actor';
import type { PropEntity } from '../../entities/prop';
import { carry, dropCarried } from '../../story/carry';
import { TugGame, mini } from '../../story/minigames';
import { ask, blackHoleIn, blackHoleOut, branch, call, card, fx, say, sound, stage } from '../../story/steps';
import type { StoryScene } from '../../story/storyScene';
import { walk } from '../../story/walk';
import { C } from '../../ui/retro';
import { spend } from '../state';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';
import { followLeader, lullWalk, placeObject, sounder } from './helpers';

/** 7.3: progress along the march, from the start toward the walls. */
function along(p: Point, start: Point, f: Point): number {
  return (p.x - start.x) * f.x + (p.y - start.y) * f.y;
}

/**
 * Level 7 — Constantinople (first siege, summer 1203; winter 1203–04 to April 1204). Zampanò is
 * Robert de Clari, a knight of very little consequence. The day he will remember for the rest of
 * his life is the one on which he manages to keep walking. Then the breach and the oath: the
 * same street has three narrators. Cast: Sbrimbrulon as Pierre d'Amiens; Bagnaskiz as Alexios III,
 * then Alexios V; Confusione as Aleaume; Jack; Santina at a window.
 */
export const CH7: ChapterDef = {
  number: 7,
  title: CHAPTER_TITLES[6],
  intro: 'ZAMPANO IS ROBERT DE CLARI, A KNIGHT OF VERY LITTLE CONSEQUENCE. THE DAY HE WILL REMEMBER FOR THE REST OF HIS LIFE IS THE ONE ON WHICH HE MANAGES TO KEEP WALKING.',
  cast: "SBRIMBRULON AS PIERRE D'AMIENS; BAGNASKIZ AS ALEXIOS III, THEN ALEXIOS V; CONFUSIONE AS ALEAUME; JACK; SANTINA AT A WINDOW",
  theme: 'constantinople',
  music: 'medieval',
  professor: {
    after: '4C',
    text: 'A FIGURE THE SIZE OF A GIRL LEANS OUT OF A WINDOW, AND THE WIND TAKES HER WORDS. ONLY AFTERWARDS, IN CLARI\'S TELLING, DO THE RIDERS LOOK LIKE ANGELS. WHO HEARD HER, I COULD NOT TELL YOU.',
  },
  subLevels: [
    {
      id: '7.1',
      title: 'Looking both ways',
      happens:
        "THE CITY FILLS THE SCREEN IN SATURATED COLOR. LOOK FROM THE CAMP TOWARDS THE DOMES, THEN THROUGH A RESIDENT'S WINDOW AT THE STRANGERS ACROSS THE WATER. ROW YOUNG ALEXIOS ALONG THE WALLS SO HIS SUPPOSED SUBJECTS CAN RECOGNIZE HIM. THE SHOUTING SENDS THE BOAT BACK. NO AMOUNT OF ROWING WILL MAKE HIM WELCOME.",
      source: 'BARBERO, LA QUARTA CROCIATA: THE ARRIVAL; NIKETAS CHONIATES ON THE STRANGERS.',
      script: () => [
        call((ctx) => {
          ctx.setStage('city', { at: 'S' });
          ctx.bleach = -0.6;
        }),
        card('CONSTANTINOPLE', 'THE CITY FILLS THE SCREEN', { color: C.yellow, seconds: 2 }),
        walk({
          objective: 'LOOK FROM THE CAMP TOWARDS THE DOMES',
          action: 'LOOK',
          pickups: [
            { at: '7', kind: 'marvel', label: 'THE GREAT WALLS', text: 'TOWER AFTER TOWER, AS FAR AS THE SEA', effects: { marvel: 'THE GREAT WALLS', commozione: 3 } },
            { at: '3', kind: 'marvel', label: 'THE CITY OF ROOFS', text: 'EVERY ROOF IS FULL OF PEOPLE STARING BACK', effects: { marvel: 'THE CITY OF ROOFS', commozione: 3 } },
            { at: '4', kind: 'marvel', label: 'THE GOLDEN DOMES', text: 'THEY SHINE EVEN WHEN THE SUN DOES NOT', effects: { marvel: 'THE GOLDEN DOMES', commozione: 3 } },
          ],
          onAction: (ctx) => ctx.say('OOOH.', { x: ctx.player.gx, y: ctx.player.gy }, C.yellow),
        }),
        card("THROUGH A RESIDENT'S WINDOW", 'THE STRANGERS ACROSS THE WATER', { color: '#c8a0ff', seconds: 2 }),
        say('greek', 'IN THE YEAR SIX THOUSAND SEVEN HUNDRED AND ELEVEN, THE BEARDLESS STRANGERS CAME. THEY SHAVE. EVEN THEIR CHINS.'),
        say('voice', 'ROW YOUNG ALEXIOS ALONG THE WALLS. HIS SUBJECTS WILL RECOGNIZE HIM.'),
        mini(() => new TugGame({ objective: 'ROW YOUNG ALEXIOS ALONG THE WALLS', label: 'ROW! (TAP)', friend: 'prince' }), { lost: { commozione: 3 } }),
        say('greek', 'WHO IS THAT? GO AWAY!'),
        card('THE SHOUTING SENDS THE BOAT BACK', 'NO AMOUNT OF ROWING WILL MAKE HIM WELCOME', { color: C.red, seconds: 2.4 }),
        say('zampano', 'THERE WAS A PRINCE, AND NOBODY HAD EVER SEEN HIM.', { remembered: true }),
      ],
    },
    {
      id: '7.2',
      title: "The Doge's banner",
      happens:
        "WATCH FOR THE BLIND DANDOLO'S BANNER AT THE PROW. FOLLOW IT THROUGH THE CONFUSION OF THE LANDING WHILE THE GALLEYS WORK THEIR LADDERS AND AXE-BEARING GUARDS APPEAR AT THE PARAPET. CARRY WORD TO THE LANDWARD CAMP: A MUCH LARGER FORCE HAS COME OUT TO MEET THEM.",
      source: "BARBERO, LA QUARTA CROCIATA: DANDOLO'S LANDING.",
      script: () => {
        let banner: PropEntity | null = null;
        return [
          call((ctx) => {
            ctx.setStage('field', { at: 'S' });
            ctx.addActor('doge', 'doge', { x: ctx.marker('S').x - 0.6, y: ctx.marker('S').y - 1 }, { kind: 'idle', face: 'N' });
            banner = placeObject(ctx, 'banner', { x: ctx.marker('S').x - 0.3, y: ctx.marker('S').y - 1.1 });
          }),
          say('doge', 'I AM OLD AND BLIND. GIVE ME THE BANNER OF SAINT MARK AND PUT ME ASHORE.'),
          card('THE LANDING', 'LADDERS FROM THE GALLEYS. CONFUSION EVERYWHERE.', { color: C.orange, seconds: 1.8 }),
          followLeader({
            objective: "FOLLOW THE DOGE'S BANNER THROUGH THE LANDING",
            leader: 'doge',
            path: ['3', { x: 8.5, y: 12.5 }, '1'],
            speed: 1.9,
            onReach: (ctx, k) => {
              if (k !== 1) return;
              ['8', '9', '7'].forEach((m, n) => ctx.addActor(`v${n}`, 'varangian', m, { kind: 'idle', face: 'S' }));
              ctx.notice('AXE-BEARING GUARDS AT THE PARAPET', C.red);
            },
            onUpdate: (ctx) => {
              const d = ctx.actor('doge');
              banner?.setPosition(d.gx + 0.3, d.gy - 0.1);
            },
          }),
          say('doge', 'GO. TELL THE CAMP ON THE LAND SIDE. WHAT COMES OUT OF THAT GATE IS NOT SMALL.'),
          carry('WORD FOR THE CAMP'),
          walk({ objective: 'CARRY WORD TO THE LANDWARD CAMP', goal: { reach: '2', label: 'LANDWARD CAMP' } }),
          dropCarried(),
          card('A MUCH LARGER FORCE', 'HAS COME OUT TO MEET THEM', { color: C.red, seconds: 2.2 }),
          say('zampano', 'THERE WAS A BANNER, AND A BLIND MAN WAS CARRYING IT.', { remembered: true }),
        ];
      },
    },
    {
      id: '7.3',
      title: 'Stay beside Pierre',
      happens:
        "BAGNASKIZ WEARS THE FACE OF ALEXIOS III. THE COUNT OF FLANDERS TURNS BACK. SBRIMBRULON, AS PIERRE D'AMIENS, AND THE COUNT OF SAINT-POL GO ON AT A WALK. HOLD ZAMPANO LEVEL WITH PIERRE'S SHOULDER; IF HE BOLTS OR DROPS BACK, EASE INTO STEP AGAIN. FLANDERS COMES ROUND AND REJOINS THEM. THE EMPEROR TURNS FOR THE CITY. NOBODY STRIKES A BLOW.",
      source: "BARBERO, LA QUARTA CROCIATA: PIERRE'S WALK, THE WINDOWS. CLARI TELLS THE VANGUARD STORY.",
      script: () => {
        const S = STORY.SHOULDER;
        let nerve = 1;
        let warnT = 0;
        let rejoined = false;
        let windowT = 1.5;
        const reset = (ctx: StoryScene) => {
          const s0 = ctx.marker('S');
          ctx.player.setPosition(s0.x, s0.y);
          ctx.actor('sbrim').setPosition(s0.x - 1, s0.y);
          ctx.actor('sbrim').setBehavior({ kind: 'goto', to: { x: ctx.marker('1').x - 1, y: ctx.marker('1').y }, speed: S.SPEED });
          ctx.world!.snapCamera();
          nerve = 1;
          ctx.metrics.restarts++;
        };
        return [
          call((ctx) => {
            ctx.setStage('field');
            ctx.addActor('emperor', 'bagnaskizEmperor', '9', { kind: 'idle', face: 'S' });
            ctx.addActor('v1', 'varangian', '8', { kind: 'idle', face: 'S' });
            ctx.addActor('v2', 'varangian', '7', { kind: 'idle', face: 'S' });
            ctx.addActor('flanders', 'knight', '3', { kind: 'idle', face: 'N' });
            ctx.addActor('window', 'santina', { x: 13.5, y: 7.5 }, { kind: 'idle', face: 'SW' });
            const s0 = ctx.marker('S');
            ctx.addActor('sbrim', 'sbrimbrulon', { x: s0.x - 1, y: s0.y }, { kind: 'idle', face: 'N' });
            ctx.addActor('stpol', 'knight', { x: s0.x + 1, y: s0.y + 0.4 }, { kind: 'idle', face: 'N' });
          }),
          say('emperor', 'I RIDE OUT. ALL OF YOU. AT THEM.'),
          card('CHARGE?', '', { color: C.red, seconds: 1 }),
          say('knight', 'THE VANGUARD TURNS BACK! BACK TO THE CAMP!'),
          call((ctx) => ctx.actor('flanders').setBehavior({ kind: 'goto', to: ctx.marker('2'), speed: 3.2, run: true })),
          say('sbrimbrulon', 'WE WILL NOT TURN BACK AT ALL. WE GO ON. AT A WALK. STAY AT MY SHOULDER.'),
          call((ctx) => {
            ctx.actor('sbrim').setBehavior({ kind: 'goto', to: { x: ctx.marker('1').x - 1, y: ctx.marker('1').y }, speed: S.SPEED });
            ctx.actor('stpol').setBehavior({ kind: 'follow', target: ctx.actor('sbrim'), distance: 2, speed: 2, side: 1.2 });
          }),
          walk({
            objective: "HOLD LEVEL WITH PIERRE'S SHOULDER",
            noRun: true,
            pilot: (ctx) => {
              const s = ctx.actor('sbrim');
              return { target: { x: s.gx + 1, y: s.gy }, hold: true };
            },
            onUpdate: (ctx, w, dt) => {
              const p = ctx.player;
              const sb = ctx.actor('sbrim');
              const s0 = ctx.marker('S');
              const g = ctx.marker('1');
              const fl = Math.hypot(g.x - s0.x, g.y - s0.y) || 1;
              const f = { x: (g.x - s0.x) / fl, y: (g.y - s0.y) / fl };
              const diff = along({ x: p.gx, y: p.gy }, s0, f) - along({ x: sb.gx, y: sb.gy }, s0, f);
              const side = Math.abs((p.gx - sb.gx) * f.y - (p.gy - sb.gy) * f.x);
              const level = Math.abs(diff) < S.BAND && side < 3;
              nerve = Math.max(0, Math.min(1, nerve + (level ? S.GAIN : -S.LOSE) * dt));
              warnT -= dt;
              if (!level && warnT <= 0) {
                warnT = 2.4;
                ctx.notice(diff > 0 ? 'HE BOLTS AHEAD. EASE BACK INTO STEP' : side >= 3 ? 'STAY AT HIS SHOULDER' : 'HE DROPS BACK. EASE INTO STEP', C.orange);
              }
              ctx.hud.setMode({ label: 'NERVE: LEVEL WITH PIERRE', value: nerve, color: 0xff7a1f });
              const done = along({ x: sb.gx, y: sb.gy }, s0, f) / fl;
              if (!rejoined && done > 0.45) {
                rejoined = true;
                ctx.actor('flanders').setBehavior({ kind: 'follow', target: sb, distance: 2.4, speed: 3, side: -1.2 });
                ctx.notice('FLANDERS COMES ROUND AND REJOINS THEM', C.cyan);
              }
              windowT -= dt;
              if (windowT <= 0 && done > 0.25) {
                windowT = 2.2;
                ctx.say('(...THE WIND TAKES HER WORDS...)', { x: 13.5, y: 7.5 }, '#c8a0ff');
              }
              if (nerve <= 0) {
                ctx.metrics.nerveBroken++;
                ctx.interrupt([card('OUT OF STEP', "BACK TO THE START: STAY LEVEL WITH PIERRE'S SHOULDER", { color: C.red, seconds: 2 }), call(() => reset(ctx))]);
                return;
              }
              if (done > 0.95 && level) w.complete = true;
            },
          }),
          call((ctx) => {
            ctx.actor('emperor').setBehavior({ kind: 'goto', to: { x: ctx.marker('9').x, y: ctx.marker('9').y - 2 }, speed: 2.2 });
            ctx.actor('v1').setBehavior({ kind: 'goto', to: { x: ctx.marker('8').x, y: ctx.marker('8').y - 2 }, speed: 2 });
            ctx.actor('v2').setBehavior({ kind: 'goto', to: { x: ctx.marker('7').x, y: ctx.marker('7').y - 2 }, speed: 2 });
            ctx.apply({ supervillain: 15, value: 'Physical courage', flags: { vanguard: true } });
          }),
          card('THE EMPEROR TURNS FOR THE CITY', 'NOBODY STRIKES A BLOW', { color: C.cyan, seconds: 2.4 }),
          say('marshal', 'EVERYONE WAS VERY GLAD.'),
          say('zampano', 'THERE WERE A LOT OF THEM, AND THEY WERE SHOUTING.'),
          say('sbrimbrulon', "LET THEM SHOUT. BY GOD'S COIF, WE WILL TALK ABOUT TODAY IN THE LADIES' CHAMBERS."),
          say('zampano', 'THERE WAS A WINDOW, AND THE WIND TOOK WHAT SHE SAID.', { remembered: true }),
        ];
      },
    },
    {
      id: '7.4',
      title: 'Tourists and fire',
      happens:
        'ALEXIOS III FLEES. ISAAC II IS RESTORED AND HIS SON BECOMES ALEXIOS IV. FOR A TIME THE PILGRIMS VISIT SHRINES. FIND A FAMILIAR TURN BY THE MOSQUE ON THE WAY TO A MARVEL. WHEN WESTERNERS ATTACK IT, MUSLIM RESIDENTS AND THEIR CHRISTIAN NEIGHBORS DEFEND IT TOGETHER. SMOKE CHOKES THE SIGHTSEEING ROUTE. LEAD A RESIDENT BACK ALONG THE STREET YOU LEARNED BEFORE THE FIRE.',
      source: 'BARBERO, LA QUARTA CROCIATA: THE MOSQUE AND THE GREAT FIRE. NIKETAS CHONIATES GIVES THE FIRE A RESIDENT\'S ADDRESS.',
      script: () => [
        stage('city', [{ name: 'watson', who: 'watson', at: { x: 19.5, y: 20.5 }, face: 'NW' }], { at: 'S' }),
        card('ALEXIOS III FLEES', 'ISAAC II IS RESTORED. HIS SON BECOMES ALEXIOS IV.', { color: C.yellow, seconds: 2.2 }),
        say('watson', 'MAN, IT IS PEACE. WE ARE TOURISTS NOW.'),
        walk({
          objective: 'SIGHTSEEING: TAKE THE TURN BY THE MOSQUE, ON TO THE MARVELS',
          action: 'LOOK',
          pickups: [
            { at: '3', kind: 'spot', label: 'THE TURN BY THE MOSQUE', text: 'REMEMBER THIS STREET' },
            { at: '5', kind: 'marvel', label: 'THE GOLDEN PALACE', text: 'FIVE HUNDRED HALLS, ALL IN GOLD MOSAIC', effects: { marvel: 'THE GOLDEN PALACE', commozione: 3 } },
            { at: '8', kind: 'relic', label: 'THE CHAPEL OF RELICS', text: 'MORE RELICS THAN THERE ARE SAINTS', effects: { marvel: 'THE CHAPEL OF RELICS', commozione: 3 } },
          ],
          onAction: (ctx) => ctx.say('OOOH.', { x: ctx.player.gx, y: ctx.player.gy }, C.yellow),
        }),
        card('THE MOSQUE', 'WESTERNERS ATTACK IT. MUSLIM RESIDENTS AND THEIR CHRISTIAN NEIGHBORS DEFEND IT TOGETHER.', { color: C.cyan, seconds: 3 }),
        call((ctx) => {
          ctx.fog = STORY.SMOKE;
          ctx.addActor('resident', 'greek', { x: ctx.player.gx + 0.8, y: ctx.player.gy + 0.4 }, { kind: 'follow', target: ctx.player, distance: 1, speed: 3, side: 0.5 });
        }),
        say('greek', 'THE SMOKE! I CANNOT SEE MY OWN STREET. YOU WALKED IT TODAY: TAKE ME BACK.'),
        walk({
          objective: 'LEAD THE RESIDENT BACK ALONG THE STREET YOU LEARNED',
          goal: { reach: 'S', label: 'OUT' },
          checkpoints: ['3'],
          fire: { from: '1', spread: 0.35, startAfter: (w) => w.time > 0.6 },
        }),
        call((ctx) => (ctx.fog = 0)),
        say('greek', 'THAT WAS MY HOUSE. IT HAD A VERY GOOD COURTYARD.'),
        say('zampano', 'THERE WAS A CITY, AND IT WAS ON FIRE, AND I KNEW ONE STREET.', { remembered: true }),
      ],
    },
    {
      id: '7.5',
      title: "The usurper's wedding night",
      happens:
        "A DOOR OPENS INTO CHRETIEN DE TROYES'S CLIGES. A DRUGGED EMPEROR EMBRACES EMPTY AIR. SLIP BY WITH THE PERFECTLY AWAKE BRIDE AND LISTEN FOR THE SOUND OF THE PREVIOUS ROOM. A COIN SPINNING TO A STOP TAKES ZAMPANO BACK TO THE COURT THAT CAN NO LONGER PAY.",
      source: 'BARBERO, IL SOGNO NEL MEDIOEVO: THE WEDDING NIGHT IN CLIGES.',
      blackHole: { where: 'A ROMANCE. A WEDDING NIGHT.', value: 'A dream embraces nothing' },
      script: () => {
        const clink = sounder('...CLINK...', C.yellow);
        return [
          ...blackHoleIn('A DOOR OPENS INTO A ROMANCE. CLIGES.'),
          call((ctx) => {
            ctx.setStage('palace');
            const e = ctx.addActor('emperor', 'bagnaskizEmperor', '4', { kind: 'flail', speed: 1.6, center: ctx.marker('4'), radius: 2.4 });
            e.sight = { range: 3, halfAngle: 0.6 };
            ctx.addActor('bride', 'lady', '8', { kind: 'idle', face: 'SW' });
          }),
          say('voice', 'THE POTION WORKS. HE EMBRACES EMPTY AIR, AND BELIEVES ALL OF IT.'),
          say('emperor', 'AH, MY LOVE! AH! MMMH! (HE IS HUGGING THE AIR.)'),
          walk({ objective: 'SLIP BY TO THE BRIDE', goal: { reach: '8', label: 'THE BRIDE' }, noRun: true, caught: 'restart', caughtText: 'HE HUGGED YOU INSTEAD' }),
          say('lady', 'I AM PERFECTLY AWAKE. LET US GO. LISTEN: THE PREVIOUS ROOM IS THAT WAY.'),
          call((ctx) => ctx.actor('bride').setBehavior({ kind: 'follow', target: ctx.player, distance: 1, speed: 2.6, side: 0.4 })),
          walk({
            objective: 'LISTEN FOR THE SOUND OF THE PREVIOUS ROOM',
            goal: { reach: '9', hidden: true },
            noRun: true,
            caught: 'restart',
            caughtText: 'HE HUGGED YOU INSTEAD',
            onUpdate: (ctx, _w, dt) => clink(ctx, ctx.marker('9'), dt),
          }),
          sound('coin'),
          card('A COIN SPINS TO A STOP', 'BACK AT THE COURT THAT CAN NO LONGER PAY', { color: C.yellow, seconds: 2.2 }),
          say('zampano', 'THERE WAS A BRIDE, AND SHE WAS THE ONLY ONE AWAKE.', { remembered: true }),
          ...blackHoleOut('A dream embraces nothing'),
        ];
      },
    },
    {
      id: '7.6',
      title: 'A third Alexios',
      happens:
        'WALK INTO THE THRONE ROOM WITH THE ENVOYS, LISTEN TO THE FORMAL CHALLENGE OVER THE UNPAID PROMISES AND WALK OUT AT THE SAME PACE. SOON ISAAC II IS DEAD, ALEXIOS IV IS KILLED AND ALEXIOS V HOLDS POWER. BAGNASKIZ APPEARS IN HIS THIRD ROLE, WEARING A DIFFERENT CROWN. THE GATES CLOSE TO THE PILGRIMS.',
      source: 'BARBERO, LA QUARTA CROCIATA: THE EMBASSY AND THE COUP.',
      script: () => {
        const runCheck = (ctx: StoryScene) => {
          if (!ctx.player.running) return;
          ctx.metrics.ran++;
          ctx.interrupt([card('YOU RAN', 'ENVOYS DO NOT RUN. AGAIN.', { color: C.red, seconds: 1.6 }), call(() => ctx.player.setPosition(ctx.marker('S').x, ctx.marker('S').y))]);
        };
        return [
          call((ctx) => {
            ctx.setStage('palace');
            ctx.addActor('alexios', 'prince', '1', { kind: 'idle', face: 'S' });
            ['2', '3', '5', '6'].forEach((m, k) => ctx.addActor(`g${k}`, 'varangian', m, { kind: 'idle', face: 'player' }));
            ctx.addActor('envoy', 'knight', { x: ctx.marker('S').x - 0.8, y: ctx.marker('S').y }, { kind: 'follow', target: ctx.player, distance: 1, speed: 2.2, side: -0.8 });
            ctx.addActor('envoy2', 'marquis', { x: ctx.marker('S').x + 0.8, y: ctx.marker('S').y }, { kind: 'follow', target: ctx.player, distance: 1, speed: 2.2, side: 0.8 });
          }),
          say('voice', 'THE EMPERORS HAVE STOPPED PAYING. WALK IN WITH THE ENVOYS. WALK OUT AT THE SAME PACE.'),
          walk({ objective: 'WALK INTO THE THRONE ROOM WITH THE ENVOYS', goal: { reach: '4', radius: 1 }, onUpdate: (ctx) => runCheck(ctx) }),
          say('knight', '(THE ENVOY) YOU SWORE TO PAY. YOU HAVE NOT PAID. FROM NOW ON, WE ARE NO LONGER FRIENDS. THAT IS OUR CHALLENGE.'),
          say('prince', '...'),
          walk({ objective: 'WALK OUT AT THE SAME PACE. DO NOT RUN', goal: { reach: 'S', radius: 1 }, onUpdate: (ctx) => runCheck(ctx) }),
          card('ALIVE', 'THEY WALK OUT ALIVE. NOBODY CAN BELIEVE IT.', { color: C.green, seconds: 2 }),
          card('SOON', 'ISAAC II IS DEAD. ALEXIOS IV IS KILLED. ALEXIOS V HOLDS POWER.', { color: '#c070f0', seconds: 2.6 }),
          call((ctx) => {
            const u = ctx.addActor('usurper', 'bagnaskizEmperor', { x: ctx.player.gx - 1.4, y: ctx.player.gy - 1 }, { kind: 'idle', face: 'player' });
            u.sprite.tint = 0xffd890;
          }),
          say('emperor', 'A DIFFERENT CROWN, LITTLE KNIGHT. SAME FACE. THE GATES ARE CLOSED.'),
          card('THE GATES CLOSE', 'TO THE PILGRIMS', { color: C.red, seconds: 2 }),
          say('zampano', 'THERE WAS A THRONE, AND I WALKED OUT OF IT AT A WALK.', { remembered: true }),
        ];
      },
    },
    {
      id: '7.7',
      title: 'The hole in the wall',
      happens:
        "HEAR THE PILGRIMS SWEAR TO RESPECT WOMEN, SPARE CHURCHES AND POOL THE SPOILS. THE FIRST APRIL ASSAULT FAILS. ON THE NEXT ATTEMPT CONFUSIONE, AS CLARI'S CLERIC BROTHER ALEAUME, SQUEEZES INTO A BREACH. TRY TO HOLD HIM BY A HIND LEG: HE WRIGGLES FREE. IF ZAMPANO KEPT VIGIL, THE CAT CALLS BACK TO HIM; OTHERWISE FOLLOW THE RATTLE OF HIS MAIL. WITHIN THE WALL, THE LITTLE CAT WAITS FOR HIM.",
      source: "BARBERO, LA QUARTA CROCIATA: ALEAUME'S BREACH.",
      script: () => {
        const rattle = sounder('...RATTLE...', '#b8b8c8');
        return [
          stage('breach', [
            { name: 'legate', who: 'legate', at: '3', face: 'SE' },
            { name: 'conf', who: 'confusione', at: '4', face: 'SW' },
            { name: 'jack', who: 'jack', at: { x: 9.5, y: 10.5 }, face: 'N' },
          ]),
          say('legate', 'SWEAR. NO WOMAN TOUCHED. NO CHURCH ROBBED. ALL SPOILS IN COMMON.'),
          ask('legate', 'SWEAR.', [{ label: 'SO HELP ME GOD.', effects: { grace: 5, flags: { sworn: true } } }]),
          say('jack', 'SO HELP ME GOD. (HE IS CROSSING HIS FINGERS.)'),
          call((ctx) => {
            if (ctx.state.flags.clothRoute) ctx.notice('ALL SPOILS IN COMMON: LIKE THE BOLT OF CLOTH AT ZARA', C.yellow);
          }),
          card('THE FIRST APRIL ASSAULT FAILS', '', { color: C.orange, seconds: 2 }),
          card('THE NEXT ATTEMPT', 'A HOLE IN THE WALL. NOBODY DARES ENTER.', { color: C.yellow, seconds: 2 }),
          say('confusione', 'I DARE. ON HANDS AND FEET.'),
          mini(() => new TugGame(), { lost: { commozione: 6 } }),
          call((ctx) => ctx.actor('conf').setBehavior({ kind: 'goto', to: ctx.marker('2'), speed: 2.6 })),
          say('zampano', 'I HAD HIS HIND LEG. I HAD IT.'),
          branch(
            (s) => s.flags.comradeship === true,
            [
              say('confusione', '(FROM INSIDE THE WALL) ZAMPANO! YOU SAT BY THE BODY AT THE WAKE. THIS WAY.'),
              walk({ objective: 'FOLLOW HIS VOICE IN', goal: { reach: '2', radius: 0.9 }, noRun: true }),
            ],
            [
              say('voice', 'HE IS GONE INTO THE DARK. ONLY HIS MAIL RATTLES.'),
              walk({
                objective: 'FOLLOW THE RATTLE OF HIS MAIL',
                goal: { reach: '2', radius: 0.9, hidden: true },
                noRun: true,
                onUpdate: (ctx, _w, dt) => {
                  const c = ctx.actor('conf');
                  rattle(ctx, { x: c.gx, y: c.gy }, dt);
                },
              }),
            ],
          ),
          fx({ supervillain: 10, value: 'Comradeship', flags: { followed: true } }),
          card('WITHIN THE WALL', 'THE LITTLE CAT WAITS FOR HIM', { color: C.cyan, seconds: 2 }),
          say('zampano', 'THERE WAS A HOLE, AND MY FRIEND WAS IN IT.', { remembered: true }),
        ];
      },
    },
    {
      id: '7.8',
      title: 'Whose street was it?',
      happens:
        "DURING THE THREE DAYS OF PLUNDER, CLARI FINDS WONDERS TO FILL HIS BOOK AND REMEMBERS AN ORDERLY SACK. TURN THE PAGE: THE SAME DOORWAY NOW BELONGS TO NIKETAS'S HOUSEHOLD, LEAVING UNDER A VENETIAN FRIEND'S PROTECTION. JACK DRAGS A GIRL OUT OF THE GROUP. WAIT FOR A LULL AND CALL THE OTHER PILGRIMS TO THEIR OATH, OR STAND SILENT WHILE NIKETAS CALLS THEM HIMSELF. THEY FREE HER. LATER THE GOLD IS MISSING FROM THE COMMON PILE.",
      source: "BARBERO, LA QUARTA CROCIATA: CLARI'S MARVELS AND NIKETAS'S FLIGHT. JACK'S ROLE IS A GAME ADAPTATION.",
      script: () => {
        let called = false;
        return [
          fx({ flags: { oath: 'undecided' } }),
          stage('city', [], { at: 'S' }),
          card('THREE DAYS', 'CLARI REMEMBERS AN ORDERLY SACK, AND FILLS HIS BOOK', { color: C.orange, seconds: 2.2 }),
          walk({
            objective: 'FILL THE BOOK OF MARVELS',
            action: 'LOOK',
            pickups: [
              { at: '1', kind: 'marvel', label: 'THE GREAT CHURCH', text: 'A DOME HUNG FROM HEAVEN BY A CHAIN', effects: { marvel: 'THE GREAT CHURCH', commozione: 5 } },
              { at: '7', kind: 'marvel', label: 'THE HIPPODROME', text: 'THIRTY TIERS OF SEATS, AND NOBODY RACING', effects: { marvel: 'THE HIPPODROME', commozione: 5 } },
              { at: '2', kind: 'marvel', label: 'THE STATUES', text: 'BRONZE PEOPLE, BRONZE BEASTS, ALL STARING', effects: { marvel: 'THE STATUES', commozione: 5 } },
            ],
            onAction: (ctx) => ctx.say('OOOH.', { x: ctx.player.gx, y: ctx.player.gy }, C.yellow),
          }),
          sound('glitch'),
          call((ctx) => ctx.game.transition.play(null, 0.6, 1)),
          card('TURN THE PAGE', "THE SAME DOORWAY NOW BELONGS TO NIKETAS'S HOUSEHOLD", { color: '#c8a0ff', seconds: 2.4 }),
          call((ctx) => {
            ctx.addActor('niketas', 'greek', '9', { kind: 'idle', face: 'E' });
            ctx.addActor('venetian', 'crowdB', { x: 4.5, y: 20.5 }, { kind: 'idle', face: 'E' });
            ctx.addActor('family', 'crowdC', { x: 3.5, y: 21.5 }, { kind: 'idle', face: 'E' });
            const jack = ctx.addActor('jack', 'jack', { x: 4.5, y: 19.5 }, { kind: 'goto', to: { x: 7.5, y: 16.5 }, speed: 0.45 });
            ctx.addActor('girl', 'lady', { x: 5, y: 19.8 }, { kind: 'follow', target: jack, distance: 0.7, speed: 0.6 });
            ctx.addActor('p1', 'crowdA', { x: 8.5, y: 18.5 }, { kind: 'wander', center: { x: 8.5, y: 18.5 }, radius: 1, speed: 0.8 });
            ctx.addActor('p2', 'knight', { x: 9.5, y: 19.5 }, { kind: 'wander', center: { x: 9.5, y: 19.5 }, radius: 1, speed: 0.8 });
            ctx.player.setPosition(10.5, 17.5);
            ctx.world!.snapCamera();
          }),
          say('voice', 'NIKETAS AND HIS HOUSEHOLD ARE LEAVING, UNDER A VENETIAN FRIEND\'S PROTECTION. JACK DRAGS A GIRL OUT OF THE GROUP.'),
          lullWalk({
            objective: 'WAIT FOR A LULL AND CALL THE PILGRIMS TO THEIR OATH, OR STAND SILENT',
            action: 'CALL',
            source: 'p1',
            stand: { x: 7.5, y: 18 },
            range: 3.6,
            noise: ['LOOT!', 'THIS WAY!', 'GOLD!', 'WHO HAS A SACK?'],
            noiseLabel: 'THE STREET IS LOUD',
            drowned: 'NOBODY HEARS HIM OVER THE LOOTING. WAIT FOR A LULL',
            actText: 'NO WOMAN TOUCHED! YOU SWORE!',
            need: 1,
            pilotActs: (p) => p.policy.ending === 'knight',
            onGood: (ctx) => {
              if (!spend(ctx.state, 'commozione', STORY.COST.OATH_BARK)) ctx.notice('IT TAKES ALL HE HAS LEFT', C.orange);
              else ctx.notice(`-${STORY.COST.OATH_BARK} COMMOZIONE`, C.red);
              called = true;
              ctx.apply({ flags: { oath: 'enforced' }, supervillain: 15, grace: 5, standing: -6, value: 'Kept oaths', remembered: 'NO WOMAN TOUCHED! YOU SWORE! (IN HIS OWN WORDS)' });
            },
            onUpdate: (ctx, w) => {
              // Silence: Niketas calls them himself.
              if (!called && w.time > 16) {
                ctx.say('YOU SWORE AN OATH! LET HER GO!', ctx.marker('9'), '#f0f0f0');
                ctx.apply({ flags: { oath: 'silent' }, remembered: '"YOU SWORE AN OATH! LET HER GO!" (NIKETAS, OVERHEARD)' });
                w.complete = true;
              }
            },
          }),
          call((ctx) => {
            ctx.actor('jack').setBehavior({ kind: 'flee', speed: 3, radius: 6 });
            ctx.actor('girl').setBehavior({ kind: 'goto', to: { x: 3.5, y: 20.8 }, speed: 1.6 });
          }),
          branch(
            (s) => s.flags.oath === 'enforced',
            [say('knight', '(THE PILGRIMS) HE IS RIGHT. WE SWORE. LET HER GO, JACK.'), say('jack', 'ALL RIGHT! ALL RIGHT! I WAS ONLY... CARRYING HER. FOR SAFETY.')],
            [say('knight', '(THE PILGRIMS) THE GREEK IS RIGHT. WE SWORE. LET HER GO, JACK.'), say('voice', 'ZAMPANO SAID NOTHING. HE HEARD EVERY WORD.')],
          ),
          say('greek', 'SHE IS BACK WITH HER FAMILY. I WILL WRITE DOWN WHO SPOKE.'),
          walk({ objective: 'GO TO THE COMMON PILE', goal: { reach: '0', label: 'THE PILE' } }),
          call((ctx) => {
            if (ctx.state.flags.clothRoute) ctx.notice('LIKE THE BOLT OF CLOTH AT ZARA: FROM A HOUSE TO THE PILE', C.yellow);
          }),
          card('THE COMMON PILE', 'THE GOLD IS MISSING. THE POOR KNIGHTS RECEIVE SILVER.', { color: '#d8d8e8', seconds: 2.4 }),
          fx({ coins: 2 }),
          say('zampano', 'THERE WAS GOLD, AND THEN THERE WAS SILVER, AND THEN THERE WAS ME.', { remembered: true }),
          sound('glitch'),
          card('JERUSALEM', 'LOADING...', { color: '#f6c0e0', seconds: 2.4, dim: 0.9 }),
          card('', 'THE PASTEL CITY NEVER LOADS', { color: '#b070ff', seconds: 2, dim: 0.95, flash: true }),
        ];
      },
    },
  ],
};

