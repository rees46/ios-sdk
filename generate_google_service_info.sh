#!/bin/bash

echo "$GOOGLE_SERVICES_STRING" | base64 --decode > GoogleService-Info.plist
