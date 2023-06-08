#!/usr/bin/env bash -xe

export consumer_key=CTbwz7HFxSMUuXekV6oBMQYaL
export consumer_secret=aTFahrygHxHOLAvUtcnDPza8uSZUBrMGg2Gh5FDTJw7nHgUTow
export access_token=954356069337202688-NkG4haeRjBLfJOWWi9aXzeBR5hMGBna
export access_token_secret=Dvmchahf6nBzv8pkNQnXXWQc40E31wgw0Yb7db7tGbzIc

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
