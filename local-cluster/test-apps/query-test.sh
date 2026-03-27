#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────
MAC_ADDRESS="AA:BB:DD:DD:DD:CC"
API_URL="https://api.dev.aukiverse.com"
DDS_URL="https://dds.dev.aukiverse.com"
EMAIL="test@test.com"
PASSWORD="asdfasdf"

# ── Helpers ────────────────────────────────────────────────────
bold=$(tput bold)
dim=$(tput setaf 8)
reset=$(tput sgr0)
green=$(tput setaf 2)
red=$(tput setaf 1)
cyan=$(tput setaf 6)

fail() { echo "${red}ERROR: $1${reset}" >&2; exit 1; }

# ── Step 1: Login ──────────────────────────────────────────────
printf "%s" "${dim}Logging in as ${EMAIL}...${reset} "
login_resp=$(curl -sf "$API_URL/user/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" 2>&1) \
  || fail "Login failed ?"

user_token=$(echo "$login_resp" | jq -r '.access_token // empty')
[ -n "$user_token" ] || fail "No access_token in login response"
echo "${green}ok${reset}"

# ── Step 2: Exchange for DDS token ─────────────────────────────
printf "%s" "${dim}Getting DDS token...${reset} "
dds_resp=$(curl -sf "$API_URL/service/domains-access-token" \
  -X POST \
  -H "Authorization: Bearer $user_token" 2>&1) \
  || fail "DDS token exchange failed"

dds_token=$(echo "$dds_resp" | jq -r '.access_token // empty')
[ -n "$dds_token" ] || fail "No access_token in DDS response"
echo "${green}ok${reset}"

# ── Step 3: Query domains by MAC address ───────────────────────
mac_upper=$(echo "$MAC_ADDRESS" | tr '[:lower:]' '[:upper:]')
printf "%s" "${dim}Querying domains for MAC ${mac_upper}...${reset} "

query_url="$DDS_URL/api/v1/domains?mac_address=$(printf '%s' "$mac_upper" | jq -sRr @uri)"
http_code=$(curl -s -o /tmp/query-test-resp.json -w '%{http_code}' "$query_url" \
  -H "Authorization: Bearer $dds_token")
domains_resp=$(cat /tmp/query-test-resp.json)
rm -f /tmp/query-test-resp.json
if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
  echo "${red}HTTP $http_code${reset}"
  echo "${dim}URL: $query_url${reset}"
  echo "${dim}Response: $domains_resp${reset}"
  fail "Domain query failed (HTTP $http_code)"
fi

count=$(echo "$domains_resp" | jq '.domains | length')
echo "${green}${count} found${reset}"

# ── Output ─────────────────────────────────────────────────────
echo ""
echo "${bold}Domains associated with MAC ${mac_upper}${reset}"
echo ""

if [ "$count" -eq 0 ]; then
  echo "  ${dim}(none)${reset}"
else
  echo "$domains_resp" | jq -r '
    .domains[] |
    "  \(.name // "(unnamed)")  \u001b[2m\(.id)\u001b[0m"
  '
  echo ""
  echo "${dim}Full response:${reset}"
  echo "$domains_resp" | jq '.domains'
fi
