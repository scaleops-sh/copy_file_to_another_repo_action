#!/bin/sh

set -e
set -x

# Validate required inputs
[ -z "$INPUT_SOURCE_FILE" ] && { echo "Source file must be defined"; exit 1; }
INPUT_GIT_SERVER="${INPUT_GIT_SERVER:-github.com}"
INPUT_DESTINATION_BRANCH="${INPUT_DESTINATION_BRANCH:-main}"
PUSH_RETRIES="${INPUT_PUSH_RETRIES:-0}"

CLONE_DIR=$(mktemp -d)
OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH"

echo "Cloning destination git repository"
git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"
git config --global --add safe.directory "$CLONE_DIR"

git clone --depth=1 --single-branch --branch "$INPUT_DESTINATION_BRANCH" \
  "https://x-access-token:$API_TOKEN_GITHUB@$INPUT_GIT_SERVER/$INPUT_DESTINATION_REPO.git" \
  "$CLONE_DIR"

# Determine destination path and filename
DEST_COPY="$CLONE_DIR/$INPUT_DESTINATION_FOLDER"
[ -n "$INPUT_RENAME" ] && DEST_COPY="$DEST_COPY/$INPUT_RENAME"

echo "Copying contents to git repo"
mkdir -p "$CLONE_DIR/$INPUT_DESTINATION_FOLDER"
if [ -n "$INPUT_USE_RSYNC" ]; then
  echo "rsync mode detected"
  rsync -avrh "$INPUT_SOURCE_FILE" "$DEST_COPY"
else
  cp -R "$INPUT_SOURCE_FILE" "$DEST_COPY"
fi

cd "$CLONE_DIR"

# Optionally create a new branch
if [ -n "$INPUT_DESTINATION_BRANCH_CREATE" ]; then
  echo "Creating new branch: ${INPUT_DESTINATION_BRANCH_CREATE}"
  git checkout -b "$INPUT_DESTINATION_BRANCH_CREATE"
  OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH_CREATE"
fi

# Commit changes
INPUT_COMMIT_MESSAGE="${INPUT_COMMIT_MESSAGE:-Update from https://$INPUT_GIT_SERVER/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}}"

echo "Adding git commit"
git add .
if git diff --cached --quiet; then
  echo "No changes detected"
else
  git commit -m "$INPUT_COMMIT_MESSAGE"

  echo "Pushing git commit"
  for counter in $(seq 1 $((PUSH_RETRIES+1))); do
    if git push -u origin HEAD:"$OUTPUT_BRANCH"; then
      break
    elif [ "$counter" -gt "$PUSH_RETRIES" ]; then
      echo "Failed after $PUSH_RETRIES retries" >&2
      exit 1
    fi
    echo "Retrying attempt $counter"
    git pull -s recursive -X theirs
  done
fi
