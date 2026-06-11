# INTERNAL-003: Integrate Improved Daily Report Generator

Project:
AI Company OS Internal Development

Category:
reporting

Risk Level:
safe

Goal:
Integrate the improved Python daily report generator into runners/generate_daily_report.sh so the main daily report command produces cleaner sections for client tasks, internal tasks, recent events, QA status, and recommended owner decisions.

Requirements:
- Improve AI Company OS safely.
- Work only inside the allowed project/task scope.
- If the change requires infrastructure, SSH, firewall, Docker daemon, production, secrets, or destructive database changes, create a proposal instead of applying it.
- Update AGENT_HANDOVER.md with INTERNAL-003 notes.
- If code/script is changed, describe test result clearly.

Rules:
- Do not access secrets.
- Do not use sudo.
- Do not deploy production.
- Do not modify SSH or firewall.
- Do not delete database, Docker volume, or project files.
- For dangerous infrastructure changes, write a proposal under company/proposals/internal instead of executing.

Required output:
- Implementation or proposal files
- Updated AGENT_HANDOVER.md
- Build/test/check result
