---
name: hackmd-sync
description: Sync HackMD notes with local filesystem. Use this skill when the user wants to export notes from HackMD, push local changes (update) to HackMD, or synchronize multiple files bidirectionally using the project's scripts.
---

# HackMD Sync

This skill allows you to operate the custom synchronization scripts in this project. These scripts provide a layer above the raw `hackmd-cli` to handle frontmatter management, conflict detection, and bidirectional syncing.

## Available Actions

### 1. Export (Pull from HackMD)

Download notes from HackMD to the local `posts/` directory.

- **Export ALL notes**
  - **User says**: "匯出所有文章", "Download all notes", "Pull everything"
  - **Command**: `./scripts/export.sh`

- **Export SINGLE note**
  - **User says**: "匯出 article.md", "Pull the latest version of my-note.md"
  - **Command**: `./scripts/export.sh "filename.md"`
  - **Note**: If the user provides a title or partial name, try to use the most likely filename.

- **Force Export (Overwrite local)**
  - **User says**: "強制匯出", "Overwrite local with remote", "Force pull"
  - **Command**: `./scripts/export.sh --force` (or `... "filename.md" --force`)
  - **Context**: Use this if the user acknowledges a conflict or explicitly wants to discard local changes.

### 2. Update (Push to HackMD)

Upload local markdown files to HackMD.

- **Update SINGLE note**
  - **User says**: "更新 article.md", "Push my changes to article.md", "Upload this file"
  - **Command**: `./scripts/update.sh "filename.md"`
  - **Context**: This script manages frontmatter intelligently (stripping custom fields).

### 3. Sync (Batch Push)

Scan for modified files and upload them.

- **Sync modified files**
  - **User says**: "同步所有修改", "Sync my changes", "Push all updates"
  - **Command**: `./scripts/sync.sh`
  - **Context**: This only pushes files that have changed since the last sync.

- **Force Sync ALL files**
  - **User says**: "強制同步所有", "Force sync everything"
  - **Command**: `./scripts/sync.sh --force`

## Usage Tips

- Always run these scripts from the project root (`./`).
- If an operation fails due to "Conflict detected", inform the user and ask if they want to force overwrite (using `--force`).
- The scripts rely on `.env` containing `HMD_API_ACCESS_TOKEN`. If missing, remind the user to set it up.
