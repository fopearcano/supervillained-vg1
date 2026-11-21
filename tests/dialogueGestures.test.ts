import { describe, expect, it, vi } from 'vitest';
import { playDialogueGesture, type DialogueGestureTarget } from '../src/story/dialogueGestures';
import { ask, say } from '../src/story/steps';
import type { StoryScene } from '../src/story/storyScene';

function target(who: string, kind = 'idle', anim = 'idle'): DialogueGestureTarget {
  return { who, alive: true, behavior: { kind }, animator: { anim: anim as 'idle' }, playAction: vi.fn() };
}

describe('on-stage speaking gestures', () => {
  it('plays one authored gesture for the matching stationary character', () => {
    const abbot = target('abbot');
    const bishop = target('bishop');
    expect(playDialogueGesture('bishop', [abbot, bishop])).toBe(true);
    expect(bishop.playAction).toHaveBeenCalledExactlyOnceWith('bark');
    expect(abbot.playAction).not.toHaveBeenCalled();
  });

  it.each(['follow', 'chase', 'goto', 'patrol', 'flee', 'wander'])('does not interrupt a %s behavior', (kind) => {
    const actor = target('householdWoman', kind);
    expect(playDialogueGesture('householdWoman', [actor])).toBe(false);
    expect(actor.playAction).not.toHaveBeenCalled();
  });

  it('does not interrupt an existing action or a dead actor', () => {
    const hurt = target('knight', 'idle', 'hurt');
    const gone = { ...target('knight'), alive: false };
    expect(playDialogueGesture('knight', [hurt, gone])).toBe(false);
    expect(hurt.playAction).not.toHaveBeenCalled();
    expect(gone.playAction).not.toHaveBeenCalled();
  });

  it('leaves off-stage voices and animal performances alone', () => {
    expect(playDialogueGesture(null, [])).toBe(false);
    expect(playDialogueGesture('fulk', [])).toBe(false);
    for (const who of ['zampano', 'sbrimbrulon', 'bagnaskiz', 'doge']) {
      const actor = target(who);
      expect(playDialogueGesture(who, [actor])).toBe(false);
      expect(actor.playAction).not.toHaveBeenCalled();
    }
  });

  it.each(['say', 'ask'])('%s resolves the canonical portrait rather than the local actor name', (kind) => {
    const bishop = target('bishop');
    const ctx = {
      actors: new Map([['legate', bishop]]),
      dialogue: { show: vi.fn() },
    } as unknown as StoryScene;
    const step = kind === 'say' ? say('bishop', 'SWEAR.') : ask('bishop', 'SWEAR.', [{ label: 'I SWEAR.' }]);
    step.start(ctx);
    expect(bishop.playAction).toHaveBeenCalledExactlyOnceWith('bark');
    expect(ctx.dialogue.show).toHaveBeenCalledExactlyOnceWith('bishop', 'SWEAR.');
  });
});
