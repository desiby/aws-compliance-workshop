#!/usr/bin/env bash
# Bash template based on https://github.com/eppeters/bashtemplate.sh
# sudo chmod +x *.sh
# ./launch-taskcat.sh GH_BRANCH
set -euo pipefail
IFS=$'\n\t'

#/ Usage: launch-stack.sh GH_BRANCH
#/ Description: Launch Stack that runs TaskCat tests on CCOA. 
#/ Examples:
#/  launch-stack.sh       (launches a stack using the the env var GH_BRANCH, or shows you these docs if it is unset)
#/  launch-stack.sh eddie (launches a stack with buckets and stack names autogenerated based on the name "eddie")
#/ Options:
#/   --help: Display this help message
usage() { grep '^#/' "$0" | cut -c4- ; exit 1 ; }
expr "$*" : ".*--help" > /dev/null && usage

readonly LOG_FILE="/tmp/$(basename "$0").log"
info()    { echo "[INFO]    $@" | tee -a "$LOG_FILE" >&2 ; }
warning() { echo "[WARNING] $@" | tee -a "$LOG_FILE" >&2 ; }
error()   { echo "[ERROR]   $@" | tee -a "$LOG_FILE" >&2 ; }
fatal()   { echo "[FATAL]   $@" | tee -a "$LOG_FILE" >&2 ; exit 1 ; }

AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')

echo "Removing buckets previously used by this script"
aws s3api list-buckets --query 'Buckets[?starts_with(Name, `tasckat-ccoa`) == `true`].[Name]' --output text | xargs -I {} aws s3 rb s3://{} --force

aws s3api list-buckets --query 'Buckets[?starts_with(Name, `tcat-ccoa`) == `true`].[Name]' --output text | xargs -I {} aws s3 rb s3://{} --force

echo "Deleting taskcat-ccoa stack"
aws cloudformation delete-stack --stack-name taskcat-ccoa
aws cloudformation wait stack-delete-complete --stack-name taskcat-ccoa

GH_BRANCH=${1:-${GH_BRANCH:-}}
if [ -z "$GH_BRANCH" ]; then
    usage
fi

aws cloudformation create-stack --stack-name taskcat-ccoa-$GH_BRANCH --capabilities CAPABILITY_NAMED_IAM --disable-rollback --template-body file://pipeline-taskcat.yml --parameters ParameterKey=GitHubBranch,ParameterValue=$GH_BRANCH