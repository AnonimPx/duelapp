export type Side = 'w' | 'b';

export const ADJ: number[][] = [
  [1, 9], [0, 2, 4], [1, 14], [4, 10], [1, 3, 5, 7], [4, 13], [7, 11], [4, 6, 8], [7, 12],
  [3, 11, 21], [3, 13, 18], [6, 10, 15], [8, 13, 17], [5, 10, 12, 20], [2, 13, 23], [11, 16],
  [15, 17, 19], [12, 16, 22], [10, 19], [16, 18, 20], [13, 19, 21], [9, 20, 22], [16, 21, 23], [14, 22],
];

export const MILLS: number[][] = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8], [9, 10, 11], [12, 13, 14], [15, 16, 17], [18, 19, 20], [21, 22, 23],
  [0, 9, 21], [3, 10, 18], [6, 11, 15], [1, 4, 7], [16, 19, 22], [2, 14, 23], [5, 13, 20], [8, 12, 17],
];

export function inMill(board: string, pos: number, side: Side): boolean {
  return MILLS.some((line) => line.includes(pos) && line.every((i) => board[i] === side));
}

export function formsMill(board: string, side: Side, pos: number): boolean {
  return inMill(board, pos, side);
}

export function validMoves(board: string, side: Side): number[][] {
  const pieces = Array.from({ length: 24 }, (_, i) => i).filter((i) => board[i] === side);
  const count = pieces.length;
  const out: number[][] = [];
  for (const from of pieces) {
    const destinations = count === 3 ? Array.from({ length: 24 }, (_, i) => i) : ADJ[from];
    for (const to of destinations) if (board[to] === '.') out.push([from, to]);
  }
  return out;
}

export function place(board: string, side: Side, pos: number): { board: string; mill: boolean } | { error: string } {
  if (board.length !== 24) return { error: 'bad_board' };
  if (!Number.isInteger(pos) || pos < 0 || pos >= 24) return { error: 'bad_cell' };
  if (board[pos] !== '.') return { error: 'cell_taken' };
  const b = board.split('');
  b[pos] = side;
  return { board: b.join(''), mill: formsMill(b.join(''), side, pos) };
}

export function move(board: string, side: Side, from: number, to: number): { board: string; mill: boolean } | { error: string } {
  if (board.length !== 24) return { error: 'bad_board' };
  if (!Number.isInteger(from) || !Number.isInteger(to) || from < 0 || from >= 24 || to < 0 || to >= 24) return { error: 'bad_cell' };
  if (board[from] !== side) return { error: 'not_your_piece' };
  if (board[to] !== '.') return { error: 'cell_taken' };
  const allowed = validMoves(board, side).some(([a, b]) => a === from && b === to);
  if (!allowed) return { error: 'bad_destination' };
  const chars = board.split('');
  chars[from] = '.';
  chars[to] = side;
  const next = chars.join('');
  return { board: next, mill: formsMill(next, side, to) };
}

export function remove(board: string, opponent: Side, pos: number): { board: string } | { error: string } {
  if (!Number.isInteger(pos) || pos < 0 || pos >= 24) return { error: 'bad_cell' };
  if (board[pos] !== opponent) return { error: 'not_opponent_piece' };
  const opponentPieces = Array.from({ length: 24 }, (_, i) => i).filter((i) => board[i] === opponent);
  const free = opponentPieces.filter((i) => !inMill(board, i, opponent));
  if (free.length > 0 && inMill(board, pos, opponent)) return { error: 'cannot_remove_mill' };
  const chars = board.split('');
  chars[pos] = '.';
  return { board: chars.join('') };
}
