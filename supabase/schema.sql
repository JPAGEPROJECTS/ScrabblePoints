-- Esquema Supabase para guardar el historial de partidas de Scrabble.
-- Ejecutar en el SQL Editor de Supabase (o via `supabase db push`).

create extension if not exists pgcrypto;

-- Una fila = una partida completa (cuando el usuario pulsa "Nueva partida"
-- o termina de jugar, se archiva la partida actual aqui).
create table if not exists games (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  finished_at timestamptz not null default now(),
  rounds_played integer not null default 0
);

-- Un jugador dentro de una partida, con su puntaje final.
-- Es la tabla minima necesaria para "solo guardar los puntajes".
create table if not exists game_players (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games(id) on delete cascade,
  name text not null,
  total_score integer not null default 0,
  bingo_count integer not null default 0,
  rank integer not null default 1 -- 1 = ganador de esa partida
);

create index if not exists idx_game_players_game_id on game_players(game_id);

-- OPCIONAL: detalle ronda por ronda, si mas adelante quieres reconstruir
-- el historial completo (tabla "Historial de rondas") y no solo el total final.
create table if not exists game_rounds (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references games(id) on delete cascade,
  round_number integer not null
);

create index if not exists idx_game_rounds_game_id on game_rounds(game_id);

create table if not exists game_round_scores (
  id uuid primary key default gen_random_uuid(),
  game_round_id uuid not null references game_rounds(id) on delete cascade,
  game_player_id uuid not null references game_players(id) on delete cascade,
  points integer not null default 0,
  bingo boolean not null default false
);

create index if not exists idx_game_round_scores_round_id on game_round_scores(game_round_id);
create index if not exists idx_game_round_scores_player_id on game_round_scores(game_player_id);

-- ---------------------------------------------------------------------
-- RLS: la app no tiene login, asi que por defecto se deja abierto a la
-- clave anon (cualquiera con la URL/anon key puede leer y escribir).
-- Si en el futuro agregas autenticacion, reemplaza estas policies por
-- unas que filtren por auth.uid() / una columna user_id.
-- ---------------------------------------------------------------------

alter table games enable row level security;
alter table game_players enable row level security;
alter table game_rounds enable row level security;
alter table game_round_scores enable row level security;

create policy "public read games" on games for select using (true);
create policy "public insert games" on games for insert with check (true);

create policy "public read game_players" on game_players for select using (true);
create policy "public insert game_players" on game_players for insert with check (true);

create policy "public read game_rounds" on game_rounds for select using (true);
create policy "public insert game_rounds" on game_rounds for insert with check (true);

create policy "public read game_round_scores" on game_round_scores for select using (true);
create policy "public insert game_round_scores" on game_round_scores for insert with check (true);

-- Necesarias para poder borrar una partida guardada desde la app.
create policy "public delete games" on games for delete using (true);
create policy "public delete game_players" on game_players for delete using (true);
create policy "public delete game_rounds" on game_rounds for delete using (true);
create policy "public delete game_round_scores" on game_round_scores for delete using (true);
