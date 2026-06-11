const http = require("http");
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const PORT = process.env.PORT || 8787;
const HOST = process.env.HOST || "127.0.0.1";
const PUBLIC_DIR = path.join(__dirname, "public");

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
  ]);
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
          COUNT(*) FILTER (WHERE task_key NOT LIKE 'INTERNAL-%') AS client_tasks,
          COUNT(*) FILTER (WHERE task_key LIKE 'INTERNAL-%') AS internal_tasks,
          COUNT(*) FILTER (WHERE status = 'WAITING_OWNER_ACCEPTANCE') AS waiting_owner,
          COUNT(*) FILTER (WHERE status = 'ACCEPTED') AS accepted,
          COUNT(*) FILTER (WHERE status IN ('QA_FAILED','NEEDS_REVISION','BLOCKED')) AS needs_attention
        FROM tasks;
      `);

      const [client_tasks, internal_tasks, waiting_owner, accepted, needs_attention] =
        text.split("|").map((value) => Number(value || 0));

      return json(res, {
        client_tasks,
        internal_tasks,
        waiting_owner,
        accepted,
        needs_attention
      });
    }

    if (pathname === "/api/tasks") {
      const text = runSql(`
        SELECT task_key, title, status, COALESCE(assigned_agent_key, '')
        FROM tasks
        ORDER BY id DESC
        LIMIT 20;
      `);

      return json(res, parseRows(text, ["task_key", "title", "status", "agent"]));
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
