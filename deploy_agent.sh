#!/usr/bin/env bash


echo "Running pre-flight checks..."

#Check that python3 and zip are installed

if which python3 > /dev/null; then
	echo "python3 is installed"
else
	echo "python3 is not installed"
	exit 1
fi

if which zip > /dev/null; then
	echo "zip is installed"
else
	echo "zip is not installed"
	exit 1
fi
echo "All pre-flight  checks passed"

