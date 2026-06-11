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
