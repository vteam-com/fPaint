#!/bin/sh
echo --- Analyze

dart format .

dart analyze 
dart fix --apply

flutter analyze


flutter test

tool/graph.sh
