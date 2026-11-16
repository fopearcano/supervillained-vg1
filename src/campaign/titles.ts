/** Level titles (shared by the chapters and the memory shards of 1.2). */
export const CHAPTER_TITLES = [
  'Greenzone',
  'On the edge of dreams',
  'Venice',
  'The sea',
  'Zara',
  'The long winter',
  'Constantinople',
  'Back to Greenzone',
] as const;

/** Name of the memory shard that unlocks level `n` (picked up in 1.2). */
export function shardName(n: number): string {
  return `LEVEL ${n}: ${CHAPTER_TITLES[n - 1]!.toUpperCase()}`;
}
