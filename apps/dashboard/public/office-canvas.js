/* INTERNAL-072: Production-style Pixel Office Renderer
   Uses uploaded pixel-office-production concepts:
   - layered ground map
   - furniture object list
   - animated agent characters
   - no old background-map flicker
*/
(() => {
  const COLS = 20;
  const ROWS = 14;
  const TS = 48;
  const W = COLS * TS;
  const H = ROWS * TS;

  const GROUND = [
    "WWWWWWWWWWWWWWWWWWWW",
    "WFFFFFFFFFFFFFFFFFSW",
    "WFFFFFFFFFFFFFFFFFSW",
    "WFFFFFFFFFFFFFFFFFSW",
    "WFFFFFFFFFFFFFFFFFSW",
    "WFFFFFFFFFFFFFFFFFSW",
    "WFFFFFFFFFFFFFFFFFSW",
    "WFFFFFFFFFFFFFFFFFSW",
    "WFFFFFFFFFFFFFFFFFSW",
    "WFFFFFFFFFFFFFFFFFSW",
    "WWWWWWWWWWWWWWWWWWWW",
    "..WWBBBBBBB W.BBBBW.",
    "..WBBBBBBBB W.BBBBW.",
    "..WBBBBBBBB W.BBBBW."
  ].map((row) => row.replaceAll(" ", ".").split(""));

  const furniture = [
    ["desk", 2, 2], ["desk", 6, 2], ["desk", 10, 2],
    ["desk", 2, 6], ["desk", 6, 6], ["desk", 10, 6],
    ["managerDesk", 14, 3],
    ["monitor", 3, 2], ["monitor", 7, 2], ["monitor", 11, 2],
    ["monitor", 3, 6], ["monitor", 7, 6], ["monitor", 11, 6],
    ["monitor", 15, 3],
    ["server", 18, 2], ["server", 18, 3], ["server", 18, 4],
    ["bookshelf", 14, 1], ["bookshelf", 15, 1], ["bookshelf", 16, 1],
    ["plant", 1, 8], ["plant", 13, 8], ["plant", 17, 1], ["plant", 18, 8],
    ["sofa", 5, 12], ["table", 7, 12], ["cooler", 9, 11],
    ["meeting", 14, 12], ["meeting", 15, 12], ["plant", 17, 13],
    ["whiteboard", 8, 1]
  ];

  const agents = [
    { agent_key: "pm_agent", label: "PM", x: 2.35, y: 3.35, shirt: "#3b82f6", hair: "#5c3317", skin: "#e8b88a", phase: 0.0 },
    { agent_key: "engineer_agent", label: "ENG", x: 6.35, y: 3.35, shirt: "#22c55e", hair: "#111827", skin: "#ffd5a8", phase: 0.25 },
    { agent_key: "qa_agent", label: "QA", x: 10.35, y: 3.35, shirt: "#a855f7", hair: "#422006", skin: "#c06820", phase: 0.5 },
    { agent_key: "devops_agent", label: "DEVOPS", x: 14.35, y: 4.35, shirt: "#f59e0b", hair: "#1f2937", skin: "#d6a36a", phase: 0.75 },
    { agent_key: "owner", label: "OWNER", x: 14.6, y: 12.55, shirt: "#38bdf8", hair: "#111827", skin: "#ffd5a8", phase: 0.35 }
  ];

  let runtimeByAgent = {};
  let canvas = null;
  let ctx = null;
  let mounted = false;

  function pr(x, y, w, h, color) {
    ctx.fillStyle = color;
    ctx.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h));
  }

  function hideLegacyDom(stage) {
    stage.querySelectorAll(".tilemap-grid, .office-grid, .office-room, .office-hallway, .office-sim-bg, .clean-office-floor, .room-zone, .map-prop, .tile-agent, .office-agent").forEach((el) => {
      el.style.display = "none";
    });
  }

  function mount() {
    if (mounted && canvas && document.body.contains(canvas)) return true;

    const office = document.querySelector("#tilemapOffice");
    const stage = document.querySelector("#tilemapOffice .tilemap-stage");

    if (!office || !stage) return false;

    office.classList.add("canvas-floorplan-mode", "production-floorplan-mode");
    hideLegacyDom(stage);

    canvas = stage.querySelector("#officeCanvas");

    if (!canvas) {
      canvas = document.createElement("canvas");
      canvas.id = "officeCanvas";
      canvas.setAttribute("aria-label", "Production Pixel Office Map");
      stage.appendChild(canvas);
    }

    canvas.width = W;
    canvas.height = H;
    canvas.style.width = "100%";
    canvas.style.height = "auto";
    canvas.style.display = "block";
    canvas.style.imageRendering = "pixelated";

    ctx = canvas.getContext("2d", { alpha: false });
    ctx.imageSmoothingEnabled = false;

    mounted = true;
    return true;
  }

  function drawGround() {
    for (let y = 0; y < ROWS; y += 1) {
      for (let x = 0; x < COLS; x += 1) {
        const tile = GROUND[y][x];
        const px = x * TS;
        const py = y * TS;

        if (tile === ".") {
          pr(px, py, TS, TS, "#070b18");
        }

        if (tile === "F") {
          pr(px, py, TS, TS, "#b8bac8");
          pr(px, py, TS, 2, "#d8dae8");
          pr(px, py, 2, TS, "#9ca0b3");
          pr(px, py + TS - 2, TS, 2, "#9699aa");
        }

        if (tile === "B") {
          pr(px, py, TS, TS, "#c4b894");
          pr(px, py, TS, 2, "#ded0a5");
          pr(px, py, 2, TS, "#a89b7d");
        }

        if (tile === "S") {
          pr(px, py, TS, TS, "#31384a");
          pr(px + 4, py + 4, TS - 8, TS - 8, "#22293a");
        }

        if (tile === "W") {
          pr(px, py, TS, TS, "#6d7088");
          pr(px, py, TS, 8, "#8d91aa");
          pr(px, py + TS - 6, TS, 6, "#4c506a");
          pr(px + TS - 5, py, 5, TS, "#555a74");
        }
      }
    }
  }

  function drawDesk(x, y, wide = 2) {
    const px = x * TS;
    const py = y * TS;
    pr(px, py + 18, TS * wide, 26, "#c99855");
    pr(px, py + 18, TS * wide, 7, "#e2b66e");
    pr(px + 4, py + 31, TS * wide - 8, 8, "#9a6d32");
    pr(px + 6, py + 40, 8, 8, "#6e4c20");
    pr(px + TS * wide - 14, py + 40, 8, 8, "#6e4c20");
  }

  function drawMonitor(x, y, time) {
    const px = x * TS;
    const py = y * TS;
    const on = Math.floor(time / 4500) % 10 !== 0;

    pr(px + 6, py - 25, 36, 26, "#111827");
    pr(px + 10, py - 21, 28, 18, on ? "#1d4ed8" : "#0f172a");

    if (on) {
      pr(px + 14, py - 17, 15, 2, "#93c5fd");
      pr(px + 14, py - 11, 22, 2, "#60a5fa");
      pr(px + 14, py - 5, 12, 2, "#60a5fa");
    }

    pr(px + 20, py + 2, 8, 12, "#1f2937");
    pr(px + 13, py + 13, 22, 5, "#111827");
  }

  function drawPlant(x, y, time) {
    const px = x * TS;
    const py = y * TS;
    const sway = Math.sin(time / 900 + x) * 3;

    pr(px + 15, py + 28, 20, 20, "#8b4a33");
    pr(px + 18, py + 31, 14, 5, "#5b2f22");
    pr(px + 12 + sway, py + 8, 12, 22, "#2f7d32");
    pr(px + 25 + sway, py + 10, 14, 18, "#3fa447");
    pr(px + 18 + sway, py - 2, 16, 26, "#4ade80");
  }

  function drawServer(x, y, time) {
    const px = x * TS;
    const py = y * TS;
    const blink = Math.floor(time / 600) % 2;

    pr(px + 5, py + 3, 36, 42, "#1f2937");
    pr(px + 8, py + 7, 30, 7, "#374151");
    pr(px + 8, py + 20, 30, 7, "#374151");
    pr(px + 8, py + 33, 30, 7, "#374151");
    pr(px + 33, py + 9, 4, 4, blink ? "#22c55e" : "#14532d");
    pr(px + 33, py + 22, 4, 4, "#f59e0b");
  }

  function drawFurniture(time) {
    for (const [type, x, y] of furniture) {
      if (type === "desk") drawDesk(x, y, 2);
      if (type === "managerDesk") drawDesk(x, y, 2);
      if (type === "monitor") drawMonitor(x, y, time);
      if (type === "plant") drawPlant(x, y, time);
      if (type === "server") drawServer(x, y, time);

      if (type === "bookshelf") {
        const px = x * TS;
        const py = y * TS;
        pr(px + 2, py + 2, 44, 40, "#7a5530");
        pr(px + 4, py + 8, 8, 14, "#ef4444");
        pr(px + 15, py + 8, 8, 14, "#3b82f6");
        pr(px + 26, py + 8, 8, 14, "#22c55e");
        pr(px + 4, py + 27, 32, 4, "#a16b3d");
      }

      if (type === "sofa") {
        const px = x * TS;
        const py = y * TS;
        pr(px + 2, py + 15, 42, 25, "#4f66a3");
        pr(px + 5, py + 5, 36, 18, "#344d86");
      }

      if (type === "table") {
        const px = x * TS;
        const py = y * TS;
        pr(px + 5, py + 18, 38, 16, "#c99855");
        pr(px + 9, py + 32, 7, 15, "#7a542c");
        pr(px + 32, py + 32, 7, 15, "#7a542c");
      }

      if (type === "cooler") {
        const px = x * TS;
        const py = y * TS;
        pr(px + 14, py + 4, 20, 38, "#93c5fd");
        pr(px + 17, py + 7, 14, 14, "#dbeafe");
        pr(px + 17, py + 27, 14, 8, "#2563eb");
      }

      if (type === "meeting") {
        drawDesk(x, y, 1);
      }

      if (type === "whiteboard") {
        const px = x * TS;
        const py = y * TS;
        pr(px + 5, py + 7, 38, 22, "#e5e7eb");
        pr(px + 8, py + 12, 25, 2, "#2563eb");
        pr(px + 8, py + 18, 18, 2, "#2563eb");
      }
    }
  }

  function drawAgent(agent, time) {
    const runtime = runtimeByAgent[agent.agent_key] || {};
    const status = runtime.runtime_status || "idle";
    const task = runtime.current_task_key || "";

    const x = agent.x * TS;
    const y = agent.y * TS + Math.sin(time / 1000 + agent.phase * 10) * 2;

    pr(x - 6, y + 39, 36, 7, "rgba(0,0,0,0.25)");
    pr(x + 2, y + 26, 8, 18, "#334155");
    pr(x + 15, y + 26, 8, 18, "#334155");
    pr(x, y + 14, 25, 20, agent.shirt);
    pr(x + 5, y + 2, 15, 15, agent.skin);
    pr(x + 4, y - 1, 17, 8, agent.hair);
    pr(x + 8, y + 9, 3, 2, "#111827");
    pr(x + 15, y + 9, 3, 2, "#111827");

    const labelW = Math.max(38, agent.label.length * 8 + 14);
    pr(x - 6, y - 30, labelW, 18, "rgba(15,23,42,0.9)");
    pr(x - 3, y - 26, 7, 7, status === "done" ? "#22c55e" : status === "idle" ? "#64748b" : "#38bdf8");

    ctx.fillStyle = "#e5e7eb";
    ctx.font = "bold 10px monospace";
    ctx.fillText(agent.label, x + 8, y - 18);

    if (task) {
      pr(x - 6, y - 12, Math.max(38, task.length * 6 + 12), 14, "rgba(30,41,59,0.85)");
      ctx.fillStyle = "#93c5fd";
      ctx.font = "9px monospace";
      ctx.fillText(task, x, y - 2);
    }
  }

  async function refreshRuntime() {
    try {
      const response = await fetch("/api/agents/runtime", { cache: "no-store" });
      if (!response.ok) return;

      const data = await response.json();
      const rows = Array.isArray(data) ? data : (data.agents || data.rows || []);
      runtimeByAgent = {};

      for (const row of rows) {
        runtimeByAgent[row.agent_key] = row;
      }
    } catch {
      runtimeByAgent = runtimeByAgent || {};
    }
  }

  function render(time) {
    if (!mount()) {
      requestAnimationFrame(render);
      return;
    }

    ctx.fillStyle = "#070b18";
    ctx.fillRect(0, 0, W, H);

    drawGround();
    drawFurniture(time);

    for (const agent of [...agents].sort((a, b) => a.y - b.y)) {
      drawAgent(agent, time);
    }

    const gradient = ctx.createRadialGradient(W / 2, H / 2, H * 0.25, W / 2, H / 2, H * 0.9);
    gradient.addColorStop(0, "rgba(0,0,0,0)");
    gradient.addColorStop(1, "rgba(0,0,20,0.45)");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, W, H);

    requestAnimationFrame(render);
  }

  function boot() {
    refreshRuntime();
    setInterval(refreshRuntime, 5000);

    const observer = new MutationObserver(() => {
      if (mounted) return;
      mount();
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });

    requestAnimationFrame(render);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
