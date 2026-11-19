import type { AnimName } from '../assets/manifest';

/** The delivered human cast uses the legacy bark slot for a speaking/role gesture. */
const HUMAN_GESTURE_KEYS: ReadonlySet<string> = new Set([
  'professor', 'niketas', 'fulk', 'clerk', 'abbot', 'envoy', 'bishop', 'cook',
  'sailmaker', 'prince', 'householdWoman', 'knight', 'pilgrim', 'venetian', 'greek',
]);

export interface DialogueGestureTarget {
  readonly who: string;
  readonly alive: boolean;
  readonly behavior: { kind: string };
  readonly animator: { anim: AnimName } | null;
  playAction(anim: AnimName): void;
}

/** Match the portrait identity, not the actor's scene-local name (e.g. bishop/legate).
 * Off-stage voices, moving actors and actions already in progress are left alone.
 * Actor.playAction supplies the authored clip duration; no dialogue timer changes it.
 */
export function playDialogueGesture(portrait: string | null, actors: Iterable<DialogueGestureTarget>): boolean {
  if (!portrait || !HUMAN_GESTURE_KEYS.has(portrait)) return false;
  for (const actor of actors) {
    if (!actor.alive || actor.who !== portrait || actor.behavior.kind !== 'idle') continue;
    if (actor.animator?.anim !== 'idle' && actor.animator?.anim !== 'sit') continue;
    actor.playAction('bark');
    return true;
  }
  return false;
}
