#!/usr/bin/env bash -xe

set -e
bundle exec ruby main.rb

set +e
git diff --exit-code --quiet
if [[ $? -eq 0 ]]; then exit; fi

set -e
git config user.email "hiroi+circleci@users.noreply.github.com"
git config user.name "hiroi+circleci"
git add .
NOW=`date +%Y/%m/%d_%H:%M`
git commit -m "diff commit ${NOW}"
git push origin master
