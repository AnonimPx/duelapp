export type Disc = 'b' | 'w';

const DIRS = [-1, 0, 1].flatMap((dr) => [-1, 0, 1].map((dc) => [dr, dc] as const)).filter(([dr, dc]) => dr !== 0 || dc !== 0);

function inside(r: number, c: number): boolean {
  return r >= 0 && r < 8 && c >= 0 && c < 8;
}

export function flipsFor(board: string, cell: number, me: Disc): number[] {
  if (board.length !== 64 || !Number.isInteger(cell) || cell < 0 || cell >= 64 || board[cell] !== '.') return [];
  const other: Disc = me === 'b' ? 'w' : 'b';
  const row = Math.floor(cell / 8), col = cell % 8;
  const flips: number[] = [];
  for (const [dr, dc] of DIRS) {
    const line: number[] = [];
    let r = row + dr, c = col + dc;
    while (inside(r, c) && board[r * 8 + c] === other) {
      line.push(r * 8 + c);
      r += dr;
      c += dc;
    }
    if (line.length > 0 && inside(r, c) && board[r * 8 + c] === me) flips.push(...line);
  }
  return flips;
}

export function validMoves(board: string, me: Disc): number[] {
  return Array.from({ length: 64 }, (_, i) => i).filter((i) => flipsFor(board, i, me).length > 0);
}

export function place(board: string, cell: number, me: Disc): { board: string; flips: number[] } | { error: string } {
  if (board.length !== 64) return { error: 'bad_board' };
  if (!Number.isInteger(cell) || cell < 0 || cell >= 64) return { error: 'bad_cell' };
  const flips = flipsFor(board, cell, me);
  if (flips.length === 0) return { error: 'illegal_move' };
  const chars = board.split('');
  chars[cell] = me;
  for (const i of flips) chars[i] = me;
  return { board: chars.join(''), flips };
}

export function count(board: string, me: Disc): number {
  return board.split('').filter((p) => p === me).length;
}

export function initialBoard(): string {
  const board = Array<string>(64).fill('.');
  board[27] = 'w';
  board[28] = 'b';
  board[35] = 'b';
  board[36] = 'w';
  return board.join('');
}
