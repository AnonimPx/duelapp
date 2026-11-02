export type Side = 'w' | 'b';
export type Tile = [number, number];

export function fullSet(): Tile[] {
  const out: Tile[] = [];
  for (let a = 0; a <= 6; a++) for (let b = a; b <= 6; b++) out.push([a, b]);
  return out;
}

export function fits(tile: Tile, end: number): boolean { return tile[0] === end || tile[1] === end; }

export function orientLeft(tile: Tile, end: number): Tile | null {
  if (tile[1] === end) return [tile[0], tile[1]];
  if (tile[0] === end) return [tile[1], tile[0]];
  return null;
}

export function orientRight(tile: Tile, end: number): Tile | null {
  if (tile[0] === end) return [tile[0], tile[1]];
  if (tile[1] === end) return [tile[1], tile[0]];
  return null;
}

export function pipTotal(hand: Tile[]): number { return hand.reduce((sum, t) => sum + t[0] + t[1], 0); }

export function canPlay(hand: Tile[], board: Tile[]): boolean {
  if (board.length === 0) return hand.length > 0;
  const left = board[0][0], right = board[board.length - 1][1];
  return hand.some((t) => fits(t, left) || fits(t, right));
}
