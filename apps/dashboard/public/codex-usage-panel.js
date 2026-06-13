(() => {
  const PANEL_ID = "codex-usage-panel";

  function formatNumber(value) {
    return Number(value || 0).toLocaleString();
  }

  function stateClass(state) {
    if (state === "STOP") return "#ef4444";
    if (state === "WARN") return "#f59e0b";
    return "#22c55e";
  }

  function render(data) {
    let panel = document.getElementById(PANEL_ID);

    if (!panel) {
      panel = document.createElement("section");
      panel.id = PANEL_ID;
      panel.style.position = "fixed";
      panel.style.right = "16px";
      panel.style.bottom = "16px";
      panel.style.zIndex = "9999";
      panel.style.width = "320px";
      panel.style.maxWidth = "calc(100vw - 32px)";
      panel.style.background = "rgba(15, 23, 42, 0.96)";
      panel.style.border = "1px solid rgba(148, 163, 184, 0.28)";
      panel.style.borderRadius = "14px";
      panel.style.boxShadow = "0 18px 45px rgba(0, 0, 0, 0.35)";
      panel.style.padding = "14px";
      panel.style.color = "#e5e7eb";
      panel.style.fontFamily = "ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif";
      panel.style.fontSize = "12px";
      document.body.appendChild(panel);
    }

    const today = data.budget.today;
    const week = data.budget.week;
    const month = data.budget.month;
    const topAgents = (data.by_agent || []).slice(0, 4);

    panel.innerHTML = `
      <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:10px;">
        <strong style="font-size:14px;color:#f8fafc;">Codex CLI Usage</strong>
        <span style="background:${stateClass(today.state)};color:#020617;font-weight:700;border-radius:999px;padding:3px 8px;">${today.state}</span>
      </div>

      <div style="display:grid;gap:6px;margin-bottom:10px;">
        <div>Today: <strong>${formatNumber(today.used_tokens)}</strong> / ${formatNumber(today.hard_limit_tokens)}</div>
        <div>Week: <strong>${formatNumber(week.used_tokens)}</strong> / ${formatNumber(week.soft_limit_tokens)}</div>
        <div>Month: <strong>${formatNumber(month.used_tokens)}</strong> / ${formatNumber(month.soft_limit_tokens)}</div>
      </div>

      <div style="border-top:1px solid rgba(148,163,184,0.25);padding-top:8px;margin-top:8px;">
        <div style="font-weight:700;margin-bottom:5px;color:#cbd5e1;">By agent</div>
        ${
          topAgents.length
            ? topAgents.map((row) => `<div style="display:flex;justify-content:space-between;gap:8px;"><span>${row.agent_key}</span><span>${formatNumber(row.tokens_used)}</span></div>`).join("")
            : `<div style="color:#94a3b8;">No Codex runs yet.</div>`
        }
      </div>

      <div style="border-top:1px solid rgba(148,163,184,0.25);padding-top:8px;margin-top:8px;color:#94a3b8;line-height:1.35;">
        Internal budget estimate, not official OpenAI remaining quota.
      </div>
    `;
  }

  async function refresh() {
    try {
      const response = await fetch("/api/codex/usage", { cache: "no-store" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      render(await response.json());
    } catch (error) {
      console.warn("Failed to load Codex usage panel", error);
    }
  }

  refresh();
  setInterval(refresh, 60000);
})();
