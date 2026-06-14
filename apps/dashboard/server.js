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
const CODEX_LIMIT_STATUS_RUNNER = path.join(ROOT_DIR, "runners", "codex_limit_status.sh");
const CODEX_BUDGET_GATE_RUNNER = path.join(ROOT_DIR, "runners", "ai_company_budget_gate.sh");
const LEARNING_CONFIG_FILE = path.join(ROOT_DIR, "company", "config", "ai_company_scheduler.env");
const LEARNING_LESSONS_DIR = path.join(ROOT_DIR, "company", "learning", "lessons");
const LEARNING_PATTERNS_DIR = path.join(ROOT_DIR, "company", "learning", "patterns");
const LEARNING_CONTEXT_FILE = path.join(ROOT_DIR, "company", "learning", "context", "latest-learning-context.md");
const LEARNING_REPORTS_DIR = path.join(ROOT_DIR, "company", "reports", "learning");
const POST_UPDATE_REPORTS_DIR = path.join(ROOT_DIR, "company", "reports", "post-update");
const STALE_TASK_REPORTS_DIR = path.join(ROOT_DIR, "company", "reports", "stale-task-recovery");
const AI_COMPANY_OS_STATUS_RUNNER = path.join(ROOT_DIR, "runners", "ai_company_os_status.sh");
const AI_COMPANY_OS_CONTROL_RUNNER = path.join(ROOT_DIR, "runners", "ai_company_os_control.sh");

function positiveInteger(value, fallback) {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

const DB_EXEC_TIMEOUT_MS = positiveInteger(process.env.AI_COMPANY_DASHBOARD_DB_TIMEOUT_MS, 5000);

function dashboardDbError(error) {
  const timedOut = error && (
    error.signal === "SIGTERM"
    || error.code === "ETIMEDOUT"
    || /timed out/i.test(String(error.message || ""))
  );
  const publicError = new Error(timedOut ? "Dashboard database query timed out" : "Dashboard database query failed");
  publicError.code = timedOut ? "DASHBOARD_DB_TIMEOUT" : "DASHBOARD_DB_ERROR";
  return publicError;
}

function runSql(sql) {
  let output = "";

  try {
    output = execFileSync(
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
      {
        encoding: "utf8",
        timeout: DB_EXEC_TIMEOUT_MS,
        maxBuffer: 1024 * 1024
      }
    );
  } catch (error) {
    throw dashboardDbError(error);
  }

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

function parseKeyValueOutput(text) {
  const result = {};
  String(text || "").split(/\r?\n/).forEach((line) => {
    if (!line || !line.includes("=")) return;
    const index = line.indexOf("=");
    result[line.slice(0, index)] = line.slice(index + 1);
  });
  return result;
}

function runKeyValueRunner(runnerPath) {
  try {
    const output = execFileSync(runnerPath, {
      cwd: ROOT_DIR,
      encoding: "utf8",
      timeout: 30000,
      maxBuffer: 1024 * 1024
    });
    return parseKeyValueOutput(output);
  } catch (error) {
    const output = error.stdout || error.stderr || "";
    return parseKeyValueOutput(output);
  }
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
  const realLimit = runKeyValueRunner(CODEX_LIMIT_STATUS_RUNNER);
  const budgetGate = runKeyValueRunner(CODEX_BUDGET_GATE_RUNNER);

  const now = new Date();
  const dailySoft = Number(config.CODEX_DAILY_SOFT_LIMIT_TOKENS || 300000);
  const dailyHard = Number(config.CODEX_DAILY_HARD_LIMIT_TOKENS || 500000);
  const weeklySoft = Number(config.CODEX_WEEKLY_SOFT_LIMIT_TOKENS || 2000000);
  const monthlySoft = Number(config.CODEX_MONTHLY_SOFT_LIMIT_TOKENS || 8000000);
  const enforcement = String(config.CODEX_INTERNAL_BUDGET_ENFORCEMENT || "warn");

  const todayUsed = tokensSince(items, startOfToday(now));
  const weekUsed = tokensSince(items, startOfWeek(now));
  const monthUsed = tokensSince(items, startOfMonth(now));

  const dailyState = todayUsed >= dailyHard ? "STOP" : todayUsed >= dailySoft ? "WARN" : "OK";
  const weeklyState = weekUsed >= weeklySoft ? "WARN" : "OK";
  const monthlyState = monthUsed >= monthlySoft ? "WARN" : "OK";
  const internalState = enforcement === "off"
    ? "OK"
    : enforcement === "warn" && dailyState === "STOP"
      ? "WARN"
      : dailyState;

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
    note: "Internal token estimate is not official Codex quota. Real limit values come from Codex CLI /status snapshot or owner-provided usage dashboard data.",
    estimates: true,
    is_estimate: true,
    limit_tokens: dailyHard,
    internal_soft_estimate_tokens: dailyHard,
    week_total_tokens: weekUsed,
    month_total_tokens: monthUsed,
    wrapper_total_tokens: wrapperTotal,
    danger_logged_total_tokens: dangerLoggedTotal,
    total_estimated_tokens: totalEstimated,
    status: budgetGate.BUDGET_STATE || internalState,
    budget_gate_state: budgetGate.BUDGET_STATE || internalState,
    internal_budget_state: budgetGate.BUDGET_INTERNAL_STATE || internalState,
    real_codex_limit_state: budgetGate.BUDGET_REAL_LIMIT_STATE || realLimit.recommended_state || "WARN",
    internal_budget_enforcement: budgetGate.BUDGET_ENFORCEMENT || enforcement,
    source: {
      ledger_exists: fs.existsSync(CODEX_LEDGER_FILE),
      budget_file_exists: fs.existsSync(CODEX_BUDGET_FILE),
      ledger_path: path.relative(ROOT_DIR, CODEX_LEDGER_FILE)
    },
    real_limit: {
      source: realLimit.source || "",
      observed_at: realLimit.observed_at || "",
      stale: realLimit.stale || "yes",
      recommended_state: realLimit.recommended_state || "WARN",
      five_hour_left_percent: realLimit.five_hour_left_percent || "",
      five_hour_reset_at: realLimit.five_hour_reset_at || "",
      weekly_left_percent: realLimit.weekly_left_percent || "",
      weekly_reset_at: realLimit.weekly_reset_at || "",
      note: realLimit.note || "Codex limit snapshot unavailable."
    },
    budget: {
      today: {
        used_tokens: todayUsed,
        soft_limit_tokens: dailySoft,
        hard_limit_tokens: dailyHard,
        state: internalState,
        raw_state: dailyState,
        enforcement
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
    note: "AI Company OS tracks Codex CLI usage through an internal ledger. Real Codex limits come from owner-provided Codex CLI /status snapshots."
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

function readReportStatus(text) {
  return readDashField(text, "status") || readDashField(text, "mode") || "";
}

function getPostUpdateDashboardSummary() {
  const reports = listMarkdownFiles(POST_UPDATE_REPORTS_DIR);
  if (reports.length === 0) {
    return {
      latest_report: "",
      latest_status: "none",
      latest_title: "",
      generated_at: ""
    };
  }

  const latest = reports[0];
  const text = fs.readFileSync(latest, "utf8");
  const title = (text.match(/^# (.+)$/m) || [])[1] || path.basename(latest);

  return {
    latest_report: path.relative(ROOT_DIR, latest),
    latest_status: readReportStatus(text) || "unknown",
    latest_title: title,
    generated_at: readDashField(text, "generated_at")
  };
}

function getStaleTaskRecoverySummary() {
  const reports = listMarkdownFiles(STALE_TASK_REPORTS_DIR);
  const config = readEnvConfig(LEARNING_CONFIG_FILE);
  const thresholdHoursRaw = Number(config.AI_COMPANY_STALE_TASK_AGE_HOURS || 24);
  const thresholdHours = Number.isInteger(thresholdHoursRaw) && thresholdHoursRaw > 0 ? thresholdHoursRaw : 24;
  const text = runSql(`
    SELECT
      COUNT(*) FILTER (
        WHERE status = 'IN_PROGRESS'
          AND updated_at < now() - interval '${thresholdHours} hours'
      ) AS stale_total,
      COUNT(*) FILTER (
        WHERE status = 'IN_PROGRESS'
          AND task_key LIKE 'INTERNAL-%'
          AND updated_at < now() - interval '${thresholdHours} hours'
      ) AS stale_internal,
      COUNT(*) FILTER (
        WHERE status = 'IN_PROGRESS'
          AND task_key LIKE 'AUTO-%'
          AND updated_at < now() - interval '${thresholdHours} hours'
      ) AS stale_auto,
      COUNT(*) FILTER (
        WHERE status = 'IN_PROGRESS'
          AND task_key NOT LIKE 'INTERNAL-%'
          AND task_key NOT LIKE 'AUTO-%'
          AND updated_at < now() - interval '${thresholdHours} hours'
      ) AS stale_client
    FROM tasks;
  `);

  const [stale_total, stale_internal, stale_auto, stale_client] =
    text.split("|").map((value) => Number(value || 0));

  return {
    stale_total,
    stale_internal,
    stale_auto,
    stale_client,
    threshold_hours: thresholdHours,
    latest_report: reports.length > 0 ? path.relative(ROOT_DIR, reports[0]) : "",
    generated_at: new Date().toISOString()
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

function safeTaskKey(value, fieldName = "task_key") {
  const text = String(value || "").trim();
  if (!/^[A-Z0-9-]+$/.test(text)) {
    throw new Error(`Invalid ${fieldName}. Use uppercase letters, numbers, and dashes only.`);
  }
  return text;
}

function redactOwnerText(value) {
  return String(value || "")
    .replace(/(OPENAI_API_KEY|ANTHROPIC_API_KEY|CODEX_[A-Z0-9_]*TOKEN|GITHUB_TOKEN|AUTH_TOKEN|PASSWORD|SECRET)\s*=\s*[^\s]+/gi, "$1=[redacted]")
    .replace(/(sk-[A-Za-z0-9_-]{12,})/g, "[redacted-api-key]")
    .replace(/(ghp_[A-Za-z0-9_]{12,})/g, "[redacted-github-token]");
}

function ownerActionRecommendation(status, taskKey) {
  if (status === "WAITING_OWNER_ACCEPTANCE") {
    return taskKey.includes("REVIEW")
      ? "Review the delivered project. Accept finalizes the project, Reject closes the review as rejected, or Request Revision sends it back for changes."
      : "Review the completed task. Accept marks it accepted, Reject or Request Revision sends it back with your note.";
  }

  if (status === "NEEDS_REVISION") {
    return "Owner or QA requested changes. Add a revision note if the current guidance is incomplete.";
  }

  if (status === "QA_FAILED") {
    return "QA failed. Decide whether to request a targeted revision or reject the current delivery path.";
  }

  if (status === "BLOCKED") {
    return "The agent is blocked. Provide an owner decision, missing context, or reject the blocked path.";
  }

  return "Review the request and choose Accept, Reject, or Request Revision.";
}

function getOwnerAttention() {
  const raw = runSql(`
    SELECT COALESCE(json_agg(row_to_json(attention))::text, '[]')
    FROM (
      SELECT
        t.task_key,
        t.title,
        t.status,
        COALESCE(t.assigned_agent_key, '') AS agent_key,
        COALESCE(p.project_key, '') AS project_key,
        COALESCE(p.name, '') AS project_name,
        COALESCE(t.current_phase, p.phase, '') AS current_phase,
        COALESCE(t.priority, '') AS priority,
        COALESCE(t.handover_note, '') AS handover_note,
        COALESCE(latest.event_text, '') AS latest_event,
        COALESCE(latest.context_summary, '') AS context_summary,
        t.created_at::text AS created_at,
        t.updated_at::text AS updated_at
      FROM tasks t
      LEFT JOIN projects p ON p.id = t.project_id
      LEFT JOIN LATERAL (
        SELECT
          concat_ws(' · ', e.event_type, e.state, e.topic) AS event_text,
          COALESCE(e.summary, '') AS context_summary
        FROM events e
        WHERE e.task_id = t.id
          OR (e.task_id IS NULL AND e.project_id = t.project_id)
        ORDER BY e.created_at DESC, e.id DESC
        LIMIT 1
      ) latest ON true
      WHERE
        t.status IN ('WAITING_OWNER_ACCEPTANCE', 'NEEDS_REVISION', 'BLOCKED', 'QA_FAILED')
        OR EXISTS (
          SELECT 1
          FROM approvals a
          WHERE a.task_id = t.id
            AND a.status = 'PENDING'
        )
        OR (
          t.task_key LIKE 'AUTO-%'
          AND EXISTS (
            SELECT 1
            FROM events e
            WHERE e.task_id = t.id
              AND (
                e.state ILIKE '%FAIL%'
                OR e.event_type ILIKE '%fail%'
                OR e.event_type ILIKE '%blocked%'
              )
              AND e.created_at > now() - interval '48 hours'
          )
        )
      ORDER BY
        CASE t.status
          WHEN 'WAITING_OWNER_ACCEPTANCE' THEN 0
          WHEN 'BLOCKED' THEN 1
          WHEN 'QA_FAILED' THEN 2
          WHEN 'NEEDS_REVISION' THEN 3
          ELSE 4
        END,
        CASE t.priority
          WHEN 'HIGH' THEN 0
          WHEN 'MEDIUM' THEN 1
          WHEN 'LOW' THEN 2
          ELSE 3
        END,
        t.updated_at DESC,
        t.id DESC
      LIMIT 30
    ) attention;
  `);

  const parsed = JSON.parse(raw || "[]");
  return {
    items: parsed.map((item) => ({
      task_key: item.task_key,
      title: redactOwnerText(item.title),
      status: item.status,
      agent_key: item.agent_key,
      project_key: item.project_key,
      project_name: redactOwnerText(item.project_name),
      current_phase: item.current_phase,
      priority: item.priority,
      handover_note: redactOwnerText(item.handover_note),
      latest_event: redactOwnerText(item.latest_event),
      context_summary: redactOwnerText(item.context_summary),
      recommended_owner_action: ownerActionRecommendation(item.status, item.task_key),
      created_at: item.created_at,
      updated_at: item.updated_at
    })),
    generated_at: new Date().toISOString()
  };
}

function runOwnerRunner(scriptName, args, timeout = 180000) {
  const scriptPath = path.join(ROOT_DIR, "runners", scriptName);
  if (!fs.existsSync(scriptPath)) {
    throw new Error(`Runner not found: ${scriptName}`);
  }

  return execFileSync(scriptPath, args, {
    cwd: ROOT_DIR,
    encoding: "utf8",
    timeout,
    maxBuffer: 1024 * 1024
  });
}

function getOwnerDecisionTask(taskKey) {
  const taskKeySql = sqlFromBase64(sqlText(taskKey));
  const raw = runSql(`
    SELECT COALESCE(json_agg(row_to_json(task_row))::text, '[]')
    FROM (
      SELECT
        t.task_key,
        t.status,
        COALESCE(t.assigned_agent_key, '') AS agent_key,
        COALESCE(p.project_key, '') AS project_key
      FROM tasks t
      LEFT JOIN projects p ON p.id = t.project_id
      WHERE t.task_key = ${taskKeySql}
      LIMIT 1
    ) task_row;
  `);
  const rows = JSON.parse(raw || "[]");
  return rows[0] || null;
}

function applyOwnerDecision(payload) {
  const taskKey = safeTaskKey(payload.task_key);
  const decision = String(payload.decision || "").trim().toUpperCase();
  const message = String(payload.message || "").trim();

  if (!["ACCEPT", "REJECT", "REVISION"].includes(decision)) {
    return { ok: false, error: "decision must be ACCEPT, REJECT, or REVISION" };
  }

  if ((decision === "REVISION" || decision === "REJECT") && !message) {
    return { ok: false, error: `${decision} requires a non-empty message` };
  }

  if (message.length > 5000) {
    return { ok: false, error: "message must be 5000 characters or fewer" };
  }

  const task = getOwnerDecisionTask(taskKey);
  if (!task) {
    return { ok: false, error: `Task not found: ${taskKey}` };
  }

  const isReviewAcceptanceTask = task.status === "WAITING_OWNER_ACCEPTANCE" && taskKey.includes("REVIEW");
  const ownerNote = message || "Owner accepted from dashboard attention widget.";
  let output = "";
  let runner = "";

  if (decision === "ACCEPT") {
    if (isReviewAcceptanceTask) {
      runner = "owner_accept_and_finalize.sh";
      output = runOwnerRunner(runner, [taskKey, ownerNote]);
    } else {
      runner = "owner_review_task.sh";
      output = runOwnerRunner(runner, [taskKey, "ACCEPT", ownerNote]);
    }
  } else if (isReviewAcceptanceTask) {
    runner = "owner_review_decision.sh";
    output = runOwnerRunner(runner, [
      taskKey,
      decision === "REVISION" ? "REVISE" : "REJECT",
      message
    ]);
  } else {
    runner = "owner_review_task.sh";
    output = runOwnerRunner(runner, [
      taskKey,
      decision === "REVISION" ? "REVISION" : "REJECT",
      decision === "REJECT" ? `Owner rejected: ${message}` : message
    ]);
  }

  return {
    ok: true,
    task_key: taskKey,
    decision,
    runner,
    output: redactOwnerText(output)
  };
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

    if (pathname === "/api/post-update/summary" && req.method === "GET") {
      json(res, getPostUpdateDashboardSummary());
      return;
    }

    if (pathname === "/api/stale-task-recovery/summary" && req.method === "GET") {
      json(res, getStaleTaskRecoverySummary());
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
      try {
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
      } catch (error) {
        return json(res, {
          error: "dashboard_summary_unavailable",
          error_code: error.code || "DASHBOARD_SUMMARY_ERROR",
          error_note: error.message,
          generated_at: new Date().toISOString()
        }, 503);
      }
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

    if (pathname === "/api/owner/attention" && req.method === "GET") {
      return json(res, getOwnerAttention());
    }

    if (pathname === "/api/owner/decision" && req.method === "POST") {
      let body = {};
      try {
        body = await readJson(req);
      } catch (error) {
        return json(res, { ok: false, error: "Invalid JSON body" }, 400);
      }

      try {
        const result = applyOwnerDecision(body);
        return json(res, result, result.ok ? 200 : 400);
      } catch (error) {
        return json(res, {
          ok: false,
          error: error.message
        }, 500);
      }
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
