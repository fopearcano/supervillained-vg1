import { LaddersGame, TugGame, mini } from '../../story/minigames';
import { ask, blackHoleIn, blackHoleOut, branch, call, card, fx, move, say, sound, stage } from '../../story/steps';
import { walk } from '../../story/walk';
import { C } from '../../ui/retro';
import { companions, dreamSkin, spend } from '../state';
import { STORY } from '../../config';
import { CHAPTER_TITLES } from '../titles';
import type { StoryScene } from '../../story/storyScene';
import type { ChapterDef } from '../types';
import { bark, near, wander } from './helpers';

/**
 * Level 7 — Constantinople. "The day of Clari's life, the vanguard that would not turn back;
 * everything before it is training for 7.3." Cast: Sbrimbrulon as Pierre d'Amiens; Bagnaskiz as
 * Alexios III, then Alexios V; Confusione as Aleaume; Jack as the looter; Santina on the walls.
 */
export const CH7: ChapterDef = {
  number: 7,
  title: CHAPTER_TITLES[6],
  intro: "CONSTANTINOPLE HOLDS THE DAY OF CLARI'S LIFE, THE VANGUARD THAT WOULD NOT TURN BACK. EVERYTHING BEFORE IT WAS TRAINING.",
  cast: "SBRIMBRULON AS PIERRE D'AMIENS; BAGNASKIZ AS THE USURPER; CONFUSIONE AS ALEAUME; JACK AS THE LOOTER; SANTINA ON THE WALLS",
  theme: 'constantinople',
  music: 'medieval',
  professor: {
    after: '4C',
    text: 'WHO TOLD ROBERT DE CLARI WHAT THE GREEK GIRLS WERE SAYING UP ON THE WALLS, I COULD NOT TELL YOU. BUT THAT THEY WERE HANDSOME THAT DAY: OF THAT HE IS CERTAIN.',
  },
  subLevels: [
    {
      id: '7.1',
      title: 'The flesh trembles',
      happens: 'THE FLEET LANDS ACROSS THE WATER FROM THE CITY. NOBODY IS SO BRAVE THAT HIS FLESH DOES NOT TREMBLE. FROM WALLS AND ROOFS THE GREEKS STARE BACK AT BEARDLESS BARBARIANS. THE PRINCE IS ROWED UNDER THE WALLS, AND NOBODY RECOGNISES HIM.',
      source: 'THE ARRIVAL AND THE MUTUAL WONDER; NIKETAS ON THE SHAVEN WESTERNERS AND THE YEAR 6711; THE PRINCE IN THE BOAT (4C).',
      script: () => [
        stage('city', [
          { name: 'g1', who: 'greek', at: '8', face: 'S' },
          { name: 'g2', who: 'greek', at: '6', face: 'SE' },
          { name: 'santina', who: 'santina', at: '5', face: 'SW' },
        ]),
        say('voice', 'NEWS: JACK THE GENERAL IS EXPECTED ANY DAY NOW. FROM THE EAST.'),
        card('THE FLESH TREMBLES', 'NOBODY IS SO BRAVE THAT HIS FLESH DOES NOT TREMBLE', { color: C.yellow, seconds: 2.2 }),
        say('zampano', 'THERE ARE MORE ROOFS THAN THERE ARE DOGS IN THE WORLD.'),
        walk({
          objective: 'WONDER HUNT: LOOK AT THE CITY (AND LET IT LOOK AT YOU)',
          action: 'LOOK',
          pickups: [
            { at: '7', kind: 'marvel', label: 'THE GREAT WALLS', text: 'TOWER AFTER TOWER, AS FAR AS THE SEA', effects: { marvel: 'THE GREAT WALLS', commozione: 3 } },
            { at: '3', kind: 'marvel', label: 'THE CITY OF ROOFS', text: 'EVERY ROOF IS FULL OF PEOPLE STARING', effects: { marvel: 'THE CITY OF ROOFS', commozione: 3 } },
            { at: '4', kind: 'marvel', label: 'THE GOLDEN DOMES', text: 'THEY SHINE EVEN WHEN THE SUN DOES NOT', effects: { marvel: 'THE GOLDEN DOMES', commozione: 3 } },
          ],
          onAction: (ctx) => ctx.say('OOOH.', { x: ctx.player.gx, y: ctx.player.gy }, C.yellow),
        }),
        say('greek', 'IN THE YEAR SIX THOUSAND SEVEN HUNDRED AND ELEVEN, THE BEARDLESS BARBARIANS CAME. THEY SHAVE. EVEN THEIR CHINS.'),
        say('santina', 'THEY LOOK LIKE BOILED EGGS WITH SWORDS.'),
        call((ctx) => ctx.addActor('prince', 'prince', { x: ctx.player.gx + 0.8, y: ctx.player.gy + 0.6 }, { kind: 'follow', target: ctx.player, distance: 1.1, speed: 2.4, side: 0.6 })),
        say('voice', 'SHOW THE PRINCE TO THE CITY. THEY WILL OPEN THE GATES FOR HIM WITH JOY.'),
        walk({ objective: 'SHOW THE PRINCE UNDER THE WALLS', goal: { reach: '0' } }),
        say('prince', 'BEHOLD! YOUR LORD!'),
        say('greek', 'WHO?'),
        card('NOBODY RECOGNISES HIM', 'THE TASK FAILS BY DESIGN', { color: C.red, seconds: 2.2 }),
        say('zampano', 'THERE WAS A PRINCE, AND NOBODY HAD EVER SEEN HIM.', { remembered: true }),
      ],
    },
    {
      id: '7.2',
      title: 'Ladders',
      happens: 'FIRST ASSAULT. LADDERS GO UP FROM THE GALLEYS; PITCH AND STONES COME DOWN; AXE-MEN HOLD THE PARAPET. THE BLIND DOGE STANDS AT THE PROW WITH THE BANNER AND ORDERS HIMSELF PUT ASHORE.',
      source: 'THE ASSAULT "AS IN FILMS AND VIDEO GAMES"; THE VARANGIANS; THE DOGE\'S LANDING (4C).',
      script: () => {
        let skin = 'zampano';
        return [
          stage('ship', [{ name: 'doge', who: 'doge', at: '3', face: 'N' }], { at: '1' }),
          call((ctx) => (skin = dreamSkin(ctx.state))),
          say('doge', 'I AM OLD AND BLIND. GIVE ME THE BANNER OF SAINT MARK AND PUT ME ASHORE.'),
          say('doge', 'WHOEVER DOES NOT FOLLOW ME, I WILL HAVE HANGED. NICELY.'),
          card('FIRST ASSAULT', 'LADDERS FROM THE GALLEYS. AS IN FILMS AND VIDEO GAMES.', { color: C.orange, seconds: 2 }),
          mini(() => new LaddersGame(30, true, skin), { won: { supervillain: 8, standing: 5 }, lost: { standing: -3 }, retryOnLoss: true }),
          say('zampano', 'THERE WAS A LADDER, AND THE TOP WAS AN AXE.', { remembered: true }),
        ];
      },
    },
    {
      id: '7.3',
      title: 'The vanguard',
      happens: 'THE USURPER RIDES OUT. FLANDERS HAS THE VANGUARD AND TURNS BACK. SBRIMBRULON AND THE COUNT OF SAINT-POL ANSWER THAT THEY WILL NOT TURN BACK AT ALL, AND GO ON AT A WALK. LADIES AT THE WINDOWS SAY THEY LOOK LIKE ANGELS. THE USURPER TURNS AND GOES IN. NO SWORD IS DRAWN.',
      source: "CLARI'S ACCOUNT OF THE DAY; PIERRE D'AMIENS, LI BIAUS ET LI PREUS; VILLEHARDOUIN'S DRY COMMENT THAT EVERYONE WAS VERY GLAD (4C). BOARD: \"CORAGGIO FISICO\".",
      script: () => {
        const said = new Set<string>();
        return [
          call((ctx) => {
            ctx.setStage('field');
            ctx.addActor('usurper', 'bagnaskizEmperor', '9', { kind: 'idle', face: 'S' });
            ctx.addActor('v1', 'varangian', '8', { kind: 'idle', face: 'S' });
            ctx.addActor('v2', 'varangian', '7', { kind: 'idle', face: 'S' });
            ctx.addActor('flanders', 'knight', '3', { kind: 'idle', face: 'N' });
            ctx.addActor('lady1', 'lady', '5', { kind: 'idle', face: 'SE' });
            ctx.addActor('lady2', 'santina', '6', { kind: 'idle', face: 'SW' });
            ctx.addActor('sbrim', 'sbrimbrulon', { x: ctx.player.gx - 0.9, y: ctx.player.gy - 0.9 }, { kind: 'idle', face: 'N' });
            ctx.addActor('stpol', 'knight', '4', { kind: 'idle', face: 'N' });
          }),
          say('emperor', 'I RIDE OUT. ALL OF YOU. AT THEM.'),
          say('knight', 'THE VANGUARD TURNS BACK! BACK TO THE CAMP!'),
          call((ctx) => ctx.actor('flanders').setBehavior({ kind: 'goto', to: ctx.marker('2'), speed: 3.2, run: true })),
          say('sbrimbrulon', 'WE WILL NOT TURN BACK AT ALL. WE GO ON. AT A WALK.'),
          say('sbrimbrulon', 'YOU ARE IN THE SECOND RANK, ZAMPANO. SAME PACE AS ME. NOT FASTER. NOT SLOWER.'),
          call((ctx) => {
            // Standing decides who walks beside him; each companion steadies his nerve.
            const who = companions(ctx.state, 'vanguard');
            ctx.actor('sbrim').setBehavior({ kind: 'follow', target: ctx.player, distance: 1.2, speed: 2.4, side: -0.9 });
            if (who.includes('stpol')) ctx.actor('stpol').setBehavior({ kind: 'follow', target: ctx.player, distance: 1.4, speed: 2.4, side: 0.9 });
            else ctx.notice('THE COUNT OF SAINT-POL KEEPS HIS DISTANCE (STANDING TOO LOW)', C.orange);
          }),
          walk({
            objective: 'HOLD THE PACE: DO NOT CHARGE, DO NOT TURN BACK',
            goal: { reach: '1', radius: 1.2 },
            pace: { pressure: 0.035, companions: ['sbrim', 'stpol', 'flanders'] },
            onUpdate: (ctx, w) => {
              const p = ctx.player;
              const goal = ctx.marker('1');
              const start = ctx.marker('S');
              const done = 1 - Math.hypot(goal.x - p.gx, goal.y - p.gy) / (Math.hypot(goal.x - start.x, goal.y - start.y) || 1);
              const once = (key: string, at: number, fn: () => void) => {
                if (done >= at && !said.has(key)) {
                  said.add(key);
                  fn();
                }
              };
              once('shout', 0.15, () => ctx.say('THEY ARE SHOUTING!', ctx.marker('8'), C.red));
              once('flanders', 0.35, () => {
                if (companions(ctx.state, 'vanguard').includes('flanders')) {
                  ctx.notice('A COUNT IS SHAMED INTO RIDING BACK TO THE FRONT', C.cyan);
                  ctx.actor('flanders').setBehavior({ kind: 'follow', target: p, distance: 1.6, speed: 3, side: 0 });
                } else ctx.notice('FLANDERS STAYS BACK IN THE CAMP', C.orange);
              });
              once('angels', 0.6, () => {
                ctx.say('THEY LOOK LIKE ANGELS!', ctx.marker('5'), C.hotPink);
                ctx.say('LIKE ANGELS!', ctx.marker('6'), C.hotPink);
              });
              once('nerve', 0.8, () => ctx.notice('NO SWORD IS DRAWN', C.yellow));
              void w;
            },
          }),
          call((ctx) => {
            ctx.actor('usurper').setBehavior({ kind: 'goto', to: { x: ctx.marker('9').x, y: ctx.marker('9').y - 2 }, speed: 2.2 });
            ctx.actor('v1').setBehavior({ kind: 'goto', to: { x: ctx.marker('8').x, y: ctx.marker('8').y - 2 }, speed: 2 });
            ctx.actor('v2').setBehavior({ kind: 'goto', to: { x: ctx.marker('7').x, y: ctx.marker('7').y - 2 }, speed: 2 });
            ctx.apply({ supervillain: 15, value: 'Physical courage', flags: { vanguard: true } });
          }),
          card('THE USURPER TURNS', 'AND GOES IN. NO SWORD IS DRAWN.', { color: C.cyan, seconds: 2.4 }),
          say('marshal', 'EVERYONE WAS VERY GLAD.'),
          say('zampano', 'THERE WERE A LOT OF THEM, AND THEY WERE SHOUTING.'),
          say('sbrimbrulon', "LET THEM SHOUT. BY GOD'S COIF, WE WILL TALK ABOUT TODAY IN THE LADIES' CHAMBERS."),
          say('zampano', 'YOU SAID COIF.'),
          say('sbrimbrulon', 'GOD, YES. THE OTHER ONE, NEVER.', { remembered: true }),
        ];
      },
    },
    {
      id: '7.4',
      title: 'Tourists and fire',
      happens: 'PEACE. THE PILGRIMS GO SIGHTSEEING AMONG PALACES, CHURCHES AND RELICS. THEN BRAWLS. A RAID ON A MOSQUE IS BEATEN OFF BY MUSLIMS AND THEIR GREEK NEIGHBOURS TOGETHER, AND A FIRE EATS A GREAT PART OF THE CITY.',
      source: "THE TOURIST SEASON, THE MOSQUE, THE GREAT FIRE, NIKETAS'S BURNT PALACE (4C).",
      script: () => [
        stage('city', [
          { name: 'watson', who: 'watson', at: '1', face: 'SE' },
          { name: 'g1', who: 'greek', at: '2', face: 'NE' },
        ]),
        say('watson', 'MAN, IT IS PEACE. WE ARE TOURISTS NOW.'),
        walk({
          objective: 'SIGHTSEEING: PALACES, CHURCHES AND RELICS',
          action: 'LOOK',
          pickups: [
            { at: '5', kind: 'marvel', label: 'THE GOLDEN PALACE', text: 'FIVE HUNDRED HALLS, ALL IN GOLD MOSAIC', effects: { marvel: 'THE GOLDEN PALACE', commozione: 3 } },
            { at: '6', kind: 'relic', label: 'THE CHAPEL OF RELICS', text: 'MORE RELICS THAN THERE ARE SAINTS', effects: { marvel: 'THE CHAPEL OF RELICS', commozione: 3 } },
            { at: '8', kind: 'marvel', label: 'THE CHURCH OF THE APOSTLES', text: 'NOBODY COULD TELL ITS RICHES', effects: { marvel: 'THE CHURCH OF THE APOSTLES', commozione: 3 } },
          ],
          onAction: (ctx) => ctx.say('OOOH.', { x: ctx.player.gx, y: ctx.player.gy }, C.yellow),
        }),
        card('BRAWLS', 'TOURISM DOES NOT LAST', { color: C.orange, seconds: 1.6 }),
        say('zampano', 'WHERE ARE THE TURKS?'),
        say('greek', 'THOSE ARE OUR NEIGHBOURS. THEY HAVE A MOSQUE. LEAVE THEM ALONE.'),
        card('THE MOSQUE', 'A RAID IS BEATEN OFF BY MUSLIMS AND THEIR GREEK NEIGHBOURS TOGETHER', { color: C.cyan, seconds: 2.6 }),
        walk({
          objective: 'ESCAPE THE FIRE',
          goal: { reach: '9' },
          fire: { from: '3', spread: 0.3, startAfter: (w) => w.time > 0.8 },
        }),
        call((ctx) => ctx.addActor('niketas', 'greek', { x: ctx.player.gx + 1, y: ctx.player.gy - 0.6 }, { kind: 'idle', face: 'player' })),
        say('greek', 'THAT WAS MY HOUSE. IT HAD A VERY GOOD COURTYARD.'),
        say('zampano', 'THERE WAS A CITY, AND IT WAS ON FIRE, AND I WAS A TOURIST.', { remembered: true }),
      ],
    },
    {
      id: '7.5',
      title: "Black hole: the usurper's wedding night",
      happens: 'A ROMANCE EMPEROR, DRUGGED, SPENDS THE NIGHT EMBRACING NOTHING AND BELIEVING ALL OF IT. THE BRIDE KEEPS HER DISTANCE.',
      source: "CHRETIEN'S CLIGES (SG). BOARD: BAGNASKIZ AS USURPER.",
      blackHole: { where: 'A ROMANCE. A WEDDING NIGHT.', value: 'A dream embraces nothing' },
      script: () => [
        ...blackHoleIn('A ROMANCE. A WEDDING NIGHT.'),
        call((ctx) => {
          ctx.setStage('palace');
          const e = ctx.addActor('emperor', 'bagnaskizEmperor', '4', { kind: 'flail', speed: 1.6, center: ctx.marker('4'), radius: 2.4 });
          e.sight = { range: 3, halfAngle: 0.6 };
          ctx.addActor('bride', 'lady', '8', { kind: 'idle', face: 'SW' });
        }),
        say('voice', 'THE POTION WORKS. HE EMBRACES NOTHING, AND BELIEVES ALL OF IT.'),
        say('emperor', 'AH, MY LOVE! AH! MMMH! (HE IS HUGGING THE AIR.)'),
        walk({
          objective: 'SNEAK ACROSS THE ROOM TO THE BRIDE',
          goal: { reach: '8' },
          noRun: true,
          caught: 'restart',
          caughtText: 'HE HUGGED YOU INSTEAD',
        }),
        say('lady', 'I KEEP MY DISTANCE. HE IS VERY HAPPY. EVERYONE WINS.'),
        say('zampano', 'THERE WAS A BRIDE, AND SHE WAS ON THE OTHER SIDE OF THE ROOM.', { remembered: true }),
        ...blackHoleOut('A dream embraces nothing'),
      ],
    },
    {
      id: '7.6',
      title: 'Out of the muck',
      happens: 'THE EMPERORS STOP PAYING. ENVOYS DEFY THEM IN THEIR OWN THRONE ROOM AND WALK OUT ALIVE. FROM HIS GALLEY THE DOGE TELLS THE BOY THAT THEY PULLED HIM OUT OF THE MUCK AND WILL PUT HIM BACK IN. A THIRD ALEXIOS DOES AWAY WITH BOTH EMPERORS AND ORDERS THE PILGRIMS TO LEAVE.',
      source: "THE EMBASSY; THE DOGE'S WORDS AS CLARI HEARD THEM; THE COUP OF ALEXIOS V (4C).",
      script: () => {
        const runCheck = (ctx: StoryScene) => {
          if (!ctx.player.running) return;
          ctx.interrupt([card('YOU RAN', 'ENVOYS DO NOT RUN. AGAIN.', { color: C.red, seconds: 1.6 }), call(() => ctx.player.setPosition(ctx.marker('S').x, ctx.marker('S').y))]);
        };
        return [
          call((ctx) => {
            ctx.setStage('palace');
            ctx.addActor('prince', 'prince', '1', { kind: 'idle', face: 'S' });
            ['2', '3', '5', '6'].forEach((m, k) => ctx.addActor(`v${k}`, 'varangian', m, { kind: 'idle', face: 'player' }));
          }),
          say('voice', 'THE EMPERORS HAVE STOPPED PAYING. GO IN ARMED. SPEAK. TURN YOUR BACK. DO NOT RUN.'),
          walk({ objective: 'GO IN ARMED. DO NOT RUN', goal: { reach: '7', radius: 1 }, onUpdate: (ctx) => runCheck(ctx) }),
          ask('prince', 'WHAT DO YOU WANT, BARBARIAN?', [
            { label: 'PAY WHAT YOU SWORE, OR WE ARE NO LONGER FRIENDS.', effects: { supervillain: 6, standing: 4 } },
            { label: 'WE DEFY YOU. FROM NOW ON, DO YOUR WORST.', cost: STORY.COST.DEFY, effects: { supervillain: 8 } },
            { label: '(TREMBLE QUIETLY)', locked: 'ENVOYS DO NOT TREMBLE' },
          ]),
          say('prince', '...'),
          walk({ objective: 'TURN YOUR BACK AND WALK OUT. DO NOT RUN', goal: { reach: 'S', radius: 1 }, onUpdate: (ctx) => runCheck(ctx) }),
          card('ALIVE', 'THEY WALK OUT ALIVE. NOBODY CAN BELIEVE IT.', { color: C.green, seconds: 2 }),
          stage('ship', [
            { name: 'doge', who: 'doge', at: '5', face: 'E' },
            { name: 'prince', who: 'prince', at: '6', face: 'W' },
          ]),
          say('doge', 'WE PULLED YOU OUT OF THE MUCK, BOY. AND WE WILL PUT YOU BACK IN.'),
          call((ctx) => ctx.addActor('watson', 'watson', { x: ctx.player.gx + 1, y: ctx.player.gy + 0.4 }, { kind: 'idle', face: 'player' })),
          say('watson', 'MAN, THERE IS A NEW EMPEROR. I HEARD IT FROM A TENT. THE OTHER TWO ARE... DONE AWAY WITH.'),
          card('A THIRD ALEXIOS', 'THE POOR KNIGHT LEARNS IT LATE AND SECOND-HAND', { color: '#c070f0', seconds: 2 }),
          call((ctx) => ctx.addActor('usurper', 'bagnaskizEmperor', { x: ctx.player.gx - 1.4, y: ctx.player.gy - 1 }, { kind: 'idle', face: 'player' })),
          say('emperor', 'LEAVE. ALL OF YOU. BY THURSDAY.'),
          say('zampano', 'THERE WAS A THRONE, AND I TURNED MY BACK ON IT.', { remembered: true }),
        ];
      },
    },
    {
      id: '7.7',
      title: 'The breach',
      happens: 'OATHS FIRST: NO WOMAN TOUCHED, NO CHURCH ROBBED, ALL LOOT IN COMMON. THE ICON IS CAPTURED. THE FIRST ASSAULT FAILS AND THE GREEKS BARE THEIR BACKSIDES FROM THE WALLS. THEN A HOLE THAT NOBODY DARES ENTER. CONFUSIONE GOES IN ON HANDS AND FEET. ZAMPANO GRABS HIS LEG TO STOP HIM, FAILS, AND FOLLOWS.',
      source: 'THE OATHS, THE ICON, THE MOONING, ALEAUME DE CLARI AND HIS BROTHER (4C). PRIESTS WHO FIGHT (CR3).',
      script: () => [
        stage('breach', [
          { name: 'legate', who: 'legate', at: '3', face: 'SE' },
          { name: 'conf', who: 'confusione', at: '4', face: 'SW' },
          { name: 'jack', who: 'jack', at: '1', face: 'S' },
        ]),
        say('legate', 'OATHS FIRST. NO WOMAN TOUCHED. NO CHURCH ROBBED. ALL LOOT IN COMMON.'),
        ask('legate', 'SWEAR.', [{ label: 'SO HELP ME GOD.', effects: { grace: 5, flags: { sworn: true } } }]),
        say('jack', 'SO HELP ME GOD. (HE IS CROSSING HIS FINGERS.)'),
        card('THE ICON IS CAPTURED', 'FROM THE USURPER\'S OWN CHARIOT', { color: C.yellow, seconds: 2 }),
        card('THE FIRST ASSAULT FAILS', 'THE GREEKS BARE THEIR BACKSIDES FROM THE WALLS', { color: C.orange, seconds: 2.4 }),
        call((ctx) => ctx.addActor('santina', 'santina', '2', { kind: 'idle', face: 'S' })),
        say('santina', 'A PRIEST WITH A SHIELD? THE SACRAMENT IN ONE HAND AND THE SHIELD IN THE OTHER? WHAT ARE YOU PEOPLE?'),
        say('voice', 'A HOLE IN THE WALL. NOBODY DARES ENTER.'),
        say('confusione', 'I DARE. ON HANDS AND FEET.'),
        mini(() => new TugGame(), { lost: { commozione: 6 } }),
        call((ctx) => ctx.actor('conf').setBehavior({ kind: 'goto', to: ctx.marker('2'), speed: 2.6 })),
        say('zampano', 'I HAD HIS LEG. I HAD IT.'),
        branch(
          (s) => s.flags.comradeship === true,
          [say('confusione', 'YOU SAT BY THE BODY AT THE WAKE. COME ON, THEN.'), fx({ supervillain: 6 })],
          [say('confusione', 'COMING?')],
        ),
        walk({ objective: 'FOLLOW HIM IN. ALONE INSIDE', goal: { reach: '2', radius: 0.9 }, noRun: true }),
        fx({ supervillain: 10, value: 'Comradeship', flags: { followed: true } }),
        card('INSIDE', 'THE FIRST STEPS ALONE. THEN NOT ALONE.', { color: C.cyan, seconds: 2 }),
        say('zampano', 'THERE WAS A HOLE, AND MY FRIEND WAS IN IT.', { remembered: true }),
      ],
    },
    {
      id: '7.8',
      title: 'Marvels and missing gold',
      happens: 'THREE DAYS OF LAWFUL SACK. CLARI REMEMBERS THAT NOBODY WAS HARMED. NIKETAS REMEMBERS A GIRL DRAGGED OFF, AND OTHER "BARBARIANS" WHO MADE THE MAN LET GO. JACK IS THAT MAN. THEN THE COMMON PILE: THE GOLD VANISHES AND THE POOR GET SILVER.',
      source: 'CLARI\'S IDYLL AND HIS PAGES OF MARVELS; NIKETAS\'S ESCAPE; THE VANISHED GOLD (4C). BOARD: "SPIRITO RELIGIOSO VS SPIRITO DI CONQUISTA (GUADAGNO)".',
      script: () => {
        let barks = 0;
        return [
          fx({ flags: { oath: 'undecided' } }),
          stage('city', [{ name: 'marshal', who: 'bagnaskizMarshal', at: '9', face: 'NE' }]),
          card('THREE DAYS', 'OF LAWFUL SACK. CLARI REMEMBERS THAT NOBODY WAS HARMED.', { color: C.orange, seconds: 2.2 }),
          walk({
            objective: 'COMPLETE THE BOOK OF MARVELS',
            action: 'LOOK',
            pickups: [
              { at: '1', kind: 'marvel', label: 'THE GREAT CHURCH', text: 'A DOME HUNG FROM HEAVEN BY A CHAIN', effects: { marvel: 'THE GREAT CHURCH', commozione: 5 } },
              { at: '7', kind: 'marvel', label: 'THE HIPPODROME', text: 'THIRTY TIERS OF SEATS, AND NOBODY RACING', effects: { marvel: 'THE HIPPODROME', commozione: 5 } },
              { at: '2', kind: 'marvel', label: 'THE STATUES', text: 'BRONZE PEOPLE, BRONZE BEASTS, ALL STARING', effects: { marvel: 'THE STATUES', commozione: 5 } },
            ],
            onAction: (ctx) => ctx.say('OOOH.', { x: ctx.player.gx, y: ctx.player.gy }, C.yellow),
          }),
          call((ctx) => ctx.actor('marshal').setPosition(ctx.player.gx - 1.2, ctx.player.gy - 0.6)),
          say('marshal', 'ALPHA-DOG RULE, LITTLE KNIGHT: BE AS NASTY AS POSSIBLE, AND KEEP INVENTING NASTINESS.'),
          say('marshal', 'THERE IS A PLACE IN THE BAND FOR YOU. ALL YOU HAVE TO DO IS LOOK AWAY.'),
          call((ctx) => {
            ctx.removeActor('marshal');
            const jack = ctx.addActor('jack', 'jack', '4', { kind: 'goto', to: ctx.marker('6'), speed: 0.5 });
            ctx.addActor('girl', 'lady', { x: ctx.marker('4').x + 0.6, y: ctx.marker('4').y + 0.4 }, { kind: 'follow', target: jack, distance: 0.7, speed: 0.6 });
          }),
          say('voice', 'NIKETAS REMEMBERS A GIRL DRAGGED OFF. JACK IS THAT MAN. YOU SWORE: NO WOMAN TOUCHED.'),
          walk({
            objective: 'ENFORCE THE OATH (BARK AT JACK) OR LOOK AWAY (GO TO THE PILE)',
            action: 'BARK',
            goal: { reach: '8', label: 'THE PILE' },
            pilot: (ctx, _w, p) => {
              const jack = ctx.actors.get('jack');
              if (p.policy.ending !== 'knight' || !jack || ctx.state.flags.oath === 'enforced') return null;
              const d = Math.hypot(jack.gx - ctx.player.gx, jack.gy - ctx.player.gy);
              return { target: { x: jack.gx, y: jack.gy }, act: d < 1.7, hold: d < 1.2 };
            },
            onAction: (ctx, w) => {
              if (!near(ctx, 'jack', 1.9)) return bark(ctx);
              if (!spend(ctx.state, 'commozione', STORY.COST.OATH_BARK)) {
                ctx.notice(`TOO UNMOVED TO ACT: NEEDS ${STORY.COST.OATH_BARK} COMMOZIONE`, C.red);
                ctx.game.audio.play('empty');
                return;
              }
              ctx.notice(`-${STORY.COST.OATH_BARK} COMMOZIONE`, C.red);
              barks++;
              bark(ctx, barks < 3 ? 'LET HER GO!' : 'SO HELP ME GOD!');
              ctx.shake(2);
              if (barks < 3) return;
              ctx.actor('jack').setBehavior({ kind: 'flee', speed: 3, radius: 6 });
              ctx.actor('girl').setBehavior(wander(ctx, '4', 0.4, 0.3));
              ctx.apply({ flags: { oath: 'enforced' }, supervillain: 15, grace: 5, standing: -10, value: 'Kept oaths' });
              w.complete = true;
            },
          }),
          branch(
            (s) => s.flags.oath === 'enforced',
            [
              say('jack', 'ALL RIGHT! ALL RIGHT! I WAS ONLY... CARRYING HER. FOR SAFETY.'),
              say('greek', 'OTHER BARBARIANS MADE THE MAN LET GO. I WILL WRITE THAT DOWN.'),
            ],
            [
              fx({ flags: { oath: 'looked-away' }, supervillain: -10, grace: -15, standing: 10 }),
              say('voice', 'YOU LOOKED AT THE PILE. THE PILE WAS VERY INTERESTING.'),
            ],
          ),
          move('zampano', '8', 2.2),
          card('THE COMMON PILE', 'THE GOLD VANISHES. THE POOR GET SILVER.', { color: '#d8d8e8', seconds: 2.4 }),
          fx({ coins: 2 }),
          say('zampano', 'THERE WAS GOLD, AND THEN THERE WAS SILVER, AND THEN THERE WAS ME.', { remembered: true }),
          sound('glitch'),
          card('JERUSALEM', 'LOADING...', { color: '#f6c0e0', seconds: 2.6, dim: 0.9 }),
          card('', 'THE PASTEL CITY NEVER LOADS', { color: '#b070ff', seconds: 2.2, dim: 0.95, flash: true }),
        ];
      },
    },
  ],
};
