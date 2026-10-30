#!/bin/bash
# Replace the TriggerFramework scratch org: delete it, create a new one, deploy the
# framework and the sample, and open the org.
#
# Run from the repository root: npm run orginit

echo "Cleaning previous scratch org..."
sf org delete scratch --no-prompt --target-org TriggerFramework

echo "Creating new scratch org"
sf org create scratch --definition-file config/project-scratch-def.json --duration-days 10 --alias TriggerFramework --set-default

echo "Deploying the framework and the sample"
sf project deploy start --source-dir force-app --source-dir sample-handler

echo "Opening org"
sf org open

echo "Org is set up"
