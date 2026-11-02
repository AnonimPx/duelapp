// Tris classico - logica pura, eseguita SOLO sul server.
// Board: 9 caratteri ('x', 'o', '.'), indici 0-8 da sinistra a destra, dall'alto in basso.
export type Mark = 'x' | 'o';
export const MAX_MOVES = 9; // una griglia piena senza vincitore e' patta

const LINES = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8],
  [0, 3, 6], [1, 4, 7], [2, 5, 8],
  [0, 4, 8], [2, 4, 6],
];

export function place(board: string, queue: number[], cell: number, mark: Mark):
  { board: string; queue: number[] } | { error: string } {
  if (board.length !== 9) return { error: 'bad_board' };
  if (!Number.isInteger(cell) || cell < 0 || cell > 8) return { error: 'bad_cell' };
  if (board[cell] !== '.') return { error: 'cell_taken' };
  const b = board.split('');
  b[cell] = mark;
  // queue resta nel contratto per compatibilita' con partite create dalla versione precedente;
  // nel Tris classico non viene piu' usata per rimuovere segni.
  return { board: b.join(''), queue: [...queue, cell] };
}

export function hasWon(board: string, mark: Mark): boolean {
  return LINES.some((l) => l.every((i) => board[i] === mark));
}
