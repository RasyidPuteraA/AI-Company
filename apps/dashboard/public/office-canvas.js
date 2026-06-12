/* INTERNAL-050: Canvas Pixel Office Renderer
   Adapted from uploaded pixel-office.html prototype into dashboard mode.
   It renders a live office scene inside #tilemapOffice .tilemap-stage. */

(function () {
  const TILE = 16;
  const SCALE = 3;
  const TS = TILE * SCALE;
  const COLS = 20;
  const ROWS = 14;

  const canvasWidth = COLS * TS;
  const canvasHeight = ROWS * TS;

  const ROOMS = {
    pm_agent: { label: "PM", x: 2.3, y: 3.3, sprite: "/assets/jik/metrocity-characters/pm.png" },
    engineer_agent: { label: "ENG", x: 6.3, y: 3.3, sprite: "/assets/jik/metrocity-characters/engineer.png" },
    qa_agent: { label: "QA", x: 10.3, y: 3.3, sprite: "/assets/jik/metrocity-characters/qa.png" },
    devops_agent: { label: "OPS", x: 14.3, y: 4.3, sprite: "/assets/jik/metrocity-characters/devops.png" },
    owner: { label: "OWNER", x: 14.6, y: 12.0, sprite: "/assets/jik/metrocity-characters/owner.png" },
  };

  const SPRITES = {};
  const runtime = {
    pm_agent: { status: "idle", task_key: "" },
    engineer_agent: { status: "idle", task_key: "" },
    qa_agent: { status: "idle", task_key: "" },
    devops_agent: { status: "idle", task_key: "" },
    owner: { status: "idle", task_key: "" },
  };

  const _ = 0;
  const FL = 1;
  const FL2 = 2;
  const WL = 3;

  const DL = 4;
  const DR = 5;
  const MON = 6;
  const CH = 7;
  const PL = 8;
  const SH = 9;
  const SRV = 10;
  const COL = 11;
  const AC = 12;
  const SOF = 13;
  const TBL = 14;
  const WC = 15;

  const GROUND = [
    [ WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL ],
    [ WL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, WL ],
    [ WL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, WL ],
    [ WL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, WL ],
    [ WL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, WL ],
    [ WL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, WL ],
    [ WL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, WL ],
    [ WL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, WL ],
    [ WL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, WL ],
    [ WL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, FL, WL ],
    [ WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL, WL ],
    [ _, _, WL, WL, FL2, FL2, FL2, FL2, FL2, FL2, FL2, WL, _, WL, FL2, FL2, FL2, FL2, WL, _ ],
    [ _, _, WL, FL2, FL2, FL2, FL2, FL2, FL2, FL2, FL2, WL, _, WL, FL2, FL2, FL2, FL2, WL, _ ],
    [ _, _, WL, FL2, FL2, FL2, FL2, FL2, FL2, FL2, FL2, WL, _, WL, FL2, FL2, FL2, FL2, WL, _ ],
  ];

  const furniture = [
    { t: AC, x: 1, y: 1 },

    { t: DL, x: 2, y: 2 }, { t: DR, x: 3, y: 2 }, { t: MON, x: 3, y: 2 }, { t: CH, x: 2, y: 3 },
    { t: DL, x: 6, y: 2 }, { t: DR, x: 7, y: 2 }, { t: MON, x: 7, y: 2 }, { t: CH, x: 6, y: 3 },
    { t: DL, x: 10, y: 2 }, { t: DR, x: 11, y: 2 }, { t: MON, x: 11, y: 2 }, { t: CH, x: 10, y: 3 },

    { t: DL, x: 2, y: 6 }, { t: DR, x: 3, y: 6 }, { t: MON, x: 3, y: 6 }, { t: CH, x: 2, y: 7 },
    { t: DL, x: 6, y: 6 }, { t: DR, x: 7, y: 6 }, { t: MON, x: 7, y: 6 }, { t: CH, x: 6, y: 7 },
    { t: DL, x: 10, y: 6 }, { t: DR, x: 11, y: 6 }, { t: MON, x: 11, y: 6 }, { t: CH, x: 10, y: 7 },

    { t: SH, x: 14, y: 1 }, { t: SH, x: 15, y: 1 }, { t: SH, x: 16, y: 1 },
    { t: DL, x: 14, y: 3 }, { t: DR, x: 15, y: 3 }, { t: MON, x: 15, y: 3 }, { t: CH, x: 14, y: 4 },
    { t: WC, x: 17, y: 3 },

    { t: SRV, x: 18, y: 2 }, { t: SRV, x: 18, y: 3 }, { t: SRV, x: 18, y: 4 },

    { t: PL, x: 1, y: 8 }, { t: PL, x: 17, y: 1 }, { t: PL, x: 18, y: 8 }, { t: PL, x: 13, y: 8 },

    { t: COL, x: 9, y: 11 },
    { t: PL, x: 4, y: 12 }, { t: PL, x: 5, y: 13 }, { t: SOF, x: 5, y: 12 }, { t: TBL, x: 7, y: 12 },

    { t: DL, x: 14, y: 12 }, { t: DR, x: 15, y: 12 }, { t: CH, x: 14, y: 13 }, { t: CH, x: 15, y: 13 },
    { t: PL, x: 17, y: 13 },
  ];

  function loadSprite(key, src) {
    const img = new Image();
    img.src = src;
    SPRITES[key] = img;
  }

  Object.entries(ROOMS).forEach(([key, cfg]) => loadSprite(key, cfg.sprite));

  function normalizeStatus(s) {
    return String(s || "idle").toLowerCase();
  }

  async function refreshRuntime() {
    try {
      const res = await fetch("/api/agents/runtime", { cache: "no-store" });
      if (!res.ok) return;
      const data = await res.json();
      const rows = Array.isArray(data) ? data : (data.agents || data.rows || data.runtime || []);

      for (const row of rows) {
        const key = row.agent_key || row.agent || row.name || row.id;
        if (!key || !runtime[key]) continue;
        runtime[key] = {
          status: normalizeStatus(row.status || row.state || row.runtime_status),
          task_key: row.task_key || row.current_task_key || row.task || "",
          room: row.room || row.location || "",
        };
      }
    } catch (_) {
      // Keep last known state.
    }
  }

  function install() {
    const stage = document.querySelector("#tilemapOffice .tilemap-stage");
    const office = document.querySelector("#tilemapOffice");
    if (!stage || !office) return false;

    if (stage.querySelector("#officeCanvas")) return true;

    office.classList.add("canvas-floorplan-mode");

    const canvas = document.createElement("canvas");
    canvas.id = "officeCanvas";
    canvas.width = canvasWidth;
    canvas.height = canvasHeight;
    canvas.setAttribute("aria-label", "Canvas Pixel Office");
    stage.appendChild(canvas);

    const ctx = canvas.getContext("2d");
    ctx.imageSmoothingEnabled = false;

    function pr(x, y, w, h, col) {
      ctx.fillStyle = col;
      ctx.fillRect(x * SCALE, y * SCALE, w * SCALE, h * SCALE);
    }

    function drawFloor(id, tx, ty) {
      if (id === _) return;
      ctx.save();
      ctx.translate(tx * TS, ty * TS);

      if (id === FL) {
        pr(0, 0, TILE, TILE, "#c0c0ce");
        pr(0, 0, TILE, 1, "#a8a8ba");
        pr(0, 0, 1, TILE, "#a8a8ba");
      } else if (id === FL2) {
        pr(0, 0, TILE, TILE, "#c4b898");
        pr(0, 0, TILE, 1, "#aa9e82");
        pr(0, 0, 1, TILE, "#aa9e82");
      } else if (id === WL) {
        pr(0, 0, TILE, TILE, "#787898");
        pr(0, 0, TILE, 3, "#9898b8");
        pr(0, TILE - 2, TILE, 2, "#505070");
        pr(TILE - 2, 0, 2, TILE, "#606080");
      }

      ctx.restore();
    }

    function drawFurniture(obj, time) {
      ctx.save();
      ctx.translate(obj.x * TS, obj.y * TS);

      switch (obj.t) {
        case DL:
          pr(0, 5, TILE, 11, "#c89858");
          pr(0, 5, TILE, 3, "#e8b870");
          pr(0, TILE - 2, TILE, 2, "#906830");
          pr(1, 9, 12, 4, "#a07838");
          pr(5, 10, 4, 2, "#c09050");
          pr(1, TILE - 3, 2, 3, "#705020");
          break;
        case DR:
          pr(0, 5, TILE, 11, "#c89858");
          pr(0, 5, TILE, 3, "#e8b870");
          pr(0, TILE - 2, TILE, 2, "#906830");
          pr(TILE - 3, TILE - 3, 2, 3, "#705020");
          break;
        case MON: {
          const screenOn = Math.floor(time / 4500) % 12 !== 0;
          const blink = Math.floor(time / 600) % 2;
          pr(6, 5, 4, 5, "#2e2e44");
          pr(4, 9, 8, 2, "#2e2e44");
          pr(1, -9, 14, 10, "#1e1e2e");
          pr(2, -8, 12, 8, screenOn ? "#1a33aa" : "#0d1530");
          if (screenOn) {
            pr(3, -7, 6, 1, "#7799ee");
            pr(3, -5, 9, 1, "#5577cc");
            pr(3, -3, 7, 1, "#5577cc");
            if (blink) pr(10, -7, 1, 1, "#ffffff");
          }
          break;
        }
        case CH:
          pr(3, -1, 10, 7, "#334a56");
          pr(3, -1, 10, 2, "#45606e");
          pr(2, 5, 12, 7, "#445566");
          pr(2, 5, 12, 2, "#556677");
          pr(1, 10, 3, 2, "#223344");
          pr(12, 10, 3, 2, "#223344");
          break;
        case PL: {
          const sway = Math.sin(time / 2000 + obj.x) * 0.4;
          ctx.save();
          ctx.translate((TILE / 2) * SCALE, 9 * SCALE);
          ctx.rotate((sway * Math.PI) / 60);
          ctx.translate((-TILE / 2) * SCALE, -9 * SCALE);
          pr(4, 9, 8, 7, "#884433");
          pr(2, 0, 4, 7, "#337733");
          pr(9, 2, 5, 5, "#337733");
          pr(5, -3, 6, 9, "#337733");
          pr(6, -2, 4, 6, "#55bb55");
          ctx.restore();
          break;
        }
        case SH:
          pr(0, 0, TILE, 14, "#7a5530");
          pr(0, 0, TILE, 2, "#9a7550");
          pr(0, 7, TILE, 2, "#9a7550");
          ["#cc4444", "#4466cc", "#44aa44", "#ddaa22", "#aa44cc", "#cc7733"].forEach((c, i) => {
            pr(1 + i * 2.3, 2, 2, 5, c);
            pr(1 + i * 2.3, 9, 2, 4, c);
          });
          break;
        case SRV: {
          const blink = Math.floor(time / 800) % 2;
          pr(0, 0, TILE, 14, "#2a3a4a");
          pr(0, 0, TILE, 2, "#3a4a5a");
          pr(1, 2, 9, 3, "#1a2a3a");
          pr(1, 8, 9, 3, "#1a2a3a");
          pr(12, 3, 2, 2, blink ? "#00ee66" : "#007733");
          pr(12, 9, 2, 2, "#ffaa00");
          break;
        }
        case COL:
          pr(4, 0, 8, 14, "#99ccee");
          pr(5, 0, 6, 7, "#88bbdd");
          pr(6, 1, 4, 2, "#cceeff");
          pr(3, 12, 10, 3, "#778899");
          break;
        case AC:
          pr(0, 2, TILE, 10, "#d0d0e2");
          pr(0, 2, TILE, 3, "#e2e2f4");
          for (let i = 0; i < 4; i++) pr(2, 6 + i * 2, 12, 1, "#b0b0cc");
          pr(13, 3, 1, 1, "#00dd44");
          break;
        case SOF:
          pr(0, 4, TILE, 10, "#5a6a99");
          pr(0, 4, TILE, 3, "#6a7aaa");
          pr(1, 0, TILE - 2, 5, "#48588a");
          pr(0, 0, 3, 14, "#48588a");
          pr(13, 0, 3, 14, "#48588a");
          break;
        case TBL:
          pr(1, 5, 14, 5, "#c89858");
          pr(1, 5, 14, 2, "#e8b870");
          pr(2, 9, 2, 6, "#906830");
          pr(12, 9, 2, 6, "#906830");
          break;
        case WC:
          pr(0, 0, TILE, 12, "#e8e8f0");
          pr(0, 0, TILE, 2, "#c8c8e0");
          pr(0, 10, TILE, 2, "#a0a0c0");
          pr(4, 4, 3, 1, "#4466cc");
          pr(4, 6, 5, 1, "#4466cc");
          break;
      }

      ctx.restore();
    }

    function drawAgent(key, cfg, time) {
      const status = runtime[key]?.status || "idle";
      const isWorking = status.includes("working") || status.includes("busy") || status.includes("running");
      const isBlocked = status.includes("blocked") || status.includes("failed") || status.includes("error");
      const bob = Math.sin(time / 500 + cfg.x) * (isWorking ? 2 : 0.8);

      const x = Math.round(cfg.x * TS);
      const y = Math.round(cfg.y * TS + bob);

      ctx.save();
      ctx.translate(x, y);

      ctx.globalAlpha = 0.25;
      ctx.fillStyle = "#000000";
      ctx.fillRect(-10, 34, 32, 7);
      ctx.globalAlpha = 1;

      const img = SPRITES[key];
      if (img && img.complete && img.naturalWidth > 0) {
        ctx.drawImage(img, -6, -16, 48, 48);
      } else {
        // fallback mini character
        ctx.fillStyle = "#ffd5a8";
        ctx.fillRect(4, -10, 18, 18);
        ctx.fillStyle = "#334455";
        ctx.fillRect(5, 8, 16, 20);
      }

      ctx.font = "bold 10px monospace";
      ctx.textAlign = "center";
      ctx.fillStyle = "#eef6ff";
      ctx.fillText(cfg.label, 10, 50);

      if (isWorking || isBlocked) {
        ctx.fillStyle = isBlocked ? "rgba(127, 29, 29, 0.92)" : "rgba(15, 23, 42, 0.92)";
        ctx.fillRect(-20, -34, 62, 16);
        ctx.fillStyle = isBlocked ? "#fecaca" : "#bae6fd";
        ctx.font = "bold 8px monospace";
        ctx.fillText(isBlocked ? "BLOCKED" : "WORKING", 11, -22);
      }

      ctx.restore();
    }

    function drawLabels() {
      ctx.save();
      ctx.font = "bold 11px monospace";
      ctx.fillStyle = "rgba(15, 23, 42, 0.78)";
      ctx.fillRect(52 * SCALE, 18 * SCALE, 38 * SCALE, 12 * SCALE);
      ctx.fillRect(150 * SCALE, 18 * SCALE, 72 * SCALE, 12 * SCALE);
      ctx.fillRect(242 * SCALE, 18 * SCALE, 36 * SCALE, 12 * SCALE);

      ctx.fillStyle = "#e0f2fe";
      ctx.fillText("PM", 56 * SCALE, 27 * SCALE);
      ctx.fillText("ENGINEER", 154 * SCALE, 27 * SCALE);
      ctx.fillText("QA", 246 * SCALE, 27 * SCALE);
      ctx.restore();
    }

    function render(time) {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.fillStyle = "#0a0a15";
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      for (let r = 0; r < ROWS; r++) {
        for (let c = 0; c < COLS; c++) drawFloor(GROUND[r][c], c, r);
      }

      [...furniture].sort((a, b) => a.y - b.y || a.x - b.x).forEach((obj) => drawFurniture(obj, time));
      drawLabels();

      Object.entries(ROOMS)
        .sort((a, b) => a[1].y - b[1].y)
        .forEach(([key, cfg]) => drawAgent(key, cfg, time));

      const vg = ctx.createRadialGradient(
        canvas.width / 2, canvas.height / 2, canvas.height * 0.28,
        canvas.width / 2, canvas.height / 2, canvas.height * 0.88
      );
      vg.addColorStop(0, "rgba(0,0,0,0)");
      vg.addColorStop(1, "rgba(0,0,20,0.38)");
      ctx.fillStyle = vg;
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    }

    function loop(ts) {
      render(ts || 0);
      requestAnimationFrame(loop);
    }

    refreshRuntime();
    setInterval(refreshRuntime, 5000);
    requestAnimationFrame(loop);

    return true;
  }

  function boot() {
    if (install()) return;

    const timer = setInterval(() => {
      if (install()) clearInterval(timer);
    }, 500);

    setTimeout(() => clearInterval(timer), 15000);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
