import { STORY } from '../../config';
import { carry, dropCarried } from '../../story/carry';
import { LaddersGame, LetterGame, mini } from '../../story/minigames';
import { ask, call, card, fx, say, stage } from '../../story/steps';
import { walk } from '../../story/walk';
import { C } from '../../ui/retro';
import { dreamSkin } from '../state';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';
import { distTo, followLeader } from './helpers';

/**
 * Level 5 — Zara (Dalmatia, November 1202). From the deck Zampanò can make out crosses in a
 * Christian city. His own cross catches on the ladder as the men behind him ask him to get a
 * move on. Cast: Bagnaskiz as the marshal; the Doge; Sbrimbrulon; a legate.
 */
export const CH5: ChapterDef = {
  number: 5,
  title: CHAPTER_TITLES[4],
  intro: 'FROM THE DECK ZAMPANO CAN MAKE OUT CROSSES IN A CHRISTIAN CITY. HIS OWN CROSS CATCHES ON THE LADDER AS THE MEN BEHIND HIM ASK HIM TO GET A MOVE ON.',
  cast: 'BAGNASKIZ AS THE MARSHAL; THE DOGE; SBRIMBRULON; A LEGATE',
  theme: 'zara',
  music: 'medieval',
  professor: {
    text: 'HE ABSOLVES THE LEADERS SO THAT THEY WILL NOT DO IT AGAIN, AND HE DOES NOT ABSOLVE THE VENETIANS AT ALL. YOU WILL NOTICE THAT IT IS A FORMULA WITH A GREAT FUTURE.',
  },
  subLevels: [
    {
      id: '5.1',
      title: 'A small favor for Venice',
      happens:
        'CARRY A MESSAGE BETWEEN TWO GROUPS ON THE QUAY. ONE SAYS THEY TOOK THE CROSS TO GO TO JERUSALEM. THE OTHER SAYS THE VOYAGE WILL COLLAPSE UNLESS THEY HELP THE DOGE. LET ZAMPANO REPEAT EITHER ARGUMENT. THE MARSHAL REMEMBERS WHO SPOKE AGAINST HIM. THE FLEET STAYS AT ZARA.',
      source: 'BARBERO, LA QUARTA CROCIATA: ZARA AND THE DIVIDED HOST.',
      script: () => [
        stage('zara', [
          { name: 'k1', who: 'knight', at: '8', face: 'E' },
          { name: 'k2', who: 'crowdA', at: { x: 4.5, y: 9.5 }, face: 'E' },
          { name: 'marshal', who: 'bagnaskizMarshal', at: '9', face: 'W' },
          { name: 'doge', who: 'doge', at: { x: 15.5, y: 8.2 }, face: 'W' },
        ]),
        say('voice', 'TWO GROUPS ON THE QUAY. NEITHER WILL WALK OVER TO THE OTHER. YOU WILL.'),
        walk({ objective: 'HEAR THE FIRST GROUP', goal: { reach: '8', radius: 1.4, label: 'THE FIRST GROUP' } }),
        say('knight', 'WE TOOK THE CROSS TO GO TO JERUSALEM. NOT TO ZARA. TELL THEM THAT.'),
        carry('THE MESSAGE'),
        walk({ objective: 'CARRY THE MESSAGE TO THE OTHER GROUP', goal: { reach: '9', radius: 1.4, label: 'THE MARSHAL' } }),
        say('marshal', 'TELL THEM THE VOYAGE WILL COLLAPSE UNLESS WE HELP THE DOGE. NO ZARA, NO SHIPS, NO JERUSALEM.'),
        carry('THE ANSWER'),
        walk({ objective: 'CARRY THE ANSWER BACK', goal: { reach: '8', radius: 1.4, label: 'THE FIRST GROUP' } }),
        dropCarried(),
        call((ctx) => {
          ctx.actor('marshal').setPosition(ctx.marker('7').x, ctx.marker('7').y);
          ctx.actor('marshal').face('W');
        }),
        say('voice', 'NOW BOTH GROUPS ARE LISTENING TO THE DOG.'),
        ask('marshal', 'WELL, LITTLE KNIGHT? SAY IT OUT LOUD.', [
          {
            label: 'WE TOOK THE CROSS TO GO TO JERUSALEM.',
            cost: STORY.COST.SPEAK_UP,
            effects: { standing: -12, supervillain: 5, flags: { dissent: true } },
            then: [say('marshal', 'I WILL REMEMBER WHO SAID THAT. (IT COSTS YOU STANDING, NOT THE LEVEL.)')],
          },
          { label: 'THE VOYAGE WILL COLLAPSE UNLESS WE HELP THE DOGE.', effects: { standing: 5 }, then: [say('marshal', 'GOOD DOG.')] },
        ]),
        say('doge', 'A SMALL FAVOR FOR VENICE. THEN JERUSALEM.'),
        card('THE FLEET STAYS AT ZARA', '', { color: C.orange, seconds: 2 }),
        say('zampano', 'THERE WAS A MESSAGE, AND IT WAS HEAVIER EACH WAY.', { remembered: true }),
      ],
    },
    {
      id: '5.2',
      title: 'A cross above the wall',
      happens:
        'CLIMB BESIDE SBRIMBRULON AND STEADY THE LADDER FOR THE NEXT SMALL BODY. THROUGH THE OPENING THE CITY SURRENDERS AND THE GOODS ARE CARRIED OUT. FOLLOW ONE BOLT OF CLOTH FROM A HOUSE TO THE COMMON PILE: THAT SHORT JOURNEY ACQUIRES A SECOND MEANING IN CONSTANTINOPLE.',
      source: 'BARBERO, LA QUARTA CROCIATA: THE TAKING OF ZARA.',
      script: () => {
        let skin = 'zampano';
        let clothT = 0;
        return [
          stage('zara', [], { at: '4' }),
          call((ctx) => (skin = dreamSkin(ctx.state))),
          card('HIS CROSS CATCHES ON THE LADDER', '"GET A MOVE ON!"', { color: C.yellow, seconds: 1.8 }),
          mini(() => new LaddersGame(16, false, skin), { won: { supervillain: 4 } }),
          call((ctx) => {
            ctx.setStage('zara', { at: { x: 9.5, y: 5.5 } });
            ctx.addActor('sbrim', 'sbrimbrulon', { x: 10.5, y: 5.5 }, { kind: 'idle', face: 'W' });
          }),
          say('sbrimbrulon', 'HOLD IT STEADY, LITTLE ONE. THE NEXT ONE IS EVEN SMALLER THAN YOU.'),
          walk({
            objective: 'STEADY THE LADDER: STAND STILL',
            survive: 3,
            pilot: () => ({ target: { x: 9.5, y: 5.5 }, hold: true }),
            onUpdate: (ctx, w) => {
              ctx.hud.setMode({ label: 'STEADY...', value: Math.min(1, w.time / 3), color: 0x5ac8ff });
              if (Math.hypot(ctx.player.vx, ctx.player.vy) > 0.3) {
                w.time = 0;
                if (!w.data.warned) {
                  w.data.warned = true;
                  ctx.notice('IT WOBBLES! STAND STILL', C.orange);
                }
              }
            },
          }),
          card('THROUGH THE OPENING', 'THE CITY SURRENDERS. THE GOODS ARE CARRIED OUT.', { color: C.orange, seconds: 2.4 }),
          call((ctx) => {
            ctx.setStage('zara', { at: { x: 5.5, y: 11.5 } });
            ctx.addActor('porter', 'burgher', '2', { kind: 'idle', face: 'player' });
          }),
          followLeader({
            objective: 'KEEP THE BOLT OF CLOTH IN VIEW, FROM THE HOUSE TO THE PILE',
            leader: 'porter',
            path: ['4', '6'],
            speed: 1.6,
            onUpdate: (ctx, _w, dt) => {
              clothT -= dt;
              if (clothT > 0) return;
              clothT = 1.4;
              const a = ctx.actor('porter');
              ctx.say('[A BOLT OF RED CLOTH]', { x: a.gx, y: a.gy }, '#ff6a6a');
            },
          }),
          card('THE COMMON PILE', 'ONE BOLT OF CLOTH, FROM A HOUSE TO THE PILE', { color: '#d8d8e8', seconds: 2.2 }),
          fx({ coins: 5, flags: { clothRoute: true } }),
          say('zampano', 'THERE WAS A CLOTH, AND I WATCHED IT ALL THE WAY.', { remembered: true }),
        ];
      },
    },
    {
      id: '5.3',
      title: 'What do I owe?',
      happens:
        "A SCRAP OF THE PROFESSOR'S LECTURE OPENS AN OLD PENITENTIAL PRESCRIBING PENANCE EVEN FOR KILLING IN WAR. ANOTHER SCRAP CARRIES URBAN II'S PROMISE OF REMISSION TO PILGRIMS. PLACE EACH UNDER THE VOICE THAT SPOKE IT. WHEN ZAMPANO ASKS WHICH ONE GAVE HIM LEAVE TO TAKE ZARA, THE CAMP HAS GONE QUIET.",
      source: 'BARBERO, LE CROCIATE, SECOND EVENING: PENITENTIALS AND THE PREACHING OF REMISSION.',
      script: () => [
        stage('zara', [
          { name: 'monk', who: 'cellarer', at: '2', face: 'E' },
          { name: 'urban', who: 'legate', at: '3', face: 'W' },
        ], { at: '4' }),
        say('zampano', 'I WAS ON THE WALL. WHAT DO I OWE?'),
        walk({
          objective: "PICK UP THE TWO SCRAPS OF THE PROFESSOR'S LECTURE",
          pickups: [
            { at: '7', kind: 'shard', label: 'A SCRAP', text: '"FORTY DAYS OF PENANCE, EVEN FOR A MAN KILLED IN WAR."', effects: { shard: 'AN OLD PENITENTIAL' } },
            { at: '1', kind: 'shard', label: 'ANOTHER SCRAP', text: '"WHOEVER GOES TO JERUSALEM FOR DEVOTION ALONE: THAT JOURNEY COUNTS FOR ALL PENANCE."', effects: { shard: "URBAN II'S PROMISE" } },
          ],
        }),
        ask('voice', '"FORTY DAYS OF PENANCE, EVEN FOR A MAN KILLED IN WAR." WHOSE VOICE?', [
          { label: 'THE OLD MONK, WITH HIS PENITENTIAL.', effects: { grace: 5 }, then: [say('cellarer', 'MINE. IT HAS ALWAYS BEEN SO.')] },
          { label: 'POPE URBAN, AT CLERMONT.', then: [say('legate', 'NOT MINE. I PROMISE MORE THAN THAT.')] },
        ]),
        ask('voice', '"THE JOURNEY COUNTS FOR ALL PENANCE." WHOSE VOICE?', [
          { label: 'THE OLD MONK, WITH HIS PENITENTIAL.', then: [say('cellarer', 'NEVER. I SAID FORTY DAYS.')] },
          { label: 'POPE URBAN, AT CLERMONT.', effects: { grace: 5 }, then: [say('legate', 'MINE. TO PILGRIMS. TO JERUSALEM.')] },
        ]),
        say('zampano', 'AND WHICH OF YOU GAVE ME LEAVE TO TAKE ZARA?'),
        card('', 'THE CAMP HAS GONE QUIET', { color: '#9aa4c0', seconds: 2.6, dim: 0.6 }),
        say('zampano', "THERE WAS A SIN, AND THEN THERE WASN'T. NOBODY WOULD SAY WHICH.", { remembered: true }),
      ],
    },
    {
      id: '5.4',
      title: 'A letter for Rome',
      happens:
        "ASSEMBLE THE BARONS' ACCOUNT FROM THE WORDS ON THEIR WRITING TABLE. THE VERSION ZAMPANO READS ALOUD CAN SAY \"NECESSITY\" OR NAME THE CITY AND THE DEBT OUTRIGHT. INNOCENT III'S ANGER REACHES CAMP EITHER WAY. THE PENITENT LEADERS RECEIVE ABSOLUTION AND A WARNING AGAINST FURTHER ATTACKS ON CHRISTIANS. THE VENETIANS HAVE YET TO RECEIVE ABSOLUTION.",
      source: 'INNOCENT III: LETTER ON ABSOLUTION AND THE GREEKS. BARBERO, LA QUARTA CROCIATA.',
      script: () => [
        stage('zara', [{ name: 'legate', who: 'legate', at: '7', face: 'SE' }], { at: '1' }),
        say('legate', "THE BARONS' WRITING TABLE. THE WORDS ARE ALL THERE. YOU READ IT ALOUD."),
        mini(() => new LetterGame(), { won: { grace: 4 } }),
        call((ctx) => ctx.notice(ctx.state.flags.letter === 'named' ? 'HE NAMED THE CITY AND THE DEBT' : 'HE SAID "NECESSITY"', C.yellow)),
        say('legate', 'THE POPE IS ANGRY EITHER WAY. YOUR LEADERS ARE ABSOLVED. THE VENETIANS ARE NOT.'),
        say('doge', '(FROM THE QUAY) WE CAN WAIT.'),
        say('zampano', 'THERE WAS A LETTER, AND IT SAID WHAT I READ.', { remembered: true }),
      ],
    },
    {
      id: '5.5',
      title: 'Too late for Egypt',
      happens:
        'AT THE QUAY THE SAILMAKERS ARE TAKING DOWN THE CANVAS. CARRY THE LAST ROLLED SAIL INTO A STOREHOUSE. THE STREET WHERE THE LOOT WAS COUNTED BECOMES THE WINTER CAMP. CHALK THE UNPAID BALANCE ON THE ACCOUNT BOARD. SOMEONE HAS ALREADY WRITTEN "JERUSALEM" AT THE TOP.',
      source: 'BARBERO, LA QUARTA CROCIATA: THE WINTER QUARTERS AT ZARA.',
      script: () => {
        return [
          stage('zara', [{ name: 'sailmaker', who: 'crowdC', at: '9', face: 'W' }], { at: 'S' }),
          say('crowdC', 'THE LAST SAIL. A BIT LATE FOR EGYPT, THEY SAY. TAKE IT TO THE STOREHOUSE.'),
          carry('THE LAST ROLLED SAIL'),
          walk({ objective: 'CARRY THE LAST SAIL INTO THE STOREHOUSE', goal: { reach: '3', label: 'STOREHOUSE' } }),
          dropCarried(),
          card('THE WINTER CAMP', 'THE STREET WHERE THE LOOT WAS COUNTED', { color: '#9aa4c0', seconds: 2 }),
          walk({
            objective: 'CHALK THE UNPAID BALANCE ON THE ACCOUNT BOARD',
            action: 'CHALK',
            goal: { reach: '1', label: 'ACCOUNT BOARD' },
            // Reaching the board is not enough: only the chalk finishes the walk.
            survive: 1e9,
            pilot: (ctx) => ({ target: ctx.marker('1'), hold: true, act: distTo(ctx, ctx.marker('1')) < 1.2 }),
            onAction: (ctx, w) => {
              if (distTo(ctx, ctx.marker('1')) > 1.5) return;
              w.complete = true;
            },
          }),
          card('JERUSALEM', 'STILL OWED: 36,000 MARKS', { above: 'SOMEONE HAS ALREADY WRITTEN', color: '#f0f0f0' }),
          say('zampano', 'THERE WAS A BOARD, AND JERUSALEM WAS AT THE TOP OF IT.', { remembered: true }),
        ];
      },
    },
  ],
};
