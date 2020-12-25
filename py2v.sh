#!/usr/bin/env bash

python ast2json.py $1 /tmp/ast2json.temp.json
v -prod run json2v /tmp/ast2json.temp.json $2
