#!/bin/bash

# Check if PAT and VERSION are set
if [ -z "$ACTIONS_PAT" ]; then
  echo "Error: ACTIONS_PAT environment variable not set"
  exit 1
fi
if [ -z "$VERSION" ]; then
  echo "Error: VERSION environment variable not set"
  exit 1
fi

# Clone the gh-pages-src branch
git clone -b gh-pages-src https://github.com/Sechorda/secOS.git secOS-version-update
cd secOS-version-update || exit 1

# Configure git
git config --global user.name "GitHub Actions"
git config --global user.email "actions@github.com"

# Update version in App.jsx
sed -i "s/Latest Release: v[0-9]*\.[0-9]*\.[0-9]* beta/Latest Release: v${VERSION} beta/" src/App.jsx

# Commit and push changes
git add src/App.jsx
git commit -m "Update version to v${VERSION}"
git push "https://$ACTIONS_PAT@github.com/Sechorda/secOS.git" gh-pages-src
