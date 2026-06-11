# INTERNAL-045: Add Tilemap Office Renderer v1

Project:
AI Company OS Internal Development

Category:
dashboard

Risk Level:
safe

Goal:
Replace room-card Pixel Office layout with a single top-down tilemap office renderer inspired by MetroCity interior assets, using wall/floor/prop tiles and coordinate-based agent placement.

Requirements:
- Improve AI Company OS safely.
- Work only inside the allowed project/task scope.
- If the change requires infrastructure, SSH, firewall, Docker daemon, production, secrets, or destructive database changes, create a proposal instead of applying it.
- Update AGENT_HANDOVER.md with INTERNAL-045 notes.
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
