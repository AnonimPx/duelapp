export type Suit = '♣' | '♦' | '♥' | '♠';
export type Card = { rank: number; suit: Suit; joker?: boolean };
export type Meld = Card[];

export function deck(): Card[] {
  const suits: Suit[] = ['♣', '♦', '♥', '♠'];
  const out: Card[] = [];
  for (let copy = 0; copy < 2; copy++) {
    for (const suit of suits) for (let rank = 1; rank <= 13; rank++) out.push({ rank, suit });
    out.push({ rank: 0, suit: '♣', joker: true }, { rank: 0, suit: '♣', joker: true });
  }
  return out;
}

export function cardPoints(c: Card): number { return c.joker ? 25 : c.rank === 1 ? 11 : Math.min(c.rank, 10); }
export function meldPoints(m: Meld): number { return m.reduce((s, c) => s + cardPoints(c), 0); }
export function isSet(m: Meld): boolean {
  if (m.length < 3 || m.some((c) => c.joker)) return false;
  const ranks = new Set(m.map((c) => c.rank));
  return ranks.size === 1 && new Set(m.map((c) => c.suit)).size === m.length;
}
export function isRun(m: Meld): boolean {
  if (m.length < 3) return false;
  const real = m.filter((c) => !c.joker).sort((a, b) => a.rank - b.rank);
  if (new Set(real.map((c) => c.suit)).size !== 1) return false;
  let gaps = 0;
  for (let i = 1; i < real.length; i++) gaps += real[i].rank - real[i - 1].rank - 1;
  return gaps <= m.filter((c) => c.joker).length;
}
export function validMeld(m: Meld): boolean { return isSet(m) || isRun(m); }
export function openingTotal(melds: Meld[]): number { return melds.filter(validMeld).reduce((s, m) => s + meldPoints(m), 0); }
export function canOpen(melds: Meld[]): boolean { return openingTotal(melds) >= 40; }
export function prize(stake: number, players: number): { gross: number; bank: number; payout: number } {
  const gross = stake * players, bank = Math.floor(gross * 0.20);
  return { gross, bank, payout: gross - bank };
}
