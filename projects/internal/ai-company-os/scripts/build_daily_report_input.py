#!/usr/bin/env python3
"""Build daily report JSON input from PostgreSQL tasks and events."""

from __future__ import annotations

import datetime as dt
import json
import os
import re
import subprocess
import sys
from typing import Any


MAX_ROWS = 100
IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)?$")


def _string(value: Any, default: str = "") -> str:
    if value is None:
        return default
    return str(value).strip()


def _first(row: dict[str, Any], names: tuple[str, ...]) -> Any:
    for name in names:
        if name in row and _string(row[name]):
            return row[name]
    return None


def _validate_table_name(name: str) -> str:
    if not IDENTIFIER_RE.fullmatch(name):
        raise ValueError(f"unsafe PostgreSQL table name: {name!r}")
    return name


def _run_psql_json(table: str) -> list[dict[str, Any]]:
    table = _validate_table_name(table)
    sql = (
        "select coalesce(jsonb_agg(to_jsonb(src)), '[]'::jsonb) "
        f"from (select * from {table} limit {MAX_ROWS}) src;"
    )
    command = [
        os.environ.get("AI_COMPANY_OS_PSQL", "psql"),
        "--no-psqlrc",
        "--set",
        "ON_ERROR_STOP=1",
        "--tuples-only",
        "--no-align",
        "--command",
        sql,
    ]

    env = os.environ.copy()
    env.pop("PGPASSWORD", None)
    env["PGPASSFILE"] = os.devnull
    env["PGSERVICEFILE"] = os.devnull

    result = subprocess.run(command, check=True, capture_output=True, text=True, env=env)
    payload = result.stdout.strip() or "[]"
    rows = json.loads(payload)
    if not isinstance(rows, list):
        raise ValueError(f"PostgreSQL query for {table} did not return a JSON array")

    return [row for row in rows if isinstance(row, dict)]


def _format_date(value: Any) -> str:
    text = _string(value)
    if not text:
        return ""
    return text[:10] if len(text) >= 10 and text[4:5] == "-" else text


def _task_from_row(row: dict[str, Any]) -> dict[str, str]:
    task = {
        "title": _string(
            _first(row, ("title", "name", "summary", "description")), "Untitled task"
        )
    }

    owner = _string(_first(row, ("owner", "assignee", "assigned_to", "responsible")))
    status = _string(_first(row, ("status", "state", "workflow_state")))
    due = _format_date(_first(row, ("due", "due_date", "deadline", "target_date")))
    blocker = _string(_first(row, ("blocker", "blocked_by", "blocking_issue")))

    if owner:
        task["owner"] = owner
    if status:
        task["status"] = status
    if due:
        task["due"] = due
    if blocker:
        task["blocker"] = blocker

    return task


def _is_client_task(row: dict[str, Any]) -> bool:
    haystack = " ".join(
        _string(_first(row, ("scope", "category", "type", "project", "client"))).split()
    ).lower()
    return "client" in haystack


def _event_from_row(row: dict[str, Any]) -> dict[str, str]:
    event = {
        "summary": _string(
            _first(row, ("summary", "title", "name", "message", "description")),
            "Untitled event",
        )
    }

    event_date = _format_date(
        _first(row, ("date", "event_date", "created_at", "occurred_at", "time"))
    )
    impact = _string(_first(row, ("impact", "severity", "result", "outcome")))

    if event_date:
        event["date"] = event_date
    if impact:
        event["impact"] = impact

    return event


def build_report_input(
    tasks: list[dict[str, Any]], events: list[dict[str, Any]]
) -> dict[str, Any]:
    client_tasks = []
    internal_tasks = []
    for row in tasks:
        target = client_tasks if _is_client_task(row) else internal_tasks
        target.append(_task_from_row(row))

    qa_notes = (
        f"Loaded {len(tasks)} task row(s) and {len(events)} event row(s) from PostgreSQL"
    )

    return {
        "title": "AI Company OS Daily Report",
        "date": dt.date.today().isoformat(),
        "summary": "Daily snapshot built from PostgreSQL tasks and events.",
        "client_tasks": client_tasks,
        "internal_tasks": internal_tasks,
        "recent_events": [_event_from_row(row) for row in events],
        "qa_status": [
            {
                "name": "PostgreSQL daily report input",
                "result": "PASS",
                "notes": qa_notes,
            }
        ],
        "owner_decisions": [],
    }


def main() -> int:
    tasks_table = os.environ.get("AI_COMPANY_OS_TASKS_TABLE", "public.tasks")
    events_table = os.environ.get("AI_COMPANY_OS_EVENTS_TABLE", "public.events")

    try:
        report_input = build_report_input(
            _run_psql_json(tasks_table), _run_psql_json(events_table)
        )
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError, ValueError) as exc:
        print(f"failed to build daily report input from PostgreSQL: {exc}", file=sys.stderr)
        return 1

    json.dump(report_input, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
