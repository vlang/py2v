#!/usr/bin/env bash

python ast2json.py $1 /tmp/ast2json.temp.json

if [[ ! -f "json2v/json2v" ]]; then
v -prod json2v -o json2v/json2v
fi
json2v/json2v /tmp/ast2json.temp.json $2
