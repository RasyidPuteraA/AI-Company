CREATE TABLE IF NOT EXISTS owner_commands (
  id SERIAL PRIMARY KEY,
  source TEXT NOT NULL DEFAULT 'dashboard',
  command_text TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'NEW',
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);
