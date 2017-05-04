#!/bin/bash

for i in *.json; do
  json-to-ndjson $i
done
