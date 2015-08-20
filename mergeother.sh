#!/bin/bash
git ls-tree -r  caf/aosp-new/lollipop-release |egrep "(setuid.S|gensyscalls.py|bionic_utils)" \
| awk ' { printf "%s %s 0\tbionic/%s\n" , $1, $3, $4 } ' | git update-index   --index-info

git checkout bionic
