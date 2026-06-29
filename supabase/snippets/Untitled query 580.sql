-- =======================================================================
-- ENVIRONMENT 1: THE FINISHED GROUP STAGE (TESTS BRACKET SEEDING + TIES)
-- =======================================================================

-- 1. Insert Master Tournament row (Configured for Semifinals 'sf')
INSERT INTO tournaments (id, name, round_robin_sets, knockout_sets, knockout_format)
VALUES (
  '11111111-1111-1111-1111-111111111111', 
  'ITTF Showcase Open', 
  5, 
  7, 
  'sf'
);

-- 2. Insert Player Roster for Group A and Group B
INSERT INTO players (id, tournament_id, name, class_tier, group_label)
VALUES 
  -- Group A Pool
  ('a1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Vivek', 'Advanced', 'Group A'),
  ('a2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Rahul', 'Advanced', 'Group A'),
  ('a3333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Priya', 'Intermediate', 'Group A'),
  -- Group B Pool
  ('b1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Aman', 'Advanced', 'Group B'),
  ('b2222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'Neha', 'Intermediate', 'Group B'),
  ('b3333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Rohan', 'Beginner', 'Group B');

-- 3. Insert Completed Round Robin Fixtures
-- Group A creates a perfect Rock-Paper-Scissors tie loop forcing the point ratio engine cascade!
INSERT INTO matches (tournament_id, player1_id, player2_id, player1_name_fallback, player2_name_fallback, status, stage, player1_score, player2_score, winner_id, set_scores)
VALUES 
  -- Match 1: Vivek beats Rahul 3-1
  (
    '11111111-1111-1111-1111-111111111111', 'a1111111-1111-1111-1111-111111111111', 'a2222222-2222-2222-2222-222222222222', 
    'Vivek (Group A)', 'Rahul (Group A)', 'completed', 'group', 3, 1, 'a1111111-1111-1111-1111-111111111111',
    '[{"p1": 11, "p2": 5}, {"p1": 11, "p2": 7}, {"p1": 9, "p2": 11}, {"p1": 11, "p2": 6}]'::jsonb
  ),
  -- Match 2: Rahul beats Priya 3-1
  (
    '11111111-1111-1111-1111-111111111111', 'a2222222-2222-2222-2222-222222222222', 'a3333333-3333-3333-3333-333333333333', 
    'Rahul (Group A)', 'Priya (Group A)', 'completed', 'group', 3, 1, 'a2222222-2222-2222-2222-222222222222',
    '[{"p1": 11, "p2": 5}, {"p1": 11, "p2": 5}, {"p1": 5, "p2": 11}, {"p1": 11, "p2": 5}]'::jsonb
  ),
  -- Match 3: Priya beats Vivek 3-1 (High-margin win triggers sub-points math!)
  (
    '11111111-1111-1111-1111-111111111111', 'a3333333-3333-3333-3333-333333333333', 'a1111111-1111-1111-1111-111111111111', 
    'Priya (Group A)', 'Vivek (Group A)', 'completed', 'group', 3, 1, 'a3333333-3333-3333-3333-333333333333',
    '[{"p1": 11, "p2": 1}, {"p1": 11, "p2": 2}, {"p1": 2, "p2": 11}, {"p1": 11, "p2": 1}]'::jsonb
  ),

  -- Group B Matches: Straightforward, dominant outcome
  -- Match 4: Aman beats Neha 3-0
  (
    '11111111-1111-1111-1111-111111111111', 'b1111111-1111-1111-1111-111111111111', 'b2222222-2222-2222-2222-222222222222', 
    'Aman (Group B)', 'Neha (Group B)', 'completed', 'group', 3, 0, 'b1111111-1111-1111-1111-111111111111',
    '[{"p1": 11, "p2": 8}, {"p1": 11, "p2": 9}, {"p1": 11, "p2": 7}]'::jsonb
  ),
  -- Match 5: Neha beats Rohan 3-1
  (
    '11111111-1111-1111-1111-111111111111', 'b2222222-2222-2222-2222-222222222222', 'b3333333-3333-3333-3333-333333333333', 
    'Neha (Group B)', 'Rohan (Group B)', 'completed', 'group', 3, 1, 'b2222222-2222-2222-2222-222222222222',
    '[{"p1": 11, "p2": 6}, {"p1": 11, "p2": 8}, {"p1": 9, "p2": 11}, {"p1": 11, "p2": 7}]'::jsonb
  ),
  -- Match 6: Aman beats Rohan 3-0
  (
    '11111111-1111-1111-1111-111111111111', 'b1111111-1111-1111-1111-111111111111', 'b3333333-3333-3333-3333-333333333333', 
    'Aman (Group B)', 'Rohan (Group B)', 'completed', 'group', 3, 0, 'b1111111-1111-1111-1111-111111111111',
    '[{"p1": 11, "p2": 5}, {"p1": 11, "p2": 6}, {"p1": 11, "p2": 4}]'::jsonb
  );


-- =======================================================================
-- ENVIRONMENT 2: THE ACTIVE WORKSPACE (TESTS LIVE SCORE LOGGING MATCHES)
-- =======================================================================

-- 1. Insert active master profile row (Configured for a direct 'finals' bracket)
INSERT INTO tournaments (id, name, round_robin_sets, knockout_sets, knockout_format)
VALUES (
  '22222222-2222-2222-2222-222222222222', 
  'Pune Grand Prix', 
  3, 
  5, 
  'finals'
);

-- 2. Insert Player Roster for a single structural tracking pool
INSERT INTO players (id, tournament_id, name, class_tier, group_label)
VALUES 
  ('c1111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'Amit', 'Intermediate', 'Group A'),
  ('c2222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'Suresh', 'Intermediate', 'Group A'),
  ('c3333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'Vikram', 'Beginner', 'Group A');

-- 3. Insert a mix of finished and scheduled matches
INSERT INTO matches (tournament_id, player1_id, player2_id, player1_name_fallback, player2_name_fallback, status, stage, player1_score, player2_score, winner_id, set_scores)
VALUES 
  -- Completed Match: Amit beats Suresh 2-1
  (
    '22222222-2222-2222-2222-222222222222', 'c1111111-1111-1111-1111-111111111111', 'c2222222-2222-2222-2222-222222222222', 
    'Amit (Group A)', 'Suresh (Group A)', 'completed', 'group', 2, 1, 'c1111111-1111-1111-1111-111111111111',
    '[{"p1": 11, "p2": 9}, {"p1": 8, "p2": 11}, {"p1": 11, "p2": 7}]'::jsonb
  ),
  -- Scheduled Match 1: Suresh vs Vikram
  (
    '22222222-2222-2222-2222-222222222222', 'c2222222-2222-2222-2222-222222222222', 'c3333333-3333-3333-3333-333333333333', 
    'Suresh (Group A)', 'Vikram (Group A)', 'scheduled', 'group', 0, 0, null, '[]'::jsonb
  ),
  -- Scheduled Match 2: Vikram vs Amit
  (
    '22222222-2222-2222-2222-222222222222', 'c3333333-3333-3333-3333-333333333333', 'c1111111-1111-1111-1111-111111111111', 
    'Vikram (Group A)', 'Amit (Group A)', 'scheduled', 'group', 0, 0, null, '[]'::jsonb
  );