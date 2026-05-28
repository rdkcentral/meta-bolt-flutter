#!/bin/bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
# no color prevents repo-tool from asking questions interactively
git config --global color.ui false

cd ${REPO_ROOT}
. setup-environment 
