import { LaddersGame, LetterGame, mini } from '../../story/minigames';
import { ask, call, card, fx, say, stage } from '../../story/steps';
import { dreamSkin } from '../state';
import { STORY } from '../../config';
import { C } from '../../ui/retro';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';

/** Level 5 — Zara. Cast: Bagnaskiz as the marshal; the Doge; a papal legate. */
export const CH5: ChapterDef = {
  number: 5,
  title: CHAPTER_TITLES[4],
  intro: 'ZARA IS THE FIRST COMPROMISE: A CHRISTIAN CITY SACKED TO PAY THE FARE.',
  cast: 'BAGNASKIZ AS THE MARSHAL; THE DOGE; A PAPAL LEGATE',
  theme: 'zara',
  music: 'medieval',
  professor: {
    text: 'HE ABSOLVES THEM SO THAT THEY WILL NOT DO IT AGAIN. YOU WILL NOTICE THAT IT IS A FORMULA WITH A GREAT FUTURE.',
  },
  subLevels: [
    {
      id: '5.1',
      title: 'A small expedition, by pure chance',
      happens: 'THE DOGE HAPPENS TO HAVE A CITY TO RETAKE. THE CAMP SPLITS: "WE DID NOT COME FOR THIS" AGAINST "THE ENTERPRISE MUST NOT FAIL". THE LEGATE SAYS THE POPE WOULD AGREE, IF HE KNEW.',
      source: 'THE ZARA PROPOSAL, THE TWO PARTIES, THE LEGATE (4C).',
      script: () => [
        stage('zara', [
          { name: 'marshal', who: 'bagnaskizMarshal', at: '1', face: 'S' },
          { name: 'legate', who: 'legate', at: '7', face: 'SE' },
          { name: 'doge', who: 'doge', at: '3', face: 'SW' },
          { name: 'k1', who: 'knight', at: '2', face: 'E' },
        ]),
        say('voice', 'NEWS: JACK THE GENERAL IS PUSHING FROM THE EAST. HE IS NOT THERE.'),
        say('doge', 'BY PURE CHANCE, THERE IS A CITY HERE THAT IS OURS. A SMALL EXPEDITION.'),
        say('knight', 'WE DID NOT COME FOR THIS. ZARA IS CHRISTIAN.'),
        say('marshal', 'THE ENTERPRISE MUST NOT FAIL. WHOEVER OBJECTS IS A TRAITOR.'),
        say('legate', 'THE POPE WOULD AGREE. IF HE KNEW.'),
        ask('marshal', 'WELL, LITTLE KNIGHT? WHICH SIDE?', [
          { label: 'WE DID NOT COME FOR THIS.', cost: STORY.COST.SPEAK_UP, effects: { standing: -15, supervillain: 5, flags: { dissent: true } }, then: [say('marshal', 'TRAITOR. EVERYONE HEARD IT. (IT COSTS YOU STANDING, NOT THE LEVEL.)')] },
          { label: 'THE ENTERPRISE MUST NOT FAIL.', effects: { standing: 5 }, then: [say('marshal', 'GOOD DOG.')] },
          { label: 'WHERE ARE THE TURKS?', then: [say('doge', 'FIRST ZARA.')] },
        ]),
        call((ctx) => ctx.addActor('stranger', 'stranger', '6', { kind: 'goto', to: ctx.marker('1'), speed: 0.9 })),
        say('voice', 'A BAREFOOT MAN CROSSES THE TENTS AND KEEPS GOING TOWARD THE ENEMY, TO TALK.'),
        ask('stranger', '...', [
          { label: 'STOP! THE ENEMY IS THAT WAY!', then: [say('stranger', 'I KNOW. THAT IS WHY I AM GOING.')] },
          { label: 'TAKE A SWORD AT LEAST.', then: [say('stranger', 'I HAVE TWO HANDS. THAT IS PLENTY.')] },
          { label: '(BLOCK HIS WAY)', then: [say('stranger', 'GOOD MORNING, BROTHER DOG.')] },
        ]),
        say('voice', 'NO DIALOGUE OPTION MAKES HIM STOP.', { remembered: true }),
      ],
    },
    {
      id: '5.2',
      title: 'The walls of Zara',
      happens: 'THE CITY IS CHRISTIAN, AND UNDER A KING WHO HAS TAKEN THE CROSS HIMSELF. IT FALLS AND IS SACKED. THE LOOT IS SHARED OUT.',
      source: 'THE TAKING OF ZARA (4C).',
      script: () => {
        let skin = 'zampano';
        return [
          stage('zara', [], { at: '4' }),
          call((ctx) => (skin = dreamSkin(ctx.state))),
          card('FIRST SIEGE', 'A SHORT REHEARSAL OF LADDERS AND WALLS', { color: C.yellow, seconds: 1.8 }),
          mini(() => new LaddersGame(18, false, skin), { won: { supervillain: 4 } }),
          card('ZARA FALLS', 'IT IS SACKED. THE LOOT IS SHARED OUT.', { color: C.orange, seconds: 2.4 }),
          fx({ coins: 5 }),
          say('zampano', 'THERE WAS A WALL, AND IT WAS CHRISTIAN.', { remembered: true }),
        ];
      },
    },
    {
      id: '5.3',
      title: 'Is it a sin?',
      happens: 'AFTER THE FIGHT HE ASKS WHAT HE OWES. THE OLD BOOKS SAY DAYS OF FASTING, OR A LONG TIME AWAY FROM COMMUNION. THE NEW PREACHING SAYS REMISSION. HE CANNOT FOLLOW THE DIFFERENCE.',
      source: "PENANCE FOR KILLING IN WAR BEFORE 1095; URBAN II'S REMISSION OF SINS, TOO SUBTLE FOR THE RANK AND FILE (CR2).",
      script: () => [
        stage('zara', [{ name: 'legate', who: 'legate', at: '7', face: 'SE' }], { at: '1' }),
        say('zampano', 'I WAS ON THE WALL. WHAT DO I OWE?'),
        say('legate', 'THE OLD MANUALS SAY: FORTY DAYS OF FASTING. OR A LONG TIME AWAY FROM COMMUNION.'),
        say('legate', 'THE NEW PREACHING SAYS: YOU ARE ON CRUSADE. REMISSION OF SINS.'),
        ask('legate', 'CHOOSE YOUR PENANCE.', [
          { label: 'FORTY DAYS OF FASTING (THE OLD MANUALS).', effects: { grace: 12, commozione: -6 } },
          { label: 'A LONG TIME AWAY FROM COMMUNION.', effects: { grace: 8, commozione: -10 } },
          { label: "I CLAIM THE CRUSADER'S PARDON.", effects: { grace: 4, commozione: 6, flags: { pardon: true } } },
        ]),
        say('legate', 'FIFTY YEARS FROM NOW, A SAINT WILL WRITE THAT KILLING FOR CHRIST IS NO SIN AT ALL.'),
        say('zampano', 'THERE WAS A SIN, AND THEN THERE WASN\'T. I CANNOT FOLLOW THE DIFFERENCE.', { remembered: true }),
      ],
    },
    {
      id: '5.4',
      title: 'The letter to the Pope',
      happens: 'THEY MUST WRITE TO ROME AND EXPLAIN. THE POPE IS NOT PLEASED AT ALL. HE ABSOLVES THEM SO THAT THEY WILL NOT DO IT AGAIN, AND FORBIDS ATTACKING OTHER CHRISTIANS.',
      source: 'THE LETTER AND THE ABSOLUTION (4C).',
      script: () => [
        stage('zara', [{ name: 'legate', who: 'legate', at: '7', face: 'SE' }], { at: '1' }),
        say('legate', 'WE MUST WRITE TO ROME. CHOOSE YOUR WORDS. CAREFULLY.'),
        mini(() => new LetterGame(), { won: { grace: 5 } }),
        say('zampano', 'THERE WAS A LETTER, AND EVERY LETTER WAS THE SAME LETTER.', { remembered: true }),
      ],
    },
    {
      id: '5.5',
      title: 'A bit late for Egypt',
      happens: 'THE LOOT IS SHARED OUT. THE VENETIANS OBSERVE THAT IT IS A BIT LATE FOR EGYPT: BETTER TO WINTER HERE AND SAIL IN SPRING.',
      source: 'THE DECISION TO WINTER AT ZARA (4C).',
      script: () => [
        stage('zara', [{ name: 'doge', who: 'doge', at: '1', face: 'S' }], { at: '9' }),
        say('doge', 'IT IS A BIT LATE FOR EGYPT. BETTER TO WINTER HERE AND SAIL IN SPRING.'),
        say('zampano', 'AND THE TURKS?'),
        say('doge', 'THEY WILL KEEP.'),
        card('THE GATES CLOSE', 'BEHIND THE FLEET. NOBODY SAILS IN WINTER.', { color: '#9aa4c0' }),
      ],
    },
  ],
};
