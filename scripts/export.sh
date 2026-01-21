#!/bin/bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Configuration
POSTS_DIR="./posts"
INDEX_FILE="$POSTS_DIR/index.json"
SYNC_STATE_FILE="$POSTS_DIR/.sync_state"
FORCE_MODE=false

# Check for --force flag
if [ "${1:-}" = "--force" ] || [ "${2:-}" = "--force" ]; then
    FORCE_MODE=true
fi

# Check token
if [ -z "${HMD_API_ACCESS_TOKEN:-}" ]; then
    echo -e "${RED}Error: HMD_API_ACCESS_TOKEN not set${NC}"
    echo "Please add it to .env file or export it"
    exit 1
fi

# Create posts directory
mkdir -p "$POSTS_DIR"

# Function to extract body content (without frontmatter) for comparison
extract_body() {
    local file="$1"
    awk '
    BEGIN { in_fm=0; fm_count=0; }
    /^---$/ {
        fm_count++;
        if (fm_count == 1) { in_fm=1; next; }
        if (fm_count == 2) { in_fm=0; next; }
    }
    !in_fm && fm_count >= 2 { print; }
    ' "$file"
}

# Function to export a single note
export_note() {
    local NOTE_ID="$1"
    local NOTE_TITLE="$2"
    local USER_PATH="$3"

    # Create safe filename from title
    FILENAME=$(echo "$NOTE_TITLE" | sed 's/[/:*?"<>|]/_/g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Handle empty or problematic filenames
    if [ -z "$FILENAME" ] || [ "$FILENAME" = "無標題" ]; then
        FILENAME="${NOTE_ID:0:8}"
    fi

    FILEPATH="$POSTS_DIR/${FILENAME}.md"

    echo -e "  Exporting: ${YELLOW}$NOTE_TITLE${NC}"

    # Export note content
    CONTENT=$(HMD_API_ACCESS_TOKEN="$HMD_API_ACCESS_TOKEN" hackmd-cli export --noteId="$NOTE_ID")

    # Prepare new content with frontmatter
    TEMP_NEW_FILE=$(mktemp)

    # Check if content already has frontmatter
    if echo "$CONTENT" | head -n 1 | grep -q '^---$'; then
        # Content has frontmatter - extract and merge with custom fields
        EXISTING_FRONTMATTER=$(echo "$CONTENT" | awk '/^---$/{if(++count==2) exit; next} count==1')
        BODY=$(echo "$CONTENT" | awk '/^---$/{if(++count==2) {getline; flag=1}} flag')

        # Create merged frontmatter
        cat > "$TEMP_NEW_FILE" <<EOF
---
$EXISTING_FRONTMATTER

# Custom fields for local management
hackmd_id: $NOTE_ID
userPath: $USER_PATH
---
$BODY
EOF
    else
        # No frontmatter - create new one
        cat > "$TEMP_NEW_FILE" <<EOF
---
title: $NOTE_TITLE

# Custom fields for local management
hackmd_id: $NOTE_ID
userPath: $USER_PATH
---
$CONTENT
EOF
    fi

    # Check if local file exists and compare content
    if [ -f "$FILEPATH" ] && [ "$FORCE_MODE" = false ]; then
        # Extract body content from both files for comparison
        LOCAL_BODY=$(extract_body "$FILEPATH")
        REMOTE_BODY=$(extract_body "$TEMP_NEW_FILE")

        # Compare content (MD5 hash)
        LOCAL_HASH=$(echo "$LOCAL_BODY" | md5sum | cut -d' ' -f1)
        REMOTE_HASH=$(echo "$REMOTE_BODY" | md5sum | cut -d' ' -f1)

        if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
            echo -e "  ${RED}⚠ Conflict detected!${NC}"
            echo -e "    Local file differs from remote version"
            echo -e "    ${YELLOW}Skipping to avoid data loss${NC}"
            echo -e "    Use: ${BLUE}./scripts/export.sh \"${FILENAME}.md\" --force${NC} to overwrite"
            rm "$TEMP_NEW_FILE"
            return 1
        else
            echo -e "  ${GREEN}✓ No changes detected${NC}"
            rm "$TEMP_NEW_FILE"
            return 0
        fi
    fi

    # No conflict or force mode - proceed with write
    mv "$TEMP_NEW_FILE" "$FILEPATH"
    echo -e "  ${GREEN}✓${NC} Saved to $FILEPATH"

    # Update sync state for this file
    CURRENT_TIME=$(date +%s)
    TEMP_STATE=$(mktemp)

    if [ -f "$SYNC_STATE_FILE" ]; then
        grep -v "^${FILENAME}.md|" "$SYNC_STATE_FILE" > "$TEMP_STATE" 2>/dev/null || true
    fi
    echo "${FILENAME}.md|$CURRENT_TIME" >> "$TEMP_STATE"
    mv "$TEMP_STATE" "$SYNC_STATE_FILE"

    return 0
}

# Check if single file export mode
SINGLE_FILE_ARG=""
for arg in "$@"; do
    if [ "$arg" != "--force" ]; then
        if [ -z "$SINGLE_FILE_ARG" ]; then
            SINGLE_FILE_ARG="$arg"
        fi
    fi
done

if [ -n "$SINGLE_FILE_ARG" ]; then
    SINGLE_FILENAME="$SINGLE_FILE_ARG"

    echo -e "${BLUE}=== Single File Export ===${NC}"
    if [ "$FORCE_MODE" = true ]; then
        echo -e "${YELLOW}Force mode enabled${NC}"
    fi
    echo -e "\n${YELLOW}Looking for: $SINGLE_FILENAME${NC}\n"

    # Load index.json to find the note ID
    if [ ! -f "$INDEX_FILE" ]; then
        echo -e "${YELLOW}Index file not found, fetching from HackMD...${NC}"
        NOTES_JSON=$(HMD_API_ACCESS_TOKEN="$HMD_API_ACCESS_TOKEN" hackmd-cli notes --output=json)
        echo "$NOTES_JSON" > "$INDEX_FILE"
    else
        NOTES_JSON=$(cat "$INDEX_FILE")
    fi

    # Find note by filename (strip .md extension if present)
    FILENAME_BASE="${SINGLE_FILENAME%.md}"

    # Search by title match or by reading hackmd_id from existing file
    NOTE_FOUND=false

    # First, try to read hackmd_id from existing file
    if [ -f "$POSTS_DIR/$SINGLE_FILENAME" ]; then
        HACKMD_ID=$(awk '
        BEGIN { in_fm=0; fm_count=0; }
        /^---$/ {
            fm_count++;
            if (fm_count == 1) { in_fm=1; next; }
            if (fm_count == 2) { in_fm=0; exit; }
        }
        in_fm && /^hackmd_id:/ {
            sub(/^hackmd_id:[[:space:]]*/, "");
            print;
            exit;
        }
        ' "$POSTS_DIR/$SINGLE_FILENAME")

        if [ -n "$HACKMD_ID" ]; then
            # Find note by ID
            NOTE_DATA=$(echo "$NOTES_JSON" | jq -r --arg id "$HACKMD_ID" '.[] | select(.id == $id)')

            if [ -n "$NOTE_DATA" ]; then
                NOTE_ID=$(echo "$NOTE_DATA" | jq -r '.id')
                NOTE_TITLE=$(echo "$NOTE_DATA" | jq -r '.title')
                USER_PATH=$(echo "$NOTE_DATA" | jq -r '.userPath')
                NOTE_FOUND=true
            fi
        fi
    fi

    # If not found by ID, search by filename/title
    if [ "$NOTE_FOUND" = false ]; then
        NOTE_DATA=$(echo "$NOTES_JSON" | jq -r --arg title "$FILENAME_BASE" '.[] | select(.title == $title)')

        if [ -n "$NOTE_DATA" ]; then
            NOTE_ID=$(echo "$NOTE_DATA" | jq -r '.id')
            NOTE_TITLE=$(echo "$NOTE_DATA" | jq -r '.title')
            USER_PATH=$(echo "$NOTE_DATA" | jq -r '.userPath')
            NOTE_FOUND=true
        fi
    fi

    if [ "$NOTE_FOUND" = false ]; then
        echo -e "${RED}Error: Note not found: $SINGLE_FILENAME${NC}"
        echo -e "${YELLOW}Try running: ./scripts/export.sh (without arguments) to sync all notes${NC}"
        exit 1
    fi

    if export_note "$NOTE_ID" "$NOTE_TITLE" "$USER_PATH"; then
        echo -e "\n${GREEN}Export completed!${NC}"
        exit 0
    else
        echo -e "\n${YELLOW}Export skipped due to conflict${NC}"
        exit 1
    fi
fi

# Full export mode (no arguments)
echo -e "${BLUE}=== Full Export ===${NC}"
if [ "$FORCE_MODE" = true ]; then
    echo -e "${YELLOW}Force mode enabled${NC}"
fi
echo -e "\n${YELLOW}Fetching notes from HackMD...${NC}"

# Fetch all notes as JSON
NOTES_JSON=$(HMD_API_ACCESS_TOKEN="$HMD_API_ACCESS_TOKEN" hackmd-cli notes --output=json)

# Save to index.json
echo "$NOTES_JSON" > "$INDEX_FILE"
echo -e "${GREEN}✓${NC} Saved index to $INDEX_FILE"

# Count total notes
TOTAL=$(echo "$NOTES_JSON" | jq 'length')
echo -e "${YELLOW}Found $TOTAL notes. Starting export...${NC}\n"

# Export each note
CONFLICT_COUNT=0
SUCCESS_COUNT=0

echo "$NOTES_JSON" | jq -c '.[]' | while read -r note; do
    NOTE_ID=$(echo "$note" | jq -r '.id')
    NOTE_TITLE=$(echo "$note" | jq -r '.title')
    USER_PATH=$(echo "$note" | jq -r '.userPath')

    if export_note "$NOTE_ID" "$NOTE_TITLE" "$USER_PATH"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        CONFLICT_COUNT=$((CONFLICT_COUNT + 1))
    fi
done

echo -e "\n${GREEN}Export completed!${NC}"
echo -e "  Total notes: $TOTAL"
echo -e "  Index file: $INDEX_FILE"
echo -e "  Posts directory: $POSTS_DIR"

if [ "$FORCE_MODE" = false ]; then
    echo -e "\n${YELLOW}Note: Files with conflicts were skipped${NC}"
    echo -e "Use ${BLUE}--force${NC} to overwrite local changes"
fi

# Initialize sync state for all exported files
echo -e "\n${YELLOW}Updating sync state...${NC}"
CURRENT_TIME=$(date +%s)

# Create new sync state file
> "$SYNC_STATE_FILE"

# Add all exported markdown files
find "$POSTS_DIR" -maxdepth 1 -name "*.md" -type f | while read -r filepath; do
    FILENAME=$(basename "$filepath")
    echo "$FILENAME|$CURRENT_TIME" >> "$SYNC_STATE_FILE"
done

SYNC_COUNT=$(wc -l < "$SYNC_STATE_FILE")
echo -e "${GREEN}✓${NC} Updated sync state for $SYNC_COUNT files"
