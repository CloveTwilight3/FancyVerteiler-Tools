#!/bin/bash
# Fetch Hytale CurseForge Versions
# This script fetches the latest Hytale versions from CurseForge
# and generates the Go code to add to versions.go

set -e

# Parse arguments
API_TOKEN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -ApiToken)
            API_TOKEN="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 -ApiToken <token>"
            echo ""
            echo "Fetches Hytale versions from CurseForge API"
            echo ""
            echo "Options:"
            echo "  -ApiToken <token>    Your CurseForge API token"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

if [ -z "$API_TOKEN" ]; then
    echo "Error: -ApiToken is required"
    echo "Usage: $0 -ApiToken <token>"
    exit 1
fi

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}Fetching Hytale versions from CurseForge...${NC}"

# Fetch versions
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "X-Api-Token: $API_TOKEN" \
    -H "Accept: application/json" \
    "https://hytale.curseforge.com/api/game/versions")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo -e "${RED}Error: HTTP $HTTP_CODE${NC}"
    echo -e "${RED}Response: $BODY${NC}"
    
    if [ "$HTTP_CODE" = "403" ]; then
        echo -e "${YELLOW}Possible issues:${NC}"
        echo -e "${YELLOW}1. API token is invalid or expired${NC}"
        echo -e "${YELLOW}2. Regenerate at: https://www.curseforge.com/account/api-tokens${NC}"
    fi
    exit 1
fi

# Parse JSON and display results
echo ""
echo -e "${GREEN}Success!${NC}"
echo ""

# Display versions in table format
echo "Version Name    Version ID    Type ID    Slug"
echo "------------    ----------    -------    ----"
echo "$BODY" | jq -r '.[] | "\(.name)\t\(.id)\t\(.gameVersionTypeID)\t\(.slug)"' | column -t

# Generate Go code
echo ""
echo -e "${YELLOW}=== Go Code for versions.go ===${NC}"
echo -e "${WHITE}var hytaleVersionToID = map[string]int{${NC}"

echo "$BODY" | jq -r '.[] | "\"\(.name)\":\(.id) // Slug: \(.slug)"' | sort | while read -r line; do
    # Calculate padding
    VERSION=$(echo "$line" | cut -d: -f1)
    REST=$(echo "$line" | cut -d: -f2-)
    # Calculate padding safely (min 0, max 20)
    PADDING_LENGTH=$((20 - ${#VERSION}))
    if [ $PADDING_LENGTH -lt 0 ]; then
        PADDING_LENGTH=0
    fi
    PADDING=$(printf '%*s' $PADDING_LENGTH '')
    echo -e "${WHITE}\t${VERSION}:${PADDING}${REST}${NC}"
done

echo -e "${WHITE}}${NC}"

# Generate JSON mapping
echo ""
echo -e "${YELLOW}=== JSON Mapping ===${NC}"

VERSION_TYPE_ID=$(echo "$BODY" | jq -r '.[0].gameVersionTypeID')
JSON_OUTPUT=$(jq -n \
    --argjson typeId "$VERSION_TYPE_ID" \
    --argjson versions "$(echo "$BODY" | jq '[.[] | {name, id, slug}]')" \
    '{versionTypeId: $typeId, versions: $versions}')

echo "$JSON_OUTPUT" | jq '.'
echo "$JSON_OUTPUT" > hytale-versions-export.json
echo -e "${GREEN}Saved to hytale-versions-export.json${NC}"

# Generate configuration examples
echo ""
echo -e "${YELLOW}=== Example Configurations ===${NC}"

FIRST_VERSION=$(echo "$BODY" | jq -r '.[0].name')
echo ""
echo -e "${CYAN}For use in deployment.json:${NC}"
cat <<EOF
{
  "curseforge": {
    "projectID": "your-project-id",
    "type": "hytale",
    "gameVersions": ["$FIRST_VERSION"],
    "releaseType": "release"
  }
}
EOF

VERSION_COUNT=$(echo "$BODY" | jq 'length')
if [ "$VERSION_COUNT" -gt 1 ]; then
    echo ""
    echo -e "${CYAN}For multiple versions:${NC}"
    VERSION_LIST=$(echo "$BODY" | jq -r '[limit(3; .[].name)] | map("\"" + . + "\"") | join(", ")')
    cat <<EOF
{
  "curseforge": {
    "projectID": "your-project-id",
    "type": "hytale",
    "gameVersions": [$VERSION_LIST],
    "releaseType": "release"
  }
}
EOF
fi

# Show version type info
echo ""
echo -e "${YELLOW}=== Version Type Information ===${NC}"
echo -e "${WHITE}Version Type ID: $VERSION_TYPE_ID${NC}"
echo -e "${GRAY}This should match HytaleVersionType constant in versions.go${NC}"

echo ""
echo -e "${CYAN}=== Instructions ===${NC}"
echo -e "${WHITE}1. Copy the 'Go Code' section above into your versions.go file${NC}"
echo -e "${WHITE}2. Replace the existing hytaleVersionToID map${NC}"
echo -e "${WHITE}3. Update your deployment.json with the version names you need${NC}"
echo -e "${WHITE}4. Test your deployment!${NC}"