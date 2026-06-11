# INTERNAL-002: Improve Daily Report Formatting

Project:
AI Company OS Internal Development

Category:
reporting

Risk Level:
safe

Goal:
Improve the daily report generator so it separates client tasks, internal tasks, recent events, QA status, and recommended owner decisions in a cleaner Markdown format.

Requirements:
- Improve AI Company OS safely.
- Work only inside the allowed project/task scope.
- If the change requires infrastructure, SSH, firewall, Docker daemon, production, secrets, or destructive database changes, create a proposal instead of applying it.
- Update AGENT_HANDOVER.md with INTERNAL-002 notes.
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
