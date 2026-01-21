# HackMD Sync System

[English](README.md) | [中文](README.zh-tw.md)

**HackMD Sync System** is a robust local synchronization tool designed to bridge your local development environment with HackMD. It enables seamless bidirectional synchronization, allowing users to edit Markdown files with their preferred local editors while keeping content perfectly synced with HackMD.

## Features

- ✅ **Bidirectional Sync** - Support pulling from and pushing to HackMD.
- ✅ **Conflict Detection** - MD5 content comparison to prevent accidental overwrites.
- ✅ **Smart Frontmatter** - Preserves official HackMD metadata while automatically managing custom local fields.
- ✅ **State Tracking** - Skips unmodified files to minimize unnecessary API calls.
- ✅ **Batch Operations** - Supports single file or batch synchronization.

## Quick Start

### 1. Install Dependencies

```bash
npm install -g @hackmd/hackmd-cli
```

### 2. Configure API Token

Create an API token in [HackMD Settings](https://hackmd.io/settings#api), then create a `.env` file:

```bash
HMD_API_ACCESS_TOKEN=your_token_here
```

### 3. Basic Usage

```bash
# Export all notes
./scripts/export.sh

# Edit a note
vim posts/my-article.md

# Push updates
./scripts/update.sh "my-article.md"

# Batch sync all changes
./scripts/sync.sh
```

## AI Agent Support

This project includes a specialized Agent Skill (`hackmd-sync`), allowing you to use natural language to let AI perform synchronization operations.

### Supported Command Examples

You don't need to memorize complex script commands, just tell the AI:

- **"Export all notes"** → AI runs `./scripts/export.sh`
- **"Export article.md"** → AI runs `./scripts/export.sh "article.md"`
- **"Update article.md"** → AI runs `./scripts/update.sh "article.md"`
- **"Sync all changes"** → AI runs `./scripts/sync.sh`
- **"Force export"** → AI runs `./scripts/export.sh --force`

The AI assistant will automatically parse your intent and call the corresponding scripts while handling parameter passing.

## System Architecture

### File Structure

```
.
├── posts/                # Notes directory
│   ├── .sync_state      # Sync state tracking
│   ├── index.json       # Notes index
│   └── *.md             # Markdown notes
├── scripts/
│   ├── export.sh        # Export (Pull)
│   ├── update.sh        # Single push
│   └── sync.sh          # Batch push
└── .env                 # API Token
```

### Workflow

```
        HackMD Cloud ☁️
              ↕
    ┌─────────┴─────────┐
    ↓                   ↓
export.sh           update.sh
(Pull)              (Push)
    ↓                   ↑
    └─────────┬─────────┘
              ↓
        Local Files 📄
    (posts/*.md + .sync_state)
              ↑
          sync.sh
        (Batch Push)
```

## Core Features

### 1. Export (Pull) - Download from HackMD

#### Export all notes
```bash
./scripts/export.sh
```

#### Export a single note (Pull function)
```bash
./scripts/export.sh "article.md"
```

**Conflict Detection:**
- If the local file differs from the remote content, a warning will be displayed and the file will be skipped.
- Use `--force` to overwrite local changes.

```bash
./scripts/export.sh "article.md" --force
```

#### Characteristics
- ✅ MD5 content comparison
- ✅ Retains original HackMD frontmatter
- ✅ Adds custom management fields
- ✅ Generates note index file
- ✅ Handles special characters in filenames (Chinese, spaces, symbols)

### 2. Update (Push) - Upload to HackMD

```bash
./scripts/update.sh "article.md"
```

#### Characteristics
- ✅ Reads `hackmd_id` from frontmatter
- ✅ Smart filtering: retains official fields, removes custom fields
- ✅ Automatically updates `.sync_state`

### 3. Sync (Batch Push) - Batch Synchronization

```bash
./scripts/sync.sh
```

#### Characteristics
- ✅ Automatically scans `posts/` directory
- ✅ Compares file modification time with export time, uploads only modified files
- ✅ Provides execution summary (success/failure/skipped count)

**Force sync all files:**
```bash
./scripts/sync.sh --force
```

## Frontmatter Handling Strategy

### Official Fields (Retained on Upload)

Native HackMD fields are retained:
- `title` - Note title
- `tags` - Tags
- `image` - Cover image
- `description` - Description
- `robots`, `lang`, `breaks`, `GA`, etc.

### Custom Fields (Removed on Upload)

Used only for local management:
- `hackmd_id` - Note ID (for updates)
- `userPath` - User path

### Frontmatter Example

```yaml
---
# HackMD Official Fields (Retained on Upload)
title: My Article
tags: tutorial, notes
image: https://example.com/cover.jpg

# Custom Fields (Removed on Upload)
hackmd_id: abc123xyz
userPath: username
---
```

## Usage Scenarios

### Scenario 1: Sync to local after editing on HackMD

```bash
# Pull latest version after editing on HackMD website
./scripts/export.sh "article.md"

# If local changes exist → Conflict warning
# If no local changes → ✓ No changes detected
```

### Scenario 2: Push to HackMD after local editing

```bash
# Local edit
vim "posts/article.md"

# Single upload
./scripts/update.sh "article.md"

# Or batch sync
./scripts/sync.sh
```

### Scenario 3: Both modified (Conflict Handling)

```bash
# Try to pull
./scripts/export.sh "article.md"
# ⚠ Conflict detected!

# Option 1: Keep local version, push to HackMD
./scripts/update.sh "article.md"

# Option 2: Discard local changes, use remote version
./scripts/export.sh "article.md" --force
```

## Core Mechanisms

### 1. Dual Record Architecture
- **JSON Index** (`index.json`) - Provides overall view, facilitates batch operations
- **YAML Frontmatter** - Each file is self-contained with metadata, recoverable even if index is lost

### 2. Sync State Tracking (`.sync_state`)
- Records the last sync time (Unix timestamp) for each file
- Prevents re-uploading unmodified files
- Automatically updates after export, update, and sync operations

### 3. Conflict Detection
- MD5 compares local and remote content
- Compares only note body (excludes frontmatter)
- Prevents accidental overwrites, protects data safety

## Script Overview

| Script | Function | Conflict Handling | State Tracking |
|--------|----------|------------------|----------------|
| `export.sh` | Export (Pull) | ✅ MD5 Check | ✅ Update |
| `update.sh` | Single Upload (Push) | ❌ Force Overwrite | ✅ Update |
| `sync.sh` | Batch Upload (Push) | ⏱ Time Comparison | ✅ Update |

## System Advantages

1. **Safety**
   - Conflict detection prevents accidental overwrites
   - State tracking prevents data loss

2. **Flexibility**
   - Supports single file or batch operations
   - `--force` parameter ensures forced overwrite option

3. **Compatibility**
   - Retains HackMD official metadata
   - Fully utilizes platform features

4. **Efficiency**
   - Syncs only modified files
   - Reduces unnecessary API requests

## FAQ

### Q: How to initialize the project?

```bash
# 1. Install hackmd-cli
npm install -g @hackmd/hackmd-cli

# 2. Set API token
echo "HMD_API_ACCESS_TOKEN=your_token" > .env

# 3. Export all notes
./scripts/export.sh
```

### Q: How to handle notes with special characters in filenames?

The system automatically handles special characters (Chinese, spaces, symbols), converting illegal characters to underscores `_`.

### Q: What if the `.sync_state` file is lost?

Running `./scripts/export.sh` will recreate `.sync_state`, marking all files as synced at the current time.

### Q: How to force re-sync all notes?

```bash
./scripts/sync.sh --force
```

## License

MIT License

## Contributing

Issues and Pull Requests are welcome!
