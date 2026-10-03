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

#Step 2: ask for the project name

echo "Enter a name for the project:"
read name

#Do not allow an empty name
if [ -z "$name" ]; then
	echo "Error: the name cannot be empty"
	exit 1
fi

dir="attendance_tracker_$name"

#If the directory already exists ask before overwriting
if [ -d "$dir" ]; then
	echo "The directory $dir already exists."
	echo "Do you want to overwite it? (y/n)"
	read answer
if [ "$answer" = "y" ]; then
	rm -rf "$dir"
else
	echo "Aborting. The existing directory was not changed."
	exit 1
        fi
fi

#Create the structure
mkdir -p "$dir/Helpers" "$dir/reports"
echo "Created $dir with Helpers and reports"

