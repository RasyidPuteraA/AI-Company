const http = require("http");
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");
const os = require("os");

const PORT = process.env.PORT || 8787;
const HOST = process.env.HOST || "127.0.0.1";
const PUBLIC_DIR = path.join(__dirname, "public");
const ROOT_DIR = path.join(__dirname, "..", "..");
const CODEX_BUDGET_FILE = path.join(ROOT_DIR, "company", "config", "codex_budget.env");
const CODEX_LEDGER_FILE = path.join(ROOT_DIR, "company", "runtime", "codex_usage.jsonl");
const LEARNING_CONFIG_FILE = path.join(ROOT_DIR, "company", "config", "ai_company_scheduler.env");
const LEARNING_LESSONS_DIR = path.join(ROOT_DIR, "company", "learning", "lessons");
const LEARNING_PATTERNS_DIR = path.join(ROOT_DIR, "company", "learning", "patterns");
const LEARNING_CONTEXT_FILE = path.join(ROOT_DIR, "company", "learning", "context", "latest-learning-context.md");
const LEARNING_REPORTS_DIR = path.join(ROOT_DIR, "company", "reports", "learning");
const AI_COMPANY_OS_STATUS_RUNNER = path.join(ROOT_DIR, "runners", "ai_company_os_status.sh");
const AI_COMPANY_OS_CONTROL_RUNNER = path.join(ROOT_DIR, "runners", "ai_company_os_control.sh");

function runSql(sql) {
  const output = execFileSync(
    "docker",
    [
      "exec",
      "ai_company_postgres",
      "psql",
      "-U",
      "ai_company",
      "-d",
      "ai_company",
      "-t",
      "-A",
      "-F",
      "|",
      "-c",
      sql
    ],
    { encoding: "utf8" }
  );

  return output.trim();
}

function json(res, data, statusCode = 200) {
  res.writeHead(statusCode, { "Content-Type": "application/json" });
  res.end(JSON.stringify(data, null, 2));
}

function serveStatic(res, filePath) {
  if (!fs.existsSync(filePath)) {
    res.writeHead(404);
    res.end("Not found");
    return;
  }

  const ext = path.extname(filePath);
  const type = {
    ".html": "text/html",
    ".css": "text/css",
    ".js": "application/javascript"
  }[ext] || "text/plain";

  res.writeHead(200, { "Content-Type": type });
  res.end(fs.readFileSync(filePath));
}

function parseRows(text, columns) {
  if (!text) return [];

  return text.split("\n").filter(Boolean).map((line) => {
    const values = line.split("|");
    const row = {};
    columns.forEach((col, index) => {
      row[col] = values[index] || "";
    });
    return row;
  });
}


let lastCpuSnapshot = null;

function readCpuSnapshot() {
  const line = fs.readFileSync("/proc/stat", "utf8").split("\n")[0];
  const values = line.trim().split(/\s+/).slice(1).map(Number);
  const idle = (values[3] || 0) + (values[4] || 0);
  const total = values.reduce((sum, value) => sum + value, 0);
  return { idle, total };
}

function getCpuUsagePercent() {
  const current = readCpuSnapshot();

  if (!lastCpuSnapshot) {
    lastCpuSnapshot = current;
    const cpuCount = Math.max(os.cpus().length, 1);
    return Math.min(100, Number(((os.loadavg()[0] / cpuCount) * 100).toFixed(1)));
  }

  const idleDelta = current.idle - lastCpuSnapshot.idle;
  const totalDelta = current.total - lastCpuSnapshot.total;
  lastCpuSnapshot = current;

  if (totalDelta <= 0) return 0;

  return Number(Math.max(0, Math.min(100, 100 - ((idleDelta / totalDelta) * 100))).toFixed(1));
}

function formatBytes(bytes) {
  const value = Number(bytes || 0);
  const units = ["B", "KB", "MB", "GB", "TB"];
  let size = value;
  let unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size = size / 1024;
    unitIndex += 1;
  }

  return `${size.toFixed(unitIndex === 0 ? 0 : 1)} ${units[unitIndex]}`;
}

function formatUptime(seconds) {
  const total = Math.floor(Number(seconds || 0));
  const days = Math.floor(total / 86400);
  const hours = Math.floor((total % 86400) / 3600);
  const minutes = Math.floor((total % 3600) / 60);

  if (days > 0) return `${days}d ${hours}h ${minutes}m`;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

function getDiskUsage() {
  const output = execFileSync("df", ["-P", "/"], { encoding: "utf8" });
  const line = output.trim().split("\n")[1] || "";
  const parts = line.trim().split(/\s+/);

  const totalKb = Number(parts[1] || 0);
  const usedKb = Number(parts[2] || 0);
  const availableKb = Number(parts[3] || 0);
  const percent = Number(String(parts[4] || "0").replace("%", ""));

  return {
    total_bytes: totalKb * 1024,
    used_bytes: usedKb * 1024,
    available_bytes: availableKb * 1024,
    used_percent: percent,
    total_human: formatBytes(totalKb * 1024),
    used_human: formatBytes(usedKb * 1024),
    available_human: formatBytes(availableKb * 1024)
  };
}



function readEnvConfig(filePath) {
  const result = {};

  if (!fs.existsSync(filePath)) return result;

  const lines = fs.readFileSync(filePath, "utf8").split(/\r?\n/);

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) continue;

    const index = trimmed.indexOf("=");
    const key = trimmed.slice(0, index).trim();
    const value = trimmed.slice(index + 1).trim();
    result[key] = value;
  }

  return result;
}

function readJsonl(filePath) {
  if (!fs.existsSync(filePath)) return [];

  return fs.readFileSync(filePath, "utf8")
    .split(/\r?\n/)
    .filter(Boolean)
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        return null;
      }
    })
    .filter(Boolean);
}

function startOfToday(now) {
  const d = new Date(now);
  d.setHours(0, 0, 0, 0);
  return d;
}

function startOfWeek(now) {
  const d = startOfToday(now);
  const day = (d.getDay() + 6) % 7;
  d.setDate(d.getDate() - day);
  return d;
}

function startOfMonth(now) {
  const d = startOfToday(now);
  d.setDate(1);
  return d;
}

function codexTokensUsed(item) {
  return Number(
    item.tokens_used
    || item.estimated_total_tokens
    || item.estimated_tokens_used
    || 0
  );
}

function tokensSince(items, startDate) {
  return items.reduce((sum, item) => {
    const created = new Date(item.created_at || 0);
    if (Number.isNaN(created.getTime())) return sum;
    if (created >= startDate) return sum + codexTokensUsed(item);
    return sum;
  }, 0);
}

function getCodexUsageDashboardSummary() {
  const config = readEnvConfig(CODEX_BUDGET_FILE);
  const items = readJsonl(CODEX_LEDGER_FILE);

  const now = new Date();
  const dailySoft = Number(config.CODEX_DAILY_SOFT_LIMIT_TOKENS || 300000);
  const dailyHard = Number(config.CODEX_DAILY_HARD_LIMIT_TOKENS || 500000);
  const weeklySoft = Number(config.CODEX_WEEKLY_SOFT_LIMIT_TOKENS || 2000000);
  const monthlySoft = Number(config.CODEX_MONTHLY_SOFT_LIMIT_TOKENS || 8000000);

  const todayUsed = tokensSince(items, startOfToday(now));
  const weekUsed = tokensSince(items, startOfWeek(now));
  const monthUsed = tokensSince(items, startOfMonth(now));

  const dailyState = todayUsed >= dailyHard ? "STOP" : todayUsed >= dailySoft ? "WARN" : "OK";
  const weeklyState = weekUsed >= weeklySoft ? "WARN" : "OK";
  const monthlyState = monthUsed >= monthlySoft ? "WARN" : "OK";

  const byAgentMap = new Map();
  const sourceBreakdownMap = new Map();

  for (const item of items) {
    const agent = item.agent_key || "unknown";
    const tokens = codexTokensUsed(item);
    const source = item.mode === "direct_danger_logged" ? "direct_danger_logged" : "wrapper";

    byAgentMap.set(agent, (byAgentMap.get(agent) || 0) + tokens);
    sourceBreakdownMap.set(source, (sourceBreakdownMap.get(source) || 0) + tokens);
  }

  const byAgent = Array.from(byAgentMap.entries())
    .map(([agent_key, tokens_used]) => ({ agent_key, tokens_used }))
    .sort((a, b) => b.tokens_used - a.tokens_used);

  const wrapperTotal = sourceBreakdownMap.get("wrapper") || 0;
  const dangerLoggedTotal = sourceBreakdownMap.get("direct_danger_logged") || 0;
  const totalEstimated = wrapperTotal + dangerLoggedTotal;

  const recentRuns = items
    .slice(-20)
    .reverse()
    .map((item) => ({
      created_at: item.created_at || "",
      agent_key: item.agent_key || "",
      task_key: item.task_key || "",
      mode: item.mode || "",
      sandbox: item.sandbox || "",
      command: item.command || "",
      tokens_used: codexTokensUsed(item),
      token_source: item.token_source || (item.mode === "direct_danger_logged" ? "estimate_chars_div_4" : "codex_cli_output"),
      exit_status: Number(item.exit_status || 0),
      run_seconds: Number(item.run_seconds || 0)
    }));

  return {
    generated_at: now.toISOString(),
    last_updated: now.toISOString(),
    note: "Internal AI Company Codex CLI budget estimate, not official OpenAI remaining quota.",
    estimates: true,
    is_estimate: true,
    limit_tokens: dailyHard,
    week_total_tokens: weekUsed,
    month_total_tokens: monthUsed,
    wrapper_total_tokens: wrapperTotal,
    danger_logged_total_tokens: dangerLoggedTotal,
    total_estimated_tokens: totalEstimated,
    status: dailyState,
    source: {
      ledger_exists: fs.existsSync(CODEX_LEDGER_FILE),
      budget_file_exists: fs.existsSync(CODEX_BUDGET_FILE),
      ledger_path: path.relative(ROOT_DIR, CODEX_LEDGER_FILE)
    },
    budget: {
      today: {
        used_tokens: todayUsed,
        soft_limit_tokens: dailySoft,
        hard_limit_tokens: dailyHard,
        state: dailyState
      },
      week: {
        used_tokens: weekUsed,
        soft_limit_tokens: weeklySoft,
        state: weeklyState
      },
      month: {
        used_tokens: monthUsed,
        soft_limit_tokens: monthlySoft,
        state: monthlyState
      }
    },
    by_agent: byAgent,
    source_breakdown: {
      wrapper: wrapperTotal,
      direct_danger_logged: dangerLoggedTotal,
      estimated_reconciled: 0
    },
    recent_runs: recentRuns
  };
}

function getAiUsageSummary() {
  return {
    mode: "local_workflow",
    api_tokens_today: 0,
    api_tokens_limit: null,
    api_cost_today_usd: 0,
    codex_usage: "tracked_internal_estimate",
    chatgpt_plan_quota: "external_not_available",
    note: "AI Company OS tracks Codex CLI usage through an internal ledger. Limits are internal estimates, not official OpenAI remaining quota."
  };
}

function listMarkdownFiles(dirPath) {
  if (!fs.existsSync(dirPath)) return [];
  return fs.readdirSync(dirPath)
    .filter((name) => name.endsWith(".md"))
    .map((name) => path.join(dirPath, name))
    .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs);
}

function readDashField(text, fieldName) {
  const escaped = fieldName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = text.match(new RegExp(`^- ${escaped}: (.*)$`, "m"));
  return match ? match[1].trim() : "";
}

function getLearningDashboardSummary() {
  const config = readEnvConfig(LEARNING_CONFIG_FILE);
  const lessons = listMarkdownFiles(LEARNING_LESSONS_DIR);
  const patterns = listMarkdownFiles(LEARNING_PATTERNS_DIR);
  const reports = listMarkdownFiles(LEARNING_REPORTS_DIR);

  let topPattern = null;
  if (patterns.length > 0) {
    const text = fs.readFileSync(patterns[0], "utf8");
    topPattern = {
      path: path.relative(ROOT_DIR, patterns[0]),
      title: readDashField(text, "title") || path.basename(patterns[0], ".md"),
      count: Number(readDashField(text, "count") || 0)
    };
  }

  return {
    enabled: String(config.AI_COMPANY_LEARNING_ENABLED || "1") === "1",
    auto_apply: String(config.AI_COMPANY_LEARNING_AUTO_APPLY || "0") === "1",
    create_tasks: String(config.AI_COMPANY_LEARNING_CREATE_TASKS || "1") === "1",
    lessons_count: lessons.length,
    latest_report: reports.length > 0 ? path.relative(ROOT_DIR, reports[0]) : "",
    top_pattern: topPattern,
    latest_context_path: fs.existsSync(LEARNING_CONTEXT_FILE) ? path.relative(ROOT_DIR, LEARNING_CONTEXT_FILE) : ""
  };
}

function runAiCompanyOsStatus() {
  const output = execFileSync(
    AI_COMPANY_OS_STATUS_RUNNER,
    ["--json"],
    {
      cwd: ROOT_DIR,
      encoding: "utf8",
      timeout: 30000,
      maxBuffer: 1024 * 1024
    }
  );

  return JSON.parse(output);
}

function setAiCompanyOsPower(action) {
  const normalized = String(action || "").trim().toLowerCase();

  if (!["on", "off"].includes(normalized)) {
    throw new Error("action must be on or off");
  }

  execFileSync(
    AI_COMPANY_OS_CONTROL_RUNNER,
    [normalized],
    {
      cwd: ROOT_DIR,
      encoding: "utf8",
      timeout: 30000,
      maxBuffer: 1024 * 1024
    }
  );

  return runAiCompanyOsStatus();
}

function getSystemMetrics() {
  const totalMem = os.totalmem();
  const freeMem = os.freemem();
  const usedMem = totalMem - freeMem;
  const ramPercent = totalMem > 0 ? Number(((usedMem / totalMem) * 100).toFixed(1)) : 0;

  return {
    cpu: {
      used_percent: getCpuUsagePercent(),
      load_1m: Number(os.loadavg()[0].toFixed(2)),
      cores: os.cpus().length
    },
    ram: {
      used_percent: ramPercent,
      total_human: formatBytes(totalMem),
      used_human: formatBytes(usedMem),
      free_human: formatBytes(freeMem)
    },
    disk: getDiskUsage(),
    uptime: {
      seconds: Math.floor(os.uptime()),
      human: formatUptime(os.uptime())
    },
    timestamp: new Date().toISOString()
  };
}

function getLatestEvents() {
  const text = runSql(`
    SELECT id, event_type, COALESCE(agent_key,''), COALESCE(state,''), COALESCE(topic,''), created_at
    FROM events
    ORDER BY id DESC
    LIMIT 20;
  `);

  return parseRows(text, ["id", "event_type", "agent", "state", "topic", "created_at"]);
}

function getAgentRuntimeStatus() {
  const text = runSql(`
    SELECT
      agent_key,
      runtime_status,
      COALESCE(current_task_key, '') AS current_task_key,
      COALESCE(location, '') AS location,
      COALESCE(status_note, '') AS status_note,
      updated_at
    FROM agent_runtime_status
    ORDER BY agent_key ASC;
  `);

  return parseRows(text, [
    "agent_key",
    "runtime_status",
    "current_task_key",
    "location",
    "status_note",
    "updated_at"
  ]).map((agent) => {
    const status = String(agent.runtime_status || "").toLowerCase();
    const taskKey = String(agent.current_task_key || "");
    const completedStates = new Set(["done", "completed", "idle", "failed"]);

    if (completedStates.has(status)) {
      return {
        ...agent,
        current_task_key: "",
        stale_current_task_cleared: Boolean(taskKey)
      };
    }

    return agent;
  });
}


function sqlText(value) {
  return Buffer.from(String(value || ""), "utf8").toString("base64");
}

function sqlFromBase64(base64Value) {
  return `convert_from(decode('${base64Value}', 'base64'), 'UTF8')`;
}

function readRequestBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk.toString();
      if (body.length > 1024 * 1024) {
        reject(new Error("Request body too large"));
      }
    });
    req.on("end", () => resolve(body));
    req.on("error", reject);
  });
}

async function readJson(req) {
  const body = await readRequestBody(req);
  if (!body.trim()) return {};
  return JSON.parse(body);
}

function getOwnerCommands() {
  const text = runSql(`
    SELECT id, source, status, command_text, created_at
    FROM owner_commands
    ORDER BY id DESC
    LIMIT 20;
  `);

  return parseRows(text, ["id", "source", "status", "command_text", "created_at"]);
}

function createOwnerCommand(commandText, source = "dashboard") {
  const commandTextSql = sqlFromBase64(sqlText(commandText));
  const sourceSql = sqlFromBase64(sqlText(source));

  const inserted = runSql(`
    INSERT INTO owner_commands (source, command_text, status)
    VALUES (${sourceSql}, ${commandTextSql}, 'NEW')
    RETURNING id, source, status, command_text, created_at;
  `);

  runSql(`
    INSERT INTO events (
      project_id,
      task_id,
      agent_key,
      event_type,
      state,
      location,
      topic,
      summary
    )
    VALUES (
      (SELECT id FROM projects WHERE project_key = 'internal-ai-company-os' LIMIT 1),
      NULL,
      'pm_agent',
      'owner_command_created',
      'NEW',
      'owner_dashboard',
      'Owner command submitted',
      ${commandTextSql}
    );
  `);

  return parseRows(inserted, ["id", "source", "status", "command_text", "created_at"])[0];
}


function safeProjectKey(value) {
  const text = String(value || "").trim();
  if (!/^[a-z0-9][a-z0-9-]*$/.test(text)) {
    throw new Error("Invalid project_key. Use lowercase letters, numbers, and dashes only.");
  }
  return text;
}

function safeFilename(value) {
  const raw = String(value || "upload.bin").trim();
  const base = path.basename(raw).replace(/[^a-zA-Z0-9._-]/g, "_");
  return base || "upload.bin";
}

function getProjectUploads(projectKey) {
  const safeKey = safeProjectKey(projectKey);
  const safeKeySql = sqlFromBase64(sqlText(safeKey));

  const text = runSql(`
    SELECT id, project_key, original_filename, stored_filename, relative_path, mime_type, size_bytes, created_at
    FROM project_uploads
    WHERE project_key = ${safeKeySql}
    ORDER BY id DESC
    LIMIT 50;
  `);

  return parseRows(text, [
    "id",
    "project_key",
    "original_filename",
    "stored_filename",
    "relative_path",
    "mime_type",
    "size_bytes",
    "created_at"
  ]);
}

function saveProjectUpload(payload) {
  const projectKey = safeProjectKey(payload.project_key);
  const originalFilename = safeFilename(payload.filename);
  const mimeType = String(payload.mime_type || "");
  const contentBase64 = String(payload.content_base64 || "");

  if (!contentBase64) {
    throw new Error("content_base64 is required");
  }

  const projectId = runSql(`
    SELECT id
    FROM projects
    WHERE project_key = ${sqlFromBase64(sqlText(projectKey))}
    LIMIT 1;
  `).trim();

  if (!projectId) {
    throw new Error(`Project not found: ${projectKey}`);
  }

  const uploadRoot = path.join(__dirname, "..", "..", "projects", "clients", projectKey, "uploads");
  fs.mkdirSync(uploadRoot, { recursive: true });

  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const storedFilename = `${timestamp}-${originalFilename}`;
  const absolutePath = path.join(uploadRoot, storedFilename);

  const buffer = Buffer.from(contentBase64, "base64");
  fs.writeFileSync(absolutePath, buffer);

  const relativePath = path.join("projects", "clients", projectKey, "uploads", storedFilename);

  const inserted = runSql(`
    INSERT INTO project_uploads (
      project_id,
      project_key,
      original_filename,
      stored_filename,
      relative_path,
      mime_type,
      size_bytes,
      source
    )
    VALUES (
      ${Number(projectId)},
      ${sqlFromBase64(sqlText(projectKey))},
      ${sqlFromBase64(sqlText(originalFilename))},
      ${sqlFromBase64(sqlText(storedFilename))},
      ${sqlFromBase64(sqlText(relativePath))},
      ${sqlFromBase64(sqlText(mimeType))},
      ${buffer.length},
      'dashboard'
    )
    RETURNING id, project_key, original_filename, stored_filename, relative_path, mime_type, size_bytes, created_at;
  `);

  runSql(`
    INSERT INTO events (
      project_id,
      task_id,
      agent_key,
      event_type,
      state,
      location,
      topic,
      summary
    )
    VALUES (
      ${Number(projectId)},
      NULL,
      'pm_agent',
      'project_file_uploaded',
      'NEW',
      'owner_dashboard',
      ${sqlFromBase64(sqlText("Project file uploaded"))},
      ${sqlFromBase64(sqlText(`Uploaded ${originalFilename} to ${projectKey}`))}
    );
  `);

  return parseRows(inserted, [
    "id",
    "project_key",
    "original_filename",
    "stored_filename",
    "relative_path",
    "mime_type",
    "size_bytes",
    "created_at"
  ])[0];
}


function convertOwnerCommandToProject(payload) {
  const commandId = String(payload.command_id || "").trim();
  const projectKey = safeProjectKey(payload.project_key);
  const projectTitle = String(payload.project_title || "").trim();

  if (!/^[0-9]+$/.test(commandId)) {
    throw new Error("command_id must be numeric");
  }

  if (!projectTitle) {
    throw new Error("project_title is required");
  }

  const rootDir = path.join(__dirname, "..", "..");
  const runnerPath = path.join(rootDir, "runners", "convert_owner_command_to_project.sh");

  const output = execFileSync(
    runnerPath,
    [commandId, projectKey, projectTitle],
    {
      cwd: rootDir,
      encoding: "utf8",
      timeout: 120000,
      maxBuffer: 1024 * 1024
    }
  );

  return {
    ok: true,
    command_id: commandId,
    project_key: projectKey,
    project_title: projectTitle,
    output
  };
}


function attachUploadsToPmContext(payload) {
  const projectKey = safeProjectKey(payload.project_key);
  const taskKey = String(payload.task_key || "").trim();

  if (!/^[A-Z0-9-]+$/.test(taskKey)) {
    throw new Error("task_key must use uppercase letters, numbers, and dashes only");
  }

  const rootDir = path.join(__dirname, "..", "..");
  const runnerPath = path.join(rootDir, "runners", "attach_uploads_to_pm_context.sh");

  const output = execFileSync(
    runnerPath,
    [projectKey, taskKey],
    {
      cwd: rootDir,
      encoding: "utf8",
      timeout: 120000,
      maxBuffer: 1024 * 1024
    }
  );

  return {
    ok: true,
    project_key: projectKey,
    task_key: taskKey,
    output
  };
}

function writeSse(res, eventName, data) {
  res.write(`event: ${eventName}\n`);
  res.write(`data: ${JSON.stringify(data)}\n\n`);
}

const server = http.createServer(async (req, res) => {
  try {
    const requestUrl = new URL(req.url, `http://${req.headers.host || "localhost"}`);
    const pathname = requestUrl.pathname;

    
    
    



    if (pathname === "/api/codex/usage" && req.method === "GET") {
      json(res, getCodexUsageDashboardSummary());
      return;
    }

    if (pathname === "/api/ai/usage" && req.method === "GET") {
      json(res, getAiUsageSummary());
      return;
    }

    if (pathname === "/api/ai-company-os/status" && req.method === "GET") {
      json(res, runAiCompanyOsStatus());
      return;
    }

    if (pathname === "/api/learning/summary" && req.method === "GET") {
      json(res, getLearningDashboardSummary());
      return;
    }

    if (pathname === "/api/ai-company-os/control" && req.method === "POST") {
      const payload = await readJson(req);
      json(res, setAiCompanyOsPower(payload.action));
      return;
    }

    if (pathname === "/api/system/metrics" && req.method === "GET") {
      json(res, getSystemMetrics());
      return;
    }

    if (pathname === "/api/workflow/action" && req.method === "POST") {
      const payload = await readJson(req);
      const action = String(payload.action || "").trim();

      function safeWorkflowTaskKey(value, fieldName = "task_key") {
        const text = String(value || "").trim();
        if (!/^[A-Z0-9-]+$/.test(text)) {
          throw new Error(`Invalid ${fieldName}. Use uppercase letters, numbers, and dashes only.`);
        }
        return text;
      }

      function runWorkflowScript(scriptName, args) {
        const rootDir = path.join(__dirname, "..", "..");
        const scriptPath = path.join(rootDir, "runners", scriptName);

        if (!fs.existsSync(scriptPath)) {
          throw new Error(`Runner not found: ${scriptName}`);
        }

        return execFileSync(
          scriptPath,
          args,
          {
            encoding: "utf8",
            cwd: rootDir,
            env: {
              ...process.env,
              AI_COMPANY_ALLOW_AFTER_HOURS: "1"
            }
          }
        );
      }

      let output = "";

      if (action === "pm_analysis") {
        output = runWorkflowScript("pm_intake_processor.sh", [
          safeProjectKey(payload.project_key),
          safeWorkflowTaskKey(payload.task_key)
        ]);
      } else if (action === "generate_tasks") {
        output = runWorkflowScript("generate_tasks_from_pm_analysis.sh", [
          safeProjectKey(payload.project_key),
          safeWorkflowTaskKey(payload.task_key)
        ]);
      } else if (action === "engineer_impl") {
        output = runWorkflowScript("engineer_implementation_runner.sh", [
          safeProjectKey(payload.project_key),
          safeWorkflowTaskKey(payload.task_key)
        ]);
      } else if (action === "qa_verify") {
        output = runWorkflowScript("qa_verification_runner.sh", [
          safeProjectKey(payload.project_key),
          safeWorkflowTaskKey(payload.task_key)
        ]);
      } else if (action === "submit_review") {
        output = runWorkflowScript("submit_project_to_owner_review.sh", [
          safeProjectKey(payload.project_key),
          safeWorkflowTaskKey(payload.task_key, "qa_task_key")
        ]);
      } else if (action === "owner_decision") {
        const decision = String(payload.decision || "").trim().toUpperCase();
        if (!["ACCEPT", "REVISE", "REJECT"].includes(decision)) {
          throw new Error("Decision must be ACCEPT, REVISE, or REJECT.");
        }

        output = runWorkflowScript("owner_review_decision.sh", [
          safeWorkflowTaskKey(payload.review_task_key, "review_task_key"),
          decision,
          String(payload.note || "")
        ]);
      } else if (action === "finalize") {
        output = runWorkflowScript("finalize_accepted_project.sh", [
          safeProjectKey(payload.project_key),
          safeWorkflowTaskKey(payload.review_task_key, "review_task_key")
        ]);
      } else {
        throw new Error(`Unknown workflow action: ${action}`);
      }

      json(res, {
        ok: true,
        action,
        output
      });
      return;
    }

    if (pathname === "/api/uploads/attach-context" && req.method === "POST") {
      const body = await readJson(req);
      const result = attachUploadsToPmContext(body);
      return json(res, result, 201);
    }

if (pathname === "/api/uploads" && req.method === "GET") {
      const projectKey = requestUrl.searchParams.get("project_key") || "";
      return json(res, getProjectUploads(projectKey));
    }

    if (pathname === "/api/uploads" && req.method === "POST") {
      const body = await readJson(req);
      const upload = saveProjectUpload(body);
      return json(res, upload, 201);
    }


    if (pathname === "/api/owner/commands/convert" && req.method === "POST") {
      const body = await readJson(req);
      const result = convertOwnerCommandToProject(body);
      return json(res, result, 201);
    }

if (pathname === "/api/owner/commands" && req.method === "GET") {
      return json(res, getOwnerCommands());
    }

    
    
    if (pathname === "/api/uploads/attach-context" && req.method === "POST") {
      const body = await readJson(req);
      const result = attachUploadsToPmContext(body);
      return json(res, result, 201);
    }

if (pathname === "/api/uploads" && req.method === "GET") {
      const projectKey = requestUrl.searchParams.get("project_key") || "";
      return json(res, getProjectUploads(projectKey));
    }

    if (pathname === "/api/uploads" && req.method === "POST") {
      const body = await readJson(req);
      const upload = saveProjectUpload(body);
      return json(res, upload, 201);
    }

if (pathname === "/api/owner/commands" && req.method === "POST") {
      const body = await readJson(req);
      const commandText = String(body.command_text || "").trim();

      if (!commandText) {
        return json(res, { error: "command_text is required" }, 400);
      }

      const command = createOwnerCommand(commandText, "dashboard");
      return json(res, command, 201);
    }

if (pathname === "/api/summary") {
      const text = runSql(`
        SELECT
          COUNT(*) FILTER (WHERE task_key NOT LIKE 'INTERNAL-%' AND task_key NOT LIKE 'AUTO-%') AS client_tasks,
          COUNT(*) FILTER (WHERE task_key LIKE 'INTERNAL-%') AS internal_tasks,
          COUNT(*) FILTER (WHERE task_key LIKE 'AUTO-%') AS autonomous_tasks,
          COUNT(*) FILTER (WHERE status = 'WAITING_OWNER_ACCEPTANCE') AS waiting_owner,
          COUNT(*) FILTER (WHERE status = 'ACCEPTED') AS accepted,
          COUNT(*) FILTER (WHERE status IN ('QA_FAILED','NEEDS_REVISION','BLOCKED')) AS needs_attention
        FROM tasks;
      `);

      const [client_tasks, internal_tasks, autonomous_tasks, waiting_owner, accepted, needs_attention] =
        text.split("|").map((value) => Number(value || 0));

      return json(res, {
        client_tasks,
        internal_tasks,
        autonomous_tasks,
        waiting_owner,
        accepted,
        needs_attention,
        generated_at: new Date().toISOString()
      });
    }

    if (pathname === "/api/tasks") {
      const text = runSql(`
        SELECT
          task_key,
          title,
          status,
          COALESCE(assigned_agent_key, ''),
          CASE
            WHEN task_key LIKE 'INTERNAL-%' THEN 'internal'
            WHEN task_key LIKE 'AUTO-%' THEN 'autonomous'
            ELSE 'client'
          END AS task_category,
          updated_at
        FROM tasks
        ORDER BY updated_at DESC, id DESC
        LIMIT 20;
      `);

      return json(res, parseRows(text, ["task_key", "title", "status", "agent", "task_category", "updated_at"]));
    }

    if (pathname === "/api/events") {
      return json(res, getLatestEvents());
    }

    if (pathname === "/api/agents/runtime") {
      return json(res, getAgentRuntimeStatus());
    }

    if (pathname === "/api/events/live") {
      res.writeHead(200, {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        "Access-Control-Allow-Origin": "*"
      });

      writeSse(res, "connected", { ok: true, time: new Date().toISOString() });

      let lastPayload = "";
      const timer = setInterval(() => {
        try {
          const events = getLatestEvents();
          const payload = JSON.stringify(events);

          if (payload !== lastPayload) {
            lastPayload = payload;
            writeSse(res, "events", events);
          } else {
            writeSse(res, "heartbeat", { time: new Date().toISOString() });
          }
        } catch (error) {
          writeSse(res, "error", { message: error.message });
        }
      }, 3000);

      req.on("close", () => {
        clearInterval(timer);
      });

      return;
    }


    // INTERNAL-055: owner review accept finalize endpoint
    if (pathname === "/api/owner/review/accept-finalize" && req.method === "POST") {
      const rawBody = await new Promise((resolve, reject) => {
        let data = "";

        req.on("data", chunk => {
          data += chunk;
          if (data.length > 1024 * 1024) {
            reject(new Error("Request body too large"));
            req.destroy();
          }
        });

        req.on("end", () => resolve(data));
        req.on("error", reject);
      });

      let body = {};
      try {
        body = rawBody ? JSON.parse(rawBody) : {};
      } catch (error) {
        return json(res, { ok: false, error: "Invalid JSON body" }, 400);
      }

      const reviewTaskKey = body.review_task_key || body.task_key;
      const ownerNote = body.owner_note || "Owner accepted delivery from dashboard.";

      if (!reviewTaskKey) {
        return json(res, { ok: false, error: "Missing review_task_key" }, 400);
      }

      const childProcess = require("child_process");

      childProcess.execFile(
        "/bin/bash",
        [
          "-lc",
          "./runners/owner_accept_and_finalize.sh \"$1\" \"$2\"",
          "owner_accept_and_finalize",
          String(reviewTaskKey),
          String(ownerNote)
        ],
        {
          cwd: process.cwd(),
          timeout: 180000,
          maxBuffer: 1024 * 1024
        },
        (error, stdout, stderr) => {
          if (error) {
            return json(res, {
              ok: false,
              error: error.message,
              stdout,
              stderr
            }, 500);
          }

          return json(res, {
            ok: true,
            review_task_key: reviewTaskKey,
            stdout,
            stderr
          });
        }
      );

      return;
    }

    const safePathname = pathname === "/" ? "/index.html" : pathname;
    const filePath = path.join(PUBLIC_DIR, safePathname);
    serveStatic(res, filePath);
  } catch (error) {
    json(res, { error: error.message }, 500);
  }
});

server.listen(PORT, HOST, () => {
  console.log(`AI Company Dashboard running on http://${HOST}:${PORT}`);
});
