async function loadJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to load ${url}`);
  return res.json();
}

function card(label, value) {
  return `<div class="card"><span>${label}</span><strong>${value}</strong></div>`;
}

function renderTasks(tasks) {
  return tasks.map(task => `
    <div class="item">
      <strong>${task.task_key}</strong> — ${task.title}<br>
      <span class="badge">${task.status}</span>
      <span>${task.agent}</span>
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

async function main() {
  const [summary, tasks, events] = await Promise.all([
    loadJson("/api/summary"),
    loadJson("/api/tasks"),
    loadJson("/api/events")
  ]);

  document.getElementById("summaryCards").innerHTML = [
    card("Client Tasks", summary.client_tasks),
    card("Internal Tasks", summary.internal_tasks),
    card("Waiting Owner", summary.waiting_owner),
    card("Accepted", summary.accepted),
    card("Needs Attention", summary.needs_attention)
  ].join("");

  document.getElementById("tasks").innerHTML = renderTasks(tasks);
  document.getElementById("events").innerHTML = renderEvents(events);
}

main().catch(error => {
  document.body.innerHTML = `<pre>${error.stack}</pre>`;
});


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
