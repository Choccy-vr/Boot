#!/bin/bash

# Exit on error
set -e

# Run the build with all your variables
flutter/bin/flutter build web --release \
  --base-href "/dashboard/" \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=HACKCLUB_CLIENT_ID=$HACKCLUB_CLIENT_ID \
  --dart-define=HACKATIME_CLIENT_ID=$HACKATIME_CLIENT_ID