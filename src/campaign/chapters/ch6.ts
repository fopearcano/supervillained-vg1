import { Graphics } from 'pixi.js';
import { STORY } from '../../config';
import type { Point } from '../../entities/actor';
import { gridToScreen } from '../../iso/projection';
import { RumourGame, mini } from '../../story/minigames';
import { ask, blackHoleIn, blackHoleOut, call, card, fx, move, say, stage } from '../../story/steps';
import type { StoryScene } from '../../story/storyScene';
import { walk, type Pickup } from '../../story/walk';
import { C } from '../../ui/retro';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';
import { distTo } from './helpers';

/** Glasses on the white tablecloths (6.1). */
const GLASSES: Point[] = [
  { x: 9.5, y: 10.5 },
  { x: 11.5, y: 12.5 },
  { x: 8.5, y: 13.5 },
  { x: 12.5, y: 8.5 },
  { x: 6.5, y: 8.5 },
  { x: 10.5, y: 8.4 },
];

/** Where Boniface's name is heard next (6.2): the cook, the tents, the council tent. */
const NAME_TRAIL: Array<{ at: string | Point; text: string }> = [
  { at: '6', text: 'THE COOK: "...FOR THE MARQUIS BONIFACE, THE GOOD WINE..."' },
  { at: '9', text: 'A TENT: "...BONIFACE HAS A GUEST..."' },
  { at: '4', text: 'ANOTHER TENT: "...A PRINCE, WITH BONIFACE..."' },
  { at: '5', text: 'THE COUNCIL TENT: "...BONIFACE SPEAKS FOR HIM..."' },
];

/**
 * Level 6 — The long winter (Zara, winter 1202–03). Only one event changes the fleet's course this
 * winter. Zampanò learns about it last, between an afternoon game, a saint's difficult question
 * and a very thirsty dream. Cast: Jack at the catapult; Santina as the princess; a saintly king.
 */
export const CH6: ChapterDef = {
  number: 6,
  title: CHAPTER_TITLES[5],
  intro: "ONLY ONE EVENT CHANGES THE FLEET'S COURSE THIS WINTER. ZAMPANO LEARNS ABOUT IT LAST, BETWEEN AN AFTERNOON GAME, A SAINT'S DIFFICULT QUESTION AND A VERY THIRSTY DREAM.",
  cast: 'JACK AT THE CATAPULT; SANTINA AS THE PURPLE-BORN PRINCESS; A SAINTLY KING; CONFUSIONE AT THE WAKE',
  theme: 'winter',
  music: 'medieval',
  professor: {
    after: 'JV',
    text: 'JERUSALEM STAYS PASTEL, YOU UNDERSTAND. THE DESERT BLEACHES EVERYTHING ELSE, UNTIL ONE PATCH OF IMPERIAL PURPLE REMAINS: EXACTLY THE COLOUR OF A CUSHION AT HOME.',
  },
  subLevels: [
    {
      id: '6.1',
      title: 'The white tablecloth',
      happens:
        "IN A CAMP BORROWED FROM JOINVILLE, SERVE DRINKS BETWEEN KNIGHTS' TENTS. THE COUNT OF EU'S TOY CATAPULT KEEPS BREAKING THE GLASSES, AND JACK FINDS THIS MAGNIFICENT. WORK OUT WHERE THE NEXT SHOT WILL LAND AND WHISK THE GLASS AWAY. UNDER THE UPTURNED TABLECLOTH SOMEONE IS TALKING POLITICS.",
      source: 'BARBERO, JOINVILLE E SAN LUIGI: THE COUNT OF EU\'S TOY CATAPULT.',
      script: () => {
        const W = STORY.WHISK;
        let saved = 0;
        let shots = 0;
        let target = -1;
        let timer = 1.2;
        let pingT = 0;
        return [
          stage('winter', [
            { name: 'jack', who: 'jack', at: '7', face: 'W' },
            { name: 'k1', who: 'knight', at: '4', face: 'SE' },
            { name: 'k2', who: 'knight', at: '5', face: 'SW' },
          ]),
          say('jack', 'THE COUNT OF EU HAS A LITTLE CATAPULT! HE IS AIMING AT THE GLASSES! MAGNIFICENT!'),
          walk({
            objective: `SERVE THE DRINKS: WHISK THE GLASS AWAY BEFORE THE SHOT LANDS (0/${W.NEED})`,
            action: 'WHISK',
            pilot: () => (target >= 0 ? { target: GLASSES[target]! } : null),
            onUpdate: (ctx, w, dt) => {
              timer -= dt;
              if (target < 0) {
                if (timer > 0) return;
                target = Math.floor(Math.random() * GLASSES.length);
                timer = W.WARN;
                shots++;
                ctx.say('THWACK! INCOMING...', ctx.marker('7'), C.orange);
              } else {
                const g = GLASSES[target]!;
                pingT -= dt;
                if (pingT <= 0) {
                  pingT = 0.35;
                  const s = gridToScreen(g.x, g.y);
                  ctx.particles.burst(s.x, s.y - 4, { count: 6, textures: ['sparkle'], colors: [0xff3030, 0xffe23a], speed: [10, 30], life: [0.3, 0.5], drag: 3 });
                }
                if (timer <= 0) {
                  if (distTo(ctx, g) < W.RADIUS) {
                    saved++;
                    ctx.say('WHISKED AWAY!', g, C.green);
                    ctx.game.audio.play('star');
                  } else {
                    ctx.say('CRASH!', g, C.red);
                    ctx.game.audio.play('hit');
                    ctx.say('MAGNIFICENT!', { x: ctx.actor('jack').gx, y: ctx.actor('jack').gy }, '#f0b060');
                  }
                  target = -1;
                  timer = W.GAP;
                }
              }
              ctx.hud.setObjective(`SERVE THE DRINKS: WHISK THE GLASS AWAY BEFORE THE SHOT LANDS (${saved}/${W.NEED})`);
              if (saved >= W.NEED || (shots >= W.SHOTS * 2 && target < 0)) w.complete = true;
            },
          }),
          fx({ standing: 4, commozione: 4 }),
          say('jack', 'YOU RUINED IT. IT WAS MAGNIFICENT.'),
          card('THE UPTURNED TABLECLOTH', 'SOMEONE UNDERNEATH IS TALKING POLITICS', { color: '#f0f0f0', seconds: 2.2 }),
          say('voice', '(UNDER THE TABLECLOTH) ...A PRINCE... BONIFACE... CONSTANTINOPLE...'),
          say('jack', 'THERE WAS A CATAPULT, AND IT WAS MAGNIFICENT.', { remembered: true }),
        ];
      },
    },
    {
      id: '6.2',
      title: 'A prince on credit',
      happens:
        "FOLLOW BONIFACE'S NAME FROM THE COOK TO THE COUNCIL TENT. PIECE TOGETHER YOUNG ALEXIOS'S PROMISE OF MONEY, MILITARY HELP AND SUBMISSION TO ROME IN EXCHANGE FOR RESTORING HIS BLINDED FATHER, ISAAC II. THE BISHOPS HAVE ALREADY JUDGED THE ENTERPRISE A GOOD WORK. ZAMPANO FINALLY UNDERSTANDS WHY THE FLEET IS TURNING EAST.",
      source: "BARBERO, LA QUARTA CROCIATA: THE PRINCE'S OFFER.",
      script: () => {
        let next = 1;
        const spot = (k: number): Pickup => ({ at: NAME_TRAIL[k]!.at, kind: 'spot', label: '"BONIFACE"', text: NAME_TRAIL[k]!.text });
        return [
          stage('winter', [{ name: 'cook', who: 'cellarer', at: { x: 4.5, y: 11.5 }, face: 'E' }], { at: 'S' }),
          say('cellarer', 'THE GOOD WINE IS FOR THE MARQUIS BONIFACE. HE HAS A GUEST.'),
          walk({
            objective: "FOLLOW BONIFACE'S NAME TO THE COUNCIL TENT",
            pickups: [spot(0)],
            need: NAME_TRAIL.length,
            onPickup: (_ctx, _p, w) => {
              if (next < NAME_TRAIL.length) w.spawn(spot(next++));
            },
          }),
          mini(() => new RumourGame(), { won: { supervillain: 3 } }),
          card('A GOOD WORK', 'THE BISHOPS HAVE ALREADY SAID SO', { color: C.yellow, seconds: 2 }),
          say('zampano', 'SO THAT IS WHY THE FLEET IS TURNING EAST.'),
          say('zampano', 'THERE WAS A PRINCE, AND HE WAS PAYING WITH A THRONE HE DID NOT HAVE.', { remembered: true }),
        ];
      },
    },
    {
      id: '6.3',
      title: 'The road of the poor · 1096–97',
      happens:
        'STEP THROUGH THE TENT FLAP INTO THE CROWD ANNA KOMNENE DESCRIBED. WALK AMONG FAMILIES CARRYING PALMS WHILE THEIR LEADERS SEEK AN AUDIENCE WITH ALEXIOS I. AT COURT A FRANK SITS ON THE EMPEROR\'S THRONE. SANTINA WATCHES WITH THE PRINCESS\'S EYE. ZAMPANO, ATTEMPTING GOOD MANNERS, INVITES HER TO SIT IN IT TOO.',
      source: 'BARBERO, LE CROCIATE, FIRST AND THIRD EVENINGS: ANNA KOMNENE.',
      blackHole: { where: '1096-97, THE ROAD OF THE POOR', value: 'Feeling makes action' },
      script: () => [
        card('THE TENT FLAP', 'HE STEPS THROUGH', { color: '#f0d8a0', seconds: 1.4 }),
        ...blackHoleIn('1096-97. THE ROAD OF THE POOR.'),
        call((ctx) => {
          ctx.setStage('road');
          ['1', '2', '3', '4', '5', '6', '7'].forEach((m, k) =>
            ctx.addActor(`p${k}`, (['crowdA', 'crowdB', 'crowdC'] as const)[k % 3], m, { kind: 'follow', distance: 1.4 + k * 0.4, speed: 2.2, side: (k % 2 ? 1 : -1) * 0.8 }),
          );
        }),
        say('voice', 'FAMILIES, WOMEN, CHILDREN, PALM BRANCHES IN HAND. THEIR LEADERS ARE SEEKING AN AUDIENCE.'),
        walk({ objective: 'WALK AMONG THE FAMILIES TO THE PALACE', goal: { reach: '9' } }),
        call((ctx) => {
          ctx.setStage('palace', { at: '7' });
          ctx.addActor('frank', 'knight', '1', { kind: 'idle', face: 'S' });
          ctx.addActor('princess', 'santina', '8', { kind: 'idle', face: 'SW' });
        }),
        say('voice', 'A FRANK SITS ON THE EMPEROR\'S THRONE AND TALKS. NOBODY HAS ASKED HIM TO.'),
        say('santina', '(THE PRINCESS) THEY ARE ALL LIKE THIS, THESE CELTS. I AM WRITING IT DOWN.'),
        ask('santina', 'AND YOU, LITTLE CELT?', [
          { label: 'YOUR HIGHNESS, DO SIT. THERE IS ROOM ON THE THRONE FOR TWO.', effects: { supervillain: 3 } },
          { label: 'AFTER YOU. IT LOOKS VERY COMFORTABLE.', effects: { supervillain: 3 } },
        ]),
        say('santina', 'HE IS INVITING ME. TO MY FATHER\'S THRONE. I AM WRITING THAT DOWN TOO.', { remembered: true }),
        ...blackHoleOut('Feeling makes action'),
      ],
    },
    {
      id: '6.4',
      title: 'The desert · Hattin, 1187',
      happens:
        "KEEP PACE TOWARDS THE LAKE OF TIBERIAS; IT VANISHES BEHIND THE NEXT RIDGE. A VOICE PROMISES TO REVEAL ZAMPANO'S TRUE BIRTH. SNIFF THE REVERED SCRAP OF PURPLE CLOTH: IT IS HIS CUSHION. THE GRAND REVELATION IS THAT HE IS A MALTESE. HE CARRIES THE CUSHION'S SMELL BACK TO CAMP.",
      source: 'BARBERO, LE CROCIATE, FIRST EVENING: HATTIN. BOARD (11:55:18-19): THE WRONG REVELATION.',
      blackHole: { where: 'HATTIN, 1187', value: 'Born in the purple (on a cushion)' },
      script: () => {
        let patch: Graphics | null = null;
        const purple = (ctx: StoryScene) => {
          const at = ctx.marker('5');
          const s = gridToScreen(at.x, at.y);
          patch = new Graphics();
          patch.rect(-6, -3, 12, 6).fill(0x7a2ab0).rect(-5, -3, 10, 2).fill(0xa050e0);
          patch.position.set(Math.round(s.x), Math.round(s.y));
          ctx.worldFx.addChildAt(patch, 0);
        };
        return [
          ...blackHoleIn('HATTIN, 1187. MIDSUMMER.'),
          call((ctx) => {
            ctx.setStage('desert');
            purple(ctx);
          }),
          say('voice', 'WALK. THE LAKE OF TIBERIAS IS JUST OVER THAT RIDGE. THEN YOU WILL KNOW YOUR TRUE BIRTH.'),
          walk({
            objective: 'KEEP PACE TOWARDS THE LAKE OF TIBERIAS',
            goal: { reach: '4' },
            thirst: { mirage: '2', drain: 0.016 },
            onUpdate: (ctx, w) => {
              ctx.bleach = Math.min(1, w.time / STORY.BLEACH_TIME);
            },
          }),
          card('THE LAKE VANISHES', 'BEHIND THE NEXT RIDGE. ONE PATCH OF PURPLE REMAINS.', { color: '#c070f0', seconds: 2.2 }),
          call((ctx) => (ctx.bleach = 1)),
          walk({
            objective: 'SNIFF THE REVERED SCRAP OF PURPLE CLOTH',
            action: 'SNIFF',
            pickups: [{ at: '5', kind: 'spot', label: 'A SCRAP OF IMPERIAL PURPLE' }],
            onAction: (ctx) => ctx.say('SNIFF...', { x: ctx.player.gx, y: ctx.player.gy }),
          }),
          say('voice', 'BEHOLD. THE GREAT REVELATION OF YOUR BIRTH. YOU ARE...'),
          say('zampano', '...A KNIGHT?'),
          say('zampano', '(SNIFF.) IT IS MY CUSHION.'),
          card('A MALTESE', 'BORN IN THE PURPLE. ON A CUSHION.', { color: '#c070f0' }),
          call(() => patch?.destroy()),
          fx({ item: 'THE SMELL OF THE CUSHION' }),
          say('zampano', 'THERE WAS A LAKE, AND IT WAS A CUSHION.', { remembered: true }),
          ...blackHoleOut('Born in the purple (on a cushion)'),
        ];
      },
    },
    {
      id: '6.5',
      title: 'Living with a saint',
      happens:
        'LOUIS IX ASKS WHETHER ZAMPANO WOULD CHOOSE LEPROSY OR MORTAL SIN: CHOOSE THIRTY MORTAL SINS, AS JOINVILLE DID. AFTER DECLINING TO WASH THE FEET OF THE POOR, OFFER TO SERVE UNPAID IF THE KING CAN KEEP HIS TEMPER FOR SIX MONTHS. LOUIS LAUGHS. CANDOR EARNS HIM A PLACE BESIDE THE KING AT SUPPER.',
      source: "BARBERO, JOINVILLE E SAN LUIGI: LOUIS'S QUESTIONS.",
      blackHole: { where: 'IN THE TENT OF A SAINTLY KING', value: 'The grand gesture' },
      script: () => [
        ...blackHoleIn('IN THE TENT OF A SAINTLY KING.'),
        stage('interior', [{ name: 'king', who: 'king', at: '2', face: 'SW' }], { at: '1' }),
        ask('king', 'TELL ME HONESTLY: WOULD YOU RATHER BE A LEPER, OR HAVE COMMITTED ONE MORTAL SIN?', [
          { label: 'THIRTY MORTAL SINS, THANK YOU. NOT THE LEPROSY.', effects: { supervillain: 8, flags: { candor: true } }, then: [say('king', 'YOU SPEAK LIKE A FOOL. AND HONESTLY.')] },
          { label: 'WHATEVER PLEASES YOUR MAJESTY.', then: [say('king', 'THAT PLEASES ME LEAST OF ALL.')] },
        ]),
        ask('king', 'TOMORROW IS HOLY THURSDAY. WILL YOU WASH THE FEET OF THE POOR WITH ME?', [
          { label: 'NO. NEVER. THEY ARE FEET.', effects: { supervillain: 4 }, then: [say('king', 'HMPH.')] },
          { label: 'PERHAPS LATER.', then: [say('king', 'LATER IS NEVER.')] },
        ]),
        ask('king', 'WILL YOU SERVE ME? NAME YOUR PRICE.', [
          { label: 'UNPAID. IF YOU KEEP YOUR TEMPER FOR SIX MONTHS.', cost: STORY.COST.GESTURE, effects: { supervillain: 10, standing: 6 } },
          { label: 'A FAIR SALARY.', then: [say('king', 'SPOKEN LIKE A MERCHANT.')] },
        ]),
        say('king', 'HA! HA HA! DONE.'),
        card('SUPPER', 'A PLACE BESIDE THE KING, FOR HIS CANDOR', { color: C.yellow, seconds: 2.2 }),
        say('zampano', 'THERE WAS A SAINT, AND HE WAS LAUGHING AT ME.', { remembered: true }),
        ...blackHoleOut('The grand gesture'),
      ],
    },
    {
      id: '6.6',
      title: "A comrade's wake",
      happens:
        'MEN KEEPING WATCH OVER A DEAD COMPANION JOKE ABOUT WHO WILL MARRY HIS WIDOW. JOIN THE LAUGHTER OR SETTLE BESIDE THE BODY. IF ZAMPANO STAYS, CONFUSIONE SITS WITH HIM. IF HE LAUGHS, THE CAT MOVES AWAY. AT THE WALL THEY WILL RECOGNIZE EACH OTHER BY THIS SILENCE OR BY THE BARK THAT BROKE IT.',
      source: 'BARBERO, JOINVILLE E SAN LUIGI: THE KNIGHTS AT THE WAKE.',
      script: () => [
        stage('winter', [
          { name: 'k1', who: 'knight', at: '1', face: 'SE' },
          { name: 'k2', who: 'knight', at: '2', face: 'NW' },
          { name: 'body', who: 'knight', at: '8', face: 'S' },
          { name: 'conf', who: 'confusione', at: '3', face: 'NE' },
        ], { at: '9' }),
        call((ctx) => {
          const b = ctx.actor('body');
          b.sprite.tint = 0x9a9aa8;
          b.sprite.rotation = Math.PI / 2;
        }),
        card('THE WAKE', 'HE IS STILL WARM', { color: '#9aa4c0', seconds: 1.8 }),
        say('knight', 'SO. WHO MARRIES THE WIDOW? I CALL IT FIRST.'),
        say('knight', 'SHE HAS A MILL. AND A DOG.'),
        ask('confusione', '(CONFUSIONE IS LOOKING AT YOU.)', [
          {
            label: '(LAUGH. WOOF! WOOF!)',
            effects: { standing: 5, flags: { comradeship: false } },
            then: [say('knight', 'HE LAUGHS! HE IS ONE OF US.'), call((ctx) => ctx.actor('conf').setBehavior({ kind: 'goto', to: ctx.marker('6'), speed: 1.4 })), say('voice', 'THE CAT MOVES AWAY.')],
          },
          {
            label: '(SETTLE BESIDE THE BODY.)',
            cost: STORY.COST.VIGIL,
            effects: { supervillain: 10, flags: { comradeship: true }, value: 'Comradeship' },
            then: [
              move('zampano', { x: 12.5, y: 9 }, 1.6),
              call((ctx) => ctx.actor('conf').setBehavior({ kind: 'goto', to: { x: 12.8, y: 9.8 }, speed: 1.2 })),
              say('voice', 'CONFUSIONE SITS WITH HIM. NOBODY SAYS ANYTHING.'),
            ],
          },
        ]),
        say('voice', 'AT THE WALL, THEY WILL KNOW EACH OTHER BY THIS: THE SILENCE, OR THE BARK THAT BROKE IT.'),
        say('zampano', 'THERE WAS A WIDOW, AND SHE HAD A MILL.', { remembered: true }),
      ],
    },
  ],
};
