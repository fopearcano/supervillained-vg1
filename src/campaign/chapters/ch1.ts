import { ask, call, card, face, flash, fx, move, prof, say, shake, skin, sound, stage, wait } from '../../story/steps';
import { walk } from '../../story/walk';
import { C } from '../../ui/retro';
import { CHAPTER_TITLES, shardName } from '../titles';
import type { ChapterDef } from '../types';
import { bark, patrol } from './helpers';

/** Level 1 — Greenzone (Homeland). Cast: everyone as themselves. */
export const CH1: ChapterDef = {
  number: 1,
  title: CHAPTER_TITLES[0],
  intro: 'THE LAWN WHERE BAGNASKIZ RULES AND THE STUDY WHERE THE PROFESSOR REHEARSES. THIS LEVEL PLANTS EVERY SHARD THE DREAM WILL GROW.',
  cast: 'EVERYONE AS THEMSELVES',
  theme: 'greenzone',
  music: 'greenzone',
  professor: {
    after: 'JV',
    text: 'IN THE MIDDLE AGES, YOU UNDERSTAND, DOGS WALKED INTO CHURCH AND NOBODY SAID A WORD. SO WE ARE NOT GOING TO BE SCANDALISED IF ONE OF THEM TAKES THE CROSS.',
  },
  subLevels: [
    {
      id: '1.1',
      title: 'The dream of the cross',
      happens: 'COLD OPEN IN PASTEL. ZAMPANO, IN ARMOUR, IS ONE STEP FROM JERUSALEM. A SLAP FROM CONFUSIONE WAKES HIM ON THE LAWN.',
      source: 'BOARD: "INIZIO: SOGNO DELLA CROCE, SVEGLIATO DA UNA SBERLA DI CONFUSIONE"; SG; CR1',
      script: () => [
        stage('jerusalem', [], { skinKey: 'zampanoKnight' }),
        card('JERUSALEM', 'IT WAS PASTEL', { color: '#f6c8e0', seconds: 2.2, dim: 0.3 }),
        prof('THE KING WHOSE SPIRIT WAS "LONG BEYOND THE SEA" BEFORE HIS BODY FOLLOWED. KEEP THAT IN MIND.'),
        walk({
          objective: 'WALK TO JERUSALEM (JOYSTICK / WASD)',
          goal: { reach: '1' },
          noRun: true,
          onAction: (ctx) => bark(ctx, 'DEUS LO VULT!'),
        }),
        call((ctx) => ctx.addActor('conf', 'confusione', '2', { kind: 'goto', to: { x: ctx.player.gx + 0.6, y: ctx.player.gy + 0.4 }, speed: 7, run: true })),
        wait(0.5),
        sound('hurt'),
        flash(),
        shake(8),
        card('SLAP!', '', { color: C.red, seconds: 1.2, dim: 0.2 }),
        stage('lawn', [{ name: 'conf', who: 'confusione', at: '0', face: 'NW' }], { skin: 'plain', at: '0', face: 'S' }),
        call((ctx) => {
          ctx.player.setPosition(ctx.marker('0').x - 0.8, ctx.marker('0').y - 0.6);
          ctx.world!.snapCamera();
        }),
        card('THE LAWN', 'HE WAKES WHERE HE ALWAYS WAKES', { color: C.green, seconds: 2 }),
        say('confusione', 'YOU WERE SNORING IN LATIN.'),
        say('zampano', 'JERUSALEM WAS ONE STEP AWAY, AND IT WAS MADE OF ICING.', { remembered: true }),
        say('confusione', 'IT IS ALWAYS ONE STEP AWAY. GET UP.'),
      ],
    },
    {
      id: '1.2',
      title: 'The study',
      happens: 'THE PROFESSOR PACES AND REHEARSES. HIS SENTENCES FALL TO THE FLOOR AS SHARDS OF MEMORY.',
      source: 'BOARD: "CRISTALLIZZARSI", A MYRIAD OF FACETS, SPLINTERS, SPARKS OF MEMORY. DREAMS ARE FURNISHED WITH DAILY LIFE (SG).',
      script: () => {
        const sentences = [
          'VILLEHARDOUIN, YOU UNDERSTAND, WAS IN ON EVERY SECRET.',
          'CLARI SEES EVERYTHING AND IS TOLD NOTHING.',
          'THE TRANSCRIPT SAYS 2002. THEY MEAN 1202.',
          'FOUR MARKS A HORSE, TWO A MAN.',
          'A CRUSADE IS A PILGRIMAGE THAT GOES ARMED.',
          'NOBODY SAILS IN WINTER.',
          'AND THE LADIES SAID THEY LOOKED LIKE ANGELS.',
        ];
        let spawned = 0;
        let timer = 1;
        return [
          call((ctx) => {
            ctx.setStage('study', { skin: 'plain', at: 'S', face: 'NW' });
            ctx.addActor('prof', 'legs', '1', patrol(ctx, ['1', '2', '3', '4', '5', '6', '7'], 1.3, 1.4));
          }),
          say('professor', 'NOW. WHERE WERE WE. THE FOURTH CRUSADE. AGAIN, FROM THE TOP.'),
          walk({
            objective: 'COLLECT THE SHARDS OF MEMORY (0/7)',
            need: 7,
            onUpdate: (ctx, w, dt) => {
              const legs = ctx.actor('prof');
              timer -= dt;
              if (timer <= 0 && spawned < 7) {
                timer = 2.4;
                const n = spawned + 2;
                ctx.say(sentences[spawned]!, { x: legs.gx, y: legs.gy - 1.5 }, '#f0d8a0');
                w.spawn({ at: { x: legs.gx + 0.4, y: legs.gy + 0.4 }, kind: 'shard', label: `SHARD: ${CHAPTER_TITLES[n - 1]!.toUpperCase()}`, effects: { shard: shardName(n) } });
                spawned++;
              }
              ctx.hud.setObjective(`COLLECT THE SHARDS OF MEMORY (${w.collected}/7)`);
              if (Math.hypot(legs.gx - ctx.player.gx, legs.gy - ctx.player.gy) < 0.7 && ctx.player.state === 'free') {
                ctx.player.knockback(ctx.player.gx - legs.gx, ctx.player.gy - legs.gy, 5);
                ctx.notice('MIND THE SLIPPERS', C.orange);
              }
            },
          }),
          say('professor', 'DREAMS ARE FURNISHED WITH DAILY LIFE. A KING DREAMS FALCONS; A COMMUTER DREAMS TRAINS AND SUITCASES.'),
          say('zampano', 'AND A DOG DREAMS LECTURES.'),
          say('professor', 'THERE WAS A PUG, AND HE WAS SAYING... NO. WHERE WAS I.', { remembered: true }),
        ];
      },
    },
    {
      id: '1.3',
      title: 'The toll of the lawn',
      happens: 'BAGNASKIZ, JACK AND WATSON HOLD THE GREEN. TO CROSS, ZAMPANO MUST COME FORWARD, OFFER HIS PAW AND BEG PARDON.',
      source: 'THE SERGEANT WHO SHOVED A KNIGHT MUST COME BAREFOOT AND OFFER HIS HAND (JV). "SIGNOR VILLANO". BOARD: "ALPHA-DOG", "EVASIONE".',
      script: () => {
        let paid = false;
        return [
          call((ctx) => {
            ctx.setStage('lawn', { skin: 'plain' });
            const b = ctx.addActor('bag', 'bagnaskiz', '2', patrol(ctx, ['2', '3', '8', '7'], 1.2, 1.2));
            b.sight = { range: 4.5, halfAngle: 0.6 };
            const j = ctx.addActor('jack', 'jack', '1', patrol(ctx, ['1', '6', '9', '5'], 2.4, 0.4));
            j.sight = { range: 3.5, halfAngle: 0.45 };
            const w = ctx.addActor('watson', 'watson', '4', { kind: 'idle', face: 'SE' });
            w.sight = { range: 2.5, halfAngle: 1.1 };
          }),
          say('watson', 'THERE WAS A LAWN, AND IT WAS OURS. MAN.'),
          walk({
            objective: 'CROSS THE GREEN TO THE FAR GATE. NO FIGHTING YET',
            goal: { reach: 'E' },
            action: 'SNIFF',
            onAction: (ctx) => ctx.say('SNIFF...', { x: ctx.player.gx, y: ctx.player.gy }),
            caught: (ctx) =>
              paid
                ? []
                : [
                    card('CAUGHT', 'THE BAND HAS SEEN YOU', { color: C.orange, seconds: 1.4 }),
                    call(() => {
                      paid = true;
                      for (const a of ctx.actors.values()) a.sight = null;
                      ctx.actor('bag').setBehavior({ kind: 'idle', face: 'player' });
                    }),
                    say('bagnaskiz', 'SIGNOR VILLANO. THE LAWN HAS A TOLL.'),
                    ask('bagnaskiz', 'COME FORWARD. OFFER YOUR PAW. BEG PARDON.', [
                      { label: '(OFFER THE PAW) PARDON.', effects: { supervillain: -5, flags: { pawOffered: true } } },
                      { label: '(BITE HIM)', locked: 'NO FIGHTING YET' },
                    ]),
                    say('jack', 'HE SAID PARDON! HE SAID IT!'),
                    say('bagnaskiz', 'PASS, THEN. EVERYONE SAW.'),
                  ],
          }),
          call((ctx) => {
            if (!paid) ctx.apply({ supervillain: 6, flags: { evasione: true } });
          }),
          call((ctx) => ctx.notice(paid ? 'SHAME WAS PAID' : 'EVASIONE! NOBODY SAW HIM', paid ? C.orange : C.green)),
          say('zampano', 'THERE WAS A TOLL, AND I WAS NOT PAYING IT. OR I WAS.', { remembered: true }),
        ];
      },
    },
    {
      id: '1.4',
      title: "Santina's gate",
      happens: 'SANTINA PASSES. HE PANICS, TRIES NOT TO BE SEEN, IS GREETED BY NAME, AND RUNS HOME TO HIDE.',
      source: 'DANTE AT EIGHTEEN MEETING BEATRICE IN THE STREET (SG). BOARD: HIS APPROACH "DA SCEMO".',
      script: () => [
        call((ctx) => {
          ctx.setStage('lawn', { skin: 'plain', at: '5', face: 'NE' });
          ctx.addActor('santina', 'santina', '8', { kind: 'goto', to: ctx.marker('7'), speed: 1.4 });
        }),
        wait(1.5),
        card('SANTINA', 'DO NOT BE SEEN. DO NOT BE SEEN.', { color: C.hotPink, seconds: 1.8, dim: 0.25 }),
        face('zampano', 'W'),
        say('santina', 'ZAMPANO! HELLO, ZAMPANO.'),
        ask('santina', 'IS THAT YOU BEHIND THE BUSH?', [
          { label: 'NO.', then: [say('santina', 'IT SOUNDS LIKE YOU.')] },
          { label: 'I AM A BUSH.', then: [say('santina', 'A VERY WHITE BUSH.')] },
          { label: 'I AM A KNIGHT. PROBABLY.', then: [say('santina', 'PROBABLY?')] },
          { label: '(SAY NOTHING, VERY LOUDLY)', then: [say('santina', '...')] },
        ]),
        card('WRONG', 'EVERY OPTION WAS WRONG', { color: C.red, seconds: 1.6 }),
        move('zampano', 'S', 3, true),
        say('zampano', 'THERE WAS A GATE, AND I WAS RUNNING.', { remembered: true }),
        fx({ flags: { courtesy14: 'lout' } }),
      ],
    },
    {
      id: '1.5',
      title: 'Taking the cross',
      happens: 'CONFUSIONE SEWS A RAG CROSS ON HIS COAT. HE HANDS IT BACK, THEN TAKES IT AGAIN "SO EVERYONE SEES I AM SANE". NOBODY IS CONVINCED.',
      source: 'A CRUSADER IS ONE WHO HAS A CROSS SEWN ON HIS COAT (4C). LOUIS IX GIVING BACK THE CROSS TO TAKE IT AGAIN IN HIS RIGHT MIND (CR1).',
      script: () => [
        call((ctx) => {
          ctx.setStage('study', { skin: 'plain', at: '5', face: 'NE' });
          ctx.addActor('conf', 'confusione', '6', { kind: 'idle', face: 'player' });
          ctx.addActor('prof', 'legs', '2', { kind: 'idle' });
        }),
        say('confusione', 'HOLD STILL. A CRUSADER IS ONE WHO HAS A CROSS SEWN ON HIS COAT.'),
        ask('confusione', 'THERE. IT IS RAG, BUT IT IS A CROSS.', [{ label: '(EQUIP THE CROSS)', effects: { unlock: 'cross' } }]),
        skin('zampanoCross'),
        sound('star'),
        say('zampano', 'I AM GIVING IT BACK.'),
        skin('zampano'),
        say('confusione', 'WHY?'),
        ask('zampano', '...', [{ label: 'SO I CAN TAKE IT AGAIN. SO EVERYONE SEES I AM SANE.' }]),
        skin('zampanoCross'),
        say('confusione', 'NOBODY IS CONVINCED.'),
        say('zampano', 'I AM NOT LOOKING BACK AT THE CUSHION. IT WOULD PULL ME HOME.'),
        move('zampano', '0', 2),
        card('UNDER THE DESK', 'HE LIES DOWN. THE LECTURE GOES ON ABOVE HIM.', { color: '#f0d8a0' }),
      ],
    },
  ],
};

