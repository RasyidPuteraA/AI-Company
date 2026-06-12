(function () {
  const PANEL_ID = 'ownerReviewActionPanel';

  function injectStyles() {
    if (document.getElementById('owner-review-action-styles')) return;

    const style = document.createElement('style');
    style.id = 'owner-review-action-styles';
    style.textContent = `
      #${PANEL_ID} {
        position: fixed;
        right: 18px;
        bottom: 88px;
        z-index: 50;
        width: min(360px, calc(100vw - 36px));
        border: 1px solid rgba(255,255,255,0.16);
        border-radius: 18px;
        background: rgba(9, 14, 24, 0.92);
        backdrop-filter: blur(12px);
        box-shadow: 0 18px 60px rgba(0,0,0,0.42);
        color: #f8fafc;
        font-family: inherit;
        overflow: hidden;
      }

      #${PANEL_ID}[hidden] {
        display: none !important;
      }

      #${PANEL_ID} .orap-head {
        padding: 14px 16px 10px;
        border-bottom: 1px solid rgba(255,255,255,0.10);
      }

      #${PANEL_ID} .orap-title {
        font-size: 14px;
        font-weight: 800;
        letter-spacing: 0.02em;
      }

      #${PANEL_ID} .orap-subtitle {
        margin-top: 4px;
        color: rgba(226,232,240,0.78);
        font-size: 12px;
      }

      #${PANEL_ID} .orap-body {
        padding: 12px 16px 16px;
      }

      #${PANEL_ID} .orap-task {
        font-size: 13px;
        line-height: 1.4;
        color: rgba(248,250,252,0.92);
        margin-bottom: 12px;
      }

      #${PANEL_ID} button {
        width: 100%;
        border: 0;
        border-radius: 12px;
        padding: 11px 12px;
        font-weight: 800;
        cursor: pointer;
        color: #07111f;
        background: linear-gradient(135deg, #a7f3d0, #67e8f9);
      }

      #${PANEL_ID} button:disabled {
        opacity: 0.55;
        cursor: wait;
      }

      #${PANEL_ID} .orap-status {
        margin-top: 10px;
        font-size: 12px;
        color: rgba(226,232,240,0.76);
        white-space: pre-wrap;
      }
    `;
    document.head.appendChild(style);
  }

  function normalizeTasks(payload) {
    if (Array.isArray(payload)) return payload;
    if (Array.isArray(payload.tasks)) return payload.tasks;
    if (Array.isArray(payload.rows)) return payload.rows;
    if (Array.isArray(payload.data)) return payload.data;
    return [];
  }

  async function fetchTasks() {
    const res = await fetch('/api/tasks', { cache: 'no-store' });
    if (!res.ok) throw new Error('Failed to fetch tasks');
    return normalizeTasks(await res.json());
  }

  function isWaitingOwnerReview(task) {
    const key = String(task.task_key || task.key || '');
    const status = String(task.status || '').toUpperCase();
    const agent = String(task.agent || task.assigned_agent_key || '');
    return key.includes('REVIEW') && status === 'WAITING_OWNER_ACCEPTANCE' && (!agent || agent === 'owner');
  }

  function getTaskTitle(task) {
    return task.title || task.task_title || task.task_key || 'Owner review task';
  }

  function ensurePanel() {
    let panel = document.getElementById(PANEL_ID);
    if (panel) return panel;

    panel = document.createElement('section');
    panel.id = PANEL_ID;
    panel.hidden = true;
    panel.innerHTML = `
      <div class="orap-head">
        <div class="orap-title">Owner Review Ready</div>
        <div class="orap-subtitle">Manual approval required</div>
      </div>
      <div class="orap-body">
        <div class="orap-task"></div>
        <button type="button">Accept + Finalize</button>
        <div class="orap-status"></div>
      </div>
    `;
    document.body.appendChild(panel);
    return panel;
  }

  async function acceptAndFinalize(task, panel) {
    const button = panel.querySelector('button');
    const status = panel.querySelector('.orap-status');
    const taskKey = task.task_key || task.key;

    button.disabled = true;
    status.textContent = 'Running owner accept + finalize...';

    try {
      const res = await fetch('/api/owner/review/accept-finalize', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          review_task_key: taskKey,
          owner_note: 'Owner accepted delivery from dashboard.'
        })
      });

      const data = await res.json().catch(() => ({}));

      if (!res.ok || !data.ok) {
        throw new Error(data.error || 'Accept finalize failed');
      }

      status.textContent = 'Completed. Refreshing...';
      setTimeout(() => window.location.reload(), 900);
    } catch (err) {
      status.textContent = `Failed: ${err.message}`;
      button.disabled = false;
    }
  }

  async function refreshOwnerReviewPanel() {
    injectStyles();

    const panel = ensurePanel();
    const title = panel.querySelector('.orap-task');
    const button = panel.querySelector('button');
    const status = panel.querySelector('.orap-status');

    try {
      const tasks = await fetchTasks();
      const reviewTask = tasks.find(isWaitingOwnerReview);

      if (!reviewTask) {
        panel.hidden = true;
        return;
      }

      const key = reviewTask.task_key || reviewTask.key;
      title.textContent = `${key} — ${getTaskTitle(reviewTask)}`;
      status.textContent = '';
      button.disabled = false;
      button.onclick = () => acceptAndFinalize(reviewTask, panel);
      panel.hidden = false;
    } catch (err) {
      panel.hidden = true;
      console.warn('Owner review action panel failed:', err);
    }
  }

  window.addEventListener('DOMContentLoaded', () => {
    refreshOwnerReviewPanel();
    setInterval(refreshOwnerReviewPanel, 15000);
  });
})();
