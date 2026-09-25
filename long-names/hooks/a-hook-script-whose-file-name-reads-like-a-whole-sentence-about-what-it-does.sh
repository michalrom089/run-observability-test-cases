#!/bin/sh
# The stack runs this before init. The path is the hook command, so the long
# file name is what the list of slowest hooks shows.
set -eu

echo "sleeping 2 seconds in a hook with a long file name"
sleep 2
