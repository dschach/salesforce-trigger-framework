#!/bin/sh
# Remove the "Last calculated by the config command as:" comments from a Code Analyzer
# configuration file. sf code-analyzer config writes them with paths from the machine
# that ran it, such as the home folder and the Java install, and they must not reach git.
#
# The codeanalyzer:setup script runs this on code-analyzer.yml right after it writes the
# file, and lint-staged runs it on the staged code-analyzer.yml in every commit.
#
# Usage: sh scripts/strip-config-paths.sh <file>...

set -eu

perl -pi -e 's/ *# Last calculated by the config command as:.*$//' "$@"
