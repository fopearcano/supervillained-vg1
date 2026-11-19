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
 * Level 5 — Zara, November 1202 to spring 1203: the first diversion. A Christian city, held by
 * the King of Hungary, is attacked for the Venetians in exchange for time on the debt. The pope
 * forbids it; the host is divided; the city falls; the host quarrels inside it and winters there,
 * still owing the money (Villehardouin pp. 16-27; Clari 13-16).
 */
export const CH5: ChapterDef = {
  number: 5,
  title: CHAPTER_TITLES[4],
  intro: 'ZARA HAS CHURCH TOWERS WITH CROSSES ON TOP, LIKE THE ONE SEWN ON HIS BACK. THE HOST IS GOING TO TAKE IT FOR THE VENETIANS, BECAUSE OF THE DEBT. ZAMPANO WILL CLIMB A LADDER AND HEAR THE REASONS AFTERWARDS.',
  cast: 'BAGNASKIZ AS THE MARSHAL; THE DOGE; SBRIMBRULON AS PIERRE; CONFUSIONE AS ALEAUME; AN ABBOT WITH A LETTER',
  theme: 'zara',
  music: 'medieval',
  professor: {
    text: "THE ABBOT FORBADE IT IN THE POPE'S NAME. THE CITY FELL ANYWAY. THEN THE ABSOLUTION CAME BACK FROM ROME, AND CLARI AND VILLEHARDOUIN DO NOT EVEN AGREE ON WHO IT WAS FOR.",
  },
  subLevels: [
    {
      id: '5.1',
      title: 'A small favor for Venice',
      happens:
        "AN ABBOT READS OUT THE POPE'S PROHIBITION: THESE PEOPLE ARE CHRISTIANS. THE DOGE WILL NOT HEAR OF STOPPING. CARRY MESSAGES BETWEEN TWO GROUPS ON THE QUAY: ONE TOOK THE CROSS FOR JERUSALEM, NOT FOR THIS; THE OTHER SAYS THE HOST FALLS APART UNLESS THEY HELP THE DOGE. THEN SAY ONE OF THEM OUT LOUD. THE MARSHAL REMEMBERS WHO SPOKE AGAINST HIM.",
      source:
        "VILLEHARDOUIN PP. 20-21: THE ABBOT OF VAUX FORBIDS THE ATTACK 'ON THE PART OF THE POPE OF ROME'; THE PARTY THAT WANTED THE HOST BROKEN UP; THE BARONS PERSIST. CLARI 14: ZARA HAS A LETTER FROM ROME THREATENING EXCOMMUNICATION, AND THE DOGE WILL NOT REFRAIN FOR IT. THE MESSENGER ROLE IS ADAPTATION.",
      script: () => [
        stage('zara', [
          { name: 'k1', who: 'knight', at: '8', face: 'E' },
          { name: 'k2', who: 'crowdA', at: { x: 4.5, y: 9.5 }, face: 'E' },
          { name: 'abbot', who: 'legate', at: { x: 6.5, y: 7.5 }, face: 'SE' },
          { name: 'marshal', who: 'bagnaskizMarshal', at: '9', face: 'W' },
          { name: 'doge', who: 'doge', at: { x: 15.5, y: 8.2 }, face: 'W' },
        ]),
        say('voice', 'ABOVE THE WALLS: CHURCH TOWERS, AND CROSSES ON THEM.'),
        say('abbot', "(AN ABBOT, WITH A LETTER) LORDS, ON THE POPE'S BEHALF I FORBID YOU TO ATTACK THIS CITY. THE PEOPLE IN IT ARE CHRISTIANS."),
        say('doge', 'NOT FOR ALL THE LETTERS IN ROME. THIS CITY IS MINE AND IT WAS TAKEN FROM ME.'),
        say('voice', 'TWO GROUPS ON THE QUAY. NEITHER WILL WALK OVER TO THE OTHER. YOU WILL.'),
        walk({ objective: 'HEAR THE FIRST GROUP', goal: { reach: '8', radius: 1.4, label: 'THE FIRST GROUP' } }),
        say('knight', 'WE TOOK THE CROSS TO GO TO JERUSALEM. NOT TO TAKE A CHRISTIAN CITY FOR VENICE. TELL THEM THAT.'),
        carry('THE MESSAGE'),
        walk({ objective: 'CARRY THE MESSAGE TO THE OTHER GROUP', goal: { reach: '9', radius: 1.4, label: 'THE MARSHAL' } }),
        say('marshal', 'TELL THEM THE HOST FALLS APART UNLESS WE HELP THE DOGE. NO ZARA, NO SHIPS, NO JERUSALEM.'),
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
            effects: { standing: -12, supervillain: 5, grace: 4, flags: { dissent: true } },
            then: [say('marshal', 'I WILL REMEMBER WHO SAID THAT.')],
          },
          { label: 'THE HOST FALLS APART UNLESS WE HELP THE DOGE.', effects: { standing: 5 }, then: [say('marshal', 'GOOD DOG.')] },
        ]),
        say('doge', 'A SMALL FAVOR FOR VENICE. THEN JERUSALEM.'),
        card('THE SIEGE BEGINS', 'SOME LORDS PITCH THEIR TENTS AWAY FROM THE OTHERS', { color: C.orange, seconds: 2.2 }),
        say('zampano', 'THERE WAS A MESSAGE, AND IT WAS HEAVIER EACH WAY.', { remembered: true }),
      ],
    },
    {
      id: '5.2',
      title: 'A cross above the wall',
      happens:
        'HIS CROSS CATCHES ON THE LADDER AND THE MEN BEHIND HIM ASK HIM TO GET A MOVE ON. CLIMB, THEN STEADY THE LADDER FOR THE NEXT SMALL BODY. THE CITY SURRENDERS AND THE GOODS ARE CARRIED OUT: FOLLOW ONE BOLT OF RED CLOTH FROM A HOUSE TO THE COMMON PILE, AND REMEMBER THE HOUSE.',
      source:
        'VILLEHARDOUIN PP. 21-22: THE SIEGE, THE SURRENDER, THE CITY DIVIDED BETWEEN VENETIANS AND FRANKS. THE LADDER, THE STONES AND THE BOLT OF CLOTH ARE ADAPTATION; THE CLOTH PREPARES THE COMMON PILE OF 1204.',
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
            ctx.addActor('sbrim', 'sbrimbrulonKnight', { x: 10.5, y: 5.5 }, { kind: 'idle', face: 'W' });
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
          card('THE CITY SURRENDERS', 'THE GOODS ARE CARRIED OUT', { color: C.orange, seconds: 2.4 }),
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
      title: 'Whose orders?',
      happens:
        "INSIDE THE CITY, VENETIANS AND PILGRIMS FIGHT IN THE STREETS ALL NIGHT. ON THE WAY HEAR WHAT THREE PEOPLE SAY HE OWES: THE ABBOT, THE MARSHAL AND A VENETIAN. ALEAUME WANTS TO KNOW WHICH OF THEM HE BELIEVES. THEN GET HIM BACK TO THEIR QUARTERS THROUGH THE BRAWL: BARK OR SHIELD THE BRAWLERS ASIDE. THE POPE FORBADE THEM TO ATTACK CHRISTIANS, AND EVERY SWORD BLOW THAT LANDS COSTS GRACE.",
      source:
        "VILLEHARDOUIN P. 22 (A FRAY BETWEEN VENETIANS AND FRANKS; PEACE AFTER A WEEK) AND PP. 20-21; CLARI 15 (A GREAT CONTENTION BETWEEN THE VENETIANS AND THE BASER SORT OF PILGRIMS, A NIGHT AND HALF A DAY). REPLACES THE OLD PENITENTIAL/URBAN II EXCURSUS. THE THREE SPEECHES, THE CHOICE, THE FIGHT THROUGH THE BRAWL AND THE GRACE IT COSTS TO USE THE SWORD ARE ADAPTATION.",
      script: () => {
        let brawlT = 0;
        return [
          stage('zara', [
            { name: 'conf', who: 'confusione', at: { x: 14.5, y: 15.5 }, face: 'NW' },
            { name: 'b1', who: 'crowdB', at: { x: 10.5, y: 11.5 }, face: 'E' },
            { name: 'b2', who: 'knight', at: { x: 11.5, y: 11.5 }, face: 'W' },
            { name: 'abbot', who: 'legate', at: '6', face: 'S' },
            { name: 'marshal', who: 'bagnaskizMarshal', at: '2', face: 'S' },
            { name: 'venetian', who: 'crowdB', at: '1', face: 'S' },
          ]),
          call((ctx) => {
            ctx.actor('conf').setBehavior({ kind: 'follow', target: ctx.player, distance: 1.2, speed: 3, side: 0.8 });
            for (const n of ['b1', 'b2']) ctx.actor(n).setBehavior({ kind: 'flail', speed: 1.4, center: { x: 11, y: 11.5 }, radius: 1.2 });
          }),
          say('confusione', 'BROTHER, THE VENETIANS AND OUR PEOPLE ARE FIGHTING IN THE STREETS. AND EVERYONE HAS AN OPINION.'),
          walk({
            objective: 'HEAR THE ABBOT, THE MARSHAL AND THE VENETIAN',
            pickups: [
              { at: { x: 13.5, y: 13.5 }, kind: 'spot', label: 'THE ABBOT', text: '"YOU WERE FORBIDDEN. YOU OWE THE POPE AN APOLOGY, AND THE PEOPLE OF THIS CITY MORE."' },
              { at: { x: 6.5, y: 9.5 }, kind: 'spot', label: 'THE MARSHAL', text: '"YOU OWE THE HOST. IF WE SCATTER, NOBODY GETS ANYWHERE."' },
              { at: { x: 9.5, y: 7.5 }, kind: 'spot', label: 'A VENETIAN', text: '"YOU OWE US THIRTY-SIX THOUSAND MARKS. THE REST IS SERMONS."' },
            ],
            onUpdate: (ctx, _w, dt) => {
              brawlT -= dt;
              if (brawlT > 0) return;
              brawlT = 1.5;
              ctx.say(['YOU CHEATED US!', 'GET OFF MY STREET!', 'VENICE!', 'PICARDY!'][Math.floor(Math.random() * 4)]!, { x: 11, y: 11.5 }, C.orange);
            },
          }),
          ask('confusione', 'SO, BROTHER. WHO DO WE OWE?', [
            {
              label: 'THE POPE. WE WERE FORBIDDEN, AND WE DID IT.',
              effects: { grace: 5, standing: -3, flags: { zaraOwe: 'pope' } },
              then: [say('confusione', 'THEN WE HAVE ALREADY FAILED TO PAY. GOOD TO KNOW.')],
            },
            {
              label: 'THE HOST. WITHOUT IT NOBODY REACHES ANYTHING.',
              effects: { standing: 4, flags: { zaraOwe: 'host' } },
              then: [say('confusione', 'THE MARSHAL WILL BE PLEASED. THE MARSHAL IS ALWAYS PLEASED WITH THE HOST.')],
            },
            {
              label: 'VENICE. WE OWE THEM MONEY. THAT IS ALL.',
              effects: { supervillain: 2, grace: -3, flags: { zaraOwe: 'debt' } },
              then: [say('confusione', 'AT LEAST MONEY CAN BE COUNTED.')],
            },
          ]),
          call((ctx) => {
            ctx.addActor('b3', 'crowdA', { x: 12.5, y: 12.5 }, { kind: 'idle', face: 'player' });
            ctx.notice('THE BRAWL SPILLS INTO YOUR STREET', C.orange);
          }),
          say('confusione', 'THE POPE FORBADE US TO DRAW ON CHRISTIANS, BROTHER. A BARK, A SHIELD. NOT THE SWORD.'),
          walk({
            objective: 'GET BACK TO YOUR QUARTERS THROUGH THE BRAWL',
            goal: { reach: 'S', label: 'QUARTERS' },
            fight: {
              foes: ['b1', 'b2', 'b3'],
              rout: 0,
              hp: 2,
              speed: 1.3,
              radius: 3.5,
              leash: 5,
              routLines: ['VENICE!', 'PICARDY!', 'NOT WORTH IT!'],
              swordCost: { grace: -1 },
              swordCostText: 'A SWORD ON A CHRISTIAN, AT ZARA: THE FORBIDDEN THING',
              knockedText: 'UP AGAIN. BARK THEM BACK OR RAISE THE SHIELD AND PUSH THROUGH.',
            },
          }),
          card('A WEEK LATER', 'THE STREETS MAKE PEACE. NOBODY MAKES PEACE WITH THE DEBT.', { color: '#9aa4c0', seconds: 2.2 }),
          say('zampano', 'THERE WERE THREE DEBTS, AND I COULD ONLY PAY ONE.', { remembered: true }),
        ];
      },
    },
    {
      id: '5.4',
      title: 'A letter for Rome',
      happens:
        "THE BARONS SEND ENVOYS TO ROME TO ASK FORGIVENESS. ASSEMBLE THEIR ACCOUNT FROM THE WORDS ON THE WRITING TABLE: THE VERSION ZAMPANO READS ALOUD CAN PLEAD 'NECESSITY' OR NAME THE DEBT OUTRIGHT. WHEN THE ENVOYS COME BACK, THE MARSHAL'S VERSION OF THE ANSWER AND THE CAMP'S VERSION ARE NOT THE SAME.",
      source:
        "VILLEHARDOUIN PP. 26-27: ENVOYS TO ROME; THE POPE ABSOLVES THE PILGRIMS. THE ENVOYS NAMED BY VILLEHARDOUIN: NEVELON BISHOP OF SOISSONS, JOHN OF NOYON, JOHN OF FRIAIZE AND ROBERT OF BOVES (WHO DOES NOT COME BACK). CLARI 15: LETTERS 'WHEREBY ALL THE PILGRIMS AND ALL THE VENETIANS WERE ABSOLVED'. THE TWO ACCOUNTS DIFFER AND THE SCENE KEEPS BOTH. NO PAPAL WORDS ARE QUOTED. THE WRITING TABLE IS ADAPTATION.",
      script: () => [
        stage('zara', [{ name: 'envoy', who: 'legate', at: '7', face: 'SE' }], { at: '1' }),
        say('envoy', "THE BARONS' WRITING TABLE. THE WORDS ARE ALL THERE. YOU READ IT ALOUD, LITTLE ONE; YOUR VOICE IS THE BIGGEST THING ABOUT YOU."),
        mini(() => new LetterGame(), { won: { grace: 4 } }),
        call((ctx) => ctx.notice(ctx.state.flags.letter === 'named' ? 'HE NAMED THE CITY AND THE DEBT' : 'HE SAID "NECESSITY"', C.yellow)),
        say('marshal', 'THE POPE HAS ABSOLVED THE PILGRIMS. THAT IS WHAT MATTERS.'),
        say('voice', '(THE CAMP) EVERYONE IS ABSOLVED. THE VENETIANS TOO, THEY SAY.'),
        say('doge', '(FROM THE QUAY) WE CAN WAIT.'),
        say('zampano', 'THERE WAS A LETTER, AND IT SAID WHAT I READ. THE ANSWER SAID TWO THINGS.', { remembered: true }),
      ],
    },
    {
      id: '5.5',
      title: 'Winter at Zara',
      happens:
        'NOBODY SAILS IN WINTER. AT THE QUAY THE SAILMAKERS ARE TAKING DOWN THE CANVAS: CARRY THE LAST ROLLED SAIL INTO A STOREHOUSE. THE STREET WHERE THE GOODS WERE COUNTED BECOMES THE WINTER CAMP. CHALK THE UNPAID BALANCE ON THE ACCOUNT BOARD. SOMEONE HAS ALREADY WRITTEN JERUSALEM AT THE TOP.',
      source:
        'CLARI 13 AND 16: IT IS WINTER; THE PILGRIMS WINTER AT ZARA AND LOSE HEART; THEY CANNOT REACH BABYLON OR ALEXANDRIA WITHOUT MONEY AND FOOD (CLARI XVI, MUNRO). THE SAIL, THE STOREHOUSE AND THE BOARD ARE ADAPTATION.',
      script: () => [
        stage('zara', [{ name: 'sailmaker', who: 'crowdC', at: '9', face: 'W' }], { at: 'S' }),
        say('sailmaker', 'THE LAST SAIL. NOBODY SAILS IN WINTER. TAKE IT TO THE STOREHOUSE.'),
        carry('THE LAST ROLLED SAIL'),
        walk({ objective: 'CARRY THE LAST SAIL INTO THE STOREHOUSE', goal: { reach: '3', label: 'STOREHOUSE' } }),
        dropCarried(),
        card('THE WINTER CAMP', 'THE STREET WHERE THE GOODS WERE COUNTED', { color: '#9aa4c0', seconds: 2 }),
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
        card('JERUSALEM', 'STILL OWED TO VENICE: 36,000 MARKS. NO MONEY FOR EGYPT. NO FOOD FOR SYRIA.', { above: 'SOMEONE HAS ALREADY WRITTEN', color: '#f0f0f0' }),
        say('zampano', 'THERE WAS A BOARD, AND JERUSALEM WAS AT THE TOP OF IT.', { remembered: true }),
      ],
    },
  ],
};
