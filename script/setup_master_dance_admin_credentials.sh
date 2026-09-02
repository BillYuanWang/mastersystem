#!/bin/zsh

set -euo pipefail

email_service="com.masterdance.admin.mcp.email"
password_service="com.masterdance.admin.mcp.password"
token_service="com.masterdance.admin.api.token"

printf "Master Dance Admin email: "
IFS= read -r admin_email
if [[ -z "$admin_email" ]]; then
  printf "Email is required.\n" >&2
  exit 1
fi

api_token="$(/usr/bin/openssl rand -hex 32)"

/usr/bin/security add-generic-password -U -s "$email_service" -a default -w "$admin_email" >/dev/null
printf "Enter the Master Dance Admin password at the secure Keychain prompt.\n"
/usr/bin/security add-generic-password -U -s "$password_service" -a default -w
/usr/bin/security add-generic-password -U -s "$token_service" -a default -w "$api_token" >/dev/null

unset api_token
printf "Credentials saved in macOS Keychain. No secret was written into the repository.\n"
