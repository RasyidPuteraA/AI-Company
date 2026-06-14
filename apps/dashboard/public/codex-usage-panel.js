(() => {
  const PANEL_ID = "codex-usage-panel";
  const SUMMARY_CARD_ID = "aiUsageSummaryCard";
  const REFRESH_MS = 30000;

  let refreshTimer = null;
  let refreshInterval = null;
  let refreshInFlight = false;
  let observerStarted = false;
  let booted = false;
  let lastGoodData = null;

  function numberValue(value) {
    const n = Number(value);
    return Number.isFinite(n) && n > 0 ? n : 0;
  }

  function formatNumber(value) {
    return Number(value || 0).toLocaleString();
  }

  function formatUpdated(value) {
    const date = value ? new Date(value) : new Date();
    const valid = Number.isNaN(date.getTime()) ? new Date() : date;
    return valid.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
  }

  function stateColor(state) {
    if (state === "STOP") return "#ef4444";
    if (state === "WARN") return "#f59e0b";
    if (state === "STALE" || state === "DEGRADED") return "#94a3b8";
    return "#22c55e";
  }

  function findAiTokensCard() {
    const byId = document.getElementById(SUMMARY_CARD_ID);
    if (byId) return byId;

    const candidates = Array.from(document.querySelectorAll("div, section, article"));

    return candidates.find((el) => {
      const text = (el.textContent || "").trim();
      if (!text.includes("AI API Tokens") && !text.includes("Codex Tokens")) return false;

      const rect = el.getBoundingClientRect();
      return rect.width >= 120 && rect.width <= 560 && rect.height >= 35 && rect.height <= 190;
    });
  }

  function findSummaryRow() {
    const candidates = Array.from(document.querySelectorAll("div, section, article"));

    return candidates.find((el) => {
      const text = (el.textContent || "").trim();
      if (!text.includes("Client Tasks")) return false;
      if (!text.includes("Internal Tasks")) return false;
      if (!text.includes("Waiting Owner")) return false;

      const rect = el.getBoundingClientRect();
      return rect.width > 700 && rect.height >= 40 && rect.height <= 240;
    });
  }

  function ensurePanel() {
    let panel = document.getElementById(PANEL_ID);
    if (panel) return panel;

    const aiTokensCard = findAiTokensCard();

    if (aiTokensCard) {
      aiTokensCard.id = PANEL_ID;
      aiTokensCard.setAttribute("data-codex-usage-card", "true");
      aiTokensCard.classList.add("codex-usage-card");
      return aiTokensCard;
    }

    const summaryRow = findSummaryRow();

    if (summaryRow) {
      const card = document.createElement("div");
      card.id = PANEL_ID;
      card.setAttribute("data-codex-usage-card", "true");
      card.className = "card ai-usage-summary-card codex-usage-card";
      summaryRow.appendChild(card);
      return card;
    }

    return null;
  }

  function ensurePanelTemplate(panel) {
    if (panel.querySelector("[data-codex-main-tokens]")) return;

    panel.replaceChildren();

    const content = document.createElement("div");
    content.className = "codex-usage-content";

    const body = document.createElement("div");
    body.className = "codex-usage-body";

    const label = document.createElement("span");
    label.className = "codex-usage-label";
    label.textContent = "Codex Limits";

    const totalRow = document.createElement("div");
    totalRow.className = "codex-usage-total-row";

    const main = document.createElement("strong");
    main.className = "codex-usage-main";
    main.dataset.codexMainTokens = "true";
    main.textContent = "--";

    const limit = document.createElement("small");
    limit.className = "codex-usage-limit";
    limit.dataset.codexLimitTokens = "true";
    limit.textContent = "internal estimate";

    totalRow.append(main, limit);

    const windows = document.createElement("small");
    windows.className = "codex-usage-line";
    windows.dataset.codexWindowTotals = "true";
    windows.textContent = "Week -- · Month --";

    const real5h = document.createElement("small");
    real5h.className = "codex-usage-line";
    real5h.dataset.codexFiveHourLimit = "true";
    real5h.textContent = "5h limit -- · reset --";

    const realWeekly = document.createElement("small");
    realWeekly.className = "codex-usage-line";
    realWeekly.dataset.codexWeeklyLimit = "true";
    realWeekly.textContent = "Weekly limit -- · reset --";

    const freshness = document.createElement("small");
    freshness.className = "codex-usage-line";
    freshness.dataset.codexSnapshotFreshness = "true";
    freshness.textContent = "Snapshot -- · Gate --";

    const sources = document.createElement("small");
    sources.className = "codex-usage-line";
    sources.dataset.codexSourceTotals = "true";
    sources.textContent = "Wrapper -- · Dangerous logged --";

    const note = document.createElement("small");
    note.className = "codex-usage-note";
    note.dataset.codexNote = "true";
    note.textContent = "Internal token estimate is not official Codex quota. Real limit values come from Codex CLI /status snapshot or owner-provided usage dashboard data.";

    const updated = document.createElement("small");
    updated.className = "codex-usage-updated";
    updated.dataset.codexUpdated = "true";
    updated.textContent = "Updated --";

    body.append(label, totalRow, windows, real5h, realWeekly, freshness, sources, note, updated);

    const status = document.createElement("div");
    status.className = "codex-usage-status";

    const statusDot = document.createElement("span");
    statusDot.className = "codex-usage-status-dot";
    statusDot.dataset.codexStatusDot = "true";

    const statusText = document.createElement("span");
    statusText.dataset.codexStatus = "true";
    statusText.textContent = "--";

    status.append(statusDot, statusText);
    content.append(body, status);
    panel.appendChild(content);
  }

  function pickMainTotal(data) {
    const wrapper = numberValue(data.wrapper_total_tokens ?? data.source_breakdown?.wrapper);
    const danger = numberValue(data.danger_logged_total_tokens ?? data.source_breakdown?.direct_danger_logged);
    const candidates = [
      data.total_estimated_tokens,
      data.month_total_tokens ?? data.budget?.month?.used_tokens,
      data.week_total_tokens ?? data.budget?.week?.used_tokens,
      wrapper + danger
    ];

    for (const value of candidates) {
      const n = numberValue(value);
      if (n > 0) return n;
    }

    return 0;
  }

  function normalize(data, degraded = false) {
    const week = numberValue(data.week_total_tokens ?? data.budget?.week?.used_tokens);
    const month = numberValue(data.month_total_tokens ?? data.budget?.month?.used_tokens);
    const wrapper = numberValue(data.wrapper_total_tokens ?? data.source_breakdown?.wrapper);
    const danger = numberValue(data.danger_logged_total_tokens ?? data.source_breakdown?.direct_danger_logged);
    const status = degraded ? "STALE" : String(data.status || data.budget?.today?.state || "OK");
    const realLimit = data.real_limit || {};

    return {
      main: pickMainTotal(data),
      internalSoftEstimate: numberValue(data.internal_soft_estimate_tokens ?? data.limit_tokens ?? data.budget?.today?.hard_limit_tokens),
      week,
      month,
      wrapper,
      danger,
      status,
      budgetGateState: data.budget_gate_state || status,
      internalBudgetState: data.internal_budget_state || data.budget?.today?.state || "OK",
      realLimitState: data.real_codex_limit_state || realLimit.recommended_state || "WARN",
      fiveHourLeft: realLimit.five_hour_left_percent || "",
      fiveHourReset: realLimit.five_hour_reset_at || "",
      weeklyLeft: realLimit.weekly_left_percent || "",
      weeklyReset: realLimit.weekly_reset_at || "",
      snapshotStale: realLimit.stale || "yes",
      note: data.note || "Internal token estimate is not official Codex quota. Real limit values come from Codex CLI /status snapshot or owner-provided usage dashboard data.",
      lastUpdated: data.last_updated || data.generated_at,
      degraded
    };
  }

  function setText(panel, selector, value) {
    const el = panel.querySelector(selector);
    if (el) el.textContent = value;
  }

  function render(data, degraded = false) {
    const panel = ensurePanel();
    if (!panel) return false;

    ensurePanelTemplate(panel);

    const usage = normalize(data, degraded);
    const color = stateColor(usage.status);

    setText(panel, "[data-codex-main-tokens]", formatNumber(usage.main));
    setText(panel, "[data-codex-limit-tokens]", `internal soft estimate ${formatNumber(usage.internalSoftEstimate)}`);
    setText(panel, "[data-codex-window-totals]", `Week ${formatNumber(usage.week)} · Month ${formatNumber(usage.month)}`);
    setText(panel, "[data-codex-five-hour-limit]", `5h limit ${usage.fiveHourLeft || "--"}% left · reset ${usage.fiveHourReset || "--"}`);
    setText(panel, "[data-codex-weekly-limit]", `Weekly limit ${usage.weeklyLeft || "--"}% left · reset ${usage.weeklyReset || "--"}`);
    setText(panel, "[data-codex-snapshot-freshness]", `Snapshot stale ${usage.snapshotStale || "yes"} · Gate ${usage.budgetGateState} · Real ${usage.realLimitState} · Internal ${usage.internalBudgetState}`);
    setText(panel, "[data-codex-source-totals]", `Wrapper ${formatNumber(usage.wrapper)} · Dangerous logged ${formatNumber(usage.danger)}`);
    setText(panel, "[data-codex-note]", usage.degraded ? `${usage.note} Current fetch degraded; showing last successful data.` : usage.note);
    setText(panel, "[data-codex-updated]", `Updated ${formatUpdated(usage.lastUpdated)}`);
    setText(panel, "[data-codex-status]", usage.status);

    const status = panel.querySelector(".codex-usage-status");
    const dot = panel.querySelector("[data-codex-status-dot]");
    if (status) status.style.color = color;
    if (dot) dot.style.background = color;

    return true;
  }

  async function refresh() {
    if (refreshInFlight) return;

    refreshInFlight = true;
    try {
      const response = await fetch("/api/codex/usage", { cache: "no-store" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);

      const data = await response.json();
      lastGoodData = data;
      const rendered = render(data);

      if (!rendered) {
        scheduleRefresh(500);
      }
    } catch (error) {
      console.warn("Failed to load Codex usage panel", error);
      if (lastGoodData) render(lastGoodData, true);
    } finally {
      refreshInFlight = false;
    }
  }

  function scheduleRefresh(delay = 150) {
    clearTimeout(refreshTimer);
    refreshTimer = setTimeout(refresh, delay);
  }

  function startObserver() {
    if (observerStarted || !document.body) return;

    observerStarted = true;

    const observer = new MutationObserver(() => {
      const panel = document.getElementById(PANEL_ID);
      const hasCodexPanel = panel && panel.querySelector("[data-codex-main-tokens]");
      const hasAiTokensCard = Boolean(findAiTokensCard());

      if (!hasCodexPanel && hasAiTokensCard) {
        if (lastGoodData) render(lastGoodData);
        scheduleRefresh(150);
      }
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });
  }

  function boot() {
    if (booted) return;
    booted = true;

    startObserver();
    scheduleRefresh(0);
    refreshInterval = setInterval(() => scheduleRefresh(0), REFRESH_MS);
  }

  window.addEventListener("beforeunload", () => {
    clearTimeout(refreshTimer);
    clearInterval(refreshInterval);
  });

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot, { once: true });
  } else {
    boot();
  }
})();
