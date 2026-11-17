import { STORY } from '../../config';
import { carry, dropCarried } from '../../story/carry';
import { BoatGame, mini, parade, rowing } from '../../story/minigames';
import { ask, blackHoleIn, blackHoleOut, call, card, fx, say, sound, stage } from '../../story/steps';
import type { StoryScene } from '../../story/storyScene';
import { walk } from '../../story/walk';
import { C } from '../../ui/retro';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';
import { distTo, placeObject } from './helpers';

/**
 * "A sound to steer by": the Adriatic oars keep a pulse under the later voyage. It disappears only
 * at the little oratory (`silentNear`).
 */
function oarPulse(silentNear?: string) {
  let t = 0;
  return (ctx: StoryScene, dt: number): void => {
    if (silentNear && distTo(ctx, ctx.marker(silentNear)) < 3.2) return;
    t -= dt;
    if (t > 0) return;
    t = 60 / STORY.PARADE.BPM;
    ctx.game.audio.play('click', { volume: 0.25, rate: 0.7 });
  };
}

/**
 * Level 4 — The sea (Adriatic, aboard the fleet). The fleet leaves Venice in 1202. As the chant
 * rises and falls, the same piece of deck keeps turning into a ship from Joinville's expedition
 * to Egypt, half a century later. Cast: Watson as the sailor; a cellarer; an emir; Jack rumoured.
 */
export const CH4: ChapterDef = {
  number: 4,
  title: CHAPTER_TITLES[3],
  intro: "THE FLEET LEAVES VENICE IN 1202. AS THE CHANT RISES AND FALLS, THE SAME PIECE OF DECK KEEPS TURNING INTO A SHIP FROM JOINVILLE'S EXPEDITION TO EGYPT, HALF A CENTURY LATER.",
  cast: 'WATSON AS THE SAILOR; A CELLARER; AN EMIR AND HIS INTERPRETER; JACK RUMOURED ON EVERY HORIZON',
  theme: 'sea',
  music: 'medieval',
  professor: {
    after: 'JV',
    text: 'THE SEA EPISODES JUMP BETWEEN CAPTIVITY AND THE VOYAGE HOME, YOU UNDERSTAND. ON PURPOSE. THE OARS KEEP THE TIME WHEN NOTHING ELSE DOES.',
  },
  subLevels: [
    {
      id: '4.1',
      title: 'Veni Creator',
      happens:
        'WALK THE LENGTH OF A PAINTED HULL. HIT THE BEAT TO RAISE SHIELDS AND BANNERS AS THE CLERGY SING; GET ONE OUT OF TIME AND THE SAILOR BESIDE ZAMPANO QUIETLY SETS HIM RIGHT. THE LOOKOUT ANNOUNCES GENERAL JACK. ON THE LAST BEAT, A FLOATING PARCEL IS ALL ANYONE CAN SEE.',
      source: "BARBERO, LA QUARTA CROCIATA: CLARI'S DEPARTURE.",
      script: () => [
        stage('ship', [{ name: 'watson', who: 'watson', at: '7', face: 'N' }], { at: '4' }),
        call((ctx) => ctx.actor('watson').setBehavior({ kind: 'follow', target: ctx.player, distance: 1.2, speed: 2.6, side: 0.8 })),
        walk({ objective: 'WALK THE LENGTH OF THE PAINTED HULL', goal: { reach: '3', label: 'THE BOW' } }),
        say('watson', 'WHEN THEY SING, MAN, YOU RAISE THE SHIELD. ON THE BEAT. I WILL BE RIGHT HERE.'),
        mini(parade, { won: { commozione: 8, marvel: 'THE FLEET LEAVING VENICE' }, lost: { commozione: 2, marvel: 'THE FLEET LEAVING VENICE' } }),
        call((ctx) => ctx.addActor('lookout', 'crowdA', '8', { kind: 'idle', face: 'N' })),
        say('voice', 'THE LOOKOUT: GENERAL JACK! ON THE HORIZON! EVERY HORIZON!'),
        call((ctx) => {
          ctx.removeActor('watson');
          ctx.addActor('parcel', 'watson', '6', { kind: 'idle', face: 'N' });
        }),
        card('ON THE LAST BEAT', 'A FLOATING PARCEL IS ALL ANYONE CAN SEE', { color: C.cyan, seconds: 2.4 }),
        say('zampano', 'THERE WAS A SHIP, AND IT WAS SINGING.', { remembered: true }),
      ],
    },
    {
      id: '4.2',
      title: 'The parcel in the water',
      happens:
        "ABOARD A SHIP ON JOINVILLE'S RETURN VOYAGE, LOWER THE BOAT AND EASE ALONGSIDE. THE PARCEL IS WATSON, FLOATING ON HIS BACK: HE BELIEVES THE VIRGIN IS HOLDING HIM UP AND SEES NO REASON TO KICK. REACH HIM WITHOUT SWAMPING THE BOAT. A LITTLE PICTURE OF THE RESCUE IS ADDED TO THE BOOK.",
      source: 'BARBERO, JOINVILLE E SAN LUIGI: THE FLOATING SAILOR AND THE PICTURE HE HAD PAINTED.',
      script: () => [
        sound('glitch'),
        call((ctx) => ctx.game.transition.play(null, 0.7, 1)),
        stage('ship', [{ name: 'watson', who: 'watson', at: '6', face: 'N' }], { at: '1' }),
        card('THE SAME DECK', "NOW A SHIP ON JOINVILLE'S RETURN VOYAGE, HALF A CENTURY LATER", { color: '#b070ff', seconds: 2.2 }),
        say('voice', 'A PARCEL IN THE WATER. LOWER THE BOAT.'),
        mini(() => new BoatGame(), { won: { commozione: 8 } }),
        say('watson', 'OUR LADY WAS HOLDING ME UP, MAN. SO WHY KICK?'),
        say('zampano', 'YOU ASKED HER?'),
        say('watson', 'I DID NOT HAVE TO. SHE WAS RIGHT THERE. LIKE A RAFT.'),
        fx({ item: 'A LITTLE PICTURE OF THE RESCUE' }),
        say('watson', 'THERE WAS A LADY, AND SHE WAS A RAFT.', { remembered: true }),
      ],
    },
    {
      id: '4.3',
      title: "The cellarer's vote",
      happens:
        'A HARD CUT TAKES THE CREW BACK TO THE EGYPTIAN CAMPAIGN. ENEMY GALLEYS SURROUND THE SHIP. CARRY THE VOTE FROM MAN TO MAN: ONLY THE CELLARER PROPOSES DYING ON THE SPOT TO GO STRAIGHT TO PARADISE. GIVE THE SKIPPER THE TALLY. THE MAJORITY SURRENDER, EVEN IF ZAMPANO VOTED WITH THE CELLARER.',
      source: "BARBERO, JOINVILLE E SAN LUIGI: THE CELLARER'S PROPOSAL.",
      blackHole: { where: '1250, OFF EGYPT. ANOTHER CRUSADE', value: 'Pilgrims, not martyrs' },
      script: () => {
        const pulse = oarPulse();
        return [
          ...blackHoleIn('1250, OFF EGYPT. ANOTHER CRUSADE.'),
          stage('ship', [
            { name: 'skipper', who: 'knight', at: '3', face: 'S' },
            { name: 'cellarer', who: 'cellarer', at: '2', face: 'SW' },
            { name: 'k1', who: 'crowdA', at: '8', face: 'S' },
            { name: 'k2', who: 'crowdB', at: '1', face: 'E' },
            { name: 'k3', who: 'crowdC', at: '7', face: 'N' },
          ]),
          say('knight', 'GALLEYS ON EVERY SIDE. WE VOTE. CARRY THE VOTE FROM MAN TO MAN.'),
          ask('knight', 'AND YOURS FIRST, LITTLE KNIGHT?', [
            { label: 'SURRENDER. WE ARE PILGRIMS.', effects: { supervillain: 3, flags: { vote: 'surrender' } } },
            { label: 'PARADISE, WITH THE CELLARER.', effects: { commozione: 4, flags: { vote: 'paradise' } } },
          ]),
          carry('THE VOTE'),
          walk({
            objective: 'CARRY THE VOTE FROM MAN TO MAN',
            pickups: [
              { at: { x: 8.5, y: 6.9 }, kind: 'spot', label: '"SURRENDER."' },
              { at: { x: 8.5, y: 9.9 }, kind: 'spot', label: '"SURRENDER. OBVIOUSLY."' },
              { at: { x: 11.5, y: 11.9 }, kind: 'spot', label: '"SURRENDER, MAN."' },
              { at: { x: 11.5, y: 9.9 }, kind: 'spot', label: '"I SAY WE ALL DIE, AND GO STRAIGHT TO PARADISE."' },
            ],
            onUpdate: (ctx, _w, dt) => pulse(ctx, dt),
          }),
          carry('THE TALLY'),
          walk({ objective: 'GIVE THE SKIPPER THE TALLY', goal: { reach: '3', radius: 1.1, label: 'SKIPPER' }, onUpdate: (ctx, _w, dt) => pulse(ctx, dt) }),
          dropCarried(),
          say('knight', 'FOUR TO ONE. OR FOUR TO TWO, COUNTING THE DOG. WE SURRENDER.'),
          card('THE MAJORITY SURRENDER', 'COMMON SENSE OUTVOTES PARADISE', { color: C.cyan, seconds: 2 }),
          say('cellarer', 'THERE WAS A PARADISE, AND I WAS ALONE IN IT.', { remembered: true }),
          ...blackHoleOut('Pilgrims, not martyrs'),
        ];
      },
    },
    {
      id: '4.4',
      title: "Friday at the emir's table",
      happens:
        'IN CAPTIVITY, TRADE FAMILY STORIES ACROSS AN INTERPRETER. ZAMPANO HAS ALREADY EATEN WHEN A FELLOW PRISONER POINTS OUT THAT IT IS FRIDAY. BOTH HOST AND LEGATE EXCUSE THE MISTAKE. CHOOSE TO SHARE THE NEXT MEAL OR SET OUT BREAD AND WATER FOR A PRIVATE PENANCE. HIS JOURNAL RECORDS THE RULE HE ELECTS TO LIVE BY.',
      source: 'BARBERO, JOINVILLE E SAN LUIGI: THE FRIDAY MEAL.',
      blackHole: { where: 'A PRISONER OF THE EMIR', value: 'Forms matter' },
      script: () => [
        ...blackHoleIn('A PRISONER OF THE EMIR.'),
        stage(
          'interior',
          [
            { name: 'emir', who: 'emir', at: '2', face: 'SW' },
            { name: 'interp', who: 'clerkB', at: '6', face: 'S' },
            { name: 'legate', who: 'legate', at: '3', face: 'NE' },
            { name: 'burgher', who: 'burgher', at: '5', face: 'W' },
          ],
          { at: '1' },
        ),
        say('emir', 'SIT. EAT. TELL ME ABOUT YOUR GRANDFATHER.'),
        ask('clerkB', '(THE INTERPRETER) HE ASKS ABOUT YOUR GRANDFATHER.', [
          { label: 'HE GUARDED A WHOLE LAWN, ALONE.', then: [say('clerkB', '"HIS GRANDFATHER WAS A GREAT LORD."'), say('emir', 'MINE ALSO.')] },
          { label: 'HE SLEPT ON A PURPLE CUSHION.', then: [say('clerkB', '"HIS GRANDFATHER WAS BORN IN THE PURPLE."'), say('emir', 'HA! MINE ALSO.')] },
        ]),
        say('emir', 'MY GRANDFATHER KNEW YOUR GRANDFATHER. THEY WOULD HAVE LIKED THIS MEAL.'),
        card('', 'ZAMPANO HAS ALREADY EATEN', { color: '#f0d8a0', seconds: 1.4, dim: 0.2 }),
        say('burgher', 'IT IS FRIDAY! AND THAT WAS MEAT!'),
        fx({ grace: -15, flags: { fridayMeat: true } }),
        say('legate', 'IT WAS AN ACCIDENT. GOD CANNOT MIND.'),
        say('emir', 'HE CANNOT MIND. A GUEST IS A GUEST.'),
        ask('legate', 'AND THE NEXT MEAL?', [
          { label: 'I WILL SHARE IT. A GUEST IS A GUEST.', effects: { standing: 5, flags: { rule: 'share' }, value: 'A guest is a guest' }, then: [say('emir', 'GOOD. MY COOK IS PROUD.')] },
          {
            label: '(SET OUT BREAD AND WATER FOR A PRIVATE PENANCE)',
            cost: STORY.COST.ATONE,
            effects: { grace: 20, flags: { rule: 'penance', atoned: true }, value: 'Forms matter' },
            then: [say('legate', 'NOBODY ASKED YOU TO.'), say('burgher', 'I DID.')],
          },
        ]),
        call((ctx) => ctx.notice(ctx.state.flags.rule === 'share' ? 'JOURNAL: A GUEST IS A GUEST' : 'JOURNAL: FRIDAY IS FRIDAY, EVEN IN PRISON', C.yellow)),
        say('zampano', 'THERE WAS A FRIDAY, AND IT WAS STARING AT ME.', { remembered: true }),
        ...blackHoleOut('Forms matter'),
      ],
    },
    {
      id: '4.5',
      title: 'The empty place at the oar',
      happens:
        'ON THE RETURN VOYAGE AT LAMPEDUSA, FIND THE WHITE ORATORY, ITS GARDEN AND TWO BODIES LAID SIDE BY SIDE. ONE SAILOR IS MISSING WHEN THE BOATS PUT OFF. LEAVE HIM A CRATE OF BISCUIT; THE MEN THINK HE WANTS TO BECOME A HERMIT. BEAT THE OLD ROWING RHYTHM AGAIN AND THE SHIP OF 1202 COMES BACK BENEATH ZAMPANO\'S FEET.',
      source: 'BARBERO, JOINVILLE E SAN LUIGI: LAMPEDUSA.',
      blackHole: { where: 'LAMPEDUSA, ON THE WAY HOME', value: 'The road is the penance' },
      script: () => {
        const pulse = oarPulse('1');
        return [
          ...blackHoleIn('LAMPEDUSA, ON THE WAY HOME FROM EGYPT.'),
          stage('island', [{ name: 'sailor', who: 'crowdB', at: '3', face: 'NW' }]),
          walk({
            objective: 'FIND THE ORATORY, ITS GARDEN AND THE TWO BODIES',
            action: 'LOOK',
            pickups: [
              { at: '1', kind: 'marvel', label: 'THE WHITE ORATORY', text: 'THE OARS GO QUIET HERE', effects: { marvel: 'THE HERMIT ORATORY', commozione: 3 } },
              { at: '2', kind: 'marvel', label: 'ITS GARDEN', text: 'FIGS, VINES AND OLIVES', effects: { marvel: 'THE HERMIT GARDEN', commozione: 3 } },
              { at: '4', kind: 'marvel', label: 'TWO BODIES, SIDE BY SIDE', text: 'THEIR HANDS CROSSED ON THEIR CHESTS', effects: { marvel: 'THE TWO SKELETONS', commozione: 3 } },
            ],
            onAction: (ctx) => ctx.say('...', { x: ctx.player.gx, y: ctx.player.gy }),
            onUpdate: (ctx, _w, dt) => pulse(ctx, dt),
          }),
          call((ctx) => ctx.removeActor('sailor')),
          card('THE BOATS PUT OFF', 'ONE SAILOR IS MISSING. HIS PLACE AT THE OAR IS EMPTY.', { color: '#9aa4c0', seconds: 2.4 }),
          carry('A CRATE OF BISCUIT'),
          walk({ objective: 'LEAVE HIM A CRATE OF BISCUIT ON THE JETTY', goal: { reach: '6', label: 'THE JETTY' }, onUpdate: (ctx, _w, dt) => pulse(ctx, dt) }),
          dropCarried(),
          call((ctx) => {
            placeObject(ctx, 'crate', '6');
            ctx.game.audio.play('hit');
            ctx.say('KNOCK.', ctx.marker('6'), C.yellow);
            ctx.shake(2);
          }),
          say('voice', 'THE MEN THINK HE WANTS TO BECOME A HERMIT.'),
          say('voice', 'THE KNOCK OF THE CRATE ON THE JETTY. THAT IS THE BEAT.'),
          mini(rowing, { won: { commozione: 5 }, lost: { commozione: 1 } }),
          sound('glitch'),
          card('1202', 'THE SHIP COMES BACK BENEATH HIS FEET', { color: C.cyan, seconds: 2.2 }),
          say('zampano', 'THERE WAS AN OAR, AND NOBODY WAS PULLING IT.', { remembered: true }),
          ...blackHoleOut('The road is the penance'),
        ];
      },
    },
  ],
};
