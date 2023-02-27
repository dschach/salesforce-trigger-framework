#!/bin/bash

echo "Cleaning previous scratch org..."
sfdx force:org:delete -p -u TriggerFramework

echo "Creating new scratch org"
sfdx force:org:create --definitionfile config/project-scratch-def.json --durationdays 10 --setalias TriggerFramework --setdefaultusername

echo "Pushing metadata"
sfdx force:source:push

echo "Opening org"
sfdx force:org:open

echo "Org is set up"