#!/usr/bin/env bash
PROJECT_DIR=""

# runs when the user presses Ctrl+C or Ctrl+Z during deploy
cleanup() {
	echo ""
	echo "Deployment was interrupted"

	if [ -d "$PROJECT_DIR" ]; then
		echo "Zipping the incomplete project..."
		zip -r "$PROJECT_DIR"_archive.zip "$PROJECT_DIR" > /dev/null
		rm -rf "$PROJECT_DIR"
		echo "Created $PROJECT_DIR"_archive.zip
		echo "Deleted the incomplete folder"
	else
		echo "no folder was created yet"
	fi

	echo "Closing Session"
	exit 130
}

deploy() {
    trap cleanup SIGINT SIGTSTP


    missing=0

    if command -v python3 > /dev/null; then
	    echo "python is installed $(python3 --version)"
    else
	    echo "python is not installed"
	    missing=1
    fi

    if command -v zip >/dev/null; then
	    echo "zip is installed $(zip -v | head -n 2 | tail -n 1)"
    else
	    echo "zip is not installed"
	    missing=1
    fi

    if [ "$missing" = "1" ]; then
	    echo "Pre-flight checks failed. Please install the missing tools."
	    return 1
    fi
    echo "All pre-flight checks passed"

#Step 2: ask for the project name

echo "Enter a name for the project:"
read name

#Do not allow an empty name
if [ -z "$name" ]; then
	echo "Error: the name cannot be empty"
	return 1
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
	return 1
        fi
fi

#Create the structure
mkdir -p "$dir/Helpers" "$dir/reports"
echo "Created $dir with Helpers and reports"
    PROJECT_DIR="$dir"

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
	return 1
fi

if [ "$choice" = "A" ]; then
# Option A: copy the header + count rows from the template
lines=$((count + 1))
head -n $lines templates/assets.csv > $dir/Helpers/assets.csv
sessions=5
echo "Copied $count students from the templates"
elif [ "$choice" = "B" ]; then
	# Option B; make a new roster with every count starting at 0

	names=("Alice Johnson" "Bob Smith" "Charlie Davis" "Diana Prince" "Ethan Cole" "Fatima Noor" "George Mensah" "Hannah Kim" "Ibrahim Osei" "Jasmine Lee")
    emails=("alice@example.com" "bob@example.com" "charlie@example.com" "diana@example.com" "ethan@example.com" "fatima@example.com" "george@example.com" "hannah@example.com" "ibrahim@example.com" "jasmine@example.com")

    # First line of the file is the header
    echo "Email,Names,Attendance Count,Absence Count" > $dir/Helpers/assets.csv

    number=1
    while [ $number -le $count ]; do
	    position=$(( (number - 1)% 10 ))

	    if [ $number -le 10 ]; then
		    # students 1 to 10 use the names and emails exactly as listed
                    echo "${emails[$position]},${names[$position]},0,0" >> $dir/Helpers/assets.csv
        else
		# after 10, repeat the names but add the number so nothing is duplicated
		echo "student$number@example.com,${names[$position]} $number,0,0" >> $dir/Helpers/assets.csv
        fi

	number=$((number + 1))
done
sessions=1
echo "Generated $count students with all counts at 0"
else
	echo "Error: please type A or B"
	return 1
fi

sed -i "s/\"total_sessions\": [0-9]*/\"total_sessions\": $sessions/" $dir/Helpers/config.json
echo "total_sessions is now $sessions"

# Step 4: set permissions

chmod +x $dir/attendance_checker.py
chmod 600 $dir/Helpers/config.json

echo "Permissions set are:"
ls -l $dir/attendance_checker.py
ls -l $dir/Helpers/config.json

# Step 5: Offer to update the alert thresholds

echo "Do you want to update the alert thresholds? (y/n)"
read update

if [ "$update" = "y" ] || [ "$update" = "Y" ]; then
	echo "Enter the warning threshold (press Enter for 75):"
	read warning
	if [ -z "$warning" ]; then
		warning=75
	fi

	echo "Enter the failure threshold (press Enter for 50):"
	read failure
	if [ -z "$failure" ]; then
		failure=50
	fi

	# check that both are numbers
	if ! [ "$warning" -ge 0 ] 2>/dev/null; then
		echo "Error: warning must be a number"
		return 1
	fi
    if ! [ "$failure" -ge 0 ] 2>/dev/null; then
		echo "Error: failure must be a number"
		return 1
	fi

	# change only the warning and failure lines 
	sed -i "s/\"warning\": [0-9]*/\"warning\": $warning/" $dir/Helpers/config.json
    sed -i "s/\"failure\": [0-9]*/\"failure\": $failure/" $dir/Helpers/config.json

    echo "Thresholds updated: warning=$warning, failure=$failure"
    elif [ "$update" = "n" ] || [ "$update" = "N" ]; then
	echo "Keeping the default thresholds (75 and 50)"
else
	echo "Error: please answer y or n"
	return 1
fi

    PROJECT_DIR=""
    trap - SIGINT SIGTSTP
# Step 6: verifying the deployment by executing the application

echo "Verifying the deployment by executing the application...."
cd $dir
python3 attendance_checker.py
cd ..

echo "Deployment finished"
}

run_app() {
	echo "Enter the project name:"
	read name
	
	if [ -z "$name" ]; then
		echo "Error: the name cannot be empty"
		return 1
	fi

	dir="attendance_tracker_$name"

	if [ ! -d "$dir" ]; then
		echo "Error: $dir does not exist. Deploy it first."
		return 1
	fi

	if [ ! -f "$dir/attendance_checker.py" ]; then
		echo "Error: attendance_checker.py is missing in $dir"
		return 1
	fi

	cd "$dir" || return 1
	python3 attendance_checker.py
	cd ..
}


archive_logs() {
	echo "Enter the project name:"
	read name

	if [ -z "$name" ]; then
		echo "Error: the name cannot be empty"
		return 1
	fi

	dir="attendance_tracker_$name"

	if [ ! -d "$dir" ]; then
		echo "Error: $dir does not exist"
		return 1
	fi

	# the timestamp, for example 20261010_030512
	timestamp=$(date +%Y%m%d_%H%M%S)

	# archive attendance.log
    if [ -f "$dir/reports/attendance.log" ]; then
		mkdir -p "$dir/archives/attendance"
	        if mv "$dir/reports/attendance.log" "$dir/archives/attendance/attendance_$timestamp.log"; then
		echo "Archived: $dir/archives/attendance/attendance_$timestamp.log"
	else
		echo "Error: could not archive attendance.log"
	fi
else
	echo "No attendance.log found, skipping"
fi
	# archive absent.log
	if [ -f "$dir/reports/absent.log" ]; then
		mkdir -p "$dir/archives/absent"
	        if mv "$dir/reports/absent.log" "$dir/archives/absent/absent_$timestamp.log"; then
		echo "Archived: $dir/archives/absent/absent_$timestamp.log"
	else
		echo "Error: could not archive absent.log"
	fi
	else
		echo "No absent.log found, skipping"
	fi
}
# Menu

while true; do
	echo ""
	echo "==== Attendance Tracker ===="
	echo "1) Deploy the Application"
	echo "2) Run the Application"
	echo "3) Archive the log files"
	echo "4) Quit"
	echo "Choose an option:"
	read option

	if [ "$option" = "1" ]; then
		deploy
        trap - SIGINT SIGTSTP
        PROJECT_DIR=""
	elif [ "$option" = "2" ]; then
        run_app
	elif [ "$option" = "3" ]; then
        archive_logs
	elif [ "$option" = "4" ]; then
		echo "Exiting"
		exit 0
	else
		echo "Error: please choose 1,2,3 or 4"
	fi
done

