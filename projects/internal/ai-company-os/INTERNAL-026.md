# INTERNAL-026: Add File Upload Intake v0

## Goal

Add dashboard and backend file upload intake so Owner can upload client requirement files and attach them to a project workspace.

## Implemented

Added migration:

- docker/postgres/005_project_uploads.sql

Added API endpoints:

- GET /api/uploads?project_key=<project_key>
- POST /api/uploads

Updated dashboard:

- added File Upload Intake panel
- added project_key input
- added file picker
- added upload button
- added upload history list

Storage:

- files are stored under projects/clients/<project_key>/uploads/
- metadata is stored in project_uploads

Updated files:

- apps/dashboard/server.js
- apps/dashboard/public/index.html
- apps/dashboard/public/styles.css
- apps/dashboard/public/app.js

## Verification

- migration applied successfully
- node --check apps/dashboard/server.js
- node --check apps/dashboard/public/app.js
- dashboard service restarted
- GET /api/uploads tested
- POST /api/uploads tested
- uploaded file verified in project workspace
- project_file_uploaded event logged

## Status

Implemented.
