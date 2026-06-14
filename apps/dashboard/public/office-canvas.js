/* Pixel Office Canvas Renderer v080
   Adds walking animation: agents lerp to runtime-based target positions.
   When dist > threshold → leg-swing walk cycle. Otherwise → idle bob. */
(() => {
  const COLS = 36;
  const ROWS = 14;
  const TS = 48;
  const W = COLS * TS;
  const H = ROWS * TS;
  const WALK_SPEED = 5; // tiles per second

  const GROUND = [
    "W".repeat(36),
    "W" + "F".repeat(28) + "S".repeat(6) + "W",
    "W" + "F".repeat(28) + "S".repeat(6) + "W",
    "W" + "F".repeat(28) + "S".repeat(6) + "W",
    "W" + "F".repeat(28) + "S".repeat(6) + "W",
    "W" + "F".repeat(28) + "S".repeat(6) + "W",
    "W" + "F".repeat(28) + "S".repeat(6) + "W",
    "W" + "F".repeat(28) + "S".repeat(6) + "W",
    "W" + "F".repeat(28) + "S".repeat(6) + "W",
    "W" + "F".repeat(28) + "S".repeat(6) + "W",
    "W".repeat(36),
    "..WW" + "B".repeat(13) + "WW" + "B".repeat(6) + "W" + "B".repeat(9) + "W",
    "..WW" + "B".repeat(13) + "WW" + "B".repeat(6) + "W" + "B".repeat(9) + "W",
    "..WW" + "B".repeat(13) + "WW" + "B".repeat(6) + "W" + "B".repeat(9) + "W"
  ].map((row) => row.split(""));

  const furniture = [
    ["desk", 2, 2], ["desk", 6, 2], ["desk", 10, 2], ["desk", 14, 2], ["desk", 18, 2], ["desk", 22, 2],
    ["desk", 2, 6], ["desk", 6, 6], ["desk", 10, 6], ["desk", 14, 6], ["desk", 18, 6], ["desk", 22, 6],
    ["monitor", 3, 2], ["monitor", 7, 2], ["monitor", 11, 2], ["monitor", 15, 2], ["monitor", 19, 2], ["monitor", 23, 2],
    ["monitor", 3, 6], ["monitor", 7, 6], ["monitor", 11, 6], ["monitor", 15, 6], ["monitor", 19, 6], ["monitor", 23, 6],
    ["managerDesk", 27, 3], ["monitor", 28, 3],
    ["server", 31, 2], ["server", 31, 3], ["server", 31, 4], ["server", 34, 2], ["server", 34, 3], ["server", 34, 4],
    ["bookshelf", 25, 1], ["bookshelf", 26, 1], ["bookshelf", 27, 1],
    ["plant", 1, 8], ["plant", 13, 8], ["plant", 24, 8], ["plant", 29, 1], ["plant", 34, 8],
    ["sofa", 6, 12], ["table", 10, 12], ["cooler", 14, 11],
    ["meeting", 20, 12], ["meeting", 21, 12], ["whiteboard", 21, 11],
    ["managerDesk", 28, 12], ["monitor", 29, 12], ["plant", 34, 13]
  ];

  const agents = [
    { agent_key: "pm_agent",       label: "PM",    x: 2.35,  y: 3.35,  shirt: "#3b82f6", hair: "#5c3317", skin: "#e8b88a", phase: 0.0 },
    { agent_key: "engineer_agent", label: "ENG",   x: 10.35, y: 3.35,  shirt: "#22c55e", hair: "#111827", skin: "#ffd5a8", phase: 0.25 },
    { agent_key: "qa_agent",       label: "QA",    x: 18.35, y: 3.35,  shirt: "#a855f7", hair: "#422006", skin: "#c06820", phase: 0.5 },
    { agent_key: "devops_agent",   label: "DEVOPS",x: 27.35, y: 4.35,  shirt: "#f59e0b", hair: "#1f2937", skin: "#d6a36a", phase: 0.75 },
    { agent_key: "owner",          label: "OWNER", x: 29.6,  y: 12.55, shirt: "#38bdf8", hair: "#111827", skin: "#ffd5a8", phase: 0.35 }
  ];

  const roomLabels = [
    { label: "PM",          x: 2,  y: 1 },
    { label: "ENGINEERING", x: 9,  y: 1 },
    { label: "QA",          x: 18, y: 1 },
    { label: "DEVOPS",      x: 27, y: 1 },
    { label: "BREAK ROOM",  x: 5,  y: 11 },
    { label: "MEETING",     x: 20, y: 11 },
    { label: "OWNER",       x: 28, y: 11 }
  ];

  /* ── Walking animation state ────────────────────────────── */
  const agentAnimState = new Map();
  for (const a of agents) {
    agentAnimState.set(a.agent_key, {
      cx: a.x, cy: a.y,  // current tile position
      tx: a.x, ty: a.y,  // target tile position
      walkPhase: 0,
      facingRight: true
    });
  }

  /* Home tile per agent */
  const HOME_TILES = {
    pm_agent:       { x: 2.5,  y: 3.5  },
    engineer_agent: { x: 10.5, y: 3.5  },
    qa_agent:       { x: 18.5, y: 3.5  },
    devops_agent:   { x: 27.5, y: 4.5  },
    owner:          { x: 29.6, y: 12.5 }
  };

  /* Room/location → tile position mapping */
  const LOCATION_TILES = {
    pm:               { x: 2.5,  y: 3.5  },
    pm_desk:          { x: 2.5,  y: 3.5  },
    pm_agent:         { x: 2.5,  y: 3.5  },
    engineering:      { x: 10.5, y: 3.5  },
    engineering_desk: { x: 10.5, y: 3.5  },
    engineer:         { x: 10.5, y: 3.5  },
    engineer_agent:   { x: 10.5, y: 3.5  },
    qa:               { x: 18.5, y: 3.5  },
    qa_desk:          { x: 18.5, y: 3.5  },
    qa_agent:         { x: 18.5, y: 3.5  },
    devops:           { x: 27.5, y: 4.5  },
    devops_desk:      { x: 27.5, y: 4.5  },
    devops_agent:     { x: 27.5, y: 4.5  },
    server:           { x: 32.5, y: 4.5  },
    server_room:      { x: 32.5, y: 4.5  },
    meeting:          { x: 14.5, y: 12.5 },
    meeting_room:     { x: 14.5, y: 12.5 },
    break:            { x: 8.5,  y: 12.5 },
    break_room:       { x: 8.5,  y: 12.5 },
    owner:            { x: 29.6, y: 12.5 },
    owner_desk:       { x: 29.6, y: 12.5 }
  };

  function getTargetTile(agentDef, runtime) {
    const loc = (runtime.location || "").toLowerCase().replace(/-/g, "_").trim();
    if (loc && LOCATION_TILES[loc]) return LOCATION_TILES[loc];
    return HOME_TILES[agentDef.agent_key] || { x: agentDef.x, y: agentDef.y };
  }

  /* ── Custom tileset support ────────────────────────────── */
  let pixelOfficeAssetConfig = null;
  let customTilesetImage = null;
  let customTilesReady = false;

  function shouldUseCustomTiles() {
    return Boolean(
      pixelOfficeAssetConfig &&
      pixelOfficeAssetConfig.mode === "custom" &&
      customTilesetImage &&
      customTilesReady
    );
  }

  function tileKeyForGround(tile) {
    if (tile === "F") return "FLOOR_OFFICE";
    if (tile === "B") return "FLOOR_BREAK";
    if (tile === "W") return "WALL";
    if (tile === "S") return "SERVER";
    return null;
  }

  function tileKeyForFurniture(type) {
    const map = {
      desk: "DESK_LEFT", managerDesk: "DESK_LEFT", monitor: "MONITOR",
      server: "SERVER", bookshelf: "BOOKSHELF", plant: "PLANT", sofa: "SOFA",
      table: "TABLE_SMALL", cooler: "COOLER", meeting: "TABLE_SMALL", whiteboard: "WHITEBOARD"
    };
    return map[type] || null;
  }

  function drawMappedTile(tileKey, tx, ty) {
    if (!shouldUseCustomTiles() || !tileKey) return false;
    const mapping = pixelOfficeAssetConfig.tileMapping || {};
    const id = Number(mapping[tileKey]);
    if (!Number.isFinite(id) || id < 0) return false;
    const tileset = pixelOfficeAssetConfig.assets?.tileset || {};
    const tileWidth = Number(tileset.tileWidth || 48);
    const tileHeight = Number(tileset.tileHeight || 48);
    const tilesPerRow = Number(tileset.tilesPerRow || 16);
    ctx.drawImage(customTilesetImage, (id % tilesPerRow) * tileWidth, Math.floor(id / tilesPerRow) * tileHeight, tileWidth, tileHeight, tx * TS, ty * TS, TS, TS);
    return true;
  }

  function drawMappedGroundTile(tile, tx, ty) { return drawMappedTile(tileKeyForGround(tile), tx, ty); }

  function drawMappedFurnitureTile(type, x, y) {
    if (!shouldUseCustomTiles()) return false;
    if (type === "desk" || type === "managerDesk") {
      return drawMappedTile("DESK_LEFT", x, y) || drawMappedTile("DESK_RIGHT", x + 1, y);
    }
    return drawMappedTile(tileKeyForFurniture(type), x, y);
  }

  async function loadAssetConfig() {
    try {
      const response = await fetch("/assets/office/config.json", { cache: "no-store" });
      if (!response.ok) return;
      const config = await response.json();
      pixelOfficeAssetConfig = config;
      window.AI_COMPANY_PIXEL_OFFICE_ASSET_CONFIG = config;
      if (config.mode !== "custom") return;
      const filename = config.assets?.tileset?.filename;
      if (!filename) return;
      const image = new Image();
      image.onload = () => { customTilesetImage = image; customTilesReady = true; };
      image.onerror = () => { customTilesReady = false; };
      image.src = `/assets/office/${filename}`;
    } catch {
      /* silently fall through to procedural renderer */
    }
  }

  /* ── Canvas state ──────────────────────────────────────── */
  let runtimeByAgent = {};
  let canvas = null;
  let ctx = null;
  let mounted = false;
  let lastRenderTime = 0;

  function pr(x, y, w, h, color) {
    ctx.fillStyle = color;
    ctx.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h));
  }

  function hideLegacyDom(stage) {
    stage.querySelectorAll(".tilemap-grid, .office-grid, .office-room, .office-hallway, .office-sim-bg, .clean-office-floor, .room-zone, .map-prop, .tile-agent, .office-agent")
      .forEach((el) => { el.style.display = "none"; });
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
    canvas.style.display = "block";
    canvas.style.imageRendering = "pixelated";
    ctx = canvas.getContext("2d", { alpha: false });
    ctx.imageSmoothingEnabled = false;
    mounted = true;
    return true;
  }

  /* ── Ground ────────────────────────────────────────────── */
  function drawGround() {
    for (let y = 0; y < ROWS; y++) {
      for (let x = 0; x < COLS; x++) {
        const tile = GROUND[y][x];
        const px = x * TS, py = y * TS;
        if (drawMappedGroundTile(tile, x, y)) continue;
        if (tile === ".") { pr(px, py, TS, TS, "#070b18"); continue; }
        if (tile === "F") { pr(px, py, TS, TS, "#b8bac8"); pr(px, py, TS, 2, "#d8dae8"); pr(px, py, 2, TS, "#9ca0b3"); pr(px, py + TS - 2, TS, 2, "#9699aa"); continue; }
        if (tile === "B") { pr(px, py, TS, TS, "#c4b894"); pr(px, py, TS, 2, "#ded0a5"); pr(px, py, 2, TS, "#a89b7d"); continue; }
        if (tile === "S") { pr(px, py, TS, TS, "#31384a"); pr(px + 4, py + 4, TS - 8, TS - 8, "#22293a"); continue; }
        if (tile === "W") { pr(px, py, TS, TS, "#6d7088"); pr(px, py, TS, 8, "#8d91aa"); pr(px, py + TS - 6, TS, 6, "#4c506a"); pr(px + TS - 5, py, 5, TS, "#555a74"); }
      }
    }
  }

  /* ── Furniture ─────────────────────────────────────────── */
  function drawDesk(x, y, wide = 2) {
    const px = x * TS, py = y * TS;
    pr(px, py + 18, TS * wide, 26, "#c99855");
    pr(px, py + 18, TS * wide, 7, "#e2b66e");
    pr(px + 4, py + 31, TS * wide - 8, 8, "#9a6d32");
    pr(px + 6, py + 40, 8, 8, "#6e4c20");
    pr(px + TS * wide - 14, py + 40, 8, 8, "#6e4c20");
  }

  function drawMonitor(x, y, time) {
    const px = x * TS, py = y * TS;
    const on = Math.floor(time / 4500) % 10 !== 0;
    pr(px + 6, py - 25, 36, 26, "#111827");
    pr(px + 10, py - 21, 28, 18, on ? "#1d4ed8" : "#0f172a");
    if (on) { pr(px + 14, py - 17, 15, 2, "#93c5fd"); pr(px + 14, py - 11, 22, 2, "#60a5fa"); pr(px + 14, py - 5, 12, 2, "#60a5fa"); }
    pr(px + 20, py + 2, 8, 12, "#1f2937");
    pr(px + 13, py + 13, 22, 5, "#111827");
  }

  function drawPlant(x, y, time) {
    const px = x * TS, py = y * TS;
    const sway = Math.sin(time / 900 + x) * 3;
    pr(px + 15, py + 28, 20, 20, "#8b4a33");
    pr(px + 18, py + 31, 14, 5, "#5b2f22");
    pr(px + 12 + sway, py + 8, 12, 22, "#2f7d32");
    pr(px + 25 + sway, py + 10, 14, 18, "#3fa447");
    pr(px + 18 + sway, py - 2, 16, 26, "#4ade80");
  }

  function drawServer(x, y, time) {
    const px = x * TS, py = y * TS;
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
      if (drawMappedFurnitureTile(type, x, y)) continue;
      if (type === "desk" || type === "managerDesk") { drawDesk(x, y, 2); continue; }
      if (type === "monitor") { drawMonitor(x, y, time); continue; }
      if (type === "plant") { drawPlant(x, y, time); continue; }
      if (type === "server") { drawServer(x, y, time); continue; }

      const px = x * TS, py = y * TS;
      if (type === "bookshelf") {
        pr(px + 2, py + 2, 44, 40, "#7a5530");
        pr(px + 4, py + 8, 8, 14, "#ef4444");
        pr(px + 15, py + 8, 8, 14, "#3b82f6");
        pr(px + 26, py + 8, 8, 14, "#22c55e");
        pr(px + 4, py + 27, 32, 4, "#a16b3d");
        continue;
      }
      if (type === "sofa") { pr(px + 2, py + 15, 42, 25, "#4f66a3"); pr(px + 5, py + 5, 36, 18, "#344d86"); continue; }
      if (type === "table") { pr(px + 5, py + 18, 38, 16, "#c99855"); pr(px + 9, py + 32, 7, 15, "#7a542c"); pr(px + 32, py + 32, 7, 15, "#7a542c"); continue; }
      if (type === "cooler") { pr(px + 14, py + 4, 20, 38, "#93c5fd"); pr(px + 17, py + 7, 14, 14, "#dbeafe"); pr(px + 17, py + 27, 14, 8, "#2563eb"); continue; }
      if (type === "meeting") { drawDesk(x, y, 1); continue; }
      if (type === "whiteboard") { pr(px + 5, py + 7, 38, 22, "#e5e7eb"); pr(px + 8, py + 12, 25, 2, "#2563eb"); pr(px + 8, py + 18, 18, 2, "#2563eb"); }
    }
  }

  function drawRoomLabels() {
    for (const room of roomLabels) {
      const x = room.x * TS, y = room.y * TS;
      const width = Math.max(42, room.label.length * 8 + 16);
      pr(x, y, width, 18, "rgba(15,23,42,0.72)");
      pr(x, y + 16, width, 2, "rgba(56,189,248,0.55)");
      ctx.fillStyle = "#67e8f9";
      ctx.font = "bold 10px monospace";
      ctx.fillText(room.label, x + 8, y + 12);
    }
  }

  /* ── Agent drawing with walk animation ─────────────────── */
  function drawAgent(agent, time) {
    const state = agentAnimState.get(agent.agent_key);
    if (!state) return;

    const runtime = runtimeByAgent[agent.agent_key] || {};
    const status = runtime.runtime_status || "idle";
    const task = runtime.current_task_key || "";

    const dx = state.tx - state.cx;
    const dy = state.ty - state.cy;
    const dist = Math.sqrt(dx * dx + dy * dy);
    const isWalking = dist > 0.08;

    const bobY = isWalking ? 0 : Math.sin(time / 1000 + agent.phase * 10) * 2;
    const x = Math.round(state.cx * TS);
    const y = Math.round(state.cy * TS + bobY);

    /* Shadow */
    pr(x - 6, y + 39, 36, 7, "rgba(0,0,0,0.25)");

    if (isWalking) {
      /* Walk cycle: 4 phases, legs alternating */
      const cyclePos = (state.walkPhase % 1) * 4;
      const legAFwd = cyclePos < 2;
      const walkBob = Math.abs(Math.sin(state.walkPhase * Math.PI * 2)) * 2;

      const legAY = legAFwd ? y + 22 : y + 30;
      const legBY = legAFwd ? y + 30 : y + 22;
      const legAH = legAFwd ? 18 : 12;
      const legBH = legAFwd ? 12 : 18;

      pr(x + 2,  legAY, 8, legAH, "#334155");
      pr(x + 15, legBY, 8, legBH, "#334155");
      pr(x, y + 14 - walkBob, 25, 20, agent.shirt);
    } else {
      /* Idle */
      pr(x + 2,  y + 26, 8, 18, "#334155");
      pr(x + 15, y + 26, 8, 18, "#334155");
      pr(x, y + 14, 25, 20, agent.shirt);
    }

    /* Head */
    pr(x + 5, y + 2,  15, 15, agent.skin);
    pr(x + 4, y - 1,  17, 8,  agent.hair);
    pr(x + 8, y + 9,  3,  2,  "#111827");
    pr(x + 15, y + 9, 3,  2,  "#111827");

    /* Name label */
    const labelW = Math.max(38, agent.label.length * 8 + 14);
    pr(x - 6, y - 30, labelW, 18, "rgba(15,23,42,0.9)");
    pr(x - 3, y - 26, 7, 7, status === "done" ? "#22c55e" : status === "idle" ? "#64748b" : "#38bdf8");
    ctx.fillStyle = "#e5e7eb";
    ctx.font = "bold 10px monospace";
    ctx.fillText(agent.label, x + 8, y - 18);

    /* Task badge */
    if (task) {
      pr(x - 6, y - 12, Math.max(38, task.length * 6 + 12), 14, "rgba(30,41,59,0.85)");
      ctx.fillStyle = "#93c5fd";
      ctx.font = "9px monospace";
      ctx.fillText(task, x, y - 2);
    }
  }

  /* ── Runtime polling ────────────────────────────────────── */
  async function refreshRuntime() {
    try {
      const response = await fetch("/api/agents/runtime", { cache: "no-store" });
      if (!response.ok) return;
      const data = await response.json();
      const rows = Array.isArray(data) ? data : (data.agents || data.rows || []);
      runtimeByAgent = {};
      for (const row of rows) runtimeByAgent[row.agent_key] = row;
    } catch {
      runtimeByAgent = runtimeByAgent || {};
    }
  }

  /* ── Render loop ────────────────────────────────────────── */
  function render(time) {
    if (!mount()) { requestAnimationFrame(render); return; }

    const dt = Math.min((time - lastRenderTime) / 1000, 0.1);
    lastRenderTime = time;

    /* Update agent positions */
    for (const agent of agents) {
      const state = agentAnimState.get(agent.agent_key);
      if (!state) continue;

      const runtime = runtimeByAgent[agent.agent_key] || {};
      const target = getTargetTile(agent, runtime);
      state.tx = target.x;
      state.ty = target.y;

      const dx = state.tx - state.cx;
      const dy = state.ty - state.cy;
      const dist = Math.sqrt(dx * dx + dy * dy);

      if (dist > 0.05) {
        if (dx !== 0) state.facingRight = dx > 0;
        const moveDist = WALK_SPEED * dt;
        if (moveDist >= dist) {
          state.cx = state.tx;
          state.cy = state.ty;
        } else {
          state.cx += (dx / dist) * moveDist;
          state.cy += (dy / dist) * moveDist;
        }
        state.walkPhase = (state.walkPhase + dt * 4) % 1;
      } else {
        state.cx = state.tx;
        state.cy = state.ty;
      }
    }

    /* Draw frame */
    ctx.fillStyle = "#070b18";
    ctx.fillRect(0, 0, W, H);

    drawGround();
    drawFurniture(time);
    drawRoomLabels();

    /* Sort by animated Y so agents in back rows are drawn first */
    const sorted = [...agents].sort((a, b) => {
      const sa = agentAnimState.get(a.agent_key) || a;
      const sb = agentAnimState.get(b.agent_key) || b;
      return (sa.cy || a.y) - (sb.cy || b.y);
    });
    for (const agent of sorted) drawAgent(agent, time);

    /* Vignette */
    const gradient = ctx.createRadialGradient(W / 2, H / 2, H * 0.25, W / 2, H / 2, H * 0.9);
    gradient.addColorStop(0, "rgba(0,0,0,0)");
    gradient.addColorStop(1, "rgba(0,0,20,0.45)");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, W, H);

    requestAnimationFrame(render);
  }

  function boot() {
    loadAssetConfig();
    refreshRuntime();
    setInterval(refreshRuntime, 5000);

    const observer = new MutationObserver(() => { if (!mounted) mount(); });
    observer.observe(document.body, { childList: true, subtree: true });

    requestAnimationFrame(render);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
