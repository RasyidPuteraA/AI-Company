(() => {
  const PANEL_ID = "codex-usage-panel";
  let retryCount = 0;

  function formatNumber(value) {
    return Number(value || 0).toLocaleString();
  }

  function stateColor(state) {
    if (state === "STOP") return "#ef4444";
    if (state === "WARN") return "#f59e0b";
    return "#22c55e";
  }

  function findAiTokensCard() {
    const candidates = Array.from(document.querySelectorAll("div, section, article"));

    return candidates.find((el) => {
      const text = (el.textContent || "").trim();
      if (!text.includes("AI API Tokens")) return false;

      const rect = el.getBoundingClientRect();
      return rect.width >= 120 && rect.width <= 520 && rect.height >= 40 && rect.height <= 180;
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
      return rect.width > 500 && rect.height >= 40 && rect.height <= 220;
    });
  }

  function ensurePanel() {
    const existing = document.getElementById(PANEL_ID);
    if (existing) return existing;

    const aiTokensCard = findAiTokensCard();

    if (aiTokensCard) {
      aiTokensCard.id = PANEL_ID;
      aiTokensCard.setAttribute("data-codex-usage-card", "true");
      return aiTokensCard;
    }

    const summaryRow = findSummaryRow();

    if (summaryRow) {
      const card = document.createElement("div");
      card.id = PANEL_ID;
      card.setAttribute("data-codex-usage-card", "true");
      card.style.border = "1px solid rgba(148, 163, 184, 0.18)";
      card.style.borderRadius = "14px";
      card.style.padding = "14px 16px";
      card.style.background = "rgba(15, 23, 42, 0.72)";
      card.style.minWidth = "190px";
      summaryRow.appendChild(card);
      return card;
    }

    return null;
  }

  function render(data) {
    const panel = ensurePanel();

    if (!panel) {
      retryCount += 1;
      if (retryCount <= 20) {
        setTimeout(() => render(data), 500);
      }
      return;
    }

    const today = data.budget.today;
    const week = data.budget.week;
    const month = data.budget.month;

    panel.innerHTML = `
      <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:10px;width:100%;">
        <div style="min-width:0;">
          <div style="font-size:11px;font-weight:800;color:#e5e7eb;margin-bottom:8px;letter-spacing:.02em;">
            Codex Tokens
          </div>

          <div style="display:flex;align-items:baseline;gap:8px;">
            <div style="font-size:24px;line-height:1;font-weight:900;color:#38bdf8;">
              ${formatNumber(today.used_tokens)}
            </div>
            <div style="font-size:10px;color:#94a3b8;">
              / ${formatNumber(today.hard_limit_tokens)}
            </div>
          </div>

          <div style="margin-top:7px;font-size:10px;color:#94a3b8;line-height:1.35;">
            Week ${formatNumber(week.used_tokens)} · Month ${formatNumber(month.used_tokens)}
          </div>
        </div>

        <div style="display:flex;align-items:center;gap:6px;font-size:10px;font-weight:800;color:${stateColor(today.state)};">
          <span style="width:7px;height:7px;border-radius:999px;background:${stateColor(today.state)};display:inline-block;"></span>
          ${today.state}
        </div>
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
