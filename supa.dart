import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get supa => Supabase.instance.client;

/// Righe restituite dagli stream di Supabase.
typedef Rows = List<Map<String, dynamic>>;

/// Messaggi leggibili per i codici di errore del server.
String errText(Object? code) {
  const map = {
    'insufficient_funds': 'Gemme insufficienti.',
    'stake_too_low': 'Puntata minima: 10 Gemme.',
    'too_many_open_challenges': 'Hai già 3 sfide aperte.',
    'challenge_not_available': 'Sfida non più disponibile.',
    'cannot_accept_own_challenge': 'Non puoi accettare la tua sfida.',
    'balance_not_low': 'Puoi ricaricare solo sotto 100 Gemme.',
    'not_your_turn': 'Non è il tuo turno.',
    'not_your_piece': 'Quella non è una tua pedina.',
    'illegal_move': 'Mossa non valida.',
    'illegal_capture': 'Presa non valida.',
    'capture_required': 'Presa obbligatoria!',
    'must_capture_max': 'Presa non consentita: devi catturare più pezzi, oppure prendere con la dama / catturare dame se possibile.',
    'must_continue_capture': 'Devi continuare a mangiare.',
    'move_ended_by_promotion': 'La promozione termina la mossa.',
    'conflict_retry': 'Mossa in conflitto, riprova.',
    'timeout_not_reached': 'Attendi 5 minuti di inattività.',
    'not_waiting_for_opponent': 'Tocca a te muovere.',
    'match_over': 'Partita già terminata.',
    'column_full': 'Colonna piena.',
    'bad_column': 'Colonna non valida.',
    'wrong_game': 'Partita di un altro gioco.',
    'cell_taken': 'Casella già occupata.',
    'bad_cell': 'Casella non valida.',
    'lichess_error': 'Lichess non risponde, riprova tra poco.',
    'not_creator': 'Attendi che il bianco crei la partita.',
    'username_taken': 'Nick già in uso.',
    'username_invalid': 'Nick: 3-20 caratteri, solo lettere, numeri e _.',
    'avatar_invalid': 'Avatar non valido.',
    'color_invalid': 'Colore non valido.',
  };
  final s = '$code';
  return map[s] ?? s;
}
