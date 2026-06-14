async function loadJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to load ${url}`);
  return res.json();
}

function card(label, value) {
  return `<div class="card"><span>${label}</span><strong>${value}</strong></div>`;
}

const summaryCardDefinitions = [
  ["client_tasks", "Client Tasks"],
  ["internal_tasks", "Internal Tasks"],
  ["autonomous_tasks", "Autonomous Tasks"],
  ["waiting_owner", "Waiting Owner"],
  ["accepted", "Accepted"],
  ["needs_attention", "Needs Attention"]
];

function formatUpdatedAt(date = new Date()) {
  return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
}

function setUpdated(id) {
  const el = document.getElementById(id);
  if (el) el.textContent = `Updated ${formatUpdatedAt()}`;
}

function renderTasks(tasks) {
  return tasks.map(task => `
    <div class="item">
      <strong>${task.task_key}</strong> — ${task.title}<br>
      <span class="badge">${task.status}</span>
      <span class="badge subtle">${task.task_category || "task"}</span>
      <span>${task.agent}</span>
      <br><small>${task.updated_at || ""}</small>
    </div>
  `).join("");
}

function renderEvents(events) {
  return events.map(event => `
    <div class="item">
      <strong>${event.event_type}</strong> · ${event.agent}<br>
      <span class="badge">${event.state}</span>
      <span>${event.topic}</span><br>
      <small>${event.created_at}</small>
    </div>
  `).join("");
}

async function loadSummaryCards() {
  const summary = await loadJson("/api/summary");
  const summaryCards = document.getElementById("summaryCards");

  if (!summaryCards.dataset.mounted) {
    summaryCards.innerHTML = summaryCardDefinitions.map(([key, label]) => `
      <div class="card" data-summary-card="${key}">
        <span>${label}</span>
        <strong data-summary-value="${key}">--</strong>
      </div>
    `).join("") + `
      <div class="card ai-usage-summary-card" id="aiUsageSummaryCard">
        <span>Codex Tokens</span>
        <strong>--</strong>
        <small>Internal estimates, not official OpenAI quota</small>
      </div>
    `;
    summaryCards.dataset.mounted = "true";
  }

  summaryCardDefinitions.forEach(([key]) => {
    const el = summaryCards.querySelector(`[data-summary-value="${key}"]`);
    if (el) el.textContent = summary[key] || 0;
  });

  setUpdated("summaryUpdatedAt");
}

async function loadLatestTasks() {
  const tasks = await loadJson("/api/tasks");
  document.getElementById("tasks").innerHTML = renderTasks(tasks);
  setUpdated("tasksUpdatedAt");
}

async function loadLatestEvents() {
  const events = await loadJson("/api/events");
  document.getElementById("events").innerHTML = renderEvents(events);
  setUpdated("eventsUpdatedAt");
}

async function refreshDashboardCore() {
  await Promise.all([
    loadSummaryCards(),
    loadLatestTasks(),
    loadLatestEvents()
  ]);
}

async function main() {
  await refreshDashboardCore();
}

main().catch(error => {
  document.body.innerHTML = `<pre>${error.stack}</pre>`;
});

function setText(id, value) {
  const el = document.getElementById(id);
  if (el) el.textContent = value || "--";
}

async function loadAiCompanyOsStatus() {
  const toggle = document.getElementById("aiCompanyOsToggle");
  if (!toggle) return;

  try {
    const status = await loadJson("/api/ai-company-os/status");
    const enabled = status.enabled === true;

    toggle.disabled = false;
    toggle.dataset.nextAction = enabled ? "off" : "on";
    toggle.textContent = enabled ? "Turn OFF" : "Turn ON";
    toggle.classList.toggle("is-on", enabled);

    setText("aiCompanyOsState", enabled ? "ON" : "OFF");
    setText("aiCompanyOsMode", status.mode);
    setText("aiCompanyOsAgent", status.active_agent || "none");
    setText("aiCompanyOsBudget", status.budget_state);
    const workHoursMode = status.work_hours_mode || "unknown";
    setText("aiCompanyOsWorkHours", `${status.work_hours_state || "unknown"} (${workHoursMode})`);
    setText("aiCompanyOsLatestEvent", status.latest_event || "No autonomous event yet.");
    setText("aiCompanyOsLatestReport", status.latest_discovery_report || "No discovery report yet.");
    setText("aiCompanyOsBudgetNote", status.budget_note || "Internal AI Company budget estimate, not official OpenAI remaining quota.");
    loadLearningSummary().catch(console.error);

    const scheduler = status.scheduler || {};
    const roles = Array.isArray(scheduler.roles) ? scheduler.roles : [];
    const locks = Array.isArray(scheduler.locks) ? scheduler.locks : [];
    const roleSummary = roles
      .map((role) => `${role.role}:${role.state}${role.task ? `/${role.task}` : ""}`)
      .join(" · ");
    const lockSummary = locks
      .map((lock) => `${lock.name}:${String(lock.state || "").split(":")[0]}`)
      .join(" · ");

    const schedulerWorkMode = scheduler.work_hours_mode || workHoursMode;
    setText("aiCompanySchedulerState", scheduler.state ? `${scheduler.state} (${scheduler.mode || "unknown"} / ${schedulerWorkMode})` : "unknown");
    setText("aiCompanySchedulerRoles", roleSummary || "none");
    setText("aiCompanySchedulerLocks", lockSummary || "none");
    loadPostUpdateSummary().catch(console.error);
    loadStaleTaskRecoverySummary().catch(console.error);
    setUpdated("aiCompanyOsUpdatedAt");
  } catch (error) {
    toggle.disabled = true;
    toggle.textContent = "Unavailable";
    setText("aiCompanyOsMode", "ERROR");
    console.error(error);
  }
}

async function loadPostUpdateSummary() {
  const summary = await loadJson("/api/post-update/summary");
  const status = summary.latest_status || "none";
  const report = summary.latest_report || "No post-update report yet.";
  setText("aiCompanyPostUpdateStatus", `${status} · ${report}`);
}

async function loadStaleTaskRecoverySummary() {
  const summary = await loadJson("/api/stale-task-recovery/summary");
  const total = summary.stale_total || 0;
  const parts = [
    `total ${total}`,
    `internal ${summary.stale_internal || 0}`,
    `auto ${summary.stale_auto || 0}`,
    `client ${summary.stale_client || 0}`
  ];
  const report = summary.latest_report || "No recovery report yet.";
  const threshold = summary.threshold_hours || 24;
  setText("aiCompanyStaleTaskRecovery", `${parts.join(" · ")} · threshold ${threshold}h · ${report}`);
}

async function loadLearningSummary() {
  const learning = await loadJson("/api/learning/summary");
  const enabled = learning.enabled ? "enabled" : "disabled";
  const topPattern = learning.top_pattern
    ? `${learning.top_pattern.title} (${learning.top_pattern.count})`
    : "no repeated pattern";
  setText("aiCompanyLearningSummary", `${enabled} · lessons ${learning.lessons_count || 0} · ${topPattern}`);
  setText("aiCompanyLearningContext", learning.latest_context_path || "No learning context generated yet.");
}

function setupAiCompanyOsToggle() {
  const toggle = document.getElementById("aiCompanyOsToggle");
  if (!toggle) return;

  toggle.addEventListener("click", async () => {
    const action = toggle.dataset.nextAction || "on";
    toggle.disabled = true;
    toggle.textContent = action === "on" ? "Turning ON" : "Turning OFF";

    try {
      const response = await fetch("/api/ai-company-os/control", {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ action })
      });

      if (!response.ok) {
        const body = await response.json().catch(() => ({}));
        throw new Error(body.error || `Control failed: ${response.status}`);
      }

      await loadAiCompanyOsStatus();
    } catch (error) {
      toggle.disabled = false;
      toggle.textContent = "Retry";
      console.error(error);
    }
  });
}

setupAiCompanyOsToggle();
loadAiCompanyOsStatus();
setInterval(loadAiCompanyOsStatus, 5000);


function setLiveStatus(text, state) {
  const el = document.getElementById("liveStatus");
  if (!el) return;
  el.textContent = text;
  el.classList.remove("connected", "disconnected");
  if (state) el.classList.add(state);
}

function startEventStream() {
  if (!window.EventSource) {
    setLiveStatus("no sse", "disconnected");
    return;
  }

  const source = new EventSource("/api/events/live");

  source.addEventListener("connected", () => {
    setLiveStatus("live", "connected");
  });

  source.addEventListener("events", event => {
    const events = JSON.parse(event.data);
    document.getElementById("events").innerHTML = renderEvents(events);
    setLiveStatus("live", "connected");
  });

  source.addEventListener("heartbeat", () => {
    setLiveStatus("live", "connected");
  });

  source.addEventListener("error", () => {
    setLiveStatus("reconnecting", "disconnected");
  });
}

startEventStream();
setInterval(loadSummaryCards, 5000);
setInterval(loadLatestTasks, 10000);
setInterval(loadLatestEvents, 10000);

const agentRoomMap = {
  pm_agent: "pm",
  engineer_agent: "engineer",
  qa_agent: "qa",
  devops_agent: "devops",
  budget_manager: "meeting"
};

const agentElementMap = {
  pm_agent: "pmAgent",
  engineer_agent: "engineerAgent",
  qa_agent: "qaAgent",
  devops_agent: "devopsAgent",
  budget_manager: "pmAgent"
};

function resetOfficeRooms() {
  document.querySelectorAll(".office-room").forEach(room => {
    room.classList.remove("active", "owner-active");
  });

  document.querySelectorAll(".office-agent").forEach(agent => {
    agent.classList.remove("busy");
  });
}

function setRoomStatus(room, text) {
  const el = document.getElementById(`${room}Status`);
  if (el) el.textContent = text;
}

function activateRoom(room, mode = "active") {
  const el = document.querySelector(`.office-room[data-room="${room}"]`);
  if (!el) return;
  el.classList.add(mode);
}

function moveAgent(agentId, room, busy = true) {
  const el = document.getElementById(agentId);
  if (!el) return;
  el.dataset.room = room;
  if (busy) el.classList.add("busy");
}

function updatePixelOffice(events) {
  if (!Array.isArray(events) || events.length === 0) return;

  resetOfficeRooms();

  const latest = events.slice(0, 8);

  latest.forEach(event => {
    const eventType = event.event_type || "";
    const agent = event.agent || "";
    const state = event.state || "";

    let room = agentRoomMap[agent] || "meeting";
    let agentId = agentElementMap[agent] || "pmAgent";
    let statusText = state.toLowerCase() || "active";

    if (eventType.includes("owner_")) {
      room = "owner";
      agentId = "ownerAgent";
      activateRoom("owner", "owner-active");
      setRoomStatus("owner", statusText);
      moveAgent(agentId, "owner", true);
      return;
    }

    if (eventType.includes("qa_")) {
      room = "qa";
      agentId = "qaAgent";
    } else if (eventType.includes("engineering_")) {
      room = "engineer";
      agentId = "engineerAgent";
    } else if (eventType.includes("devops_")) {
      room = "devops";
      agentId = "devopsAgent";
    } else if (eventType.includes("internal_task_created") || eventType.includes("task_created")) {
      room = "pm";
      agentId = "pmAgent";
    }

    activateRoom(room);
    setRoomStatus(room, statusText);
    moveAgent(agentId, room, true);
  });
}

const originalRenderEvents = renderEvents;
renderEvents = function(events) {
  updatePixelOffice(events);
  return originalRenderEvents(events);
};

async function loadAgentRuntimeStatus() {
  const container = document.getElementById("agentRuntimeList");
  if (!container) return;

  try {
    const response = await fetch("/api/agents/runtime");
    const agents = await response.json();

    container.innerHTML = agents.map((agent) => {
      const task = agent.current_task_key || "no active task";
      const note = agent.status_note || "";
      return `
        <div class="agent-runtime-row">
          <div class="agent-runtime-name">${agent.agent_key}</div>
          <div class="agent-runtime-status">${agent.runtime_status}</div>
          <div class="agent-runtime-task">${task}</div>
          <div class="agent-runtime-note">${note}</div>
        </div>
      `;
    }).join("");
    setUpdated("agentRuntimeUpdatedAt");
  } catch (error) {
    container.innerHTML = `<div class="muted">Failed to load agent runtime status.</div>`;
    console.error(error);
  }
}

loadAgentRuntimeStatus();
setInterval(loadAgentRuntimeStatus, 5000);

/* Pixel Office Runtime Status Integration */
const runtimeAgentMap = {
  pm_agent: {
    room: "pm",
    sprite: "pmAgent",
    status: "pmStatus"
  },
  engineer_agent: {
    room: "engineer",
    sprite: "engineerAgent",
    status: "engineerStatus"
  },
  qa_agent: {
    room: "qa",
    sprite: "qaAgent",
    status: "qaStatus"
  },
  devops_agent: {
    room: "devops",
    sprite: "devopsAgent",
    status: "devopsStatus"
  },
  budget_manager: {
    room: "meeting",
    sprite: "pmAgent",
    status: "meetingStatus"
  }
};

function runtimeStatusIsBusy(status) {
  return ["queued", "claimed", "working", "safety_blocked"].includes(status);
}

function runtimeStatusRoomClass(status) {
  if (status === "safety_blocked" || status === "failed") return "owner-active";
  if (runtimeStatusIsBusy(status)) return "active";
  return "";
}

function updatePixelOfficeFromRuntime(agents) {
  if (!Array.isArray(agents)) return;

  if (typeof resetOfficeRooms === "function") {
    resetOfficeRooms();
  }

  agents.forEach((agent) => {
    const config = runtimeAgentMap[agent.agent_key];
    if (!config) return;

    const status = agent.runtime_status || "idle";
    const task = agent.current_task_key || "";
    const note = agent.status_note || "";

    const roomEl = document.querySelector(`.office-room[data-room="${config.room}"]`);
    const spriteEl = document.getElementById(config.sprite);
    const statusEl = document.getElementById(config.status);

    if (statusEl) {
      statusEl.textContent = task ? `${status}: ${task}` : status;
      statusEl.title = note;
    }

    if (roomEl) {
      const roomClass = runtimeStatusRoomClass(status);
      if (roomClass) roomEl.classList.add(roomClass);
    }

    if (spriteEl) {
      spriteEl.dataset.room = config.room;
      if (runtimeStatusIsBusy(status)) {
        spriteEl.classList.add("busy");
      } else {
        spriteEl.classList.remove("busy");
      }
    }
  });
}

async function loadPixelOfficeRuntimeStatus() {
  try {
    const response = await fetch("/api/agents/runtime");
    const agents = await response.json();
    updatePixelOfficeFromRuntime(agents);
  } catch (error) {
    console.error("Failed to update pixel office runtime status", error);
  }
}

loadPixelOfficeRuntimeStatus();
setInterval(loadPixelOfficeRuntimeStatus, 5000);

async function loadOwnerCommands() {
  const container = document.getElementById("ownerCommandList");
  if (!container) return;

  try {
    const response = await fetch("/api/owner/commands");
    const commands = await response.json();

    if (!Array.isArray(commands) || commands.length === 0) {
      container.innerHTML = `<div class="muted">No owner commands yet.</div>`;
      return;
    }

    container.innerHTML = commands.map((command) => `
      <div class="owner-command-item">
        <div class="owner-command-meta">
          <span>#${command.id}</span>
          <span>${command.status}</span>
          <span>${command.created_at}</span>
        </div>
        <div class="owner-command-text">${command.command_text}</div>
      </div>
    `).join("");
  } catch (error) {
    container.innerHTML = `<div class="muted">Failed to load owner commands.</div>`;
    console.error(error);
  }
}

function setupOwnerCommandForm() {
  const form = document.getElementById("ownerCommandForm");
  const input = document.getElementById("ownerCommandInput");
  const status = document.getElementById("ownerCommandStatus");

  if (!form || !input) return;

  form.addEventListener("submit", async (event) => {
    event.preventDefault();

    const commandText = input.value.trim();
    if (!commandText) return;

    if (status) status.textContent = "Submitting command...";

    try {
      const response = await fetch("/api/owner/commands", {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          command_text: commandText
        })
      });

      if (!response.ok) {
        throw new Error(`Submit failed: ${response.status}`);
      }

      input.value = "";
      if (status) status.textContent = "Command submitted.";
      await loadOwnerCommands();
    } catch (error) {
      if (status) status.textContent = "Failed to submit command.";
      console.error(error);
    }
  });
}

setupOwnerCommandForm();
loadOwnerCommands();
setInterval(loadOwnerCommands, 5000);

function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = String(reader.result || "");
      const base64 = result.includes(",") ? result.split(",")[1] : result;
      resolve(base64);
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

async function loadProjectUploads() {
  const container = document.getElementById("uploadList");
  const projectInput = document.getElementById("uploadProjectKey");
  if (!container || !projectInput) return;

  const projectKey = projectInput.value.trim();
  if (!projectKey) {
    container.innerHTML = `<div class="muted">Enter project_key to load uploads.</div>`;
    return;
  }

  try {
    const response = await fetch(`/api/uploads?project_key=${encodeURIComponent(projectKey)}`);
    const uploads = await response.json();

    if (!Array.isArray(uploads) || uploads.length === 0) {
      container.innerHTML = `<div class="muted">No uploads for this project yet.</div>`;
      return;
    }

    container.innerHTML = uploads.map((upload) => `
      <div class="upload-item">
        <div class="upload-name">${upload.original_filename}</div>
        <div class="upload-meta">
          <span>#${upload.id}</span>
          <span>${upload.mime_type || "file"}</span>
          <span>${upload.size_bytes} bytes</span>
          <span>${upload.created_at}</span>
        </div>
        <div class="muted">${upload.relative_path}</div>
      </div>
    `).join("");
  } catch (error) {
    container.innerHTML = `<div class="muted">Failed to load uploads.</div>`;
    console.error(error);
  }
}

function setupUploadForm() {
  const form = document.getElementById("uploadForm");
  const projectInput = document.getElementById("uploadProjectKey");
  const fileInput = document.getElementById("uploadFileInput");
  const status = document.getElementById("uploadStatus");

  if (!form || !projectInput || !fileInput) return;

  form.addEventListener("submit", async (event) => {
    event.preventDefault();

    const projectKey = projectInput.value.trim();
    const file = fileInput.files && fileInput.files[0];

    if (!projectKey || !file) {
      if (status) status.textContent = "Project key and file are required.";
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      if (status) status.textContent = "File too large for v0. Max 5 MB.";
      return;
    }

    if (status) status.textContent = "Uploading file...";

    try {
      const contentBase64 = await fileToBase64(file);

      const response = await fetch("/api/uploads", {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          project_key: projectKey,
          filename: file.name,
          mime_type: file.type || "",
          content_base64: contentBase64
        })
      });

      if (!response.ok) {
        const errorBody = await response.json().catch(() => ({}));
        throw new Error(errorBody.error || `Upload failed: ${response.status}`);
      }

      fileInput.value = "";
      if (status) status.textContent = "File uploaded.";
      await loadProjectUploads();
    } catch (error) {
      if (status) status.textContent = `Upload failed: ${error.message}`;
      console.error(error);
    }
  });

  projectInput.addEventListener("change", loadProjectUploads);
}

setupUploadForm();
loadProjectUploads();
setInterval(loadProjectUploads, 7000);

function setupConvertCommandForm() {
  const form = document.getElementById("convertCommandForm");
  const commandIdInput = document.getElementById("convertCommandId");
  const projectKeyInput = document.getElementById("convertProjectKey");
  const projectTitleInput = document.getElementById("convertProjectTitle");
  const status = document.getElementById("convertCommandStatus");
  const output = document.getElementById("convertCommandOutput");

  if (!form || !commandIdInput || !projectKeyInput || !projectTitleInput) return;

  form.addEventListener("submit", async (event) => {
    event.preventDefault();

    const commandId = commandIdInput.value.trim();
    const projectKey = projectKeyInput.value.trim();
    const projectTitle = projectTitleInput.value.trim();

    if (!commandId || !projectKey || !projectTitle) {
      if (status) status.textContent = "command id, project key, and project title are required.";
      return;
    }

    if (status) status.textContent = "Converting owner command to project...";
    if (output) output.textContent = "";

    try {
      const response = await fetch("/api/owner/commands/convert", {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          command_id: commandId,
          project_key: projectKey,
          project_title: projectTitle
        })
      });

      const body = await response.json();

      if (!response.ok) {
        throw new Error(body.error || `Convert failed: ${response.status}`);
      }

      if (status) status.textContent = "Command converted to project.";
      if (output) output.textContent = body.output || JSON.stringify(body, null, 2);

      await loadOwnerCommands();
      await loadProjectUploads();
    } catch (error) {
      if (status) status.textContent = `Convert failed: ${error.message}`;
      if (output) output.textContent = String(error.stack || error.message || error);
      console.error(error);
    }
  });
}

setupConvertCommandForm();

function setupAttachUploadsForm() {
  const form = document.getElementById("attachUploadsForm");
  const projectKeyInput = document.getElementById("attachProjectKey");
  const taskKeyInput = document.getElementById("attachTaskKey");
  const status = document.getElementById("attachUploadsStatus");
  const output = document.getElementById("attachUploadsOutput");

  if (!form || !projectKeyInput || !taskKeyInput) return;

  form.addEventListener("submit", async (event) => {
    event.preventDefault();

    const projectKey = projectKeyInput.value.trim();
    const taskKey = taskKeyInput.value.trim();

    if (!projectKey || !taskKey) {
      if (status) status.textContent = "project key and task key are required.";
      return;
    }

    if (status) status.textContent = "Attaching uploads to PM context...";
    if (output) output.textContent = "";

    try {
      const response = await fetch("/api/uploads/attach-context", {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          project_key: projectKey,
          task_key: taskKey
        })
      });

      const body = await response.json();

      if (!response.ok) {
        throw new Error(body.error || `Attach failed: ${response.status}`);
      }

      if (status) status.textContent = "Uploads attached to PM context.";
      if (output) output.textContent = body.output || JSON.stringify(body, null, 2);
    } catch (error) {
      if (status) status.textContent = `Attach failed: ${error.message}`;
      if (output) output.textContent = String(error.stack || error.message || error);
      console.error(error);
    }
  });
}

setupAttachUploadsForm();

function setupAttachUploadsForm() {
  const form = document.getElementById("attachUploadsForm");
  const projectKeyInput = document.getElementById("attachProjectKey");
  const taskKeyInput = document.getElementById("attachTaskKey");
  const status = document.getElementById("attachUploadsStatus");
  const output = document.getElementById("attachUploadsOutput");

  if (!form || !projectKeyInput || !taskKeyInput) return;

  form.addEventListener("submit", async (event) => {
    event.preventDefault();

    const projectKey = projectKeyInput.value.trim();
    const taskKey = taskKeyInput.value.trim();

    if (!projectKey || !taskKey) {
      if (status) status.textContent = "project key and task key are required.";
      return;
    }

    if (status) status.textContent = "Attaching uploads to PM context...";
    if (output) output.textContent = "";

    try {
      const response = await fetch("/api/uploads/attach-context", {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          project_key: projectKey,
          task_key: taskKey
        })
      });

      const body = await response.json();

      if (!response.ok) {
        throw new Error(body.error || `Attach failed: ${response.status}`);
      }

      if (status) status.textContent = "Uploads attached to PM context.";
      if (output) output.textContent = body.output || JSON.stringify(body, null, 2);
    } catch (error) {
      if (status) status.textContent = `Attach failed: ${error.message}`;
      if (output) output.textContent = String(error.stack || error.message || error);
      console.error(error);
    }
  });
}

setupAttachUploadsForm();

/* End-to-End Workflow Actions */
function workflowInputValue(id) {
  const el = document.getElementById(id);
  return el ? el.value.trim() : "";
}

function workflowPayloadForAction(action) {
  const projectKey = workflowInputValue("workflowProjectKey");

  if (action === "pm_analysis") {
    return {
      action,
      project_key: projectKey,
      task_key: workflowInputValue("workflowPmTaskKey")
    };
  }

  if (action === "generate_tasks") {
    return {
      action,
      project_key: projectKey,
      task_key: workflowInputValue("workflowPmTaskKey")
    };
  }

  if (action === "engineer_impl") {
    return {
      action,
      project_key: projectKey,
      task_key: workflowInputValue("workflowEngineerTaskKey")
    };
  }

  if (action === "qa_verify") {
    return {
      action,
      project_key: projectKey,
      task_key: workflowInputValue("workflowQaTaskKey")
    };
  }

  if (action === "submit_review") {
    return {
      action,
      project_key: projectKey,
      task_key: workflowInputValue("workflowQaTaskKey")
    };
  }

  if (action === "owner_decision") {
    return {
      action,
      review_task_key: workflowInputValue("workflowReviewTaskKey"),
      decision: workflowInputValue("workflowDecision"),
      note: workflowInputValue("workflowNote")
    };
  }

  if (action === "finalize") {
    return {
      action,
      project_key: projectKey,
      review_task_key: workflowInputValue("workflowReviewTaskKey")
    };
  }

  return { action };
}

async function runWorkflowAction(action) {
  const status = document.getElementById("workflowActionStatus");
  const output = document.getElementById("workflowActionOutput");

  if (status) status.textContent = `Running ${action}...`;
  if (output) output.textContent = "";

  try {
    const response = await fetch("/api/workflow/action", {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(workflowPayloadForAction(action))
    });

    const data = await response.json();

    if (!response.ok || data.ok === false) {
      throw new Error(data.error || `Workflow action failed: ${action}`);
    }

    if (status) status.textContent = `Completed: ${action}`;
    if (output) output.textContent = data.output || JSON.stringify(data, null, 2);

    try {
      await main();
      await loadAgentRuntimeStatus();
      await loadPixelOfficeRuntimeStatus();
      await loadOwnerCommands();
      await loadUploads();
    } catch (refreshError) {
      console.error("Workflow refresh failed", refreshError);
    }
  } catch (error) {
    if (status) status.textContent = `Failed: ${action}`;
    if (output) output.textContent = error.stack || String(error);
    console.error(error);
  }
}

function setupWorkflowActionButtons() {
  document.querySelectorAll("[data-workflow-action]").forEach((button) => {
    button.addEventListener("click", () => {
      const action = button.getAttribute("data-workflow-action");
      runWorkflowAction(action);
    });
  });
}

setupWorkflowActionButtons();

/* Minimal Chat Command Bar UI */
function createMinimalCommandBar() {
  if (document.getElementById("aiCompanyCommandBar")) return;

  const wrapper = document.createElement("div");
  wrapper.id = "aiCompanyCommandBar";
  wrapper.className = "ai-command-shell";
  wrapper.innerHTML = `
    <div class="ai-plus-menu" id="aiPlusMenu">
      <button type="button" data-plus-action="advanced">Toggle Advanced Tools</button>
      <button type="button" data-plus-action="help">Show Slash Commands</button>
      <button type="button" data-plus-action="refresh">Refresh Dashboard</button>
    </div>

    <div class="ai-command-bar">
      <button type="button" id="aiPlusButton" class="ai-plus-button">+</button>
      <textarea
        id="aiCommandInput"
        class="ai-command-input"
        rows="1"
        placeholder="Ask AI Company or type /help..."
      ></textarea>
      <button type="button" id="aiSendButton" class="ai-send-button">Send</button>
    </div>

    <div id="aiCommandStatus" class="ai-command-status"></div>
    <pre id="aiCommandOutputPanel" class="ai-command-output-panel"></pre>
  `;

  document.body.appendChild(wrapper);
}

function getDefaultWorkflowValue(id, fallback = "") {
  const el = document.getElementById(id);
  return el && el.value ? el.value.trim() : fallback;
}

function showCommandStatus(message) {
  const el = document.getElementById("aiCommandStatus");
  if (!el) return;
  el.textContent = message || "";
}

function appendCommandOutput(title, output) {
  const status = document.getElementById("aiCommandStatus");
  const panel = document.getElementById("aiCommandOutputPanel");

  if (status) {
    status.textContent = title || "";
  }

  if (!panel) return;

  const text = String(output || "").trim();

  if (!text) {
    panel.textContent = "";
    panel.classList.remove("open");
    return;
  }

  panel.dataset.kind = "command-output";
  panel.textContent = text;
  panel.classList.add("open");
}

function hideLegacyPanelsByDefault() {
  const selectors = [
    ".owner-command-card",
    ".upload-intake-card",
    ".convert-command-card",
    ".attach-uploads-card",
    ".workflow-action-card"
  ];

  selectors.forEach((selector) => {
    document.querySelectorAll(selector).forEach((el) => {
      el.classList.add("legacy-tool-panel");
      el.classList.add("legacy-tool-hidden");
    });
  });
}

function toggleAdvancedTools() {
  document.querySelectorAll(".legacy-tool-panel").forEach((el) => {
    el.classList.toggle("legacy-tool-hidden");
  });
}

function showSlashHelp() {
  const panel = document.getElementById("aiCommandOutputPanel");

  if (panel && panel.classList.contains("open") && panel.dataset.kind === "slash-help") {
    panel.textContent = "";
    panel.dataset.kind = "";
    panel.classList.remove("open");
    showCommandStatus("Slash commands hidden.");
    return;
  }

  const help = [
    "Slash commands",
    "",
    "/help",
    "/new <requirement>",
    "/pm <project_key> <pm_task_key>",
    "/tasks <project_key> <pm_task_key>",
    "/eng <project_key> <engineer_task_key>",
    "/qa <project_key> <qa_task_key>",
    "/review <project_key> <qa_task_key>",
    "/accept <review_task_key> <note>",
    "/revise <review_task_key> <note>",
    "/reject <review_task_key> <note>",
    "/finalize <project_key> <review_task_key>",
    "/advanced",
    "",
    "Normal text without / will be submitted as a new Owner Command."
  ].join("\n");

  if (panel) {
    panel.dataset.kind = "slash-help";
    panel.textContent = help;
    panel.classList.add("open");
  }

  showCommandStatus("Slash commands shown.");
}

async function postJson(url, payload) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(payload)
  });

  const data = await response.json();

  if (!response.ok || data.ok === false) {
    throw new Error(data.error || `Request failed: ${url}`);
  }

  return data;
}

function parseCommandLine(text) {
  const trimmed = text.trim();
  if (!trimmed.startsWith("/")) {
    return {
      command: "new",
      args: [trimmed],
      raw: trimmed
    };
  }

  const parts = trimmed.split(/\s+/);
  const command = parts[0].slice(1).toLowerCase();
  const args = parts.slice(1);

  return { command, args, raw: trimmed };
}

async function runSlashOrOwnerCommand(text) {
  const parsed = parseCommandLine(text);
  const command = parsed.command;
  const args = parsed.args;

  if (!text.trim()) return;

  showCommandStatus("Running...");

  if (command === "help") {
    showSlashHelp();
    return;
  }

  if (command === "advanced") {
    toggleAdvancedTools();
    showCommandStatus("Advanced tools toggled.");
    return;
  }

  if (command === "new") {
    const commandText = args.join(" ").trim();
    if (!commandText) throw new Error("Command text is required.");

    const data = await postJson("/api/owner/commands", {
      command_text: commandText
    });

    appendCommandOutput("Owner command submitted", JSON.stringify(data, null, 2));
    showCommandStatus("Owner command submitted.");
    await refreshDashboardAfterCommand();
    return;
  }

  if (command === "pm") {
    const projectKey = args[0] || getDefaultWorkflowValue("workflowProjectKey", "client-company-profile-demo");
    const taskKey = args[1] || getDefaultWorkflowValue("workflowPmTaskKey", "CLIENT-1-001");

    const data = await postJson("/api/workflow/action", {
      action: "pm_analysis",
      project_key: projectKey,
      task_key: taskKey
    });

    appendCommandOutput("PM analysis completed", data.output);
    showCommandStatus("PM analysis completed.");
    await refreshDashboardAfterCommand();
    return;
  }

  if (command === "tasks") {
    const projectKey = args[0] || getDefaultWorkflowValue("workflowProjectKey", "client-company-profile-demo");
    const taskKey = args[1] || getDefaultWorkflowValue("workflowPmTaskKey", "CLIENT-1-001");

    const data = await postJson("/api/workflow/action", {
      action: "generate_tasks",
      project_key: projectKey,
      task_key: taskKey
    });

    appendCommandOutput("Engineer/QA tasks generated", data.output);
    showCommandStatus("Engineer/QA tasks generated.");
    await refreshDashboardAfterCommand();
    return;
  }

  if (command === "eng") {
    const projectKey = args[0] || getDefaultWorkflowValue("workflowProjectKey", "client-company-profile-demo");
    const taskKey = args[1] || getDefaultWorkflowValue("workflowEngineerTaskKey", "CLIENT-1-ENG-001");

    const data = await postJson("/api/workflow/action", {
      action: "engineer_impl",
      project_key: projectKey,
      task_key: taskKey
    });

    appendCommandOutput("Engineer implementation completed", data.output);
    showCommandStatus("Engineer implementation completed.");
    await refreshDashboardAfterCommand();
    return;
  }

  if (command === "qa") {
    const projectKey = args[0] || getDefaultWorkflowValue("workflowProjectKey", "client-company-profile-demo");
    const taskKey = args[1] || getDefaultWorkflowValue("workflowQaTaskKey", "CLIENT-1-QA-001");

    const data = await postJson("/api/workflow/action", {
      action: "qa_verify",
      project_key: projectKey,
      task_key: taskKey
    });

    appendCommandOutput("QA verification completed", data.output);
    showCommandStatus("QA verification completed.");
    await refreshDashboardAfterCommand();
    return;
  }

  if (command === "review") {
    const projectKey = args[0] || getDefaultWorkflowValue("workflowProjectKey", "client-company-profile-demo");
    const taskKey = args[1] || getDefaultWorkflowValue("workflowQaTaskKey", "CLIENT-1-QA-001");

    const data = await postJson("/api/workflow/action", {
      action: "submit_review",
      project_key: projectKey,
      task_key: taskKey
    });

    appendCommandOutput("Submitted to Owner review", data.output);
    showCommandStatus("Submitted to Owner review.");
    await refreshDashboardAfterCommand();
    return;
  }

  if (["accept", "revise", "reject"].includes(command)) {
    const reviewTaskKey = args[0] || getDefaultWorkflowValue("workflowReviewTaskKey", "CLIENT-1-REVIEW-001");
    const note = args.slice(1).join(" ") || getDefaultWorkflowValue("workflowNote", "Owner decision from command bar.");
    const decision = command.toUpperCase();

    const data = await postJson("/api/workflow/action", {
      action: "owner_decision",
      review_task_key: reviewTaskKey,
      decision,
      note
    });

    appendCommandOutput(`Owner decision: ${decision}`, data.output);
    showCommandStatus(`Owner decision ${decision} completed.`);
    await refreshDashboardAfterCommand();
    return;
  }

  if (command === "finalize") {
    const projectKey = args[0] || getDefaultWorkflowValue("workflowProjectKey", "client-company-profile-demo");
    const reviewTaskKey = args[1] || getDefaultWorkflowValue("workflowReviewTaskKey", "CLIENT-1-REVIEW-001");

    const data = await postJson("/api/workflow/action", {
      action: "finalize",
      project_key: projectKey,
      review_task_key: reviewTaskKey
    });

    appendCommandOutput("Project finalized", data.output);
    showCommandStatus("Project finalized.");
    await refreshDashboardAfterCommand();
    return;
  }

  throw new Error(`Unknown slash command: /${command}. Type /help.`);
}

async function refreshDashboardAfterCommand() {
  try {
    await main();
    if (typeof loadAgentRuntimeStatus === "function") await loadAgentRuntimeStatus();
    if (typeof loadPixelOfficeRuntimeStatus === "function") await loadPixelOfficeRuntimeStatus();
    if (typeof loadOwnerCommands === "function") await loadOwnerCommands();
    if (typeof loadUploads === "function") await loadUploads();
  } catch (error) {
    console.error("Dashboard refresh failed", error);
  }
}

function setupMinimalCommandBar() {
  createMinimalCommandBar();
  hideLegacyPanelsByDefault();

  const plusButton = document.getElementById("aiPlusButton");
  const plusMenu = document.getElementById("aiPlusMenu");
  const sendButton = document.getElementById("aiSendButton");
  const input = document.getElementById("aiCommandInput");

  if (plusButton && plusMenu) {
    plusButton.addEventListener("click", () => {
      plusMenu.classList.toggle("open");
    });
  }

  document.querySelectorAll("[data-plus-action]").forEach((button) => {
    button.addEventListener("click", async () => {
      const action = button.getAttribute("data-plus-action");

      if (action === "advanced") {
        toggleAdvancedTools();
        showCommandStatus("Advanced tools toggled.");
      }

      if (action === "help") {
        showSlashHelp();
      }

      if (action === "refresh") {
        await refreshDashboardAfterCommand();
        showCommandStatus("Dashboard refreshed.");
      }

      if (plusMenu) plusMenu.classList.remove("open");
    });
  });

  async function submit() {
    if (!input) return;
    const value = input.value.trim();
    if (!value) return;

    input.value = "";

    try {
      await runSlashOrOwnerCommand(value);
    } catch (error) {
      showCommandStatus(error.message);
      appendCommandOutput("Command failed", error.stack || String(error));
      console.error(error);
    }
  }

  if (sendButton) {
    sendButton.addEventListener("click", submit);
  }

  if (input) {
    input.addEventListener("keydown", (event) => {
      if (event.key === "Enter" && !event.shiftKey) {
        event.preventDefault();
        submit();
      }
    });
  }
}

setupMinimalCommandBar();

/* INTERNAL-039: Slash Command Palette + Plus Upload */
const aiSlashCommands = [
  {
    command: "/new",
    hint: "Submit new owner requirement",
    template: "/new "
  },
  {
    command: "/pm",
    hint: "Run PM analysis",
    template: "/pm client-company-profile-demo CLIENT-1-001"
  },
  {
    command: "/tasks",
    hint: "Generate Engineer and QA tasks",
    template: "/tasks client-company-profile-demo CLIENT-1-001"
  },
  {
    command: "/eng",
    hint: "Run engineer implementation",
    template: "/eng client-company-profile-demo CLIENT-1-ENG-001"
  },
  {
    command: "/qa",
    hint: "Run QA verification",
    template: "/qa client-company-profile-demo CLIENT-1-QA-001"
  },
  {
    command: "/review",
    hint: "Submit QA-passed project to owner review",
    template: "/review client-company-profile-demo CLIENT-1-QA-001"
  },
  {
    command: "/accept",
    hint: "Accept owner review",
    template: "/accept CLIENT-1-REVIEW-001 Approved."
  },
  {
    command: "/revise",
    hint: "Request revision",
    template: "/revise CLIENT-1-REVIEW-001 "
  },
  {
    command: "/reject",
    hint: "Reject project",
    template: "/reject CLIENT-1-REVIEW-001 "
  },
  {
    command: "/finalize",
    hint: "Finalize accepted project",
    template: "/finalize client-company-profile-demo CLIENT-1-REVIEW-001"
  },
  {
    command: "/advanced",
    hint: "Toggle advanced tools",
    template: "/advanced"
  }
];

function ensureSlashPalette() {
  let palette = document.getElementById("aiSlashPalette");
  if (palette) return palette;

  const shell = document.getElementById("aiCompanyCommandBar");
  if (!shell) return null;

  palette = document.createElement("div");
  palette.id = "aiSlashPalette";
  palette.className = "ai-slash-palette";
  shell.insertBefore(palette, shell.firstChild);

  return palette;
}

function renderSlashPalette(query = "") {
  const palette = ensureSlashPalette();
  if (!palette) return;

  const normalized = query.toLowerCase().trim();

  const matches = aiSlashCommands.filter((item) => {
    if (!normalized || normalized === "/") return true;
    return item.command.toLowerCase().includes(normalized);
  });

  if (matches.length === 0) {
    palette.classList.remove("open");
    palette.innerHTML = "";
    return;
  }

  palette.innerHTML = matches.map((item, index) => `
    <button type="button" class="ai-slash-item ${index === 0 ? "selected" : ""}" data-template="${item.template.replace(/"/g, "&quot;")}">
      <span class="ai-slash-command">${item.command}</span>
      <span class="ai-slash-hint">${item.hint}</span>
    </button>
  `).join("");

  palette.classList.add("open");

  palette.querySelectorAll(".ai-slash-item").forEach((button) => {
    button.addEventListener("click", () => {
      const input = document.getElementById("aiCommandInput");
      if (!input) return;

      input.value = button.getAttribute("data-template") || "";
      input.focus();

      const length = input.value.length;
      input.setSelectionRange(length, length);

      palette.classList.remove("open");
    });
  });
}

function hideSlashPalette() {
  const palette = document.getElementById("aiSlashPalette");
  if (!palette) return;
  palette.classList.remove("open");
}

function setupSlashPaletteV2() {
  const input = document.getElementById("aiCommandInput");
  if (!input) return;

  input.addEventListener("input", () => {
    const value = input.value.trimStart();

    if (value.startsWith("/")) {
      const firstToken = value.split(/\s+/)[0];
      renderSlashPalette(firstToken);
    } else {
      hideSlashPalette();
    }
  });

  input.addEventListener("keydown", (event) => {
    const palette = document.getElementById("aiSlashPalette");
    if (!palette || !palette.classList.contains("open")) return;

    if (event.key === "Escape") {
      hideSlashPalette();
      return;
    }

    if (event.key === "Tab") {
      const selected = palette.querySelector(".ai-slash-item.selected") || palette.querySelector(".ai-slash-item");
      if (!selected) return;

      event.preventDefault();

      input.value = selected.getAttribute("data-template") || "";
      input.focus();

      const length = input.value.length;
      input.setSelectionRange(length, length);
      hideSlashPalette();
    }

    if (event.key === "Enter" && !event.shiftKey) {
      hideSlashPalette();
    }
  });
}

function ensureHiddenUploadInput() {
  let input = document.getElementById("aiCommandUploadInput");
  if (input) return input;

  input = document.createElement("input");
  input.id = "aiCommandUploadInput";
  input.type = "file";
  input.style.display = "none";
  document.body.appendChild(input);

  input.addEventListener("change", async () => {
    const file = input.files && input.files[0];
    if (!file) return;

    const projectKey =
      getDefaultWorkflowValue("workflowProjectKey", "") ||
      getDefaultWorkflowValue("uploadProjectKey", "") ||
      "client-company-profile-demo";

    showCommandStatus(`Uploading ${file.name}...`);

    try {
      const contentBase64 = await new Promise((resolve, reject) => {
        const reader = new FileReader();

        reader.onload = () => {
          const result = String(reader.result || "");
          const base64 = result.includes(",") ? result.split(",")[1] : result;
          resolve(base64);
        };

        reader.onerror = reject;
        reader.readAsDataURL(file);
      });

      const data = await postJson("/api/uploads", {
        project_key: projectKey,
        filename: file.name,
        mime_type: file.type || "application/octet-stream",
        content_base64: contentBase64
      });

      appendCommandOutput("File uploaded", JSON.stringify(data, null, 2));
      showCommandStatus(`Uploaded ${file.name} to ${projectKey}.`);

      await refreshDashboardAfterCommand();
    } catch (error) {
      appendCommandOutput("Upload failed", error.stack || String(error));
      showCommandStatus(`Upload failed: ${error.message}`);
    } finally {
      input.value = "";
    }
  });

  return input;
}

function setupPlusUploadV2() {
  const oldPlus = document.getElementById("aiPlusButton");
  if (!oldPlus) return;

  const plus = oldPlus.cloneNode(true);
  oldPlus.replaceWith(plus);

  plus.title = "Upload file";
  plus.setAttribute("aria-label", "Upload file");

  plus.addEventListener("click", () => {
    const uploadInput = ensureHiddenUploadInput();
    uploadInput.click();
  });

  const oldPlusMenu = document.getElementById("aiPlusMenu");
  if (oldPlusMenu) {
    oldPlusMenu.remove();
  }
}

function upgradeCommandBarToV2() {
  setupPlusUploadV2();
  setupSlashPaletteV2();

  const input = document.getElementById("aiCommandInput");
  if (input) {
    input.placeholder = "Ask AI Company or type / for commands...";
  }

  showCommandStatus("Type / for commands. Press + to upload files.");
}

upgradeCommandBarToV2();

/* INTERNAL-041: VPS Performance Widget */
function setPerfBar(id, value) {
  const el = document.getElementById(id);
  if (!el) return;
  const safe = Math.max(0, Math.min(100, Number(value || 0)));
  el.style.width = `${safe}%`;
}

function setText(id, value) {
  const el = document.getElementById(id);
  if (el) el.textContent = value;
}

async function loadVpsPerformance() {
  try {
    const metrics = await loadJson("/api/system/metrics");

    setText("cpuPercent", `${metrics.cpu.used_percent}%`);
    setText("cpuMeta", `load ${metrics.cpu.load_1m} · ${metrics.cpu.cores} cores`);
    setPerfBar("cpuBar", metrics.cpu.used_percent);

    setText("ramPercent", `${metrics.ram.used_percent}%`);
    setText("ramMeta", `${metrics.ram.used_human} used / ${metrics.ram.total_human} total`);
    setPerfBar("ramBar", metrics.ram.used_percent);

    setText("diskPercent", `${metrics.disk.used_percent}%`);
    setText("diskMeta", `${metrics.disk.used_human} used / ${metrics.disk.total_human} total`);
    setPerfBar("diskBar", metrics.disk.used_percent);

    setText("uptimeText", metrics.uptime.human);
    setText("metricsTimestamp", `updated ${new Date(metrics.timestamp).toLocaleTimeString()}`);
  } catch (error) {
    setText("metricsTimestamp", "failed to load VPS metrics");
    console.error("Failed to load VPS performance", error);
  }
}

function setupVpsPerformanceToggle() {
  const button = document.getElementById("vpsPerformanceToggle");
  const card = document.getElementById("vpsPerformanceCard");

  if (!button || !card) return;

  button.addEventListener("click", () => {
    card.classList.toggle("collapsed");
    button.textContent = card.classList.contains("collapsed") ? "Show" : "Hide";
  });
}

setupVpsPerformanceToggle();
loadVpsPerformance();
setInterval(loadVpsPerformance, 5000);

/* INTERNAL-042: Pixel Office Visual v1 */
function setPixelAgentBubble(agentElement, status, task) {
  if (!agentElement) return;

  const bubble = agentElement.querySelector(".agent-bubble");
  if (!bubble) return;

  if (task) {
    bubble.textContent = task.length > 18 ? `${task.slice(0, 18)}…` : task;
  } else {
    bubble.textContent = status || "idle";
  }
}

function setPixelAgentState(agentElement, status) {
  if (!agentElement) return;

  agentElement.classList.remove(
    "state-idle",
    "state-working",
    "state-done",
    "state-blocked",
    "state-failed"
  );

  if (status === "done") {
    agentElement.classList.add("state-done");
  } else if (status === "safety_blocked" || status === "blocked") {
    agentElement.classList.add("state-blocked");
  } else if (status === "failed") {
    agentElement.classList.add("state-failed");
  } else if (["queued", "claimed", "working", "in_progress"].includes(status)) {
    agentElement.classList.add("state-working");
  } else {
    agentElement.classList.add("state-idle");
  }
}

function enhancePixelOfficeRuntime() {
  const original = window.updatePixelOfficeFromRuntime || updatePixelOfficeFromRuntime;

  if (!original || original.__pixelEnhanced) return;

  const enhanced = function(agents) {
    original(agents);

    if (!Array.isArray(agents)) return;

    agents.forEach((agent) => {
      const config = runtimeAgentMap[agent.agent_key];
      if (!config) return;

      const spriteEl = document.getElementById(config.sprite);
      const status = agent.runtime_status || "idle";
      const task = agent.current_task_key || "";

      setPixelAgentBubble(spriteEl, status, task);
      setPixelAgentState(spriteEl, status);
    });
  };

  enhanced.__pixelEnhanced = true;

  if (typeof window.updatePixelOfficeFromRuntime !== "undefined") {
    window.updatePixelOfficeFromRuntime = enhanced;
  }

  updatePixelOfficeFromRuntime = enhanced;
}

try {
  enhancePixelOfficeRuntime();
} catch (error) {
  console.error("Pixel office enhancement failed", error);
}

/* INTERNAL-043: Pixel Office Simulation Stage v1 */
const officeSimRoomText = {
  pm: "Planning",
  engineer: "Building",
  qa: "Checking",
  devops: "Deploy",
  meeting: "Sync",
  owner: "Review"
};

function setSimAgentRoom(agentId, room, status = "idle", task = "") {
  const agent = document.getElementById(agentId);
  if (!agent) return;

  agent.dataset.room = room;
  agent.dataset.status = status;

  agent.classList.remove("state-idle", "state-working", "state-done", "state-blocked", "state-failed");

  if (status === "done") {
    agent.classList.add("state-done");
  } else if (status === "failed") {
    agent.classList.add("state-failed");
  } else if (status === "safety_blocked" || status === "blocked") {
    agent.classList.add("state-blocked");
  } else if (["queued", "claimed", "working", "in_progress", "IN_PROGRESS"].includes(status)) {
    agent.classList.add("state-working");
  } else {
    agent.classList.add("state-idle");
  }

  const bubble = agent.querySelector(".agent-bubble");
  if (bubble) {
    const label = task || officeSimRoomText[room] || status || "idle";
    bubble.textContent = label.length > 20 ? `${label.slice(0, 20)}…` : label;
  }
}

function syncSimulationStageFromRuntime(agents) {
  if (!Array.isArray(agents)) return;

  agents.forEach((agent) => {
    const config = runtimeAgentMap[agent.agent_key];
    if (!config) return;

    const status = agent.runtime_status || "idle";
    const task = agent.current_task_key || "";
    setSimAgentRoom(config.sprite, config.room, status, task);
  });
}

const originalLoadPixelOfficeRuntimeStatusForSim = loadPixelOfficeRuntimeStatus;
loadPixelOfficeRuntimeStatus = async function() {
  try {
    const response = await fetch("/api/agents/runtime");
    const agents = await response.json();

    if (typeof updatePixelOfficeFromRuntime === "function") {
      updatePixelOfficeFromRuntime(agents);
    }

    syncSimulationStageFromRuntime(agents);
  } catch (error) {
    console.error("Failed to update pixel office simulation status", error);
  }
};

loadPixelOfficeRuntimeStatus();


/* INTERNAL-044: AI Usage Summary */
async function loadAiUsageSummary() {
  const card = document.getElementById("aiUsageSummaryCard");
  if (!card) return;
  if (card.dataset.codexUsageCard === "true") return;

  const usage = await loadJson("/api/ai/usage");

  const limitText = usage.api_tokens_limit === null ? "no API limit tracked" : `${usage.api_tokens_limit}`;
  card.innerHTML = `
    <span>AI API Tokens</span>
    <strong>${usage.api_tokens_today}</strong>
    <small>${limitText} · Codex: ${usage.codex_usage}</small>
  `;
}

/* INTERNAL-045: Tilemap Office Renderer v1 */
const tilemapRows = [
  "########################",
  "#......#......#........#",
  "#..PM..#..EN..#..QA....#",
  "#......#......#........#",
  "#......#......#........#",
  "########..##..##########",
  "#......................#",
  "########..##..##########",
  "#......#......#........#",
  "#..DV..#..MT..#..OW....#",
  "#......#......#........#",
  "#......#......#........#",
  "########################"
];

const tileClassMap = {
  "#": "wall",
  ".": "floor"
};

function buildTilemapOffice() {
  const grid = document.getElementById("tilemapGrid");
  if (!grid || grid.dataset.built === "true") return;

  grid.style.setProperty("--tile-cols", tilemapRows[0].length);
  grid.style.setProperty("--tile-rows", tilemapRows.length);

  grid.innerHTML = tilemapRows.flatMap((row) => {
    return row.split("").map((char) => {
      const cls = tileClassMap[char] || "floor";
      return `<span class="map-tile tile-${cls}"></span>`;
    });
  }).join("");

  grid.dataset.built = "true";
}

const tileAgentPositions = {
  pm: { left: "18%", top: "30%" },
  engineer: { left: "50%", top: "30%" },
  qa: { left: "82%", top: "30%" },
  devops: { left: "18%", top: "78%" },
  meeting: { left: "50%", top: "78%" },
  owner: { left: "82%", top: "78%" }
};

function placeTileAgent(agentId, room, status = "idle", task = "") {
  const agent = document.getElementById(agentId);
  if (!agent) return;

  const pos = tileAgentPositions[room] || tileAgentPositions.meeting;
  agent.style.left = pos.left;
  agent.style.top = pos.top;
  agent.dataset.room = room;
  agent.dataset.status = status;

  agent.classList.remove("state-idle", "state-working", "state-done", "state-blocked", "state-failed");

  if (status === "done") {
    agent.classList.add("state-done");
  } else if (status === "failed") {
    agent.classList.add("state-failed");
  } else if (status === "safety_blocked" || status === "blocked") {
    agent.classList.add("state-blocked");
  } else if (["queued", "claimed", "working", "in_progress", "IN_PROGRESS"].includes(status)) {
    agent.classList.add("state-working");
  } else {
    agent.classList.add("state-idle");
  }

  const bubble = agent.querySelector(".agent-bubble");
  if (bubble) {
    const label = task || status || "idle";
    bubble.textContent = label.length > 20 ? `${label.slice(0, 20)}…` : label;
  }
}

function syncTilemapOfficeFromRuntime(agents) {
  if (!Array.isArray(agents)) return;

  agents.forEach((agent) => {
    const config = runtimeAgentMap[agent.agent_key];
    if (!config) return;

    placeTileAgent(
      config.sprite,
      config.room,
      agent.runtime_status || "idle",
      agent.current_task_key || ""
    );
  });
}

const originalTilemapRuntimeLoader = loadPixelOfficeRuntimeStatus;
loadPixelOfficeRuntimeStatus = async function() {
  try {
    const response = await fetch("/api/agents/runtime");
    const agents = await response.json();

    if (typeof updatePixelOfficeFromRuntime === "function") {
      updatePixelOfficeFromRuntime(agents);
    }

    syncTilemapOfficeFromRuntime(agents);
  } catch (error) {
    console.error("Failed to update tilemap office runtime", error);
  }
};

buildTilemapOffice();
loadPixelOfficeRuntimeStatus();
