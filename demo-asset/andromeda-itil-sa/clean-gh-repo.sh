#!/bin/sh
gh repo list itil-sa --json nameWithOwner | jq .[].nameWithOwner -r | grep hello-quarkus > repo-to-delete

echo "going to delete those repos:"
cat repo-to-delete

echo ""
echo "press a key to continue"
read a
for i in `cat repo-to-delete`; do
    echo "deleting $i in 0 sec"
    gh repo delete $i --yes
done
