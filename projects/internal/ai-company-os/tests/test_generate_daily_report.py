import json
import tempfile
import unittest
from pathlib import Path

from scripts.generate_daily_report import generate_report, main


class GenerateDailyReportTests(unittest.TestCase):
    def test_generates_required_sections_in_order(self):
        report = generate_report(
            {
                "title": "Daily Report",
                "date": "2026-06-11",
                "client_tasks": [{"title": "Client follow-up", "owner": "Ops"}],
                "internal_tasks": [{"title": "Format report", "status": "done"}],
                "recent_events": [{"date": "2026-06-11", "summary": "Task completed"}],
                "qa_status": [{"name": "Unit tests", "result": "PASS"}],
                "owner_decisions": [
                    {
                        "decision": "Approve format",
                        "owner": "Owner",
                        "recommendation": "Adopt for daily reports",
                    }
                ],
            }
        )

        expected_sections = [
            "## Client Tasks",
            "## Internal Tasks",
            "## Recent Events",
            "## QA Status",
            "## Recommended Owner Decisions",
        ]
        positions = [report.index(section) for section in expected_sections]

        self.assertEqual(positions, sorted(positions))
        self.assertIn("- **Client follow-up** (Owner: Ops)", report)
        self.assertIn("- **Format report** (Status: done)", report)
        self.assertIn("- 2026-06-11: Task completed", report)
        self.assertIn("- **Unit tests**: PASS", report)
        self.assertIn("Recommendation: Adopt for daily reports", report)

    def test_empty_sections_are_explicit(self):
        report = generate_report({"date": "2026-06-11"})

        self.assertEqual(report.count("- None reported."), 5)

    def test_cli_writes_output_file(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            input_path = temp_path / "input.json"
            output_path = temp_path / "report.md"
            input_path.write_text(
                json.dumps(
                    {
                        "date": "2026-06-11",
                        "qa_status": [{"name": "CLI check", "result": "PASS"}],
                    }
                ),
                encoding="utf-8",
            )

            result = main([str(input_path), "--output", str(output_path)])

            self.assertEqual(result, 0)
            self.assertIn("## QA Status", output_path.read_text(encoding="utf-8"))
            self.assertIn("CLI check", output_path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
