#!/bin/sh
# Installs the providers again, REINSTALL_PASSES times. The stack runs this
# after init. No provider cache is set, so every pass downloads every provider.
# The worker adds up the installs of one provider in one state, so the passes
# make the install slow without a slow network.
set -eu

passes="${REINSTALL_PASSES:-10}"

i=1
while [ "$i" -le "$passes" ]; do
  echo "reinstall pass ${i} of ${passes}"
  rm -rf .terraform/providers
  tofu init -input=false
  i=$((i + 1))
done
