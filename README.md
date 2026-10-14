# Student Attendance Tracker – Deployment Agent

## What this project is

The Student Attendance Tracker is a Python program (`attendance_checker.py`) that lets an
instructor mark each student present or absent. It keeps a running count per student, calculates
their attendance percentage, warns about students falling behind, and writes log files.

Setting it up by hand is slow and error-prone, so `deploy_agent.sh` does it automatically and the
same way every time. It can:

1. **Deploy** a ready-to-use copy of the tracker,
2. **Run** the tracker in a deployed copy, and
3. **Archive** the tracker's logs, with a timestamp in each filename.

If the user presses Ctrl+C or Ctrl+Z during a deployment, the script saves the half-built project
in a ZIP file and removes it, so no broken folder is left behind. **The Python program is never
modified.**

**Requirements:** Linux/Ubuntu with `bash`, `python3` and `zip`. No `sudo` is needed.

## How the templates were created

The `templates/` folder holds the three original files that the script copies into every
deployment. The assignment says the Python program and the config must be deployed unmodified, so I
recreated the files exactly as given and did not change their contents.

1. I created the GitHub repository `deploy_agent_cndawi`, made a local folder of the same name, ran
   `git init` there, and linked them with `git remote add origin`.
2. I created `templates/` with `mkdir templates` and wrote the three files into it with `vi`,
   copying the contents from the originals.
3. I checked each file before committing, because a typo in a template would be copied into every
   deployment:
   - `python3 -m json.tool templates/config.json` confirmed the config is valid JSON.
   - `awk -F, 'NF!=4' templates/assets.csv` printed nothing, so every row has exactly four
     columns. There must be no spaces around the commas, because the program reads the roster with
     Python's `csv` module.
   - `python3 -m py_compile templates/attendance_checker.py` confirmed the Python file is valid. I
     then removed the generated `__pycache__` folder so `templates/` holds exactly three files.
4. I committed them on `master` as "Add unmodified source templates" and pushed.
5. Editor swap files (`.swp`) once appeared in the project folder, so I deleted them and added a
   `.gitignore`.

## What is in this repository

```
deploy_agent_cndawi/
├── deploy_agent.sh
├── README.md
├── .gitignore
└── templates/
    ├── attendance_checker.py
    ├── assets.csv
    └── config.json
```

The program expects fixed paths: `Helpers/config.json`, `Helpers/assets.csv` and a `reports/`
folder. The script builds exactly that structure. It copies from `templates/`, so it must be run
from the folder that contains `templates/`.

## How to run

```bash
chmod +x deploy_agent.sh
./deploy_agent.sh
```

Or:

```bash
bash deploy_agent.sh
```

I chose an interactive menu, which reappears after every action until you quit:

```
==== Attendance Tracker ====
1) Deploy the Application
2) Run the Application
3) Archive the log files
4) Quit
```

## 1) Deploy

Each step runs in order. If one fails, the script prints an error and returns to the menu.

1. **Pre-flight checks.** Checks that `python3` and `zip` are installed and prints their versions.
   If either is missing, it stops before creating anything.
2. **Project name.** An empty name is rejected. The folder is called `attendance_tracker_<name>`.
3. **Overwrite protection.** If the folder exists, the script asks `(y/n)`. Only `y` replaces it.
   Any other answer aborts and leaves the old folder untouched.
4. **Folders.** Creates `Helpers/` and `reports/`.
5. **Files.** Copies `attendance_checker.py` and `config.json` unmodified from `templates/`.
6. **Roster.** The user types `A` or `B`, then a student count (a whole number of 1 or more):
   - **A (copy):** the header plus N rows from `templates/assets.csv`. These students already have
     4 earlier sessions. The template has only 10 students.
   - **B (generate):** N rows built from arrays of names and emails, with Attendance Count and
     Absence Count both at 0. After the 10th student, names are numbered
     (`student11@example.com,Alice Johnson 11,0,0`) so nothing is duplicated.
7. **`total_sessions`** is set to match the roster.
8. **Permissions** are set and printed.
9. **Thresholds** can be updated.
10. **Verification.** The script starts the tracker in the new project. If it runs, the folders,
    roster and config work together. This is a real marking session, so it records attendance.

The deployed project looks like this:

```
attendance_tracker_<name>/
├── attendance_checker.py
├── Helpers/
│   ├── assets.csv
│   └── config.json
└── reports/
```

### `total_sessions`

The program calculates attendance % = sessions attended ÷ `total_sessions` × 100. So
`total_sessions` must be one more than the earlier sessions already recorded (today counts too).
The script sets it with `sed`:

| Roster | Earlier sessions per student | `total_sessions` |
|---|---|---|
| A (copy) | 4 | 5 |
| B (generate) | 0 | 1 |

If a student's earlier sessions don't equal `total_sessions - 1`, the program prints a note and
carries on. You will see it if you run the program again on the same project, because the
verification run already recorded one session. It is harmless.

### Permissions

- `chmod +x attendance_checker.py` lets the file run as a program (`-rwxr-xr-x`).
- `chmod 600 Helpers/config.json` gives the owner read and write and everyone else nothing
  (`-rw-------`), because the config holds the thresholds that decide who is flagged as failing.

### Alert thresholds

A student below **failure** (default 50) is shown as URGENT, below **warning** (default 75) as
WARNING, and otherwise as on track.

The script asks `Update the alert thresholds? (y/n)`:

- `n` or `N` keeps 75 and 50.
- `y` or `Y` asks for a warning value and a failure value.
- Pressing Enter keeps the default.
- A value that is not a number is rejected.
- Any other answer prints an error.

The values are written with `sed`, which changes only the `"warning": <number>` and
`"failure": <number>` lines, so the file is not reformatted or reordered and keeps its permissions.

## 2) Run

Asks for a project name and checks that the project and `attendance_checker.py` exist, with a clear
error if not. It then runs `python3 attendance_checker.py` inside the project.

The program asks `[P]resent or [A]bsent?` for each student, updates `Helpers/assets.csv`, and
appends to:

- `reports/attendance.log` — every student
- `reports/absent.log` — absent students only

## 3) Archive

Moves each log into its own folder with a timestamp from `date +%Y%m%d_%H%M%S`. Example:

```
attendance_tracker_<name>/archives/attendance/attendance_20261013_163000.log
attendance_tracker_<name>/archives/absent/absent_20261013_163000.log
```

- The logs are **moved**, so `reports/` is clean for the next session.
- The timestamp makes every archived file unique.
- A missing log, for example no `absent.log` because nobody was absent, is skipped with a message
  instead of crashing.
- The new paths are printed.
- A failed move is reported as an error.

## Ctrl+C and Ctrl+Z during a deployment

While a deployment is in progress, the script traps `SIGINT` (Ctrl+C) and `SIGTSTP` (Ctrl+Z).

On an interrupt it:

1. Prints `Deployment was interrupted`.
2. Zips the incomplete project to `attendance_tracker_<name>_archive.zip` in the current folder.
3. Deletes the incomplete project folder.
4. Prints `Closing Session` and exits with status 130.

**Safe by design.** The folder name is stored in `PROJECT_DIR` only after the folder is created. An
interrupt before that prints `no folder was created yet` and creates and deletes nothing.

**What the ZIP holds.** Whatever existed at the moment of interruption: the folder tree and files
already copied, such as `attendance_checker.py`, `Helpers/config.json`, and `assets.csv` if it had
already been built.

**Not during marking.** The trap is switched off before the tracker starts. If you press Ctrl+C
while marking, the Python program saves the students already marked and stops, and the finished
project stays intact.

### How to test it

Choose `1`, enter `traptest`, and press Ctrl+C or Ctrl+Z at the roster question. Then run:

```bash
ls attendance_tracker_traptest_archive.zip
ls -d attendance_tracker_traptest
unzip -l attendance_tracker_traptest_archive.zip
```

The ZIP should exist, while the incomplete project folder should no longer exist.

## Testing

| What I tried | Result |
|---|---|
| Pre-flight normal, and with `zip` misspelled temporarily | Continued normally, or stopped before creating anything |
| New name, existing name answered `n` and `y`, empty name | Created, left untouched, replaced, or rejected |
| Roster A (3) and B (3, 12, 15 students) | Correct rows, `total_sessions` 5 and 1 |
| `abc` as count, `C` as roster choice, `maybe` as y/n | Rejected, back to the menu |
| `ls -l` after deploy | `-rwxr-xr-x` and `-rw-------` |
| Thresholds `80`/`60`, and Enter for defaults | Only those two lines changed |
| Run with an existing, a missing and an empty project name | Session started, or a clear error |
| Archive with both logs, a second time, and with no `absent.log` | Timestamped files, then skipped with a message |
| Ctrl+C and Ctrl+Z after the folder existed | ZIP created, folder deleted |
| Ctrl+C at the project-name question | No folder yet, no ZIP |
| Ctrl+C during the marking session | Program saved progress, project intact |

The command below checks the Bash script for syntax errors without running it:

```bash
bash -n deploy_agent.sh
```

## Known limitations

- Project names should use only letters, digits, `-` and `_`.
- Roster A copies at most the 10 students in the template, although the message shows the number
  requested.
- Thresholds are checked to be numbers, but not limited to 0–100.
- The ZIP-and-delete cleanup runs only on Ctrl+C or Ctrl+Z, not on invalid input after the folder
  exists.

## Video walkthrough

[Video Link] [https://youtu.be/CyO0HzoZcSE]
