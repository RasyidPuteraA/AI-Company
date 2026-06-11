CREATE TABLE IF NOT EXISTS agent_runtime_status (
  agent_key TEXT PRIMARY KEY,
  runtime_status TEXT NOT NULL DEFAULT 'idle',
  current_task_key TEXT,
  location TEXT DEFAULT 'unknown',
  status_note TEXT DEFAULT '',
  updated_at TIMESTAMP DEFAULT now()
);

INSERT INTO agent_runtime_status (
  agent_key,
  runtime_status,
  current_task_key,
  location,
  status_note,
  updated_at
)
SELECT
  agent_key,
  'idle',
  NULL,
  'system',
  'Initialized runtime status tracking.',
  now()
FROM agents
ON CONFLICT (agent_key) DO NOTHING;
