#!/usr/bin/env bash

set -o errexit

for file in examples/*.py
do
python ast2json.py $file /tmp/out.json
json2v/json2v /tmp/out.json /tmp/out.v
diff -u ${file%.py}.v /tmp/out.v
done
