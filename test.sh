#!/opt/homebrew/bin/bash

TEXT_RED='\e[0;31m'
TEXT_GREEN='\e[0;32m'
TEXT_NORMAL='\e[0m'

# Define the path to the mu.lua script
MU_LUA_PATH="./mu.lua"

# Function to run a single test with a name
run_test() {
  local test_name=$1
  local input_file=$2
  local expected_output_file=$3

  # Convert the input file using Pandoc and mu.lua
  pandoc -f mediawiki --lua-filter=$MU_LUA_PATH -t plain "$input_file" -o output.micron

  # Compare the output with the expected output
  if diff -q output.micron "$expected_output_file" > /dev/null; then
    echo -e "$test_name ${TEXT_GREEN}passed${TEXT_NORMAL}"
  else
    echo -e "$test_name ${TEXT_RED}failed${TEXT_NORMAL}"
    /opt/homebrew/bin/grc /usr/bin/diff "$expected_output_file" output.micron 
    # print output from output.micron
    echo "output.micron:"
    echo "----------------------------------------"
    cat output.micron
    echo "----------------------------------------"
  fi

  # Clean up
  rm output.micron
}

# List of test cases
declare -a tests=()

# read tests from ./tests directory, and add them to the tests array
for test_file in tests/input/*.mediawiki; do
  test_name=$(basename "$test_file" .mediawiki)
  expected_output_file="tests/expected/$test_name.micron"
  tests+=("$test_name $test_file $expected_output_file")
done

# Run all tests
echo "Running ${#tests[@]} tests"
for test in "${tests[@]}"; do
  # shellcheck disable=SC2086
  run_test $test
done
