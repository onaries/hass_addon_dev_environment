#!/bin/bash
# Claude Code OAuth token auto-refresh script
# Periodically checks token expiration and refreshes before it expires

CLAUDE_CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"
REFRESH_ENDPOINT="https://console.anthropic.com/v1/oauth/token"
CHECK_INTERVAL=${CLAUDE_TOKEN_CHECK_INTERVAL:-3600}  # default: check every 1 hour
REFRESH_MARGIN=${CLAUDE_TOKEN_REFRESH_MARGIN:-7200}   # default: refresh if < 2 hours remaining

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] claude-token-refresh: $*"
}

find_credentials() {
    # Find credentials file for the dev user (not root)
    local user_home
    for user_home in /home/*/; do
        local cred_file="${user_home}.claude/.credentials.json"
        if [ -f "$cred_file" ]; then
            echo "$cred_file"
            return 0
        fi
    done
    return 1
}

refresh_token() {
    local cred_file="$1"
    local current_refresh_token
    local owner

    current_refresh_token=$(jq -r '.claudeAiOauth.refreshToken // empty' "$cred_file" 2>/dev/null)
    if [ -z "$current_refresh_token" ]; then
        log "ERROR: No refresh token found in $cred_file"
        return 1
    fi

    owner=$(stat -c '%U' "$cred_file" 2>/dev/null || echo "root")

    log "Requesting new token..."
    local response
    response=$(curl -s -X POST "$REFRESH_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "{
            \"grant_type\": \"refresh_token\",
            \"refresh_token\": \"$current_refresh_token\",
            \"client_id\": \"$CLAUDE_CLIENT_ID\"
        }" 2>/dev/null)

    if [ -z "$response" ]; then
        log "ERROR: Empty response from refresh endpoint"
        return 1
    fi

    # Check for error in response
    local error
    error=$(echo "$response" | jq -r '.error // empty' 2>/dev/null)
    if [ -n "$error" ]; then
        local error_desc
        error_desc=$(echo "$response" | jq -r '.error_description // "unknown"' 2>/dev/null)
        log "ERROR: Token refresh failed: $error - $error_desc"
        return 1
    fi

    # Extract new tokens
    local new_access_token new_refresh_token new_expires_in
    new_access_token=$(echo "$response" | jq -r '.access_token // empty' 2>/dev/null)
    new_refresh_token=$(echo "$response" | jq -r '.refresh_token // empty' 2>/dev/null)
    new_expires_in=$(echo "$response" | jq -r '.expires_in // empty' 2>/dev/null)

    if [ -z "$new_access_token" ] || [ -z "$new_refresh_token" ]; then
        log "ERROR: Missing tokens in response"
        return 1
    fi

    # Calculate new expiresAt (current time + expires_in seconds, in milliseconds)
    local new_expires_at
    new_expires_at=$(( ($(date +%s) + ${new_expires_in:-28800}) * 1000 ))

    # Preserve existing fields and update tokens
    local tmp_file="${cred_file}.tmp"
    jq --arg at "$new_access_token" \
       --arg rt "$new_refresh_token" \
       --argjson ea "$new_expires_at" \
       '.claudeAiOauth.accessToken = $at | .claudeAiOauth.refreshToken = $rt | .claudeAiOauth.expiresAt = $ea' \
       "$cred_file" > "$tmp_file" 2>/dev/null

    if [ $? -eq 0 ] && [ -s "$tmp_file" ]; then
        mv "$tmp_file" "$cred_file"
        chmod 600 "$cred_file"
        chown "$owner:$owner" "$cred_file" 2>/dev/null || true
        log "Token refreshed successfully. New expiry: $(date -d @$((new_expires_at / 1000)) '+%Y-%m-%d %H:%M:%S')"
        return 0
    else
        rm -f "$tmp_file"
        log "ERROR: Failed to write updated credentials"
        return 1
    fi
}

# Main loop
log "Starting Claude Code token refresh daemon (check interval: ${CHECK_INTERVAL}s, refresh margin: ${REFRESH_MARGIN}s)"

while true; do
    CRED_FILE=$(find_credentials)

    if [ -z "$CRED_FILE" ]; then
        log "No credentials file found, waiting..."
        sleep "$CHECK_INTERVAL"
        continue
    fi

    # Read expiration
    EXPIRES_AT=$(jq -r '.claudeAiOauth.expiresAt // 0' "$CRED_FILE" 2>/dev/null)
    CURRENT_MS=$(( $(date +%s) * 1000 ))
    REMAINING_S=$(( (EXPIRES_AT - CURRENT_MS) / 1000 ))

    if [ "$REMAINING_S" -le 0 ]; then
        log "Token EXPIRED. Refreshing now..."
        refresh_token "$CRED_FILE"
    elif [ "$REMAINING_S" -le "$REFRESH_MARGIN" ]; then
        log "Token expires in ${REMAINING_S}s (< ${REFRESH_MARGIN}s margin). Refreshing..."
        refresh_token "$CRED_FILE"
    else
        HOURS=$(( REMAINING_S / 3600 ))
        MINS=$(( (REMAINING_S % 3600) / 60 ))
        log "Token valid for ${HOURS}h ${MINS}m. Next check in ${CHECK_INTERVAL}s."
    fi

    sleep "$CHECK_INTERVAL"
done
