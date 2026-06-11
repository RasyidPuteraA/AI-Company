CREATE TABLE IF NOT EXISTS agents (
    id SERIAL PRIMARY KEY,
    agent_key VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(150) NOT NULL,
    department VARCHAR(100),
    role_description TEXT,
    status VARCHAR(50) DEFAULT 'OFF_DUTY',
    current_task_id INTEGER,
    fatigue_percent NUMERIC(5,2) DEFAULT 0,
    token_budget_percent NUMERIC(5,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS projects (
    id SERIAL PRIMARY KEY,
    project_key VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    client_name VARCHAR(200),
    status VARCHAR(50) DEFAULT 'PLANNING',
    phase VARCHAR(100) DEFAULT 'INTAKE',
    staging_url TEXT,
    production_url TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    task_key VARCHAR(100) UNIQUE NOT NULL,
    project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'TODO',
    priority VARCHAR(50) DEFAULT 'MEDIUM',
    assigned_agent_key VARCHAR(100),
    current_phase VARCHAR(100),
    handover_note TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS events (
    id SERIAL PRIMARY KEY,
    event_key VARCHAR(120),
    project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL,
    task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
    agent_key VARCHAR(100),
    event_type VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    location VARCHAR(100),
    topic VARCHAR(255),
    summary TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS budget_usage (
    id SERIAL PRIMARY KEY,
    usage_date DATE DEFAULT CURRENT_DATE,
    agent_key VARCHAR(100),
    project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL,
    task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
    usage_type VARCHAR(100),
    estimated_token_units NUMERIC(12,2) DEFAULT 0,
    fatigue_delta_percent NUMERIC(5,2) DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reports (
    id SERIAL PRIMARY KEY,
    report_key VARCHAR(120) UNIQUE NOT NULL,
    report_type VARCHAR(50) NOT NULL,
    project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    created_by_agent_key VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS approvals (
    id SERIAL PRIMARY KEY,
    approval_key VARCHAR(120) UNIQUE NOT NULL,
    project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL,
    task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
    requested_by_agent_key VARCHAR(100),
    approval_type VARCHAR(100) NOT NULL,
    status VARCHAR(50) DEFAULT 'PENDING',
    reason TEXT,
    owner_decision_note TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    decided_at TIMESTAMP
);

INSERT INTO agents (agent_key, name, department, role_description, status, token_budget_percent)
VALUES
('pm_agent', 'PM Agent', 'Operations', 'Plans tasks, coordinates agents, manages handover and reports.', 'OFF_DUTY', 8),
('budget_manager', 'Budget Manager Agent', 'Finance', 'Manages token budget, fatigue, owner reserve, emergency buffer, and resource reports.', 'OFF_DUTY', 5),
('engineer_agent', 'Engineer Agent', 'Engineering', 'Builds and modifies software projects inside assigned workspaces.', 'OFF_DUTY', 35),
('qa_agent', 'QA Agent', 'Quality Assurance', 'Runs tests, reviews outputs, reports bugs, and validates staging readiness.', 'OFF_DUTY', 15),
('devops_agent', 'DevOps Agent', 'Production', 'Deploys to staging, records deployment logs, and never deploys production without owner approval.', 'OFF_DUTY', 7)
ON CONFLICT (agent_key) DO NOTHING;
