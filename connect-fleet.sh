#!/bin/bash

###
### Opens an interactive PowerShell session with the first compute instance in a GameLift Fleet.
###

usage() {
    echo "Usage:"
    echo "  $0 \ "
    echo "      --fleet-id <fleet id>"
    echo "      [--profile <AWS CLI Profile: default>] \ "
    echo "      [--region <AWS Region: us-west-2>]"
    exit 1
}

# Default values
PROFILE=${AWS_PROFILE:-"default"}
REGION=${AWS_DEFAULT_REGION:-"us-west-2"}

# Command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p|--profile)  PROFILE="$2"; shift ;;
        -f|--fleet-id) FLEET_ID="$2"; shift ;;
        -r|--region)   REGION="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$FLEET_ID" ]; then
    echo "At least one required parameter is missing (--fleet-id)"
    usage 
fi

echo "Connecting to fleet $FLEET_ID in region $REGION with AWS CLI profile $PROFILE."

# List all compute instances associated with this fleet
computeList=$(AWS_PROFILE=$PROFILE aws gamelift list-compute --fleet-id $FLEET_ID --region $REGION | jq -r .ComputeList)

computeName=$(echo $computeList | jq -r .[0].ComputeName)
if [ -z "$computeName" ]; then
        echo "An error occurred while running the 'aws gamelift list-compute' command. Exiting."
        exit 1
fi

computeListLength=$(echo $computeList | jq length)
if [ $computeListLength -gt 1 ]; then
    echo "[WARNING] There is more than one compute instance associated with this fleet. Connecting to $computeName"
elif [ $computeListLength -eq 0 ]; then
    echo "There are currently no compute instances associated with the given fleet. Exiting."
    exit 1
fi

# Get credentials to access the selected compute instance
computeAccess=$(AWS_PROFILE=$PROFILE aws gamelift get-compute-access --fleet-id $FLEET_ID --compute-name $computeName --region $REGION)

echo "Compute access: $computeAccess"

AWS_ACCESS_KEY_ID=$(echo $computeAccess | jq -r .Credentials.AccessKeyId)
AWS_SECRET_ACCESS_KEY=$(echo $computeAccess | jq -r .Credentials.SecretAccessKey)
AWS_SESSION_TOKEN=$(echo $computeAccess | jq -r .Credentials.SessionToken)

# Start an interactive session with the selected compute instance, using the credentials we retrieved
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN \
    aws ssm start-session --target $computeName --region $REGION
