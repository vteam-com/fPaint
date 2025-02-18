#!/bin/sh
echo --- Analyze

dart analyze 
dart fix --apply

flutter analyze

dart format . l 120

flutter test

tools/graph.sh
