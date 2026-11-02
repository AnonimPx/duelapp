export type Card = [number, number]; // valore 1-10, seme 0-3

export function deck(): Card[] {
  const out: Card[] = [];
  for (let suit = 0; suit < 4; suit++) for (let value = 1; value <= 10; value++) out.push([value, suit]);
  return out;
}

export function sum(cards: Card[]): number { return cards.reduce((a, c) => a + c[0], 0); }

export function captureSets(table: Card[], card: Card): number[][] {
  const exact = table.map((c, i) => c[0] === card[0] ? i : -1).filter((i) => i >= 0);
  if (exact.length > 0) return exact.map((i) => [i]);
  const out: number[][] = [];
  const walk = (start: number, picked: number[], total: number) => {
    if (total === card[0] && picked.length > 0) { out.push([...picked]); return; }
    if (total >= card[0]) return;
    for (let i = start; i < table.length; i++) walk(i + 1, [...picked, i], total + table[i][0]);
  };
  walk(0, [], 0);
  return out;
}

export function sameSet(a: number[], b: number[]): boolean { return a.length === b.length && [...a].sort((x, y) => x - y).every((v, i) => v === [...b].sort((x, y) => x - y)[i]); }

export function score(cards: Card[], captured: Card[], scopa: number): number {
  const points = captured.length > 20 ? 1 : 0;
  const denari = captured.filter((c) => c[1] === 0).length >= 6 ? 1 : 0;
  const settebello = captured.some((c) => c[0] === 7 && c[1] === 0) ? 1 : 0;
  const primiera = Math.floor(captured.reduce((a, c) => a + (c[0] === 7 ? 21 : c[0] === 6 ? 18 : c[0] === 1 ? 16 : 10), 0) / 60);
  return points + denari + settebello + (primiera > 0 ? 1 : 0) + scopa;
}
