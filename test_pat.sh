#!/bin/bash

# Check if PAT is set
if [ -z "$ACTIONS_PAT" ]; then
  echo "Error: ACTIONS_PAT environment variable not set"
  exit 1
fi

# Clone the gh-pages-src branch
git clone -b gh-pages-src https://github.com/Sechorda/secOS.git secOS-gh-pages
cd secOS-gh-pages || exit 1

# Configure git to use PAT for authentication
git config --global user.name "GitHub Actions"
git config --global user.email "actions@github.com"

# Make a simple change
echo "Test commit using PAT" > test_change.txt
git add test_change.txt
git commit -m "Test commit using PAT"

# Push using PAT authentication
git push "https://$ACTIONS_PAT@github.com/Sechorda/secOS.git" gh-pages-src
