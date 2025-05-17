#!/bin/sh

echo "New FISHIAL_CLIENT_SECRET will be read from stdin."
exec firebase functions:secrets:set FISHIAL_CLIENT_SECRET
