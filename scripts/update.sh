#!/bin/bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check arguments
if [ $# -ne 1 ]; then
    echo -e "${RED}Usage: $0 <filename>${NC}"
    echo "Example: $0 btop++.md"
    exit 1
fi

FILENAME="$1"
FILEPATH="./posts/$FILENAME"

# Check if file exists
if [ ! -f "$FILEPATH" ]; then
    echo -e "${RED}Error: File not found: $FILEPATH${NC}"
    exit 1
fi

# Check token
if [ -z "${HMD_API_ACCESS_TOKEN:-}" ]; then
    echo -e "${RED}Error: HMD_API_ACCESS_TOKEN not set${NC}"
    echo "Please add it to .env file or export it"
    exit 1
fi

echo -e "${YELLOW}Processing: $FILENAME${NC}"

# Extract hackmd_id from frontmatter (only first YAML block)
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
' "$FILEPATH")

if [ -z "$HACKMD_ID" ]; then
    echo -e "${RED}Error: No hackmd_id found in frontmatter${NC}"
    exit 1
fi

echo -e "  HackMD ID: ${YELLOW}$HACKMD_ID${NC}"

# Official HackMD metadata fields to preserve
OFFICIAL_FIELDS="title|tags|image|description|robots|lang|breaks|GA"

# Custom fields to remove
CUSTOM_FIELDS="hackmd_id|userPath"

# Process the file
TEMP_FILE=$(mktemp)

# Extract and filter frontmatter, then append body
awk -v official="$OFFICIAL_FIELDS" -v custom="$CUSTOM_FIELDS" '
BEGIN {
    in_frontmatter=0;
    frontmatter_count=0;
    has_official=0;
}

# Detect frontmatter boundaries
/^---$/ {
    frontmatter_count++;
    if (frontmatter_count == 1) {
        in_frontmatter=1;
        print "---";
        next;
    } else if (frontmatter_count == 2) {
        in_frontmatter=0;
        if (has_official) {
            print "---";
        }
        next;
    }
}

# Inside frontmatter
in_frontmatter {
    # Skip comments
    if ($0 ~ /^[[:space:]]*#/) {
        next;
    }

    # Skip custom fields
    if ($0 ~ "^(" custom "):") {
        next;
    }

    # Keep official fields
    if ($0 ~ "^(" official "):") {
        print;
        has_official=1;
        next;
    }

    # Keep other YAML content (arrays, multiline values, etc.)
    if ($0 ~ /^[[:space:]]/ || $0 ~ /^-[[:space:]]/) {
        if (has_official) {
            print;
        }
        next;
    }
}

# Outside frontmatter (body content)
!in_frontmatter && frontmatter_count >= 2 {
    print;
}
' "$FILEPATH" > "$TEMP_FILE"

# Update to HackMD
echo -e "  ${YELLOW}Uploading to HackMD...${NC}"

# Read the temp file content
CONTENT=$(cat "$TEMP_FILE")

if HMD_API_ACCESS_TOKEN="$HMD_API_ACCESS_TOKEN" hackmd-cli notes update --noteId="$HACKMD_ID" --content="$CONTENT" 2>&1; then
    echo -e "  ${GREEN}✓ Successfully updated!${NC}"
    rm "$TEMP_FILE"

    # Update sync state
    SYNC_STATE_FILE="./posts/.sync_state"
    CURRENT_TIME=$(date +%s)
    TEMP_STATE=$(mktemp)

    # Update or add entry for this file
    if [ -f "$SYNC_STATE_FILE" ]; then
        grep -v "^$FILENAME|" "$SYNC_STATE_FILE" > "$TEMP_STATE" 2>/dev/null || true
    fi
    echo "$FILENAME|$CURRENT_TIME" >> "$TEMP_STATE"
    mv "$TEMP_STATE" "$SYNC_STATE_FILE"

    exit 0
else
    echo -e "  ${RED}✗ Update failed${NC}"
    echo -e "  ${YELLOW}Content saved to: $TEMP_FILE${NC}"
    exit 1
fi

