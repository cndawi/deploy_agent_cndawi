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

#Step 3: copying files from templates

cp templates/attendance_checker.py $dir/attendance_checker.py
cp templates/config.json $dir/Helpers/config.json
echo "Copied the files attendance_checker.py and config.json"

#Ask how to build the roster
echo "How do you want to build the roster?"
echo "A= copy from templates"
echo "B= generate a new roster"
read choice

echo "How many students"
read count

#Check that count is a number number that is 1 or more
if [ "$count" -ge 1 ] 2>/dev/null; then
	echo "Number accepted"
else
	echo "Error: enter a number of 1 or more"
	exit 1
fi

if [ "$choice" = "A" ]; then
# Option A: copy the header + count rows from the template
lines=$((count + 1))
head -n $lines templates/assets.csv > $dir/Helpers/assets.csv
sessions=5
echo "Copied $count students from the templates"
fi
