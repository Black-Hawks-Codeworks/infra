-- Initialize database schema and seed data
-- Creates a `users` table and a `"user"` view (so both "user" and users can be queried)
-- Inserts 5 dummy users

BEGIN;

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  age INTEGER
);

-- Provide a convenience view named "user" if something expects that exact name
CREATE OR REPLACE VIEW "user" AS
  SELECT * FROM users;

-- Seed data (5 dummy users)
INSERT INTO users (name, email, age) VALUES
  ('Alice Smith', 'alice@example.com', 30),
  ('Bob Jones', 'bob@example.com', 25),
  ('Carol White', 'carol@example.com', 28),
  ('David Brown', 'david@example.com', 35),
  ('Eve Black', 'eve@example.com', 22)
ON CONFLICT DO NOTHING;

COMMIT;
