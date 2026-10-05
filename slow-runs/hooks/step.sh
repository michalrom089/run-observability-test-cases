#!/bin/sh
# Usage: sh hooks/step.sh <name> <base seconds> <percent of TF_VAR_sleep_seconds>
#
# The hook sleeps its base, plus its share of the slow run sleep. A fast run
# leaves TF_VAR_sleep_seconds unset, so only the base remains.
set -eu

name=$1
base=$2
percent=$3

seconds=$((base + ${TF_VAR_sleep_seconds:-0} * percent / 100))

echo "hook ${name}: sleeping ${seconds} seconds"
sleep "${seconds}"
