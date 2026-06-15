/* Pixel Office Canvas Renderer v090
   Dynamic character poses driven by real-time agent runtime status.
   Walking animation: agents lerp to location-based target tiles.
   Pose system: idle / typing / talking / thinking / stressed / sleeping */
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
    // Main desks — one row only (PM / Eng / QA / secondary)
    ["desk", 2, 2], ["desk", 6, 2], ["desk", 10, 2], ["desk", 14, 2], ["desk", 18, 2], ["desk", 22, 2],
    ["monitor", 3, 2], ["monitor", 7, 2], ["monitor", 11, 2], ["monitor", 15, 2], ["monitor", 19, 2], ["monitor", 23, 2],
    // DevOps desk
    ["managerDesk", 27, 3], ["monitor", 28, 3],
    // Server room
    ["server", 31, 2], ["server", 31, 3], ["server", 31, 4], ["server", 34, 2], ["server", 34, 3], ["server", 34, 4],
    // Bookshelves
    ["bookshelf", 25, 1], ["bookshelf", 26, 1], ["bookshelf", 27, 1],
    // Plants
    ["plant", 1, 4], ["plant", 1, 8], ["plant", 13, 8], ["plant", 24, 8], ["plant", 29, 1], ["plant", 34, 8],
    // Break room
    ["sofa", 6, 12], ["chair", 9, 12], ["chair", 11, 12], ["table", 10, 12], ["cooler", 14, 11],
    // Meeting room — whiteboard on left wall, tables inside
    ["whiteboard", 19, 12], ["meeting", 20, 12], ["meeting", 21, 12],
    // Owner area
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

  /* ── Animation state machine ───────────────────────────────── */
  const ANIM_IDLE      = "idle";
  const ANIM_TYPING    = "typing";
  const ANIM_TALKING   = "talking";
  const ANIM_THINKING  = "thinking";
  const ANIM_STRESSED  = "stressed";
  const ANIM_SLEEPING  = "sleeping";
  const ANIM_DONE      = "done";

  const STATUS_ANIM_MAP = {
    idle: ANIM_IDLE, done: ANIM_DONE, completed: ANIM_IDLE,
    claimed: ANIM_TYPING,
    planning: ANIM_TALKING,
    working: ANIM_TYPING, implementing: ANIM_TYPING, in_progress: ANIM_TYPING,
    reviewing: ANIM_THINKING, testing: ANIM_THINKING,
    deploying: ANIM_TYPING, monitoring: ANIM_TYPING,
    failed: ANIM_STRESSED, stuck: ANIM_STRESSED, blocked: ANIM_STRESSED,
    sleeping: ANIM_SLEEPING
  };

  function getAnimState(runtimeStatus, elapsedSec) {
    const s = String(runtimeStatus || "idle").toLowerCase().replace(/[-\s]/g, "_");
    const activeStatus = s !== "idle" && s !== "done" && s !== "completed";
    if (activeStatus && elapsedSec > 600) return ANIM_SLEEPING;
    return STATUS_ANIM_MAP[s] || (s !== "idle" ? ANIM_TYPING : ANIM_IDLE);
  }

  function getStatusColor(animState) {
    if (animState === ANIM_IDLE)     return "#64748b";
    if (animState === ANIM_DONE)     return "#22c55e";
    if (animState === ANIM_TYPING)   return "#38bdf8";
    if (animState === ANIM_TALKING)  return "#a78bfa";
    if (animState === ANIM_THINKING) return "#34d399";
    if (animState === ANIM_STRESSED) return "#f87171";
    if (animState === ANIM_SLEEPING) return "#94a3b8";
    return "#38bdf8";
  }

  /* ── Walking animation state ────────────────────────────────── */
  const agentAnimState = new Map();
  for (const a of agents) {
    agentAnimState.set(a.agent_key, {
      cx: a.x, cy: a.y,
      tx: a.x, ty: a.y,
      ftx: a.x, fty: a.y,
      waypoint: null,
      walkPhase: 0,
      facingRight: true
    });
  }

  /* ── Break room seating ────────────────────────────────────── */
  const BREAK_ROOM_SEATS = [
    { id: "sofa_l",  x: 6.5,  y: 12.5, type: "sofa",     occupant: null },
    { id: "sofa_r",  x: 7.5,  y: 12.5, type: "sofa",     occupant: null },
    { id: "chair_l", x: 9.5,  y: 12.5, type: "chair",    occupant: null },
    { id: "chair_r", x: 11.5, y: 12.5, type: "chair",    occupant: null },
    { id: "cooler",  x: 13.5, y: 12.0, type: "standing", occupant: null },
  ];

  const seatAllocations = new Map();

  function allocateSeat(agentKey) {
    if (seatAllocations.has(agentKey)) return seatAllocations.get(agentKey);
    const seat = BREAK_ROOM_SEATS.find(s => !s.occupant);
    if (!seat) return null;
    seat.occupant = agentKey;
    seatAllocations.set(agentKey, seat);
    return seat;
  }

  function freeSeat(agentKey) {
    const seat = seatAllocations.get(agentKey);
    if (!seat) return;
    seat.occupant = null;
    seatAllocations.delete(agentKey);
  }

  function isBreakRoomTarget(tx, ty) {
    return Math.abs(tx - 8.5) < 0.1 && Math.abs(ty - 12.5) < 0.1;
  }

  /* ── Door waypoint routing ──────────────────────────────────── */
  /* Row 10 is a solid wall. Agents crossing between main office
     (y < 10) and bottom rooms (y > 10) must pass through a door. */
  const DOOR_XS = [8.5, 21.0, 30.0];

  function getWaypointDoorX(toX) {
    return DOOR_XS.reduce((best, dx) =>
      Math.abs(dx - toX) < Math.abs(best - toX) ? dx : best, DOOR_XS[0]);
  }

  function needsWaypoint(fromY, toY) {
    return (fromY < 10 && toY > 10) || (fromY > 10 && toY < 10);
  }

  /* ── Thought bubbles ────────────────────────────────────────── */
  const AGENT_THOUGHTS = {
    pm_agent: {
      idle:     ["☕ Break time", "Pondering...", "Reviewing"],
      typing:   ["📋 Planning", "Writing spec", "Analyzing"],
      talking:  ["👥 In meeting", "Discussing", "Aligning"],
      thinking: ["🔍 Reviewing", "Checking..."],
      stressed: ["🚨 Blocked!", "Need help!"],
      sleeping: ["ZZZ...", "Napping"],
    },
    engineer_agent: {
      idle:     ["☕ Coffee", "Chilling...", "Pondering"],
      typing:   ["💻 Coding", "Building...", "Fixing"],
      talking:  ["👥 Code review", "Syncing"],
      thinking: ["🔍 Debugging", "Analyzing"],
      stressed: ["🐛 Bug hunt!", "On fire!"],
      sleeping: ["ZZZ...", "Napping"],
    },
    qa_agent: {
      idle:     ["☕ Break", "Chilling...", "Pondering"],
      typing:   ["🧪 Testing", "Verifying", "Checking"],
      talking:  ["👥 Test plan", "Discussion"],
      thinking: ["👀 Reviewing", "Testing..."],
      stressed: ["🚨 Failed!", "Bugs found!"],
      sleeping: ["ZZZ...", "Napping"],
    },
    devops_agent: {
      idle:     ["☕ Break", "Chilling...", "Monitoring"],
      typing:   ["🚀 Deploying", "Managing", "Building"],
      talking:  ["👥 Infra talk", "Planning"],
      thinking: ["📊 Watching", "Monitoring"],
      stressed: ["🔥 On fire!", "Down alert!"],
      sleeping: ["ZZZ...", "Napping"],
    },
    owner: {
      idle:     ["☕ Break", "Reviewing", "Planning"],
      typing:   ["📝 Reviewing", "Approving"],
      talking:  ["👥 In meeting", "Discussing"],
      thinking: ["🤔 Deciding", "Reviewing"],
      stressed: ["😤 Urgent!", "Action!"],
      sleeping: ["ZZZ...", "Resting"],
    },
  };

  const agentThoughtState = new Map();

  function getAgentCurrentThought(agentKey, animState) {
    const now = Date.now();
    const cacheKey = agentKey + ":" + animState;
    let ts = agentThoughtState.get(cacheKey);
    if (!ts || now >= ts.nextRotate) {
      const pool = (AGENT_THOUGHTS[agentKey] || {})[animState] || ["💭 Thinking"];
      const thought = pool[Math.floor(Math.random() * pool.length)];
      ts = { thought, nextRotate: now + 10000 };
      agentThoughtState.set(cacheKey, ts);
    }
    return ts.thought;
  }

  /* Home tile per agent */
  const HOME_TILES = {
    pm_agent:       { x: 2.5,  y: 3.5  },
    engineer_agent: { x: 10.5, y: 3.5  },
    qa_agent:       { x: 18.5, y: 3.5  },
    devops_agent:   { x: 27.5, y: 4.5  },
    owner:          { x: 29.6, y: 12.5 }
  };

  /* Location/status → tile position */
  const LOCATION_TILES = {
    pm: { x: 2.5, y: 3.5 }, pm_desk: { x: 2.5, y: 3.5 }, pm_agent: { x: 2.5, y: 3.5 },
    engineering: { x: 10.5, y: 3.5 }, engineering_desk: { x: 10.5, y: 3.5 },
    engineer: { x: 10.5, y: 3.5 }, engineer_agent: { x: 10.5, y: 3.5 },
    engineering_room: { x: 10.5, y: 3.5 },
    qa: { x: 18.5, y: 3.5 }, qa_desk: { x: 18.5, y: 3.5 }, qa_agent: { x: 18.5, y: 3.5 },
    devops: { x: 27.5, y: 4.5 }, devops_desk: { x: 27.5, y: 4.5 }, devops_agent: { x: 27.5, y: 4.5 },
    server: { x: 32.5, y: 4.5 }, server_room: { x: 32.5, y: 4.5 },
    meeting: { x: 20.5, y: 12.5 }, meeting_room: { x: 20.5, y: 12.5 },
    break: { x: 8.5, y: 12.5 }, break_room: { x: 8.5, y: 12.5 },
    owner: { x: 29.6, y: 12.5 }, owner_desk: { x: 29.6, y: 12.5 },
    autonomous_scheduler: { x: 10.5, y: 3.5 },
    agent_queue: { x: 10.5, y: 3.5 },
    system: { x: 27.5, y: 4.5 }
  };

  /* Status-specific location overrides per agent when location field is generic */
  const STATUS_LOCATION_OVERRIDE = {
    pm_agent: {
      planning: { x: 20.5, y: 12.5 }  // PM goes to meeting room when planning
    },
    engineer_agent: {
      planning: { x: 6.5, y: 3.5 }    // ENG at different desk during planning
    }
  };

  function getTargetTile(agentDef, runtime) {
    const loc = String(runtime.location || "").toLowerCase().replace(/-/g, "_").trim();
    const status = String(runtime.runtime_status || "").toLowerCase();

    // Idle/done agents go to break room — ignore stale location field (e.g. "system")
    const restingStates = new Set(["idle", "done", "completed", "failed", ""]);
    if (restingStates.has(status)) {
      return LOCATION_TILES.break_room;
    }

    // Prefer explicit location mapping if it's specific
    if (loc && LOCATION_TILES[loc]) return LOCATION_TILES[loc];

    // Status-based override for this agent
    const override = STATUS_LOCATION_OVERRIDE[agentDef.agent_key];
    if (override && override[status]) return override[status];

    return HOME_TILES[agentDef.agent_key] || { x: agentDef.x, y: agentDef.y };
  }

  /* ── Custom tileset support ────────────────────────────────── */
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

  /* ── Canvas state ──────────────────────────────────────────── */
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

  /* ── Ground ────────────────────────────────────────────────── */
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

  /* ── Furniture ─────────────────────────────────────────────── */
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
      if (type === "chair") { pr(px + 8, py + 20, 32, 18, "#4f66a3"); pr(px + 10, py + 8, 28, 14, "#344d86"); pr(px + 10, py + 36, 6, 10, "#2a3d6b"); pr(px + 32, py + 36, 6, 10, "#2a3d6b"); continue; }
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
      ctx.font = "bold 13px monospace";
      ctx.fillText(room.label, x + 8, y + 12);
    }
  }

  /* ── Doors ─────────────────────────────────────────────────── */
  function drawDoors() {
    const doorPositions = [
      { x: 8,  y: 10 },  // Break room entrance
      { x: 21, y: 10 },  // Meeting room entrance
      { x: 30, y: 10 },  // Owner office entrance
    ];
    for (const door of doorPositions) {
      const px = door.x * TS, py = door.y * TS;
      /* Repaint wall section as doorway opening */
      pr(px + 8, py, TS - 16, TS, "#8a7c68");           // floor colour visible through gap
      /* Door frame sides */
      pr(px + 5,       py, 5, TS, "#3d2b1f");
      pr(px + TS - 10, py, 5, TS, "#3d2b1f");
      /* Open door panel pushed to one side */
      pr(px + TS - 16, py + 4, 8, TS - 8, "#5c3d1a");
      pr(px + TS - 16, py + 4, 2, TS - 8, "#7a5530");   // door edge highlight
      /* Doorknob */
      pr(px + TS - 19, py + 22, 5, 5, "#ccaa44");
    }
  }

  /* ── Character pose drawing ─────────────────────────────────── */

  /* Shared head draw (used by all poses) */
  function drawHead(x, y, skin, hair, eyeColor) {
    pr(x + 5, y + 2,  15, 15, skin);
    pr(x + 4, y - 1,  17, 8,  hair);
    pr(x + 8, y + 9,  3,  2,  eyeColor || "#111827");
    pr(x + 15, y + 9, 3,  2,  eyeColor || "#111827");
  }

  function drawPoseIdle(agent, x, y, time) {
    pr(x + 2,  y + 26, 8, 18, "#334155");
    pr(x + 15, y + 26, 8, 18, "#334155");
    pr(x, y + 14, 25, 20, agent.shirt);
    pr(x - 2, y + 16, 4, 14, agent.skin);
    pr(x + 23, y + 16, 4, 14, agent.skin);
    drawHead(x, y, agent.skin, agent.hair, null);
  }

  function drawPoseTyping(agent, x, y, time) {
    /* Leaned forward, hands at keyboard */
    const keyBob = Math.sin(time / 250) > 0 ? -1 : 0;
    pr(x + 2,  y + 26, 8, 18, "#334155");
    pr(x + 15, y + 26, 8, 18, "#334155");
    pr(x, y + 13, 25, 21, agent.shirt);
    /* Arms down-forward to keyboard */
    pr(x - 3, y + 20, 5, 10, agent.shirt);
    pr(x + 23, y + 20, 5, 10, agent.shirt);
    pr(x - 3, y + 29, 5, 4, agent.skin);
    pr(x + 23, y + 29, 5, 4, agent.skin);
    /* Head slightly forward/down */
    pr(x + 5, y + 1 + keyBob,  15, 15, agent.skin);
    pr(x + 4, y - 2 + keyBob,  17, 8,  agent.hair);
    pr(x + 8, y + 8 + keyBob,  3,  2,  "#111827");
    pr(x + 15, y + 8 + keyBob, 3,  2,  "#111827");
  }

  function drawPoseTalking(agent, x, y, time) {
    /* Upright, one arm gesturing outward */
    const gesture = Math.sin(time / 700) * 3;
    pr(x + 2,  y + 26, 8, 18, "#334155");
    pr(x + 15, y + 26, 8, 18, "#334155");
    pr(x, y + 14, 25, 20, agent.shirt);
    /* Right arm out gesturing */
    pr(x + 23, y + 15 + gesture, 8, 10, agent.shirt);
    pr(x + 23, y + 24 + gesture, 6, 4, agent.skin);
    /* Left arm relaxed */
    pr(x - 2, y + 16, 4, 14, agent.skin);
    drawHead(x, y, agent.skin, agent.hair, null);
    /* Open mouth dot */
    pr(x + 11, y + 12, 3, 2, "#cc6644");
  }

  function drawPoseThinking(agent, x, y, time) {
    /* Hand on chin, head tilted */
    const tilt = Math.sin(time / 1800) * 1;
    pr(x + 2,  y + 26, 8, 18, "#334155");
    pr(x + 15, y + 26, 8, 18, "#334155");
    pr(x, y + 14, 25, 20, agent.shirt);
    /* Left arm bent up to chin */
    pr(x - 2, y + 14, 4, 10, agent.shirt);
    pr(x - 2, y + 23, 8, 4, agent.skin);
    /* Right arm relaxed */
    pr(x + 23, y + 16, 4, 14, agent.skin);
    /* Head slightly tilted */
    pr(x + 5 + tilt, y + 2,  15, 15, agent.skin);
    pr(x + 4 + tilt, y - 1,  17, 8,  agent.hair);
    pr(x + 8 + tilt, y + 9,  3,  2,  "#111827");
    pr(x + 15 + tilt, y + 9, 3,  2,  "#111827");
  }

  function drawPoseStressed(agent, x, y, time) {
    /* Arms raised, eyes wide/red */
    const shake = Math.sin(time / 150) * 2;
    pr(x + 2 + shake,  y + 26, 8, 18, "#334155");
    pr(x + 15 + shake, y + 26, 8, 18, "#334155");
    pr(x + shake, y + 13, 25, 21, agent.shirt);
    /* Both arms up */
    pr(x - 4 + shake, y + 10, 5, 10, agent.shirt);
    pr(x + 24 + shake, y + 10, 5, 10, agent.shirt);
    pr(x - 5 + shake, y + 7, 5, 5, agent.skin);
    pr(x + 25 + shake, y + 7, 5, 5, agent.skin);
    /* Head with wide red eyes */
    pr(x + 5 + shake, y + 2,  15, 15, agent.skin);
    pr(x + 4 + shake, y - 1,  17, 8,  agent.hair);
    pr(x + 8 + shake, y + 9,  3,  2,  "#ef4444");
    pr(x + 15 + shake, y + 9, 3,  2,  "#ef4444");
  }

  function drawPoseSleeping(agent, x, y, time) {
    /* Head slumped on desk, ZZZ above */
    const breathe = Math.sin(time / 2000) * 1;
    pr(x + 2,  y + 26, 8, 18, "#334155");
    pr(x + 15, y + 26, 8, 18, "#334155");
    pr(x, y + 14, 25, 20 + breathe, agent.shirt);
    pr(x - 2, y + 16, 4, 14, agent.skin);
    pr(x + 23, y + 16, 4, 14, agent.skin);
    /* Head dropped forward onto arms */
    pr(x + 3, y + 8 + breathe,  16, 14, agent.skin);
    pr(x + 2, y + 5 + breathe,  18, 8,  agent.hair);
    /* ZZZ indicator */
    ctx.fillStyle = "#94a3b8";
    ctx.font = "bold 9px monospace";
    ctx.fillText("z", x + 22, y - 2 + breathe);
    ctx.font = "bold 11px monospace";
    ctx.fillText("z", x + 26, y - 9 + breathe);
    ctx.font = "bold 13px monospace";
    ctx.fillText("Z", x + 30, y - 17 + breathe);
  }

  function drawPoseSittingSofa(agent, x, y, time) {
    const breathe = Math.sin(time / 2200) * 1;
    pr(x + 4,  y + 30, 6, 12, "#334155");
    pr(x + 16, y + 30, 6, 12, "#334155");
    pr(x + 1, y + 16 + breathe, 24, 16, agent.shirt);
    pr(x - 3, y + 18 + breathe, 4, 10, agent.skin);
    pr(x + 24, y + 18 + breathe, 4, 10, agent.skin);
    pr(x + 5, y + 4 + breathe, 16, 15, agent.skin);
    pr(x + 4, y + 1 + breathe, 17, 7, agent.hair);
    pr(x + 8, y + 10 + breathe, 3, 2, "#111827");
    pr(x + 15, y + 10 + breathe, 3, 2, "#111827");
  }

  function drawPoseSittingChair(agent, x, y, time) {
    const sway = Math.sin(time / 1600) * 0.8;
    pr(x + 2,  y + 28, 8, 14, "#334155");
    pr(x + 16, y + 28, 8, 14, "#334155");
    pr(x, y + 14, 26, 16, agent.shirt);
    pr(x - 3, y + 17, 4, 12, agent.skin);
    pr(x + 24, y + 17, 4, 12, agent.skin);
    pr(x + 5 + sway, y + 2, 15, 15, agent.skin);
    pr(x + 4 + sway, y - 1, 17, 8, agent.hair);
    pr(x + 8 + sway, y + 9, 3, 2, "#111827");
    pr(x + 15 + sway, y + 9, 3, 2, "#111827");
  }

  function drawComicBubble(cx, cy, text) {
    const w = 74, h = 20, r = 4;
    const bx = cx - w / 2, by = cy - 108;
    ctx.save();
    /* Bubble body */
    ctx.fillStyle = "#fffde7";
    ctx.strokeStyle = "#2a2a2a";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(bx + r, by);
    ctx.lineTo(bx + w - r, by);
    ctx.quadraticCurveTo(bx + w, by, bx + w, by + r);
    ctx.lineTo(bx + w, by + h - r);
    ctx.quadraticCurveTo(bx + w, by + h, bx + w - r, by + h);
    ctx.lineTo(bx + r, by + h);
    ctx.quadraticCurveTo(bx, by + h, bx, by + h - r);
    ctx.lineTo(bx, by + r);
    ctx.quadraticCurveTo(bx, by, bx + r, by);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    /* Triangle tail */
    ctx.fillStyle = "#fffde7";
    ctx.beginPath();
    ctx.moveTo(cx - 7, by + h);
    ctx.lineTo(cx + 7, by + h);
    ctx.lineTo(cx, by + h + 10);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = "#2a2a2a";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(cx - 7, by + h + 1);
    ctx.lineTo(cx, by + h + 11);
    ctx.lineTo(cx + 7, by + h + 1);
    ctx.stroke();
    /* Text */
    ctx.fillStyle = "#1a1a2e";
    ctx.font = "bold 11px monospace";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    const label = text.length > 14 ? text.slice(0, 13) + "…" : text;
    ctx.fillText(label, cx, by + h / 2);
    ctx.restore();
  }

  function drawThinkingBubble(cx, cy, text) {
    const w = 74, h = 20, r = 4;
    const bx = cx - w / 2, by = cy - 108;
    ctx.save();
    /* Bubble body */
    ctx.fillStyle = "rgba(30,41,59,0.92)";
    ctx.strokeStyle = "rgba(147,197,253,0.55)";
    ctx.lineWidth = 1;
    ctx.setLineDash([3, 2]);
    ctx.beginPath();
    ctx.moveTo(bx + r, by);
    ctx.lineTo(bx + w - r, by);
    ctx.quadraticCurveTo(bx + w, by, bx + w, by + r);
    ctx.lineTo(bx + w, by + h - r);
    ctx.quadraticCurveTo(bx + w, by + h, bx + w - r, by + h);
    ctx.lineTo(bx + r, by + h);
    ctx.quadraticCurveTo(bx, by + h, bx, by + h - r);
    ctx.lineTo(bx, by + r);
    ctx.quadraticCurveTo(bx, by, bx + r, by);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.setLineDash([]);
    /* Dot trail toward character */
    [5, 3.5, 2].forEach((dotR, i) => {
      ctx.beginPath();
      ctx.arc(cx, by + h + 7 + i * 8, dotR, 0, Math.PI * 2);
      ctx.fillStyle = "rgba(30,41,59,0.92)";
      ctx.fill();
      ctx.strokeStyle = "rgba(147,197,253,0.55)";
      ctx.lineWidth = 1;
      ctx.setLineDash([3, 2]);
      ctx.stroke();
      ctx.setLineDash([]);
    });
    /* Text */
    ctx.fillStyle = "#93c5fd";
    ctx.font = "11px monospace";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    const label = text.length > 14 ? text.slice(0, 13) + "…" : text;
    ctx.fillText(label, cx, by + h / 2);
    ctx.restore();
  }

  function drawWalkingBody(agent, x, y, time, state) {
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
    pr(x - 2, y + 16 - walkBob, 4, 14, agent.skin);
    pr(x + 23, y + 16 - walkBob, 4, 14, agent.skin);
    drawHead(x, y - walkBob, agent.skin, agent.hair, null);
  }

  function drawAgentPose(animState, agent, x, y, time) {
    const seat = seatAllocations.get(agent.agent_key);
    if (seat && animState !== ANIM_STRESSED) {
      if (animState === ANIM_SLEEPING) { drawPoseSleeping(agent, x, y, time); return; }
      if (seat.type === "sofa")  { drawPoseSittingSofa(agent, x, y, time); return; }
      if (seat.type === "chair") { drawPoseSittingChair(agent, x, y, time); return; }
    }
    switch (animState) {
      case ANIM_TYPING:   drawPoseTyping(agent, x, y, time);   break;
      case ANIM_TALKING:  drawPoseTalking(agent, x, y, time);  break;
      case ANIM_THINKING: drawPoseThinking(agent, x, y, time); break;
      case ANIM_STRESSED: drawPoseStressed(agent, x, y, time); break;
      case ANIM_SLEEPING: drawPoseSleeping(agent, x, y, time); break;
      default:            drawPoseIdle(agent, x, y, time);     break;
    }
  }

  /* ── Agent label + task badge ───────────────────────────────── */
  function drawAgentLabel(agent, runtime, x, y, animState, task) {
    const statusColor = getStatusColor(animState);
    const runtimeStatus = String(runtime.runtime_status || "idle");

    /* Name badge background */
    const labelW = Math.max(42, agent.label.length * 8 + 20);
    pr(x - 6, y - 30, labelW, 18, "rgba(15,23,42,0.92)");
    pr(x - 6, y - 12, labelW, 2, statusColor);

    /* Status dot */
    pr(x - 3, y - 26, 7, 7, statusColor);

    /* Agent name */
    ctx.fillStyle = "#e5e7eb";
    ctx.font = "bold 13px monospace";
    ctx.fillText(agent.label, x + 8, y - 18);

    /* Task badge */
    if (task) {
      const taskW = Math.max(42, task.length * 6 + 14);
      pr(x - 6, y - 44, taskW, 14, "rgba(30,41,59,0.88)");
      pr(x - 6, y - 44, 3, 14, statusColor);
      ctx.fillStyle = "#93c5fd";
      ctx.font = "12px monospace";
      ctx.fillText(task.slice(0, 14), x, y - 34);
    }

    /* Status text when not idle */
    if (runtimeStatus !== "idle" && runtimeStatus !== "done" && runtimeStatus !== "completed") {
      const statusLabel = runtimeStatus.toUpperCase().slice(0, 10);
      pr(x - 6, y - 58, Math.max(36, statusLabel.length * 6 + 10), 12, "rgba(15,23,42,0.75)");
      ctx.fillStyle = statusColor;
      ctx.font = "11px monospace";
      ctx.fillText(statusLabel, x - 2, y - 49);
    }
  }

  /* ── Agent drawing ──────────────────────────────────────────── */
  function drawAgent(agent, time) {
    const state = agentAnimState.get(agent.agent_key);
    if (!state) return;

    const runtime = runtimeByAgent[agent.agent_key] || {};
    const runtimeStatus = String(runtime.runtime_status || "idle");
    const task = runtime.current_task_key || "";

    /* Compute elapsed time for sleeping detection */
    let elapsedSec = 0;
    if (runtime.updated_at) {
      const updated = new Date(String(runtime.updated_at).replace(" ", "T"));
      if (!Number.isNaN(updated.getTime())) {
        elapsedSec = Math.floor((Date.now() - updated.getTime()) / 1000);
      }
    }

    const animState = getAnimState(runtimeStatus, elapsedSec);

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
      drawWalkingBody(agent, x, y, time, state);
    } else {
      drawAgentPose(animState, agent, x, y, time);
    }

    /* Label, task badge, status text */
    drawAgentLabel(agent, runtime, x, y, animState, task);

    /* Thought bubble */
    if (!isWalking) {
      const thought = getAgentCurrentThought(agent.agent_key, animState);
      const cx = x + 12;
      if (animState === ANIM_IDLE || animState === ANIM_DONE || animState === ANIM_SLEEPING) {
        drawThinkingBubble(cx, y, thought);
      } else {
        drawComicBubble(cx, y, thought);
      }
    }
  }

  /* ── Runtime polling ────────────────────────────────────────── */
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

  /* ── Render loop ────────────────────────────────────────────── */
  function render(time) {
    if (!mount()) { requestAnimationFrame(render); return; }

    const dt = Math.min((time - lastRenderTime) / 1000, 0.1);
    lastRenderTime = time;

    /* Update agent positions */
    for (const agent of agents) {
      const state = agentAnimState.get(agent.agent_key);
      if (!state) continue;

      const runtime = runtimeByAgent[agent.agent_key] || {};
      const agentStatus = String(runtime.runtime_status || '').toLowerCase();
      const rawTarget = getTargetTile(agent, runtime);
      let target = rawTarget;
      if (isBreakRoomTarget(rawTarget.x, rawTarget.y) && agentStatus !== 'failed') {
        const seat = allocateSeat(agent.agent_key);
        if (seat) target = { x: seat.x, y: seat.y };
      } else {
        freeSeat(agent.agent_key);
      }
      const finalX = target.x, finalY = target.y;

      /* Recompute waypoint whenever final destination changes */
      if (finalX !== state.ftx || finalY !== state.fty) {
        state.ftx = finalX;
        state.fty = finalY;
        state.waypoint = needsWaypoint(state.cy, finalY)
          ? { x: getWaypointDoorX(finalX), y: state.cy > 10 ? 9.5 : 10.5 }
          : null;
      }

      /* Clear waypoint once agent is close enough to it */
      if (state.waypoint) {
        const wdx = state.waypoint.x - state.cx;
        const wdy = state.waypoint.y - state.cy;
        if (Math.sqrt(wdx * wdx + wdy * wdy) < 0.25) state.waypoint = null;
      }

      /* Walk toward door waypoint first, then final target */
      state.tx = state.waypoint ? state.waypoint.x : finalX;
      state.ty = state.waypoint ? state.waypoint.y : finalY;

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
    drawDoors();
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
    setInterval(refreshRuntime, 2000);  // Poll every 2 seconds

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
