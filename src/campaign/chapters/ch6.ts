import { CatapultGame, RumourGame, mini } from '../../story/minigames';
import { ask, blackHoleIn, blackHoleOut, call, card, fx, say, stage } from '../../story/steps';
import { walk } from '../../story/walk';
import { STORY } from '../../config';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';

/** Level 6 — The long winter. Cast: Santina as the purple-born princess; a saintly king; Jack on the catapult. */
export const CH6: ChapterDef = {
  number: 6,
  title: CHAPTER_TITLES[5],
  intro: 'NOBODY SAILS IN WINTER, SO THE ARMY WAITS AT ZARA; WAITING IS WHERE THE VALUES ARE TAUGHT AND WHERE THE DREAM WANDERS FURTHEST.',
  cast: 'SANTINA AS THE PURPLE-BORN PRINCESS; A SAINTLY KING; JACK ON THE CATAPULT',
  theme: 'winter',
  music: 'medieval',
  professor: {
    after: 'JV',
    text: 'IT IS ONE THING TO BE A DEVOUT MAN. IT IS QUITE ANOTHER TO SHARE A TENT WITH SOMEONE WHO REALLY MEANS IT.',
  },
  subLevels: [
    {
      id: '6.1',
      title: 'The white tablecloth',
      happens: 'THE KNIGHTS DINE OUTSIDE THEIR TENTS ON WHITE LINEN. FROM THE NEXT TABLE A COUNT FIRES A TOY CATAPULT AT THE GLASSES. EVERYONE FINDS HIM DELIGHTFUL.',
      source: 'THE COUNT OF EU\'S CATAPULT; GROWN-UPS WHO PLAY LIKE CHILDREN (JV). BOARD: "SPONTANEITA INFANTILE".',
      script: () => [
        stage('winter', [
          { name: 'jack', who: 'jack', at: '2', face: 'NW' },
          { name: 'k1', who: 'knight', at: '1', face: 'SE' },
          { name: 'k2', who: 'knight', at: '3', face: 'NE' },
        ]),
        say('voice', 'NEWS: JACK THE GENERAL IS STILL COMING FROM THE EAST. MEANWHILE JACK IS ON THE CATAPULT.'),
        say('jack', 'THE COUNT LENT ME HIS LITTLE CATAPULT! AT THE GLASSES! GO ON!'),
        mini(() => new CatapultGame(), { won: { commozione: 5, standing: 5 } }),
        say('knight', 'DELIGHTFUL! NOW DICE. ONE ROUND. NOBODY WILL KNOW.'),
        ask('knight', 'DICE ARE FORBIDDEN, OF COURSE.', [
          { label: 'ONE ROUND.', effects: { grace: -10, coins: 3, flags: { dice: true } }, then: [say('knight', 'YOU WON. NOBODY WILL KNOW. EXCEPT GOD.')] },
          { label: 'NO DICE.', effects: { grace: 3 }, then: [say('knight', 'SUIT YOURSELF. BLIND MAN\'S BUFF, THEN.')] },
        ]),
        walk({
          objective: 'HIDE AND SEEK: FIND THE THREE KNIGHTS',
          action: 'SNIFF',
          pickups: [
            { at: '4', kind: 'spot', label: 'FOUND YOU!' },
            { at: '5', kind: 'spot', label: 'FOUND YOU!' },
            { at: '7', kind: 'spot', label: 'FOUND YOU!' },
          ],
          onAction: (ctx) => ctx.say('SNIFF SNIFF', { x: ctx.player.gx, y: ctx.player.gy }),
        }),
        say('jack', 'THERE WAS A CATAPULT, AND IT WAS MINE.', { remembered: true }),
      ],
    },
    {
      id: '6.2',
      title: 'The exotic guest',
      happens: 'IN DECEMBER THE MARQUIS ARRIVES WITH A RUNAWAY PRINCE. PUT MY FATHER BACK ON THE THRONE, HE SAYS, AND I PAY FOR EVERYTHING. THE BISHOPS RULE IT A GOOD WORK. THE POOR KNIGHTS HEAR LAST.',
      source: 'BONIFACE AND THE YOUNG ALEXIOS; "BIAU SEIGNOR, IN PALESTINE YOU WILL ACHIEVE NOTHING"; THE BISHOPS; CLARI TOLD AFTERWARDS (4C).',
      script: () => [
        stage('winter', [{ name: 'watson', who: 'watson', at: '6', face: 'NE' }], { at: '9' }),
        say('watson', 'MAN, THERE IS NEWS. I HEARD IT FROM A TENT THAT HEARD IT FROM A TENT.'),
        mini(() => new RumourGame(), { won: { supervillain: 3 } }),
        say('voice', 'BIAU SEIGNOR, IN PALESTINE YOU WILL ACHIEVE NOTHING. IN CONSTANTINOPLE, EVERYTHING.'),
        say('zampano', 'THERE WAS A PRINCE, AND HE WAS RUNNING AWAY TOWARD US.', { remembered: true }),
      ],
    },
    {
      id: '6.3',
      title: 'Black hole: the road of the poor',
      happens: '1096. THE ROADS ARE PACKED: FIGHTERS, FAMILIES, WOMEN, PALM BRANCHES IN HAND AND CROSSES ON THEIR SHOULDERS. IN THE PALACE A "CELT" SITS ON THE EMPEROR\'S THRONE AND TALKS WITH NO WATER CLOCK. THE PRINCESS WATCHES AND GENERALISES.',
      source: 'ANNA KOMNENE ON THE CRUSADERS (CR3). BOARD: "CROCIATA DEI POVERI" AGAINST "CROCIATA DEI BARONI".',
      blackHole: { where: '1096, THE ROAD OF THE POOR', value: 'Feeling makes action' },
      script: () => [
        ...blackHoleIn('1096. THE ROAD OF THE POOR.'),
        call((ctx) => {
          ctx.setStage('road');
          ['1', '2', '3', '4', '5', '6', '7'].forEach((m, k) =>
            ctx.addActor(`p${k}`, (['crowdA', 'crowdB', 'crowdC'] as const)[k % 3], m, { kind: 'follow', distance: 1.4 + k * 0.4, speed: 2.2, side: (k % 2 ? 1 : -1) * 0.8 }),
          );
        }),
        walk({ objective: 'MARCH WITH THE CROWD TO THE PALACE', goal: { reach: '9' } }),
        call((ctx) => {
          ctx.setStage('palace', { at: '7' });
          ctx.addActor('celt', 'knight', '1', { kind: 'idle', face: 'S' });
          ctx.addActor('princess', 'santina', '8', { kind: 'idle', face: 'SW' });
        }),
        say('voice', 'A "CELT" SITS ON THE EMPEROR\'S THRONE AND TALKS WITH NO WATER CLOCK.'),
        ask('santina', 'SPEAK, BARBARIAN. THE COURT IS LISTENING.', [
          { label: 'YOUR MAJESTY, MAY WE HUMBLY...', locked: 'TOO POLITE' },
          { label: 'WITH RESPECT, WE WOULD ASK...', locked: 'TOO POLITE' },
          { label: 'WE ARE HERE! WHERE IS JERUSALEM?', effects: { supervillain: 4 } },
        ]),
        say('santina', 'THE SIMPLE FOLK ARE SINCERE. THE CHIEFS, I DOUBT.'),
        say('santina', 'ALL CELTS ARE LIKE THIS. TALKATIVE. I AM GENERALISING.', { remembered: true }),
        ...blackHoleOut('Feeling makes action'),
      ],
    },
    {
      id: '6.4',
      title: 'Black hole: the desert',
      happens: 'MIDSUMMER, NO WATER, A LAKE ALWAYS ONE HILL AWAY. A VOICE PREPARES THE GREAT REVELATION OF WHO HE IS. HE EXPECTS KNIGHT. IT SAYS: MALTESE. BORN IN THE PURPLE, ON A CUSHION.',
      source: 'THE WATERLESS MARCH TOWARD TIBERIAS (CR1). BOARD: "DESERTO: LUOGO DEL SOGNO E DELLA RIVELAZIONE" AND "NATO NELLA PORPORA" (CR3).',
      blackHole: { where: 'MIDSUMMER, THE ROAD TO TIBERIAS', value: 'Born in the purple (on a cushion)' },
      script: () => [
        ...blackHoleIn('MIDSUMMER. THE ROAD TO TIBERIAS.'),
        stage('desert'),
        say('voice', 'WALK. THE LAKE IS JUST OVER THAT HILL. THEN YOU WILL KNOW WHO YOU ARE.'),
        walk({ objective: 'THIRST MARCH: REACH THE LAKE', goal: { reach: '5' }, thirst: { mirage: '2', drain: 0.018 } }),
        say('voice', 'BEHOLD. THE GREAT REVELATION. YOU ARE...'),
        say('zampano', '...A KNIGHT?'),
        card('MALTESE', 'BORN IN THE PURPLE. ON A CUSHION.', { color: '#c070f0' }),
        fx({ item: 'AN IDENTITY CARD HE DID NOT WANT' }),
        say('zampano', 'THERE WAS A LAKE, AND IT WAS A CUSHION.', { remembered: true }),
        ...blackHoleOut('Born in the purple (on a cushion)'),
      ],
    },
    {
      id: '6.5',
      title: 'Black hole: living with a saint',
      happens: 'A SAINTLY KING ASKS: LEPER, OR MORTAL SIN? ZAMPANO ANSWERS THIRTY MORTAL SINS. ASKED TO WASH THE FEET OF THE POOR, HE DECLINES. HE OFFERS TO SERVE UNPAID IF THE KING PROMISES NOT TO LOSE HIS TEMPER FOR SIX MONTHS.',
      source: 'LOUIS IX AND JOINVILLE: THE LEPER QUESTION, THE FEET OF THE POOR, THE NO-ANGER CONTRACT (JV, SG).',
      blackHole: { where: 'IN THE TENT OF A SAINTLY KING', value: 'The grand gesture' },
      script: () => [
        ...blackHoleIn('IN THE TENT OF A SAINTLY KING.'),
        stage('interior', [{ name: 'king', who: 'king', at: '2', face: 'SW' }], { at: '1' }),
        ask('king', 'TELL ME HONESTLY: WOULD YOU RATHER BE A LEPER, OR HAVE COMMITTED ONE MORTAL SIN?', [
          { label: 'THIRTY MORTAL SINS, THANK YOU. NOT THE LEPROSY.', effects: { supervillain: 8 }, then: [say('king', 'YOU SPEAK LIKE A FOOL. AND HONESTLY.')] },
          { label: 'WHATEVER PLEASES YOUR MAJESTY.', then: [say('king', 'THAT PLEASES ME LEAST OF ALL.')] },
        ]),
        ask('king', 'TOMORROW IS HOLY THURSDAY. WILL YOU WASH THE FEET OF THE POOR WITH ME?', [
          { label: 'NO. NEVER. THEY ARE FEET.', effects: { supervillain: 8 }, then: [say('king', 'HMPH.')] },
          { label: 'PERHAPS LATER.', then: [say('king', 'LATER IS NEVER.')] },
        ]),
        ask('king', 'WILL YOU SERVE ME? NAME YOUR PRICE.', [
          { label: 'UNPAID. IF YOU PROMISE NOT TO LOSE YOUR TEMPER FOR SIX MONTHS.', cost: STORY.COST.GESTURE, effects: { supervillain: 10 } },
          { label: 'A FAIR SALARY.', then: [say('king', 'SPOKEN LIKE A MERCHANT.')] },
        ]),
        say('king', 'HA! HA HA! DONE.'),
        say('zampano', 'THERE WAS A SAINT, AND HE WAS LAUGHING AT ME.', { remembered: true }),
        ...blackHoleOut('The grand gesture'),
      ],
    },
    {
      id: '6.6',
      title: 'The still-warm comrade',
      happens: 'A KNIGHT HAS DIED. HIS COMPANIONS KEEP THE WAKE AND JOKE ABOUT WHO WILL MARRY THE WIDOW. ZAMPANO MUST DECIDE WHETHER TO LAUGH.',
      source: "JOINVILLE'S KNIGHTS AT THE WAKE (JV).",
      script: () => [
        stage('winter', [
          { name: 'k1', who: 'knight', at: '1', face: 'SE' },
          { name: 'k2', who: 'knight', at: '2', face: 'NW' },
          { name: 'conf', who: 'confusione', at: '3', face: 'NE' },
        ]),
        card('THE WAKE', 'HE IS STILL WARM', { color: '#9aa4c0', seconds: 1.8 }),
        say('knight', 'SO. WHO MARRIES THE WIDOW? I CALL IT FIRST.'),
        say('knight', 'SHE HAS A MILL. AND A DOG.'),
        ask('confusione', '(CONFUSIONE IS LOOKING AT YOU.)', [
          { label: '(LAUGH)', effects: { standing: 5, flags: { comradeship: false } }, then: [say('knight', 'HE LAUGHS! HE IS ONE OF US.')] },
          { label: '(DO NOT LAUGH. SIT BY THE BODY.)', cost: STORY.COST.VIGIL, effects: { supervillain: 10, flags: { comradeship: true }, value: 'Comradeship' }, then: [say('confusione', 'I WILL REMEMBER THAT.')] },
        ]),
        say('zampano', 'THERE WAS A WIDOW, AND SHE HAD A MILL.', { remembered: true }),
      ],
    },
  ],
};
