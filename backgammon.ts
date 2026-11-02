export type Player = 'w' | 'b';
export type Board = number[];

export const initialBoard: Board = [2, 0, 0, 0, 0, -5, 0, -3, 0, 0, 0, 5, -5, 0, 0, 0, 3, 0, 5, 0, 0, 0, 0, -2];
export function homeComplete(board: Board, p: Player): boolean {
  return board.every((n, i) => p === 'w' ? (i < 18 || n <= 0) : (i > 5 || n >= 0));
}
export function target(from: number, die: number, p: Player): number { return p === 'w' ? from + die : from - die; }
export function canLand(board: Board, to: number, p: Player): boolean {
  return to >= 0 && to < 24 && (p === 'w' ? board[to] >= -1 : board[to] <= 1);
}
export function pipCount(board: Board, p: Player): number {
  return board.reduce((s, n, i) => s + (p === 'w' ? Math.max(0, n) * (24 - i) : Math.max(0, -n) * (i + 1)), 0);
}
