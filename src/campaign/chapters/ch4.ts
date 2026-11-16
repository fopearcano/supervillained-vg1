import { CalmGame, mini, parade } from '../../story/minigames';
import { ask, blackHoleIn, blackHoleOut, call, card, fx, say, stage } from '../../story/steps';
import { walk } from '../../story/walk';
import { STORY } from '../../config';
import { C } from '../../ui/retro';
import { CHAPTER_TITLES } from '../titles';
import type { ChapterDef } from '../types';

/** Level 4 — The sea. Cast: Watson as the sailor; an emir; a cellarer; Jack rumoured on every horizon. */
export const CH4: ChapterDef = {
  number: 4,
  title: CHAPTER_TITLES[3],
  intro: "THE CROSSING IS BEAUTIFUL, AND IT IS WHERE THE DREAM FIRST SLIPS INTO ANOTHER CRUSADE: JOINVILLE'S, THE CRUSADE OF 1248.",
  cast: 'WATSON AS THE SAILOR; AN EMIR; A CELLARER; JACK RUMOURED ON EVERY HORIZON',
  theme: 'sea',
  music: 'medieval',
  professor: {
    after: 'JV',
    text: 'AND HERE, FINALLY, IS THE MIDDLE AGES AS WE EXPECT IT: MARTYRDOM TO THE LAST MAN. EXCEPT THAT THE ONLY ONE WHO SAYS SO IS THE CELLARER.',
  },
  subLevels: [
    {
      id: '4.1',
      title: 'Veni Creator',
      happens: 'THE FLEET LEAVES: PAINTED HULLS, BANNERS, SHIELDS, TRUMPETS, DRUMS, THE CLERGY SINGING. WAR IS BEAUTIFUL AND THEY ALL KNOW IT.',
      source: 'CLARI\'S DEPARTURE AND THE POINT THAT MEDIEVAL WAR HAS AN AESTHETIC (4C). BOARD: "MERAVIGLIA (BELLEZZA) DELLA GUERRA".',
      script: () => [
        stage('ship', [{ name: 'watson', who: 'watson', at: '2', face: 'SW' }]),
        say('voice', 'NEWS: JACK THE GENERAL HAS BEEN SEEN ON THE HORIZON. EVERY HORIZON.'),
        mini(parade, { won: { commozione: 8, marvel: 'THE FLEET LEAVING VENICE' }, lost: { commozione: 2, marvel: 'THE FLEET LEAVING VENICE' } }),
        card('VENI CREATOR', 'WAR IS BEAUTIFUL AND THEY ALL KNOW IT', { color: C.cyan, seconds: 2.4 }),
        say('watson', 'THERE WAS A SHIP, MAN, AND IT WAS SINGING.', { remembered: true }),
      ],
    },
    {
      id: '4.2',
      title: 'Man overboard',
      happens: 'WATSON FALLS IN AND FLOATS, PERFECTLY STILL. FROM THE NEXT SHIP HE LOOKS LIKE A PARCEL. HE EXPLAINS THAT OUR LADY WAS HOLDING HIM UP, SO WHY SWIM.',
      source: "THE SAILOR ON JOINVILLE'S VOYAGE HOME, AND THE MIRACLE HE HAD PAINTED AT JOINVILLE (JV).",
      script: () => [
        stage('ship', [{ name: 'watson', who: 'watson', at: '6', face: 'E' }], { at: '1' }),
        card('MAN OVERBOARD!', 'FROM HERE HE LOOKS LIKE A PARCEL', { color: C.red, seconds: 2 }),
        mini(() => new CalmGame(), { won: { commozione: 8, item: 'A FRESCO FOR THE CHAPEL AT HOME' } }),
        call((ctx) => ctx.actor('watson').setPosition(ctx.marker('5').x, ctx.marker('5').y)),
        say('watson', 'OUR LADY WAS HOLDING ME UP, MAN. SO WHY SWIM?'),
        say('zampano', 'YOU ASKED HER?'),
        say('watson', 'I ASKED. IF THE DAY OF DEATH WERE WRITTEN IN ADVANCE, SERVING GOD WOULD BE FOOLISH.'),
        say('watson', 'THERE WAS A LADY, AND SHE WAS A RAFT.', { remembered: true }),
      ],
    },
    {
      id: '4.3',
      title: 'Black hole: boarded',
      happens: 'ENEMY GALLEYS RING THE SHIP. EVERYONE AGREES TO SURRENDER. THE CELLARER VOTES THAT THEY ALL BE KILLED AND GO STRAIGHT TO PARADISE. NOBODY LISTENS TO HIM.',
      source: "THE CELLARER'S PROPOSAL (JV). BOARD: KNOWING WHEN TO WITHDRAW IS GOOD SENSE, NOT SHAME.",
      blackHole: { where: '1250, OFF EGYPT. ANOTHER CRUSADE', value: 'Pilgrims, not martyrs' },
      script: () => [
        ...blackHoleIn('1250, OFF EGYPT. ANOTHER CRUSADE.'),
        stage('ship', [
          { name: 'cellarer', who: 'cellarer', at: '2', face: 'SW' },
          { name: 'k1', who: 'knight', at: '3', face: 'S' },
          { name: 'k2', who: 'knight', at: '8', face: 'SE' },
        ]),
        say('knight', 'GALLEYS ON EVERY SIDE. WE VOTE. I SAY: SURRENDER.'),
        say('cellarer', 'I SAY WE ALL BE KILLED AND GO STRAIGHT TO PARADISE.'),
        ask('knight', 'YOUR VOTE, LITTLE KNIGHT?', [
          { label: 'SURRENDER.', effects: { supervillain: 4 }, then: [say('knight', 'GOOD SENSE. NOT SHAME.')] },
          { label: 'TO PARADISE, ALL OF US.', effects: { commozione: 4 }, then: [say('knight', 'NOBODY LISTENS TO THE CELLARER. NOR TO YOU.')] },
          { label: 'WHERE ARE THE TURKS?', then: [say('cellarer', 'RIGHT THERE. ON EVERY SIDE.')] },
        ]),
        card('SURRENDER', 'COMMON SENSE OUTVOTES PARADISE', { color: C.cyan, seconds: 2 }),
        say('cellarer', 'THERE WAS A PARADISE, AND I WAS ALONE IN IT.', { remembered: true }),
        ...blackHoleOut('Pilgrims, not martyrs'),
      ],
    },
    {
      id: '4.4',
      title: "Black hole: Friday at the emir's table",
      happens: 'A PRISONER, HE LUNCHES WITH AN EMIR AND COMPARES FAMILY TREES. A BURGHER CRIES OUT: IT IS FRIDAY, AND THAT IS MEAT. EMIR AND PAPAL LEGATE BOTH SAY GOD CANNOT MIND.',
      source: 'JOINVILLE AT THE EMIR\'S TABLE (JV). BOARD: "LE FORME SONO IMPORTANTI".',
      blackHole: { where: 'A PRISONER OF THE EMIR', value: 'Forms matter' },
      script: () => [
        ...blackHoleIn('A PRISONER OF THE EMIR.'),
        stage(
          'interior',
          [
            { name: 'emir', who: 'emir', at: '2', face: 'SW' },
            { name: 'legate', who: 'legate', at: '3', face: 'NE' },
            { name: 'burgher', who: 'burgher', at: '5', face: 'W' },
          ],
          { at: '1' },
        ),
        say('emir', 'SIT. EAT. TELL ME ABOUT YOUR GRANDFATHER. MINE KNEW YOUR GRANDFATHER.'),
        ask('emir', 'YOU ARE NOT EATING.', [{ label: '(EAT THE MEAT)' }]),
        say('burgher', 'IT IS FRIDAY! AND THAT IS MEAT!'),
        fx({ grace: -20, flags: { fridayMeat: true } }),
        say('legate', 'IT WAS AN ACCIDENT. GOD CANNOT MIND.'),
        say('emir', 'HE CANNOT MIND. EAT.'),
        ask('legate', 'WELL?', [
          { label: 'I WILL FAST ON BREAD AND WATER ANYWAY.', cost: STORY.COST.ATONE, effects: { grace: 20, flags: { atoned: true } }, then: [say('legate', 'NOBODY ASKED YOU TO.')] },
          { label: 'IF GOD CANNOT MIND, I CANNOT MIND.', then: [say('burgher', 'IT IS STILL FRIDAY.')] },
        ]),
        say('zampano', 'THERE WAS A FRIDAY, AND IT WAS STARING AT ME.', { remembered: true }),
        ...blackHoleOut('Forms matter'),
      ],
    },
    {
      id: '4.5',
      title: 'Black hole: the hermit island',
      happens: 'THE SHIPS TAKE ON WATER AT A DESERTED ISLAND: A WHITEWASHED ORATORY, A GARDEN OF FIGS, VINES AND OLIVES, TWO SKELETONS LAID OUT SIDE BY SIDE. ONE SAILOR STAYS TO BE A HERMIT.',
      source: 'LAMPEDUSA ON THE WAY BACK FROM EGYPT (JV).',
      blackHole: { where: 'LAMPEDUSA, ON THE WAY HOME', value: 'The road is the penance' },
      script: () => [
        ...blackHoleIn('LAMPEDUSA, ON THE WAY HOME FROM EGYPT.'),
        stage('island', [
          { name: 'watson', who: 'watson', at: '5', face: 'NW' },
          { name: 'jack', who: 'jack', at: '6', face: 'NE' },
        ]),
        walk({
          objective: 'EXPLORE THE ISLAND',
          action: 'LOOK',
          pickups: [
            { at: '1', kind: 'marvel', label: 'THE WHITEWASHED ORATORY', effects: { marvel: 'THE HERMIT ORATORY', commozione: 3 } },
            { at: '2', kind: 'marvel', label: 'FIGS, VINES AND OLIVES', effects: { marvel: 'THE HERMIT GARDEN', commozione: 3 } },
            { at: '4', kind: 'marvel', label: 'TWO SKELETONS, SIDE BY SIDE', effects: { marvel: 'THE TWO SKELETONS', commozione: 3 } },
          ],
          onAction: (ctx) => ctx.say('...', { x: ctx.player.gx, y: ctx.player.gy }),
        }),
        ask('voice', 'ONE OF THEM WILL STAY TO BE A HERMIT. WHO?', [
          { label: 'WATSON. THE HERMITAGE WAS THERE.', effects: { flags: { hermit: 'watson' } }, then: [say('watson', 'IT WAS THERE, MAN. SO I STAY.')] },
          { label: 'JACK.', effects: { flags: { hermit: 'jack' } }, then: [say('jack', 'ME? A HERMIT? I AM A GENERAL!')] },
          { label: 'NOBODY. WE ALL GO HOME.', effects: { flags: { hermit: 'nobody' } }, then: [say('watson', 'I STAY ANYWAY, MAN.')] },
        ]),
        say('voice', 'THEY LEAVE HIM CRATES OF BISCUIT. HE REAPPEARS LATER ANYWAY.'),
        ...blackHoleOut('The road is the penance'),
      ],
    },
  ],
};
