import { STORY } from '../../config';
import type { PropEntity } from '../../entities/prop';
import { carry, dropCarried } from '../../story/carry';
import { ask, call, card, face, flash, fx, move, prof, say, shake, skin, sound, stage, wait } from '../../story/steps';
import type { StoryScene } from '../../story/storyScene';
import { walk } from '../../story/walk';
import { C } from '../../ui/retro';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';
import { bark, distTo, followLeader, placeObject } from './helpers';

/** Heads popping up along the fences to watch (Jack calls them). */
function heads(ctx: StoryScene): void {
  ctx.addActor('h1', 'crowdA', '3', { kind: 'idle', face: 'player' });
  ctx.addActor('h2', 'crowdB', '4', { kind: 'idle', face: 'player' });
  for (const n of ['h1', 'h2']) ctx.actor(n).emote('bark');
}

/**
 * Level 1 — The Greenzone (Homeland · Outbound, then Santina's gate). Zampanò wakes on the common
 * lawn. The way home runs through a neighborhood where every other dog can walk straight to the
 * water bowl. Cast: everyone as themselves.
 */
export const CH1: ChapterDef = {
  number: 1,
  title: CHAPTER_TITLES[0],
  menuTitle: 'The Greenzone',
  intro: 'ZAMPANO WAKES ON THE COMMON LAWN. THE WAY HOME RUNS THROUGH A NEIGHBORHOOD WHERE EVERY OTHER DOG CAN WALK STRAIGHT TO THE WATER BOWL.',
  cast: 'EVERYONE AS THEMSELVES',
  theme: 'greenzone',
  music: 'greenzone',
  professor: {
    after: 'JV',
    text: 'IN THE MIDDLE AGES, YOU UNDERSTAND, DOGS WALKED INTO CHURCH AND NOBODY SAID A WORD. SO WE ARE NOT GOING TO BE SCANDALISED IF ONE OF THEM TAKES THE CROSS.',
  },
  subLevels: [
    {
      id: '1.0',
      title: 'The Green Zone',
      happens:
        'THE DAILY WALK IN THE PARK. EAT TREATS AGAINST HUNGER, PEE TO CLEAN WHAT THE POOPS SPOIL, CATCH CATS FOR COINS, IGNORE THE BALLS, AND BARK AWAY BAGNASKIZ WHEN HE POLLUTES THE ZONE. AT THE END OF THE WALK, TIRED, HE LIES DOWN ON THE LAWN.',
      source: 'SPEC: THE GREEN ZONE (FROM THE VIDEO). BOARD: THE GREENZONE, BAGNASKIZ THE BULLY.',
      greenZone: 1,
      script: () => [],
    },
    {
      id: '1.1',
      title: 'One step from Jerusalem',
      happens:
        'WALK THE LITTLE MALTESE TOWARDS A PASTEL CITY. HIS HELMET SLIPS DOWN WHENEVER HE LOWERS HIS HEAD. A PAW COMES IN FROM OUTSIDE THE FRAME: CONFUSIONE HAS SLAPPED HIM AWAKE ON THE LAWN. THE CITY GATE IS A GAP IN A HEDGE.',
      source: "BOARD PHOTOS, 16 NOVEMBER: CONFUSIONE'S SLAP (11:53:35).",
      script: () => [
        stage('jerusalem', [], { skinKey: 'zampanoKnight' }),
        card('', 'AFTER THE WALK, ON THE LAWN, HE DOZES OFF...', { color: '#f6c8e0', seconds: 2, dim: 0.9 }),
        card('JERUSALEM', 'ONE STEP AWAY. PASTEL.', { color: '#f6c8e0', seconds: 2.2, dim: 0.3 }),
        walk({
          objective: 'WALK TO THE CITY GATE. KEEP YOUR HEAD UP',
          goal: { reach: '1' },
          noRun: true,
          action: 'BARK',
          onAction: (ctx, w) => {
            bark(ctx, 'DEUS LO VULT!');
            w.data.bow = 0.8;
          },
          onUpdate: (ctx, w, dt) => {
            // The helmet slips down whenever he lowers his head: standing still (sniffing) or barking.
            const V = STORY.VISOR;
            const p = ctx.player;
            const still = Math.hypot(p.vx, p.vy) < 0.2;
            const stillT = still ? ((w.data.stillT as number) ?? 0) + dt : 0;
            const bow = Math.max(0, ((w.data.bow as number) ?? 0) - dt);
            w.data.stillT = stillT;
            w.data.bow = bow;
            const down = stillT > V.STILL_AFTER || bow > 0;
            ctx.visor = down ? Math.min(V.MAX, ctx.visor + V.DOWN_RATE * dt) : Math.max(0, ctx.visor - V.UP_RATE * dt);
            if (down && !w.data.told) {
              w.data.told = true;
              ctx.notice('THE HELMET SLIPS DOWN. WALK ON TO PUSH IT UP', C.cyan);
            }
          },
        }),
        call((ctx) => {
          ctx.visor = 0;
          ctx.addActor('conf', 'confusione', { x: ctx.player.gx + 3.5, y: ctx.player.gy + 3 }, { kind: 'goto', to: { x: ctx.player.gx + 0.6, y: ctx.player.gy + 0.4 }, speed: 8, run: true });
        }),
        card('', 'A PAW COMES IN FROM OUTSIDE THE FRAME', { color: '#f6c8e0', seconds: 0.9, dim: 0 }),
        sound('hurt'),
        flash(),
        shake(8),
        card('SLAP!', '', { color: C.red, seconds: 1.1, dim: 0.2 }),
        stage('neighborhood', [{ name: 'conf', who: 'confusione', at: '4', face: 'NW' }], { skin: 'plain', at: '6', face: 'N' }),
        card('THE LAWN', 'THE CITY GATE WAS A GAP IN THE HEDGE', { color: C.green, seconds: 2.2 }),
        say('confusione', 'YOU WERE SNORING IN LATIN.'),
        say('zampano', 'JERUSALEM WAS ONE STEP AWAY. THE GATE WAS RIGHT HERE.', { remembered: true }),
        say('confusione', 'THAT IS THE HEDGE. IT IS ALWAYS ONE STEP AWAY. GET UP.'),
      ],
    },
    {
      id: '1.2',
      title: "Under the Professor's desk",
      happens:
        'FOLLOW HIS FATHER, A MEDIEVAL HISTORIAN REHEARSING A LECTURE, INTO THE STUDY. SNIFF THE CHAIR LEG, A SUITCASE AND THE HEM OF HIS COAT FOR SCRAPS OF THE LECTURE. OUTSIDE, JACK LETS THE OTHER DOGS PASS BETWEEN TWO GARDEN GATES, BUT ECHOES ZAMPANO\'S BARK UNTIL HEADS POP UP ALONG THE FENCES. AT A CREAK FROM THE WINDOW HE LETS HIM THROUGH.',
      source: 'BOARD: DREAMS ARE FURNISHED WITH DAILY LIFE (SG). THE LECTURE: A FLEET BOUGHT ON CREDIT, A KNIGHT WHO KEPT WALKING, A CITY SEEN FROM ITS WALLS.',
      script: () => {
        let echoes = 0;
        let open = false;
        let tries = 0;
        const letThrough = (ctx: StoryScene) => {
          if (open) return;
          open = true;
          ctx.say('CREAK...', { x: 1.5, y: 1.5 }, '#f0d8a0');
          ctx.insert([
            say('jack', '(A CREAK FROM THE PROFESSOR\'S WINDOW. JACK STEPS ASIDE AS IF HE HAD ALWAYS MEANT TO.)'),
            call((c) => c.actor('jack').setBehavior({ kind: 'goto', to: { x: 8.5, y: 4.5 }, speed: 2.5 })),
          ]);
        };
        return [
          call((ctx) => {
            ctx.setStage('study', { skin: 'plain', at: 'S', face: 'NW' });
            ctx.addActor('prof', 'legs', { x: ctx.marker('S').x - 0.8, y: ctx.marker('S').y - 0.6 }, { kind: 'idle' });
          }),
          say('professor', 'NOW. WHERE WERE WE. THE FOURTH CRUSADE. AGAIN, FROM THE TOP.'),
          followLeader({
            objective: 'FOLLOW YOUR FATHER INTO THE STUDY',
            leader: 'prof',
            path: ['3', '7', '1', '6'],
            speed: 1.4,
            onReach: (ctx, k) => {
              const lines = ['VILLEHARDOUIN, YOU UNDERSTAND, WAS IN ON EVERY SECRET.', 'CLARI SEES EVERYTHING AND IS TOLD NOTHING.', 'NOBODY SAILS IN WINTER.', 'AND FROM THE WALLS, THE WHOLE CITY WAS WATCHING.'];
              const legs = ctx.actor('prof');
              ctx.say(lines[k % lines.length]!, { x: legs.gx, y: legs.gy - 1.2 }, '#f0d8a0');
            },
          }),
          call((ctx) => ctx.actor('prof').setBehavior({ kind: 'idle' })),
          walk({
            objective: 'SNIFF THE CHAIR LEG, THE SUITCASE AND THE HEM OF HIS COAT',
            action: 'SNIFF',
            onAction: (ctx) => ctx.say('SNIFF...', { x: ctx.player.gx, y: ctx.player.gy }),
            pickups: [
              { at: '0', kind: 'shard', label: 'THE CHAIR LEG', text: '"A FLEET BOUGHT ON CREDIT. EIGHTY-FIVE THOUSAND MARKS, AND THEY HAD NOT GOT IT."', effects: { shard: 'A FLEET BOUGHT ON CREDIT' } },
              { at: '5', kind: 'shard', label: 'THE SUITCASE', text: '"THE OTHERS TURNED BACK. ONE KNIGHT KEPT WALKING."', effects: { shard: 'A KNIGHT WHO KEPT WALKING' } },
              { at: '6', kind: 'shard', label: 'THE HEM OF HIS COAT', text: '"A CITY SEEN FROM ITS WALLS, AND THE WALLS FULL OF PEOPLE."', effects: { shard: 'A CITY SEEN FROM ITS WALLS' } },
            ],
          }),
          say('professor', 'DREAMS ARE FURNISHED WITH DAILY LIFE. A KING DREAMS FALCONS; A COMMUTER DREAMS TRAINS AND SUITCASES.'),
          say('zampano', 'AND A DOG DREAMS LECTURES.', { remembered: true }),
          call((ctx) => {
            ctx.setStage('neighborhood', { skin: 'plain', at: 'S', face: 'NE' });
            ctx.addActor('jack', 'jack', '2', { kind: 'idle', face: 'W' });
            ctx.addActor('d1', 'crowdC', { x: 4.5, y: 3.5 }, { kind: 'goto', to: { x: 11.5, y: 3.5 }, speed: 2 });
          }),
          card('OUTSIDE', 'TWO GARDEN GATES, AND JACK IN BETWEEN', { color: C.green, seconds: 1.8 }),
          call((ctx) => ctx.actor('jack').setBehavior({ kind: 'goto', to: { x: 8.5, y: 4.5 }, speed: 3 })),
          say('jack', 'GO ON, GO ON. EVERYBODY PASSES. (THE OTHER DOG TROTS THROUGH.)'),
          call((ctx) => ctx.actor('jack').setBehavior({ kind: 'goto', to: ctx.marker('2'), speed: 3 })),
          wait(0.6),
          say('jack', 'EVERYBODY EXCEPT YOU.'),
          walk({
            objective: 'GET THROUGH THE GARDEN GATES TO THE BOWL',
            goal: { reach: '1', label: 'THE BOWL' },
            pilot: (ctx) => (open ? null : { target: { x: 6.2, y: 3.5 }, act: distTo(ctx, { x: 6.2, y: 3.5 }) < 1.2, hold: true }),
            onAction: (ctx) => {
              bark(ctx, 'WOOF!');
              if (open || distTo(ctx, ctx.marker('2')) > 3) return;
              echoes++;
              const j = ctx.actor('jack');
              ctx.say(echoes === 1 ? 'WOOF!' : echoes === 2 ? 'WOOF! WOOF!' : '"WOOF," HE SAYS. "WOOF!"', { x: j.gx, y: j.gy }, '#f0b060');
              j.emote('bark');
              if (echoes === 2) heads(ctx);
              if (echoes >= 3) letThrough(ctx);
            },
            onUpdate: (ctx, _w, dt) => {
              const p = ctx.player;
              if (!open && p.gx > 6.55 && p.gy > 2 && p.gy < 5) {
                p.gx = 6.55;
                p.knockback(-1, 0, 3);
                tries += dt + 0.4;
                ctx.say('NOPE!', ctx.marker('2'), '#f0b060');
                if (tries > 3) ctx.notice('JACK WILL NOT MOVE. BARK?', C.orange);
              }
              if (!open && tries > 12) letThrough(ctx);
            },
          }),
          say('zampano', 'THERE WAS A GATE, AND IT WAS A CHIHUAHUA.', { remembered: true }),
        ];
      },
    },
    {
      id: '1.3',
      title: 'The toll at the bowl',
      happens:
        'BAGNASKIZ LETS SBRIMBRULON DRINK, THEN PUTS HIS PAW OVER THE BOWL AND DEMANDS THE USUAL APOLOGY. JACK CALLS THE FENCES TO WATCH; WATSON DRAGS THE BOWL JUST OUT OF REACH. OFFER THE PAW AND HE DEMANDS THE OTHER ONE TOO. TRY THE DIRECT PATH AND JACK CUTS HIM OFF. THE HEDGE IS ALWAYS OPEN: THE LONG WAY TO HIS OWN NEIGHBOR\'S GATE.',
      source: "BOARD: BAGNASKIZ'S CHARACTER CARD (11:52:06). BARBERO, JOINVILLE E SAN LUIGI: THE BAREFOOT APOLOGY, TRANSPOSED TO THE LAWN.",
      script: () => {
        let bowl: PropEntity | null = null;
        let cutOff = 0;
        let jokeT = 0;
        const jokes = ['AND THEN HE OFFERED THE OTHER PAW!', 'HA HA HA!', 'THE OTHER PAW!', 'HA HA!'];
        let j = 0;
        return [
          call((ctx) => {
            ctx.setStage('neighborhood', { skin: 'plain', at: { x: 10.5, y: 3.5 }, face: 'E' });
            bowl = placeObject(ctx, 'bowl', '1');
            ctx.addActor('bag', 'bagnaskiz', { x: 13.5, y: 2.6 }, { kind: 'idle', face: 'S' });
            ctx.addActor('sbrim', 'sbrimbrulon', { x: 13.5, y: 4.2 }, { kind: 'idle', face: 'N' });
            ctx.addActor('jack', 'jack', { x: 16.5, y: 4.5 }, { kind: 'idle', face: 'player' });
            ctx.addActor('watson', 'watson', '7', { kind: 'idle', face: 'SW' });
          }),
          card('THE BOWL', "THE BAND'S TOLL", { color: C.orange, seconds: 1.6 }),
          say('bagnaskiz', 'DRINK, SBRIMBRULON. TAKE YOUR TIME.'),
          call((ctx) => ctx.actor('sbrim').setBehavior({ kind: 'goto', to: { x: 20.5, y: 4.5 }, speed: 1.6 })),
          move('zampano', { x: 12.4, y: 3.5 }, 2),
          call((ctx) => {
            const b = ctx.actor('bag');
            b.setPosition(13.2, 3.1);
            b.emote('bark');
          }),
          say('bagnaskiz', '(HE PUTS HIS PAW OVER THE BOWL.) SIGNOR VILLANO. YOU KNOW THE TOLL. THE USUAL APOLOGY.'),
          say('jack', 'EVERYBODY! COME AND WATCH!'),
          call((ctx) => heads(ctx)),
          ask('bagnaskiz', 'THE PAW, ZAMPANO.', [
            {
              label: '(OFFER THE PAW) PARDON.',
              effects: { supervillain: -3, flags: { pawOffered: true } },
              then: [say('jack', '(OFFERING A PAW, VERY SLOWLY) PAAARDON...'), say('bagnaskiz', 'AND THE OTHER ONE.')],
            },
            { label: '(LOOK PAST HIM AT THE WATER)', then: [say('bagnaskiz', 'THE WATER IS NOT LOOKING AT YOU.')] },
          ]),
          call(() => {
            if (bowl) bowl.setPosition(14.6, 2.4);
          }),
          say('watson', '(HE DRAGS THE BOWL JUST OUT OF REACH.) OOPS, MAN.'),
          walk({
            objective: "GO HOME BY SANTINA'S GATE. ANY WAY YOU CAN",
            goal: { reach: '8', label: "SANTINA'S GATE" },
            checkpoints: ['6'],
            pilot: (ctx) => {
              // Through the hedge gap, along the lower lane, up through the far gap.
              const p = ctx.player;
              if (p.gy < 6 && p.gx < 19) return { target: { x: 12.5, y: 7.5 } };
              if (p.gy >= 6 && p.gx < 19.8) return { target: { x: 20.5, y: 7.6 } };
              return null;
            },
            onUpdate: (ctx, _w, dt) => {
              const p = ctx.player;
              // Jack cuts him off at the next opening on the direct path.
              if (p.gx > 17.4 && p.gx < 18.9 && p.gy > 2 && p.gy < 5) {
                p.gx = 17.4;
                p.knockback(-1, 0, 4);
                const jack = ctx.actor('jack');
                jack.setPosition(18.5, 3.5);
                jack.emote('bark');
                ctx.say('NOT THIS WAY, SIGNOR!', { x: 18.5, y: 3.5 }, '#f0b060');
                if (cutOff++ === 0) ctx.notice('JACK CUTS HIM OFF. THE HEDGE IS ALWAYS OPEN', C.orange);
              }
              // From the lower lane he can hear Jack telling the same joke on the other side.
              if (p.gy > 6.6) {
                jokeT -= dt;
                if (jokeT <= 0) {
                  jokeT = 2.4;
                  ctx.say(jokes[j++ % jokes.length]!, { x: p.gx - 0.5, y: 5.4 }, '#f0b060');
                }
              }
            },
          }),
          fx({ flags: { longWay: true } }),
          card('THE LONG WAY', "TO HIS OWN NEIGHBOR'S GATE", { color: C.orange, seconds: 2 }),
          say('zampano', 'THERE WAS A BOWL, AND IT WAS ALWAYS ONE STEP AWAY.', { remembered: true }),
        ];
      },
    },
    {
      id: '1.4',
      title: 'Santina wants her ball back',
      happens:
        'A RED BALL HAS ROLLED THROUGH THE BARS. SANTINA AND A FRIEND CAN SEE IT ON ZAMPANO\'S SIDE OF THE GATE, AND SHE ASKS HIM TO ROLL IT BACK. EVERY REPLY COMES FROM HIS SINCERE CONVICTION THAT SHE WANTS TO SEE SOMETHING IMPRESSIVE.',
      source: 'BOARD: THE HANDWRITTEN NOTE BESIDE THE CASTING LIST (11:52:30). BARBERO, IL SOGNO NEL MEDIOEVO: DANTE MEETING BEATRICE.',
      script: () => {
        let ball: PropEntity | null = null;
        const used = new Set<string>();
        const tries: Array<{ key: string; label: string; then: ReturnType<typeof say>[] }> = [
          {
            key: 'bow',
            label: '(A COURTLY BOW)',
            then: [say('voice', 'HE PUTS A PAW ON THE BALL AND BOWS UNTIL HIS CHIN TOUCHES IT.'), say('santina', 'THE BALL, ZAMPANO. YOU HAVE FOUND IT.')],
          },
          {
            key: 'strength',
            label: '(A DISPLAY OF STRENGTH)',
            then: [say('voice', 'HE TRIES TO LIFT THE GATE CLEAN OFF ITS HINGES. THE BALL RESTS BY HIS BACK PAW.'), say('lady', 'IT FITS BETWEEN THE BARS.')],
          },
          { key: 'compliment', label: 'YOUR GATE SMELLS VERY NICE.', then: [say('voice', 'SANTINA LOOKS AT THE GATE.'), say('santina', 'MY FATHER PAINTED IT YESTERDAY.')] },
        ];
        const wheel = (): ReturnType<typeof call> =>
          call((ctx) => {
            const left = tries.filter((t) => !used.has(t.key));
            if (!left.length) return;
            ctx.insert([
              ask(
                'santina',
                used.size === 0 ? 'CAN YOU ROLL IT BACK TO ME?' : 'THE BALL, ZAMPANO. CAN YOU ROLL IT BACK?',
                left.map((t) => ({ label: t.label, then: [call(() => used.add(t.key)), ...t.then, wheel()] })),
              ),
            ]);
          });
        return [
          call((ctx) => {
            ctx.setStage('neighborhood', { skin: 'plain', at: { x: 18.5, y: 3.5 }, face: 'E' });
            ctx.addActor('santina', 'santina', '9', { kind: 'idle', face: 'W' });
            ctx.addActor('friend', 'lady', '0', { kind: 'idle', face: 'W' });
            ball = placeObject(ctx, 'ball', { x: 21.2, y: 3.75 }, 0xff4040);
          }),
          card("SANTINA'S GATE", 'THE BAND IS ALREADY OUT OF EARSHOT', { color: C.hotPink, seconds: 1.8 }),
          say('santina', 'ZAMPANO! MY BALL. THE RED ONE, THERE, BY YOUR PAW.'),
          move('zampano', { x: 20.6, y: 3.5 }, 2),
          face('zampano', 'E'),
          wheel(),
          call(() => {
            if (ball) ball.setPosition(21.4, 4.4);
          }),
          card('', 'THE BALL SETTLES BESIDE THE GATEPOST. ON HIS SIDE.', { color: C.hotPink, seconds: 2 }),
          say('zampano', '(HE STRAIGHTENS UP, PLEASED WITH HIS PERFORMANCE.)'),
          move('zampano', { x: 16.5, y: 3.5 }, 2.2),
          say('voice', 'SANTINA WATCHES HIM GO.'),
          fx({ flags: { santinaBall: 'performed' } }),
          say('zampano', 'THERE WAS A GATE, AND I WAS MAGNIFICENT AT IT.', { remembered: true }),
        ];
      },
    },
    {
      id: '1.5',
      title: 'Taking the cross',
      happens:
        'FOLLOW THE FAMILIAR LANE HOME CARRYING A SCRAP OF RED CLOTH FROM THE HEDGE. CONFUSIONE HELPS SEW IT TO HIS COAT. HE RETURNS THE CROSS, WAITS FOR THE PROFESSOR TO LOOK, THEN TAKES IT AGAIN SO EVERYONE CAN SEE HE WAS IN HIS RIGHT MIND. CURL UP UNDER THE DESK.',
      source: 'BARBERO, LE CROCIATE, FIRST EVENING: LOUIS IX TAKING THE CROSS A SECOND TIME. A CRUSADER IS ONE WHO HAS A CROSS SEWN ON HIS COAT (4C).',
      script: () => [
        stage('neighborhood', [], { skin: 'plain', at: '8', face: 'W' }),
        walk({
          objective: 'TAKE THE SCRAP OF RED CLOTH CAUGHT IN THE HEDGE',
          pickups: [{ at: { x: 20.5, y: 5.5 }, kind: 'spot', label: 'A SCRAP OF RED CLOTH' }],
        }),
        carry('RED CLOTH'),
        walk({ objective: 'FOLLOW THE FAMILIAR LANE HOME', goal: { reach: 'S', label: 'HOME' } }),
        dropCarried(),
        call((ctx) => {
          ctx.setStage('study', { skin: 'plain', at: '5', face: 'NE' });
          ctx.addActor('conf', 'confusione', '6', { kind: 'idle', face: 'player' });
          ctx.addActor('prof', 'legs', '2', { kind: 'idle' });
        }),
        say('confusione', 'HOLD STILL. A CRUSADER IS ONE WHO HAS A CROSS SEWN ON HIS COAT.'),
        ask('confusione', 'THERE. IT IS RAG, BUT IT IS A CROSS.', [{ label: '(WEAR THE CROSS)', effects: { unlock: 'cross' } }]),
        skin('zampanoCross'),
        sound('star'),
        say('zampano', 'I AM GIVING IT BACK.'),
        skin('zampano'),
        say('confusione', 'WHY?'),
        say('zampano', 'WAIT.'),
        call((ctx) => ctx.actor('prof').setBehavior({ kind: 'goto', to: { x: ctx.player.gx + 1.2, y: ctx.player.gy - 0.8 }, speed: 1.2 })),
        wait(1.4),
        card('', 'THE PROFESSOR LOOKS', { color: '#f0d8a0', seconds: 1.4, dim: 0.2 }),
        ask('zampano', '(NOW EVERYONE IS WATCHING.)', [{ label: '(TAKE IT AGAIN, SO EVERYONE SEES I AM IN MY RIGHT MIND.)', effects: { supervillain: 3 } }]),
        skin('zampanoCross'),
        say('confusione', 'IN YOUR RIGHT MIND. OBVIOUSLY.'),
        walk({ objective: 'CURL UP UNDER THE DESK', goal: { reach: '0', label: 'THE DESK' } }),
        prof('...AND THEY SAILED.'),
        card('UNDER THE DESK', "IN THE DARK, THE HEM OF HIS FATHER'S TROUSERS BECOMES THE EDGE OF A SAIL.", { color: '#f0d8a0' }),
      ],
    },
  ],
};
