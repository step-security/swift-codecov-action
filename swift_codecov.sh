#!/usr/bin/env bash
# fail if any commands fails
set -e

# validate subscription status
REPO_PRIVATE=$(jq -r '.repository.private | tostring' "$GITHUB_EVENT_PATH" 2>/dev/null || echo "")
UPSTREAM="mattpolzin/swift-codecov-action"
ACTION_REPO="${GITHUB_ACTION_REPOSITORY:-}"
DOCS_URL="https://docs.stepsecurity.io/actions/stepsecurity-maintained-actions"

echo ""
echo -e "\033[1;36mStepSecurity Maintained Action\033[0m"
echo "Secure drop-in replacement for $UPSTREAM"
if [ "$REPO_PRIVATE" = "false" ]; then
  echo -e "\033[32m✓ Free for public repositories\033[0m"
fi
echo -e "\033[36mLearn more:\033[0m $DOCS_URL"
echo ""

if [ "$REPO_PRIVATE" != "false" ]; then
  SERVER_URL="${GITHUB_SERVER_URL:-https://github.com}"

  if [ "$SERVER_URL" != "https://github.com" ]; then
    BODY=$(printf '{"action":"%s","ghes_server":"%s"}' "$ACTION_REPO" "$SERVER_URL")
  else
    BODY=$(printf '{"action":"%s"}' "$ACTION_REPO")
  fi

  API_URL="https://agent.api.stepsecurity.io/v1/github/$GITHUB_REPOSITORY/actions/maintained-actions-subscription"

  RESPONSE=$(curl --max-time 3 -s -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$BODY" \
    "$API_URL" -o /dev/null) && CURL_EXIT_CODE=0 || CURL_EXIT_CODE=$?

  if [ $CURL_EXIT_CODE -ne 0 ]; then
    echo "Timeout or API not reachable. Continuing to next step."
  elif [ "$RESPONSE" = "403" ]; then
    echo -e "::error::\033[1;31mThis action requires a StepSecurity subscription for private repositories.\033[0m"
    echo -e "::error::\033[31mLearn how to enable a subscription: $DOCS_URL\033[0m"
    exit 1
  fi
fi

##
## INPUTS
## - $INPUT_PROJECT_NAME         - The of the project, which must be exactly the
##                                 name of the root folder of the target project
##                                 for local dependencies and target project source
##                                 code to be accurately differentiated.
## - $INPUT_CODECOV_JSON         - The location of the JSON file produced by
##                                 swift test --enable-code-coverage
## - $INPUT_PRINT_STDOUT         - 'true' by default, but if 'false' then will not
##                                 output the whole codecov table to stdout.
## - $INPUT_SORT_ORDER           - 'filename' by default. Possible values: filename,
## 		                             +cov, -cov
## - $INPUT_MINIMUM_COVERAGE     - By default, there is no minimum coverage. Set this
##                                 to make the script fail if the minimum coverage is not met.
## - $INPUT_INCLUDE_DEPENDENCIES - 'false' by default, but if 'true' then coverage numbers will
##                                 include project dependencies.
## - $INPUT_INCLUDE_TESTS        - 'false' by default, but if 'true' then coverage numbers will
##                                 include the percentage of the test files themselves that was
##                                 exercised.
##
## OUTPUTS
## - $CODECOV             - Overal code coverage percent.
## - $MINIMUM_COVERAGE    - Passes the input through to the output.
## - ./codecov.txt        - Code coverage in a file.
##

# The project name (root folder of target project)
PROJECT_NAME="${INPUT_PROJECT_NAME}"

# Set default location for JSON
CODECOV_JSON=${INPUT_CODECOV_JSON:-.build/debug/codecov/*.json}

# Set default print option
PRINT_STDOUT=${INPUT_PRINT_STDOUT:-true}

# Set default sort order
SORT_ORDER=${INPUT_SORT_ORDER:-filename}

if [[ "$INPUT_INCLUDE_DEPENDENCIES" = 'true' ]]; then
  DEPS_ARG='--dependencies'
else
  DEPS_ARG='--no-dependencies'
fi

if [[ "$INPUT_INCLUDE_TESTS" = 'true' ]]; then
  TESTS_ARG='--tests'
else
  TESTS_ARG='--no-tests'
fi

if [[ "$INPUT_MINIMUM_COVERAGE" = '' ]]; then
  MIN_COV_ARG=''
else
  MIN_COV_ARG="--minimum $INPUT_MINIMUM_COVERAGE"
fi

# Run Codecov for overall coverage
set +e
COV=`swift-test-codecov $CODECOV_JSON $MIN_COV_ARG $DEPS_ARG $TESTS_ARG --no-explain-failure --print-format minimal --project-name "$PROJECT_NAME"`
FAILED="$?"

# Run Codecov for full table
FULL_COV_TABLE=`swift-test-codecov $CODECOV_JSON $MIN_COV_ARG $DEPS_ARG $TESTS_ARG --sort $SORT_ORDER --explain-failure --print-format table --project-name "$PROJECT_NAME"`
set -e

# Dump to txt file
echo "$FULL_COV_TABLE" > './codecov.txt'

# Export env vars
echo "CODECOV=${COV}" >> $GITHUB_OUTPUT
echo "MINIMUM_COVERAGE=${INPUT_MINIMUM_COVERAGE}" >> $GITHUB_OUTPUT
echo "CODECOV=${COV}" >> $GITHUB_ENV
echo "MINIMUM_COVERAGE=${INPUT_MINIMUM_COVERAGE}" >> $GITHUB_ENV

# Print to stdout
if [ "$PRINT_STDOUT" = 'true' ]; then
  echo "$FULL_COV_TABLE"
fi

if [[ "$FAILED" = '1' ]]; then
  exit 1
fi
