-- Explicitly grant full permission to the public anon role for local testing
GRANT ALL ON TABLE tournaments TO anon;
GRANT ALL ON TABLE players TO anon;
GRANT ALL ON TABLE groups TO anon;
GRANT ALL ON TABLE matches TO anon;