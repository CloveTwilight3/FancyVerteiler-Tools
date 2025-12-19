#!/bin/bash
# Fetch Minecraft CurseForge Versions
# This script fetches the latest Minecraft versions from CurseForge
# and generates the Go code to add to versions.go

set -e

# Parse arguments
API_TOKEN=""
PROJECT_TYPE="plugin"

while [[ $# -gt 0 ]]; do
    case $1 in
        -ApiToken)
            API_TOKEN="$2"
            shift 2
            ;;
        -Type)
            PROJECT_TYPE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 -ApiToken <token> [-Type <type>]"
            echo ""
            echo "Fetches Minecraft versions from CurseForge API"
            echo ""
            echo "Options:"
            echo "  -ApiToken <token>    Your CurseForge API token"
            echo "  -Type <type>         Project type: 'plugin' or 'mod' (default: plugin)"
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
    echo "Usage: $0 -ApiToken <token> [-Type <type>]"
    exit 1
fi

if [ "$PROJECT_TYPE" != "plugin" ] && [ "$PROJECT_TYPE" != "mod" ]; then
    echo "Error: -Type must be 'plugin' or 'mod'"
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

echo -e "${CYAN}Fetching Minecraft ${PROJECT_TYPE} versions from CurseForge...${NC}"

# Fetch versions
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "X-Api-Token: $API_TOKEN" \
    -H "Accept: application/json" \
    "https://minecraft.curseforge.com/api/game/versions")

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

# Determine which gameVersionTypeID to filter by
if [ "$PROJECT_TYPE" = "plugin" ]; then
    TYPE_ID=1
else
    # For mods, we'll show multiple version types
    TYPE_ID="73407,75125,77784"
fi

# Filter and parse JSON
if [ "$PROJECT_TYPE" = "plugin" ]; then
    FILTERED=$(echo "$BODY" | jq "[.[] | select(.gameVersionTypeID == $TYPE_ID)]")
else
    FILTERED=$(echo "$BODY" | jq "[.[] | select(.gameVersionTypeID == 73407 or .gameVersionTypeID == 75125 or .gameVersionTypeID == 77784)]")
fi

VERSION_COUNT=$(echo "$FILTERED" | jq 'length')

echo ""
echo -e "${GREEN}Found $VERSION_COUNT ${PROJECT_TYPE} versions${NC}"
echo ""

# Display recent versions in table format (last 20)
echo -e "${CYAN}Recent Versions (last 20):${NC}"
echo "Version Name    Version ID    Type ID    Slug"
echo "------------    ----------    -------    ----"
echo "$FILTERED" | jq -r '.[-20:] | .[] | "\(.name)\t\(.id)\t\(.gameVersionTypeID)\t\(.slug)"' | column -t

# Generate Go code
echo ""
echo -e "${YELLOW}=== Go Code for versions.go ===${NC}"

if [ "$PROJECT_TYPE" = "plugin" ]; then
    echo -e "${WHITE}var pluginVersionToID = map[string]int{${NC}"
else
    echo -e "${WHITE}var modVersionToID = map[string]int{${NC}"
fi

# Show last 30 versions sorted
echo "$FILTERED" | jq -r '.[-30:] | .[] | "\"\(.name)\":\(.id) // gameVersionTypeID: \(.gameVersionTypeID), slug: \(.slug)"' | while read -r line; do
    VERSION=$(echo "$line" | cut -d: -f1)
    REST=$(echo "$line" | cut -d: -f2-)
    # Calculate padding safely (min 0, max 20)
    PADDING_LENGTH=$((20 - ${#VERSION}))
    if [ $PADDING_LENGTH -lt 0 ]; then
        PADDING_LENGTH=0
    fi
    PADDING=$(printf '%*s' $PADDING_LENGTH '')
    
    # Add version comments for major releases
    VERSION_NUM=$(echo "$VERSION" | tr -d '"')
    if [[ "$VERSION_NUM" =~ ^\"1\.[0-9]+$ ]]; then
        echo ""
        echo -e "${GRAY}\t// $VERSION_NUM.x versions${NC}"
    fi
    
    echo -e "${WHITE}\t${VERSION}:${PADDING}${REST}${NC}"
done

echo -e "${WHITE}}${NC}"

# Generate JSON mapping
echo ""
echo -e "${YELLOW}=== JSON Export ===${NC}"

JSON_OUTPUT=$(echo "$FILTERED" | jq '[.[] | {name, id, gameVersionTypeID, slug}]')
echo "$JSON_OUTPUT" | jq '.' | head -20
echo "..."

OUTPUT_FILE="minecraft-${PROJECT_TYPE}-versions-export.json"
echo "$JSON_OUTPUT" > "$OUTPUT_FILE"
echo -e "${GREEN}Full data saved to $OUTPUT_FILE${NC}"

# Generate configuration examples
echo ""
echo -e "${YELLOW}=== Example Configurations ===${NC}"

LATEST_VERSION=$(echo "$FILTERED" | jq -r '.[-1].name')
echo ""
echo -e "${CYAN}For latest version ($LATEST_VERSION):${NC}"

if [ "$PROJECT_TYPE" = "plugin" ]; then
    cat <<EOF
{
  "curseforge": {
    "projectID": "your-project-id",
    "type": "plugin",
    "gameVersions": ["$LATEST_VERSION"],
    "releaseType": "release"
  }
}
EOF
else
    cat <<EOF
{
  "curseforge": {
    "projectID": "your-project-id",
    "type": "mod",
    "loader": "fabric",  // or "forge", "neoforge", "quilt"
    "gameVersions": ["$LATEST_VERSION"],
    "releaseType": "release"
  }
}
EOF
fi

# Show multiple version example
echo ""
echo -e "${CYAN}For multiple versions:${NC}"
VERSION_LIST=$(echo "$FILTERED" | jq -r '.[-3:] | [.[].name] | map("\"" + . + "\"") | join(", ")')

if [ "$PROJECT_TYPE" = "plugin" ]; then
    cat <<EOF
{
  "curseforge": {
    "projectID": "your-project-id",
    "type": "plugin",
    "gameVersions": [$VERSION_LIST],
    "releaseType": "release"
  }
}
EOF
else
    cat <<EOF
{
  "curseforge": {
    "projectID": "your-project-id",
    "type": "mod",
    "loader": "fabric",
    "gameVersions": [$VERSION_LIST],
    "releaseType": "release"
  }
}
EOF
fi

# Show version type info
echo ""
echo -e "${YELLOW}=== Version Type Information ===${NC}"
if [ "$PROJECT_TYPE" = "plugin" ]; then
    echo -e "${WHITE}Version Type ID: 1 (PluginVersionType)${NC}"
    echo -e "${GRAY}All Bukkit/Spigot/Paper plugin versions use gameVersionTypeID = 1${NC}"
else
    echo -e "${WHITE}Version Type IDs for Mods:${NC}"
    echo -e "${WHITE}  - 1.19.x: 73407 (ModVersionType_119)${NC}"
    echo -e "${WHITE}  - 1.20.x: 75125 (ModVersionType_120)${NC}"
    echo -e "${WHITE}  - 1.21.x: 77784 (ModVersionType_121)${NC}"
    echo -e "${GRAY}Mod versions are split by Minecraft version family${NC}"
fi

echo ""
echo -e "${CYAN}=== Instructions ===${NC}"
echo -e "${WHITE}1. Copy the 'Go Code' section above into your versions.go file${NC}"
if [ "$PROJECT_TYPE" = "plugin" ]; then
    echo -e "${WHITE}2. Replace or update the pluginVersionToID map${NC}"
else
    echo -e "${WHITE}2. Replace or update the modVersionToID map${NC}"
fi
echo -e "${WHITE}3. Update your deployment.json with the version names you need${NC}"
echo -e "${WHITE}4. Test your deployment!${NC}"

echo ""
echo -e "${GRAY}Tip: Run with -Type mod to get mod versions, or -Type plugin for plugin versions${NC}"