#!/bin/bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
POSTS_DIR="./posts"
UPDATE_SCRIPT="./scripts/update.sh"
SYNC_STATE_FILE="./posts/.sync_state"

# Counters
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

echo -e "${BLUE}=== HackMD Sync Script ===${NC}\n"

# Check if posts directory exists
if [ ! -d "$POSTS_DIR" ]; then
    echo -e "${RED}Error: Posts directory not found: $POSTS_DIR${NC}"
    exit 1
fi

# Check for force flag
FORCE_SYNC=false
if [ "${1:-}" = "--force" ] || [ "${1:-}" = "-f" ]; then
    FORCE_SYNC=true
    echo -e "${YELLOW}Force mode enabled - syncing all files${NC}\n"
fi

# Load last sync timestamps
declare -A LAST_SYNC_TIMES
if [ -f "$SYNC_STATE_FILE" ] && [ "$FORCE_SYNC" = false ]; then
    while IFS='|' read -r filename timestamp; do
        LAST_SYNC_TIMES["$filename"]="$timestamp"
    done < "$SYNC_STATE_FILE"
    echo -e "${BLUE}Loaded sync state for ${#LAST_SYNC_TIMES[@]} files${NC}\n"
fi

# Find all markdown files
MARKDOWN_FILES=$(find "$POSTS_DIR" -maxdepth 1 -name "*.md" -type f)

if [ -z "$MARKDOWN_FILES" ]; then
    echo -e "${YELLOW}No markdown files found in $POSTS_DIR${NC}"
    exit 0
fi

# Count total files
TOTAL_COUNT=$(echo "$MARKDOWN_FILES" | wc -l)
echo -e "${YELLOW}Found $TOTAL_COUNT markdown files${NC}\n"

# Temporary file for new sync state
TEMP_SYNC_STATE=$(mktemp)

# Process each file
CURRENT=0
while IFS= read -r filepath; do
    CURRENT=$((CURRENT + 1))
    FILENAME=$(basename "$filepath")

    echo -e "${BLUE}[$CURRENT/$TOTAL_COUNT]${NC} Processing: $FILENAME"

    # Check if file has hackmd_id
    if ! grep -q '^hackmd_id:' "$filepath"; then
        echo -e "  ${YELLOW}⊘ Skipped - No hackmd_id found${NC}\n"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi

    # Get file modification time (epoch seconds)
    FILE_MTIME=$(stat -c %Y "$filepath" 2>/dev/null || stat -f %m "$filepath" 2>/dev/null)

    # Check if file needs syncing
    NEEDS_SYNC=false
    if [ "$FORCE_SYNC" = true ]; then
        NEEDS_SYNC=true
    elif [ -z "${LAST_SYNC_TIMES[$FILENAME]:-}" ]; then
        echo -e "  ${YELLOW}→ New file, needs sync${NC}"
        NEEDS_SYNC=true
    elif [ "$FILE_MTIME" -gt "${LAST_SYNC_TIMES[$FILENAME]}" ]; then
        LAST_SYNC_DATE=$(date -d "@${LAST_SYNC_TIMES[$FILENAME]}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "${LAST_SYNC_TIMES[$FILENAME]}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
        echo -e "  ${YELLOW}→ Modified since last sync ($LAST_SYNC_DATE)${NC}"
        NEEDS_SYNC=true
    else
        echo -e "  ${GREEN}✓ Up to date, skipping${NC}\n"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        # Still record in new sync state
        echo "$FILENAME|${LAST_SYNC_TIMES[$FILENAME]}" >> "$TEMP_SYNC_STATE"
        continue
    fi

    if [ "$NEEDS_SYNC" = true ]; then
        # Call update script
        if bash "$UPDATE_SCRIPT" "$FILENAME" 2>&1 | grep -q "Successfully updated"; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            # Record successful sync time
            CURRENT_TIME=$(date +%s)
            echo "$FILENAME|$CURRENT_TIME" >> "$TEMP_SYNC_STATE"
        else
            echo -e "  ${RED}✗ Update failed${NC}"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            # Keep old timestamp if update failed
            if [ -n "${LAST_SYNC_TIMES[$FILENAME]:-}" ]; then
                echo "$FILENAME|${LAST_SYNC_TIMES[$FILENAME]}" >> "$TEMP_SYNC_STATE"
            fi
        fi
    fi

    echo ""
done <<< "$MARKDOWN_FILES"

# Update sync state file
mv "$TEMP_SYNC_STATE" "$SYNC_STATE_FILE"

# Summary
echo -e "${BLUE}=== Sync Summary ===${NC}"
echo -e "  Total files:    $TOTAL_COUNT"
echo -e "  ${GREEN}Successful:     $SUCCESS_COUNT${NC}"
echo -e "  ${RED}Failed:         $FAIL_COUNT${NC}"
echo -e "  ${YELLOW}Skipped:        $SKIP_COUNT${NC}"

if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
fi
