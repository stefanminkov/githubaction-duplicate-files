#!/bin/bash

cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
echo '::endgroup::'


export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"


echo Scanning ${INPUT_DIRECTORY}

find ${INPUT_DIRECTORY} -type f -name "\"${INPUT_FILE_FIND_PATTERN}\"" | sed 's_.*/__' | awk -F"__" '{print $1}' | sort | uniq -d |
while read fileName
do
  find $dirname -type f | grep "${fileName}" |
  while read fname
  do
    echo "${fname}:1:1: Duplicate filename for prefix ${fileName}" >> .dupe.out
  done
done

find ${INPUT_DIRECTORY} -type f -name "\"${INPUT_FILE_FIND_PATTERN}\"" | sed 's_.*/__' | awk -F"__" '{print $1}' | sort | grep '\.' |
while read fileName
do
  echo "${fileName}: Invalid version format" >> .dupe.out
done

echo '::group::Found duplicate files'
cat .dupe.out
echo '::endgroup::'

echo '::group:: Running dupe-files with reviewdog'
# shellcheck disable=SC2086
cat .dupe.out | reviewdog -efm="%f:%l:%c: %m" \
      -name="${INPUT_TOOL_NAME}" \
      -reporter="${INPUT_REPORTER:-github-pr-check}" \
      -fail-on-error="${INPUT_FAIL_ON_ERROR:-false}" \
      -level="${INPUT_LEVEL}" \
      ${INPUT_REVIEWDOG_FLAGS}

cat .dupe.out | reviewdog -efm="%f:%l:%c: %m" \
      -name="${INPUT_TOOL_NAME}" \
      -reporter="github-pr-review" \
      -filter-mode="${INPUT_FILTER_MODE:-added}" \
      -fail-on-error="${INPUT_FAIL_ON_ERROR:-false}" \
      -level="${INPUT_LEVEL}" \
      ${INPUT_REVIEWDOG_FLAGS}
      
echo '::endgroup::'
