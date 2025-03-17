#!/bin/bash

# Define the path to the appdata file
APPDATA_FILE=/var/lib/appdata/users.json

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "jq is not installed. Please install it with: sudo apt install jq"
  exit 1
fi

# Function to format the date
format_date() {
  date -d @$1 '+%Y-%m-%d %H:%M:%S UTC'
}

# Read the JSON data
if [ ! -f "$APPDATA_FILE" ]; then
  echo "Error: $APPDATA_FILE not found."
  exit 1
fi

# Loop through the users
jq -r '.users | keys[] as $user ( .users[$user] | . as $data |
  "User: " + $user + " (created: " + ($data.created | format_date) + ")\n" +
  (
    $data.apps | keys[] as $app (
      "└─ App: " + $app + "\n" +
      (
        "   ├─ Domain: " + $data.apps[$app].domain + "\n" +
        "   ├─ Database: " + $data.apps[$app].db_name + "\n" +
        (if $data.apps[$app].ssl then "   ├─ SSL Enabled: Yes\n" else "" end) +
        "   ├─ Public HTML: " + $data.apps[$app].paths.public_html + "\n" +
        "   └─ Configs: " + $data.apps[$app].paths.configs + "\n"
      )
    )
  )
)' "$APPDATA_FILE"
