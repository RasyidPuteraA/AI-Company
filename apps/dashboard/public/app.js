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
