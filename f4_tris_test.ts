import { drop, wins, ROWS, COLS } from '../supabase/functions/forza4-move/forza4.ts';
import { place, hasWon } from '../supabase/functions/tris-move/tris.ts';
import { initialBoard, place as othelloPlace, validMoves, count } from '../supabase/functions/othello-move/othello.ts';
import { place as millPlace, move as millMove, remove as millRemove, inMill } from '../supabase/functions/mulino-move/mulino.ts';
import { orientLeft, orientRight, canPlay, pipTotal, type Tile } from '../supabase/functions/domino-move/domino.ts';
import { captureSets, score, type Card } from '../supabase/functions/scopa-move/scopa.ts';
import { initialBoard as backgammonInitial, homeComplete, canLand, target } from '../supabase/functions/backgammon-move/backgammon.ts';
let ok = 0, ko = 0;
const t = (n: string, c: boolean) => { c ? ok++ : ko++; console.log((c ? 'OK  ' : 'FAIL ') + n); };
const empty4 = '.'.repeat(ROWS * COLS);

// Forza 4
let r: any = drop(empty4, 3, 'r');
t('f4: disco cade in fondo', r.row === 5 && r.board[5 * COLS + 3] === 'r');
r = drop(r.board, 3, 'y');
t('f4: secondo disco sopra', r.row === 4);
t('f4: colonna non valida', 'error' in (drop(empty4, 7, 'r') as any) && 'error' in (drop(empty4, -1, 'r') as any));
let full = empty4;
for (let i = 0; i < ROWS; i++) full = (drop(full, 0, i % 2 ? 'y' : 'r') as any).board;
t('f4: colonna piena', (drop(full, 0, 'r') as any).error === 'column_full');
let b = empty4;
for (let c = 0; c < 4; c++) b = (drop(b, c, 'r') as any).board;
t('f4: vittoria orizzontale', wins(b, 5, 3));
b = empty4; let last = 0;
for (let i = 0; i < 4; i++) { const x: any = drop(b, 2, 'y'); b = x.board; last = x.row; }
t('f4: vittoria verticale', wins(b, last, 2));
// diagonale: r in (5,0),(4,1),(3,2),(2,3)
const arr = empty4.split('');
for (const [rr, cc] of [[5, 0], [4, 1], [3, 2], [2, 3]]) arr[rr * COLS + cc] = 'r';
t('f4: vittoria diagonale', wins(arr.join(''), 3, 2));
const arr2 = empty4.split('');
for (const [rr, cc] of [[5, 3], [4, 2], [3, 1], [2, 0]]) arr2[rr * COLS + cc] = 'y';
t('f4: vittoria anti-diagonale', wins(arr2.join(''), 4, 2));
const three = empty4.split(''); for (let c = 0; c < 3; c++) three[5 * COLS + c] = 'r';
t('f4: tre in fila non vincono', !wins(three.join(''), 5, 1));

// Tris Pro
let board = '.........', q: number[] = [];
let p: any = place(board, q, 4, 'x'); board = p.board; q = p.queue;
t('tris: piazza segno', board[4] === 'x' && q.length === 1);
t('tris: casella occupata', (place(board, q, 4, 'o') as any).error === 'cell_taken');
t('tris: casella fuori range', (place(board, q, 9, 'o') as any).error === 'bad_cell');
board = '.........'; q = [];
for (const c of [0, 1, 2]) { p = place(board, q, c, 'x'); board = p.board; q = p.queue; }
p = place(board, q, 8, 'x');
t('tris: il quarto segno resta sulla griglia', p.board[0] === 'x' && p.board[8] === 'x' && p.queue.join() === '0,1,2,8');
t('tris: vittoria riga', hasWon('xxx......', 'x') && !hasWon('xxx......', 'o'));
t('tris: vittoria diagonale', hasWon('o...o...o', 'o') && hasWon('..x.x.x..', 'x'));
t('tris: nessuna vittoria', !hasWon('xo.ox.o..', 'x'));
t('tris: la riga resta completa nel Tris classico', hasWon('xxx......', 'x'));

// Othello/Reversi
const ob = initialBoard();
t('othello: board iniziale con 4 pedine', count(ob, 'b') === 2 && count(ob, 'w') === 2);
t('othello: mosse iniziali nere', validMoves(ob, 'b').length === 4);
const op: any = othelloPlace(ob, 19, 'b');
t('othello: mossa ribalta una pedina', op.board[19] === 'b' && op.board[27] === 'b' && op.flips.includes(27));
t('othello: casella occupata non valida', 'error' in (othelloPlace(ob, 27, 'b') as any));

// Mulino
let mb = '.'.repeat(24);
let mr: any = millPlace(mb, 'w', 0); mb = mr.board;
mr = millPlace(mb, 'w', 1); mb = mr.board;
mr = millPlace(mb, 'w', 2);
t('mulino: formazione del mulino', mr.mill && inMill(mr.board, 1, 'w'));
mb = mr.board.replace(/w/g, 'w');
mr = millMove(mb, 'w', 0, 9);
t('mulino: movimento adiacente', !('error' in mr) && mr.board[9] === 'w' && mr.board[0] === '.');
const blockedMill = 'bbb......b..............';
t('mulino: non rimuove pedina in mulino se esiste altra', 'error' in (millRemove(blockedMill, 'b', 0) as any));

// Domino
const dominoBoard: Tile[] = [[2, 5]];
t('domino: collega a sinistra', JSON.stringify(orientLeft([3, 2], 2)) === JSON.stringify([3, 2]));
t('domino: collega a destra invertendo', JSON.stringify(orientRight([5, 4], 5)) === JSON.stringify([5, 4]));
t('domino: rileva tessera giocabile', canPlay([[1, 4], [5, 4]], dominoBoard));
t('domino: somma punti', pipTotal([[6, 6], [1, 2]]) === 15);

// Scopa
const scopaTable: Card[] = [[2, 0], [3, 1], [4, 2]];
t('scopa: presa esatta', captureSets(scopaTable, [2, 3]).length === 1 && captureSets(scopaTable, [2, 3])[0][0] === 0);
t('scopa: presa a somma', captureSets(scopaTable, [7, 3]).some((set) => set.length === 2));
t('scopa: punto scopa', score([], Array.from({length: 21}, (_, i) => [1, i % 4] as Card), 1) >= 2);

// Backgammon
t('backgammon: posizione iniziale 24 punti', backgammonInitial.length === 24 && backgammonInitial.reduce((a, n) => a + Math.abs(n), 0) === 30);
t('backgammon: punto singolo attaccabile', canLand([0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 2, 'w'));
t('backgammon: direzione dadi', target(5, 3, 'w') === 8 && target(5, 3, 'b') === 2);
t('backgammon: casa iniziale non completa', !homeComplete(backgammonInitial, 'w'));

console.log(ok, 'ok', ko, 'fail');
if (ko) throw new Error('test falliti');
