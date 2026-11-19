import { STORY } from '../../config';
import type { Point } from '../../entities/actor';
import { RumourGame, mini } from '../../story/minigames';
import { ask, call, card, move, say, stage } from '../../story/steps';
import { walk, type Pickup } from '../../story/walk';
import { C } from '../../ui/retro';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';
import { followLeader } from './helpers';

/** Where the marquis's guest is talked about next (6.2): the cook, the tents, the council tent. */
const NAME_TRAIL: Array<{ at: string | Point; text: string }> = [
  { at: '6', text: 'THE COOK: "...THE GOOD WINE IS FOR THE MARQUIS BONIFACE..."' },
  { at: '9', text: 'A TENT: "...GERMANS, FROM KING PHILIP. ENVOYS..."' },
  { at: '4', text: 'ANOTHER TENT: "...A PRINCE. A GREEK PRINCE. HIS FATHER WAS DEPOSED..."' },
  { at: '5', text: 'THE COUNCIL TENT: "...BONIFACE SPEAKS FOR HIM..."' },
];

/**
 * Level 6 — The long winter, Zara 1202-03 to Corfu, May 1203: a prince on credit. Scarcity,
 * desertions and the young Alexios's offer, which turns the debt-ridden host towards
 * Constantinople; at Corfu the host nearly breaks up and its leaders kneel to keep it together
 * (Villehardouin pp. 22-30; Clari XVI-XVII and 31-39).
 */
export const CH6: ChapterDef = {
  number: 6,
  title: CHAPTER_TITLES[5],
  intro: 'ZARA, WINTER 1202-03. HALF A LOAF A DAY, SHIPS LEAVING FOR SYRIA WITHOUT THEM, AND A PRINCE NOBODY HAS MET WHO WILL PAY FOR EVERYTHING. ZAMPANO LEARNS ABOUT HIM LAST.',
  cast: 'CONFUSIONE AS ALEAUME; JACK AT THE DICE; SBRIMBRULON AS PIERRE; THE YOUNG ALEXIOS; BAGNASKIZ AS THE MARSHAL',
  theme: 'winter',
  music: 'medieval',
  professor: {
    text: 'A PRINCE PROMISED TWO HUNDRED THOUSAND MARKS HE DID NOT HAVE, AND A HOST THAT COULD NOT PAY FOR ITS SHIPS WANTED VERY MUCH TO BELIEVE HIM. YOU WOULD HAVE TOO.',
  },
  subLevels: [
    {
      id: '6.1',
      title: 'Short rations',
      happens:
        'WINTER QUARTERS. TAKE THE DAY\'S RATIONS ROUND THE TENTS: HALF A LOAF EACH, AND A SHIP LEAVING FOR SYRIA WITH MEN WHO SWORE TO STAY. AT THE LAST TENT ALEAUME IS SHIVERING WITH NOTHING IN HIS HANDS, AND JACK IS CALLING EVERYONE TO THE DICE. SHARE YOUR OWN HALF LOAF, OR GO AND PLAY.',
      source:
        "VILLEHARDOUIN PP. 25-26 (DESERTIONS OVER THE WINTER; A SHIP SENT TO SYRIA, AN OATH BROKEN) AND CLARI 16 / XVI (THE WINTER AT ZARA; NO MONEY OR FOOD TO REACH BABYLON OR ALEXANDRIA). THE RATIONS, THE DICE AND THE SHARED BREAD ARE ADAPTATION: THE NEW SETUP OF THE 'COMRADESHIP' FLAG READ AT THE BREACH (7.7).",
      script: () => [
        stage('winter', [
          { name: 'k1', who: 'knight', at: '4', face: 'SE' },
          { name: 'k2', who: 'crowdA', at: '5', face: 'SW' },
          { name: 'k3', who: 'crowdC', at: '9', face: 'E' },
          { name: 'jack', who: 'jack', at: '7', face: 'W' },
          { name: 'conf', who: 'confusione', at: '3', face: 'NE' },
        ]),
        say('voice', 'WINTER QUARTERS. NOBODY SAILS IN WINTER, AND NOBODY EATS VERY MUCH EITHER.'),
        walk({
          objective: "TAKE THE DAY'S RATIONS ROUND THE TENTS",
          pickups: [
            { at: { x: 5.5, y: 6.5 }, kind: 'spot', label: 'A KNIGHT', text: '"HALF A LOAF. FOR A KNIGHT. IN VENICE MY HORSE ATE BETTER."' },
            { at: { x: 14.5, y: 6.5 }, kind: 'spot', label: 'A SERGEANT', text: '"A SHIP LEFT FOR SYRIA THIS MORNING. THEY SWORE TO STAY WITH US."' },
            { at: { x: 6.5, y: 9.5 }, kind: 'spot', label: 'A PILGRIM', text: '"BABYLON? ALEXANDRIA? WITH WHAT MONEY? WITH WHAT FOOD?"' },
          ],
        }),
        walk({ objective: 'THE LAST TENT', goal: { reach: '3', radius: 1.4, label: 'ALEAUME' } }),
        say('confusione', '(SHIVERING) I GAVE MINE TO A BOY FROM ARRAS. CLERKS ARE NOT MEANT TO BE HUNGRY. WE ARE MEANT TO BE WISE.'),
        say('jack', '(FROM THE FIRE) DICE! DICE! THE WINNER EATS TWICE! MAGNIFICENT!'),
        ask('confusione', '(ALEAUME LOOKS AT YOUR HALF LOAF, THEN AWAY.)', [
          {
            label: '(BREAK IT IN TWO. GIVE HIM THE BIGGER HALF.)',
            cost: STORY.COST.SHARE,
            effects: { supervillain: 8, flags: { comradeship: true }, value: 'Comradeship' },
            then: [
              move('zampano', { x: 7.9, y: 12.6 }, 1.6),
              say('voice', 'THEY EAT SITTING BACK TO BACK, FOR THE WARMTH. NOBODY SAYS ANYTHING.'),
              say('confusione', 'YOU WILL REGRET THIS AT ABOUT MIDNIGHT, BROTHER.'),
            ],
          },
          {
            label: '(GO AND PLAY DICE WITH JACK.)',
            effects: { standing: 4, flags: { comradeship: false } },
            then: [
              call((ctx) => ctx.actor('conf').setBehavior({ kind: 'goto', to: ctx.marker('6'), speed: 1.2 })),
              say('jack', 'THE LITTLE KNIGHT PLAYS! HE IS ONE OF US!'),
              say('voice', 'ALEAUME WALKS OFF INTO THE COLD. HE DOES NOT LOOK BACK.'),
            ],
          },
        ]),
        say('zampano', 'THERE WAS HALF A LOAF, AND IT WAS NEVER ENOUGH.', { remembered: true }),
      ],
    },
    {
      id: '6.2',
      title: 'A prince on credit',
      happens:
        "FOLLOW THE TALK OF THE MARQUIS'S GUESTS FROM THE COOK TO THE COUNCIL TENT. PIECE TOGETHER THE OFFER BROUGHT BY KING PHILIP'S ENVOYS: YOUNG ALEXIOS, SON OF THE DEPOSED ISAAC II, WILL PAY TWO HUNDRED THOUSAND MARKS, FEED THE HOST, SEND MEN TO EGYPT AND PUT THE GREEK CHURCH UNDER ROME, IF THEY HELP HIM TAKE BACK CONSTANTINOPLE. THE LEADERS SAY YES.",
      source:
        "VILLEHARDOUIN PP. 23-25: THE ENVOYS OF KING PHILIP; THE OFFER (OBEDIENCE TO ROME, 200,000 MARKS, FOOD FOR A YEAR, 10,000 MEN FOR A YEAR, 500 KNIGHTS FOR LIFE); THE DEBATE; ONLY TWELVE SWEAR FOR THE FRANKS. CLARI XVII (MUNRO): BONIFACE HAD MET THE YOUNG MAN AT PHILIP'S COURT. THE TRAIL AND THE GARBLED PIECES ARE ADAPTATION.",
      script: () => {
        let next = 1;
        const spot = (k: number): Pickup => ({ at: NAME_TRAIL[k]!.at, kind: 'spot', label: '"BONIFACE"', text: NAME_TRAIL[k]!.text });
        return [
          stage('winter', [{ name: 'cook', who: 'cellarer', at: { x: 4.5, y: 11.5 }, face: 'E' }], { at: 'S' }),
          say('cook', 'THE GOOD WINE IS FOR THE MARQUIS BONIFACE. HE HAS GUESTS FROM GERMANY.'),
          walk({
            objective: "FOLLOW THE TALK TO THE COUNCIL TENT",
            pickups: [spot(0)],
            need: NAME_TRAIL.length,
            onPickup: (_ctx, _p, w) => {
              if (next < NAME_TRAIL.length) w.spawn(spot(next++));
            },
          }),
          mini(() => new RumourGame(), { won: { supervillain: 3 } }),
          card('THE LEADERS SAY YES', 'ONLY A DOZEN OF THEM SWEAR TO IT', { color: C.yellow, seconds: 2.2 }),
          say('zampano', 'SO THAT IS WHY THE FLEET IS TURNING EAST. AND THE MONEY?'),
          say('marshal', 'THE PRINCE WILL PAY. ONCE HE IS EMPEROR.'),
          say('zampano', 'THERE WAS A PRINCE, AND HE WAS PAYING WITH A THRONE HE DID NOT HAVE.', { remembered: true }),
        ];
      },
    },
    {
      id: '6.3',
      title: 'On their knees at Corfu',
      happens:
        "AT CORFU THE YOUNG ALEXIOS JOINS THE FLEET IN PERSON. HALF THE HOST WANTS TO STAY ON THE ISLAND AND SEND FOR SHIPS TO SYRIA, AND PIERRE IS ONE OF THEM. FOLLOW HIS LORD TO THE OTHER CAMP. THE LEADERS COME AND KNEEL IN FRONT OF THEM, WEEPING. TELL PIERRE WHAT YOU THINK; HE DECIDES. THE FLEET SAILS FOR CONSTANTINOPLE.",
      source:
        "VILLEHARDOUIN PP. 27-30: THE YOUNG ALEXIUS JOINS AT CORFU; MORE THAN HALF THE HOST, PETER OF AMIENS AMONG THEM, MEANS TO STAY; THE CHIEFS GO ON THEIR KNEES; A COVENANT TO STAY TOGETHER UNTIL MICHAELMAS; SAILING ON THE EVE OF PENTECOST 1203. CLARI 31-33 AND 39: 'BAH! WHAT HAVE WE TO DO IN CONSTANTINOPLE?'; THE BISHOPS CALL IT 'A GOOD WORK OF GREAT MERIT'. ZAMPANO'S ADVICE IS ADAPTATION.",
      script: () => [
        stage('island', [
          { name: 'prince', who: 'prince', at: '3', face: 'S' },
          { name: 'marquis', who: 'marquis', at: { x: 11.5, y: 8.5 }, face: 'SW' },
        ], { at: 'S' }),
        card('CORFU', 'SPRING 1203. THE PRINCE IS HERE IN PERSON.', { color: C.yellow, seconds: 2 }),
        say('prince', '(THE YOUNG ALEXIOS) MY FATHER WAS EMPEROR. I WILL BE EMPEROR. EVERYTHING I PROMISED, I WILL PAY.'),
        say('voice', 'HE IS SHORTER THAN HIS PROMISE.'),
        call((ctx) => ctx.addActor('pierre', 'sbrimbrulonKnight', { x: ctx.marker('S').x - 1, y: ctx.marker('S').y - 0.6 }, { kind: 'idle', face: 'player' })),
        say('sbrimbrulon', 'BAH. WHAT HAVE WE TO DO IN CONSTANTINOPLE? WE STAY ON THIS ISLAND AND SEND FOR SHIPS TO SYRIA. COME, LITTLE ONE.'),
        followLeader({
          objective: 'FOLLOW PIERRE TO THE CAMP OF THOSE WHO WANT TO STAY',
          leader: 'pierre',
          path: ['5', '4', '6'],
          speed: 1.6,
        }),
        call((ctx) => {
          ctx.addActor('l1', 'marquis', { x: 6.5, y: 12.5 }, { kind: 'idle', face: 'W' });
          ctx.addActor('l2', 'bagnaskizMarshal', { x: 6.5, y: 11.5 }, { kind: 'idle', face: 'W' });
          for (const n of ['l1', 'l2']) ctx.actor(n).emote('hurt', 1.2);
        }),
        card('THE LEADERS KNEEL', 'IN FRONT OF THEIR OWN MEN, WEEPING. THEY WILL NOT GET UP UNTIL THE HOST STAYS TOGETHER.', { color: '#f0d8a0', seconds: 2.8 }),
        say('marshal', 'IF YOU GO, THE HOST IS LOST, AND JERUSALEM WITH IT. STAY.'),
        ask('sbrimbrulon', 'THEY ARE ON THEIR KNEES, LITTLE ONE. WHAT DO WE DO?', [
          {
            label: 'LET THEM GET UP. WE STAY TOGETHER.',
            effects: { standing: 6, flags: { corfu: 'stay' } },
            then: [say('sbrimbrulon', 'YOU ARE SOFTER THAN YOU LOOK.')],
          },
          {
            label: 'WE SAID SYRIA. A WORD IS A WORD.',
            effects: { supervillain: 3, standing: -3, flags: { corfu: 'syria' } },
            then: [say('sbrimbrulon', 'YOU ARE HARDER THAN YOU LOOK.')],
          },
        ]),
        say('sbrimbrulon', 'WE STAY UNTIL MICHAELMAS. AFTER THAT, WE WILL SEE. THAT IS WHAT THEY HAVE SWORN.'),
        card('A GOOD WORK, OF GREAT MERIT', 'THE BISHOPS HAVE SAID SO. THE PRINCE HAS SWORN ON RELICS.', { color: C.yellow, seconds: 2.4 }),
        card('THE EVE OF PENTECOST', 'THE FLEET SAILS FOR CONSTANTINOPLE', { color: C.cyan, seconds: 2.2 }),
        say('zampano', 'THERE WERE LORDS ON THEIR KNEES, AND I WAS TALLER THAN THEM FOR A MINUTE.', { remembered: true }),
      ],
    },
  ],
};
