#!/bin/sh
# Pins hashicorp/random to RANDOM_VERSION. The stack runs this before init.
# An override file replaces the version constraint in main.tf. Without the
# variable the script does nothing, and init resolves the newest version.
set -eu

[ -n "${RANDOM_VERSION:-}" ] || exit 0

cat >random_override.tf <<HCL
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "= ${RANDOM_VERSION}"
    }
  }
}
HCL

echo "pinned hashicorp/random to ${RANDOM_VERSION}"
