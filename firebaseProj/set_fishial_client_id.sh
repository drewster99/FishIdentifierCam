#!/bin/sh

echo "New FISHIAL_CLIENT_ID will be read from stdin."
exec firebase functions:secrets:set FISHIAL_CLIENT_ID
