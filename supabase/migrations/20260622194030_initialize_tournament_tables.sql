
  create table "public"."groups" (
    "id" uuid not null default gen_random_uuid(),
    "tournament_id" uuid,
    "class_tier" text not null,
    "group_name" text not null,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."groups" enable row level security;


  create table "public"."matches" (
    "id" uuid not null default gen_random_uuid(),
    "tournament_id" uuid,
    "group_id" uuid,
    "player1_id" uuid,
    "player2_id" uuid,
    "scores" jsonb default '[]'::jsonb,
    "winner_id" uuid,
    "stage" text not null,
    "status" text not null default 'pending'::text,
    "created_at" timestamp with time zone default now(),
    "player1_name_fallback" text,
    "player2_name_fallback" text,
    "player1_score" integer default 0,
    "player2_score" integer default 0,
    "set_scores" jsonb default '[]'::jsonb
      );



  create table "public"."players" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "class_tier" text not null default 'Beginner'::text,
    "created_at" timestamp with time zone default now(),
    "tournament_id" uuid,
    "group_label" text default 'Group A'::text
      );



  create table "public"."tournaments" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "status" text not null default 'upcoming'::text,
    "settings" jsonb not null default '{"best_of": {"final": 7, "semi-final": 5, "round-robin": 3, "quarter-final": 5}}'::jsonb,
    "dr_form_url" text,
    "dr_sheet_url" text,
    "created_at" timestamp with time zone default now()
      );


CREATE UNIQUE INDEX groups_pkey ON public.groups USING btree (id);

CREATE UNIQUE INDEX matches_pkey ON public.matches USING btree (id);

CREATE UNIQUE INDEX players_pkey ON public.players USING btree (id);

CREATE UNIQUE INDEX tournaments_pkey ON public.tournaments USING btree (id);

alter table "public"."groups" add constraint "groups_pkey" PRIMARY KEY using index "groups_pkey";

alter table "public"."matches" add constraint "matches_pkey" PRIMARY KEY using index "matches_pkey";

alter table "public"."players" add constraint "players_pkey" PRIMARY KEY using index "players_pkey";

alter table "public"."tournaments" add constraint "tournaments_pkey" PRIMARY KEY using index "tournaments_pkey";

alter table "public"."groups" add constraint "groups_tournament_id_fkey" FOREIGN KEY (tournament_id) REFERENCES public.tournaments(id) ON DELETE CASCADE not valid;

alter table "public"."groups" validate constraint "groups_tournament_id_fkey";

alter table "public"."matches" add constraint "matches_group_id_fkey" FOREIGN KEY (group_id) REFERENCES public.groups(id) ON DELETE CASCADE not valid;

alter table "public"."matches" validate constraint "matches_group_id_fkey";

alter table "public"."matches" add constraint "matches_player1_id_fkey" FOREIGN KEY (player1_id) REFERENCES public.players(id) ON DELETE CASCADE not valid;

alter table "public"."matches" validate constraint "matches_player1_id_fkey";

alter table "public"."matches" add constraint "matches_player2_id_fkey" FOREIGN KEY (player2_id) REFERENCES public.players(id) ON DELETE CASCADE not valid;

alter table "public"."matches" validate constraint "matches_player2_id_fkey";

alter table "public"."matches" add constraint "matches_tournament_id_fkey" FOREIGN KEY (tournament_id) REFERENCES public.tournaments(id) ON DELETE CASCADE not valid;

alter table "public"."matches" validate constraint "matches_tournament_id_fkey";

alter table "public"."matches" add constraint "matches_winner_id_fkey" FOREIGN KEY (winner_id) REFERENCES public.players(id) not valid;

alter table "public"."matches" validate constraint "matches_winner_id_fkey";

alter table "public"."players" add constraint "players_tournament_id_fkey" FOREIGN KEY (tournament_id) REFERENCES public.tournaments(id) ON DELETE CASCADE not valid;

alter table "public"."players" validate constraint "players_tournament_id_fkey";

grant delete on table "public"."groups" to "anon";

grant insert on table "public"."groups" to "anon";

grant references on table "public"."groups" to "anon";

grant select on table "public"."groups" to "anon";

grant trigger on table "public"."groups" to "anon";

grant truncate on table "public"."groups" to "anon";

grant update on table "public"."groups" to "anon";

grant references on table "public"."groups" to "authenticated";

grant trigger on table "public"."groups" to "authenticated";

grant truncate on table "public"."groups" to "authenticated";

grant references on table "public"."groups" to "service_role";

grant trigger on table "public"."groups" to "service_role";

grant truncate on table "public"."groups" to "service_role";

grant delete on table "public"."matches" to "anon";

grant insert on table "public"."matches" to "anon";

grant references on table "public"."matches" to "anon";

grant select on table "public"."matches" to "anon";

grant trigger on table "public"."matches" to "anon";

grant truncate on table "public"."matches" to "anon";

grant update on table "public"."matches" to "anon";

grant references on table "public"."matches" to "authenticated";

grant trigger on table "public"."matches" to "authenticated";

grant truncate on table "public"."matches" to "authenticated";

grant references on table "public"."matches" to "service_role";

grant trigger on table "public"."matches" to "service_role";

grant truncate on table "public"."matches" to "service_role";

grant delete on table "public"."players" to "anon";

grant insert on table "public"."players" to "anon";

grant references on table "public"."players" to "anon";

grant select on table "public"."players" to "anon";

grant trigger on table "public"."players" to "anon";

grant truncate on table "public"."players" to "anon";

grant update on table "public"."players" to "anon";

grant references on table "public"."players" to "authenticated";

grant trigger on table "public"."players" to "authenticated";

grant truncate on table "public"."players" to "authenticated";

grant references on table "public"."players" to "service_role";

grant trigger on table "public"."players" to "service_role";

grant truncate on table "public"."players" to "service_role";

grant delete on table "public"."tournaments" to "anon";

grant insert on table "public"."tournaments" to "anon";

grant references on table "public"."tournaments" to "anon";

grant select on table "public"."tournaments" to "anon";

grant trigger on table "public"."tournaments" to "anon";

grant truncate on table "public"."tournaments" to "anon";

grant update on table "public"."tournaments" to "anon";

grant references on table "public"."tournaments" to "authenticated";

grant trigger on table "public"."tournaments" to "authenticated";

grant truncate on table "public"."tournaments" to "authenticated";

grant references on table "public"."tournaments" to "service_role";

grant trigger on table "public"."tournaments" to "service_role";

grant truncate on table "public"."tournaments" to "service_role";


  create policy "Allow public insert"
  on "public"."groups"
  as permissive
  for insert
  to public
with check (true);



  create policy "Allow public select"
  on "public"."groups"
  as permissive
  for select
  to public
using (true);



  create policy "Allow public all"
  on "public"."matches"
  as permissive
  for all
  to public
using (true);



  create policy "Allow public select"
  on "public"."matches"
  as permissive
  for select
  to public
using (true);



  create policy "Allow public insert"
  on "public"."players"
  as permissive
  for insert
  to public
with check (true);



  create policy "Allow public select"
  on "public"."players"
  as permissive
  for select
  to public
using (true);



  create policy "Allow public insert"
  on "public"."tournaments"
  as permissive
  for insert
  to public
with check (true);



  create policy "Allow public select"
  on "public"."tournaments"
  as permissive
  for select
  to public
using (true);



