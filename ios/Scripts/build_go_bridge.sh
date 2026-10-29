#!/bin/bash
set -e

# Log to a temp file for debugging
LOG_FILE="/tmp/wireguard_build_log.txt"
echo "--- Build started at $(date) ---" > "$LOG_FILE"
echo "ACTION: $1" >> "$LOG_FILE"
echo "BUILD_DIR: $BUILD_DIR" >> "$LOG_FILE"
echo "SYMROOT: $SYMROOT" >> "$LOG_FILE"
echo "SOURCE_ROOT: $SOURCE_ROOT" >> "$LOG_FILE"
echo "PATH: $PATH" >> "$LOG_FILE"

# Ensure Go is in PATH (common locations)
export PATH="$PATH:/usr/local/go/bin:/opt/homebrew/bin:/usr/local/bin"
echo "Updated PATH: $PATH" >> "$LOG_FILE"

if ! command -v go &> /dev/null; then
    echo "error: go not found in PATH" | tee -a "$LOG_FILE"
    exit 1
fi

ACTION="$1"

# Heuristic 1: Check standard DerivedData structure (3 levels up)
CANDIDATE_1="$BUILD_DIR/../../SourcePackages/checkouts/wireguard-apple/Sources/WireGuardKitGo"
# Heuristic 2: Check 4 levels up
CANDIDATE_2="$BUILD_DIR/../../../SourcePackages/checkouts/wireguard-apple/Sources/WireGuardKitGo"
# Heuristic 3: Check 2 levels up relative to SYMROOT
CANDIDATE_3="$SYMROOT/../../SourcePackages/checkouts/wireguard-apple/Sources/WireGuardKitGo"

echo "Candidate 1: $CANDIDATE_1" >> "$LOG_FILE"
echo "Candidate 2: $CANDIDATE_2" >> "$LOG_FILE"
echo "Candidate 3: $CANDIDATE_3" >> "$LOG_FILE"

if [ -d "$CANDIDATE_1" ]; then
    TARGET_DIR="$CANDIDATE_1"
    echo "Selected Candidate 1" >> "$LOG_FILE"
elif [ -d "$CANDIDATE_2" ]; then
    TARGET_DIR="$CANDIDATE_2"
    echo "Selected Candidate 2" >> "$LOG_FILE"
elif [ -d "$CANDIDATE_3" ]; then
    TARGET_DIR="$CANDIDATE_3"
    echo "Selected Candidate 3" >> "$LOG_FILE"
else
    echo "Standard paths not found. Searching..." >> "$LOG_FILE"
    # Fallback: Find command
    # Search up from BUILD_DIR until we find SourcePackages or reach root (limit depth)
    # Using a safer finder
    
    # Try finding 'SourcePackages' first
    FOUND_PACKAGES=$(find "$BUILD_DIR/../../.." -type d -name "SourcePackages" -maxdepth 4 2>/dev/null | head -n 1)
    if [ -n "$FOUND_PACKAGES" ]; then
         TARGET_DIR="$FOUND_PACKAGES/checkouts/wireguard-apple/Sources/WireGuardKitGo"
         echo "Found SourcePackages at: $FOUND_PACKAGES" >> "$LOG_FILE"
    fi
fi

echo "Target Dir: $TARGET_DIR" >> "$LOG_FILE"

if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
    echo "error: [WireGuardGoBridge] WireGuardKitGo directory not found." | tee -a "$LOG_FILE"
    exit 1
fi

cd "$TARGET_DIR"
echo "Current Directory: $(pwd)" >> "$LOG_FILE"

# Run make
if [ "$ACTION" == "build" ] || [ -z "$ACTION" ]; then
    echo "Running make..." >> "$LOG_FILE"
    /usr/bin/make >> "$LOG_FILE" 2>&1
    EXIT_CODE=$?
else
    echo "Running make $ACTION..." >> "$LOG_FILE"
    /usr/bin/make "$ACTION" >> "$LOG_FILE" 2>&1
    EXIT_CODE=$?
fi

echo "Make finished with exit code: $EXIT_CODE" >> "$LOG_FILE"
exit $EXIT_CODE
