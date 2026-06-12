# INTERNAL-060: Add Pre-Commit Safety Check

## Goal

Add a pre-commit safety runner that verifies system health, shell syntax, and avoids accidental raw asset staging before commits.

## Implemented

Added:

- `runners/pre_commit_check.sh`

## Checks

- unified system health via `./runners/health.sh`
- shell syntax for runner scripts
- git status visibility before commit
- suspicious raw or paid asset paths are not staged

## Usage

    ./runners/pre_commit_check.sh

## Expected Result

    Pre-commit check passed.

## Status

Implemented.
