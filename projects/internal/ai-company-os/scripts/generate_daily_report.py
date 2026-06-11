#!/usr/bin/env python3
"""Generate a clean AI Company OS daily report in Markdown."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path
from typing import Any


SECTION_ORDER = (
    ("client_tasks", "Client Tasks"),
    ("internal_tasks", "Internal Tasks"),
    ("recent_events", "Recent Events"),
    ("qa_status", "QA Status"),
    ("owner_decisions", "Recommended Owner Decisions"),
)


def _as_list(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]


def _string(value: Any, default: str = "") -> str:
    if value is None:
        return default
    return str(value).strip()


def _format_task(item: Any) -> str:
    if isinstance(item, str):
        return f"- {item}"

    if not isinstance(item, dict):
        return f"- {item}"

    title = _string(item.get("title"), "Untitled task")
    owner = _string(item.get("owner"))
    status = _string(item.get("status"))
    due = _string(item.get("due"))
    blocker = _string(item.get("blocker"))

    metadata = []
    if owner:
        metadata.append(f"Owner: {owner}")
    if status:
        metadata.append(f"Status: {status}")
    if due:
        metadata.append(f"Due: {due}")
    if blocker:
        metadata.append(f"Blocker: {blocker}")

    suffix = f" ({'; '.join(metadata)})" if metadata else ""
    return f"- **{title}**{suffix}"


def _format_event(item: Any) -> str:
    if isinstance(item, str):
        return f"- {item}"

    if not isinstance(item, dict):
        return f"- {item}"

    date = _string(item.get("date") or item.get("time"))
    summary = _string(item.get("summary") or item.get("title"), "Untitled event")
    impact = _string(item.get("impact"))

    prefix = f"{date}: " if date else ""
    suffix = f" (Impact: {impact})" if impact else ""
    return f"- {prefix}{summary}{suffix}"


def _format_qa_status(item: Any) -> str:
    if isinstance(item, str):
        return f"- {item}"

    if not isinstance(item, dict):
        return f"- {item}"

    name = _string(item.get("name") or item.get("check"), "Unnamed check")
    result = _string(item.get("result") or item.get("status"), "unknown")
    notes = _string(item.get("notes"))

    suffix = f" - {notes}" if notes else ""
    return f"- **{name}**: {result}{suffix}"


def _format_decision(item: Any) -> str:
    if isinstance(item, str):
        return f"- {item}"

    if not isinstance(item, dict):
        return f"- {item}"

    decision = _string(item.get("decision") or item.get("title"), "Decision needed")
    owner = _string(item.get("owner"))
    recommendation = _string(item.get("recommendation"))
    by = _string(item.get("by") or item.get("due"))

    metadata = []
    if owner:
        metadata.append(f"Owner: {owner}")
    if by:
        metadata.append(f"By: {by}")

    suffix = f" ({'; '.join(metadata)})" if metadata else ""
    detail = f" Recommendation: {recommendation}" if recommendation else ""
    return f"- **{decision}**{suffix}.{detail}".rstrip()


def _format_items(section_key: str, items: list[Any]) -> list[str]:
    if not items:
        return ["- None reported."]

    if section_key in {"client_tasks", "internal_tasks"}:
        return [_format_task(item) for item in items]
    if section_key == "recent_events":
        return [_format_event(item) for item in items]
    if section_key == "qa_status":
        return [_format_qa_status(item) for item in items]
    if section_key == "owner_decisions":
        return [_format_decision(item) for item in items]
    return [f"- {item}" for item in items]


def generate_report(data: dict[str, Any]) -> str:
    title = _string(data.get("title"), "AI Company OS Daily Report")
    report_date = _string(data.get("date"), dt.date.today().isoformat())
    summary = _string(data.get("summary"))

    lines = [
        f"# {title}",
        "",
        f"Date: {report_date}",
    ]

    if summary:
        lines.extend(["", "## Summary", "", summary])

    for section_key, section_title in SECTION_ORDER:
        lines.extend(["", f"## {section_title}", ""])
        lines.extend(_format_items(section_key, _as_list(data.get(section_key))))

    lines.append("")
    return "\n".join(lines)


def load_input(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError("daily report input must be a JSON object")
    return data


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a clean Markdown daily report from a JSON input file."
    )
    parser.add_argument("input", type=Path, help="Path to report input JSON")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Optional output path. Defaults to stdout.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    report = generate_report(load_input(args.input))

    if args.output:
        args.output.write_text(report, encoding="utf-8")
    else:
        sys.stdout.write(report)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
