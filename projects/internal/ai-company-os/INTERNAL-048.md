# INTERNAL-048: Clean Pixel Office CSS and Sprite Frame Selection

Project:
AI Company OS Internal Development

Category:
dashboard

Risk Level:
safe

Goal:
Clean accumulated Pixel Office CSS overrides, consolidate final office map styles, and prepare frame selection rules for JIK character sprites.

Requirements:
- Improve AI Company OS safely.
- Work only inside the allowed project/task scope.
- If the change requires infrastructure, SSH, firewall, Docker daemon, production, secrets, or destructive database changes, create a proposal instead of applying it.
- Update AGENT_HANDOVER.md with INTERNAL-048 notes.
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
