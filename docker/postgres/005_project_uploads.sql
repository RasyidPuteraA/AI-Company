CREATE TABLE IF NOT EXISTS project_uploads (
  id SERIAL PRIMARY KEY,
  project_id INTEGER REFERENCES projects(id),
  project_key TEXT NOT NULL,
  original_filename TEXT NOT NULL,
  stored_filename TEXT NOT NULL,
  relative_path TEXT NOT NULL,
  mime_type TEXT DEFAULT '',
  size_bytes INTEGER DEFAULT 0,
  source TEXT NOT NULL DEFAULT 'dashboard',
  created_at TIMESTAMP DEFAULT now()
);
