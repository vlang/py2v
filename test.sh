#!/usr/bin/env bash

# TODO: merge this to py2v.v

set -o errexit

for file in examples/*.py
do
./py2v $file /tmp/out.v
diff -u ${file%.py}.v /tmp/out.v
done
