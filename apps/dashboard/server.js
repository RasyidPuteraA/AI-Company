const http = require("http");
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const PORT = process.env.PORT || 8787;
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

function json(res, data) {
  res.writeHead(200, { "Content-Type": "application/json" });
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
  return text.split("\n").filter(Boolean).map(line => {
    const values = line.split("|");
    const row = {};
    columns.forEach((col, index) => {
      row[col] = values[index] || "";
    });
    return row;
  });
}

const server = http.createServer((req, res) => {
  try {
    if (req.url === "/api/summary") {
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
        text.split("|").map(v => Number(v || 0));

      return json(res, {
        client_tasks,
        internal_tasks,
        waiting_owner,
        accepted,
        needs_attention
      });
    }

    if (req.url === "/api/tasks") {
      const text = runSql(`
        SELECT task_key, title, status, COALESCE(assigned_agent_key, '')
        FROM tasks
        ORDER BY id DESC
        LIMIT 20;
      `);

      return json(res, parseRows(text, ["task_key", "title", "status", "agent"]));
    }

    if (req.url === "/api/events") {
      const text = runSql(`
        SELECT event_type, COALESCE(agent_key,''), COALESCE(state,''), COALESCE(topic,''), created_at
        FROM events
        ORDER BY id DESC
        LIMIT 20;
      `);

      return json(res, parseRows(text, ["event_type", "agent", "state", "topic", "created_at"]));
    }

    const file = req.url === "/"
      ? path.join(PUBLIC_DIR, "index.html")
      : path.join(PUBLIC_DIR, req.url);

    serveStatic(res, file);
  } catch (error) {
    res.writeHead(500, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: error.message }, null, 2));
  }
});

const HOST = process.env.HOST || "127.0.0.1";

server.listen(PORT, HOST, () => {
  console.log(`AI Company Dashboard running on http://${HOST}:${PORT}`);
});
