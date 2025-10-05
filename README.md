# Online Course Log Analyzer

## Overview
This project is a **Shell Script** developed for the course **ENCS3130 Linux Laboratory** (Second Summer 2024/2025).  
The script analyzes **online teaching platform logs** (Zoom/Teams) and provides useful analytics for instructors, administrators, and students.  
It parses the log files, extracts information, and displays statistics through a simple **menu-based interface**.

## Requirements
- Linux / Ubuntu / WSL environment  
- Bash shell  
- `gawk`  

Log file in CSV format containing:
```
Tool,StudentID,FirstName,LastName,InstructorID,CourseID,StartTime,Length,SessionID,StudentBeginTime,StudentLeaveTime
```

Registration files for each course (CourseID.reg) containing:
```
StudentID,FirstName,LastName
```

## How to Run
1. Extract the project folder:
   ```bash
   unzip online-course-log-analyzer-final.zip
   cd online-course-log-analyzer-final
   ```
2. Make the script executable:
   ```bash
   chmod +x analyzer.sh
   ```
3. Run the script:
   ```bash
    ./analyzer.sh
   ```

## Features (Menu Options)
1. **Number of sessions per course**  
2. **Average attendance per course**  
3. **List of absent students per course**  
4. **List of late arrivals per session**  
5. **List of students leaving early**  
6. **Average attendance time per student per course**  
7. **Average number of attendances per instructor**  
8. **Most frequently used tool (Zoom/Teams)**  

## Example Run
```
======================================
 Online Course Log Analyzer (bash+awk)
======================================
1) Number of sessions per course
2) Average attendance per course
3) Absent students per course
4) Late arrivals in a session
5) Early leavers in a session
6) Avg attendance time per student (course)
7) Avg attendance per instructor
8) Most-used tool (by distinct sessions)
9) Exit
Choose [1-9]: 1
Enter CourseID [ENCS101]: ENCS101
Sessions in ENCS101: 2
```

## Test Cases
See the file `TESTS.txt` for detailed input/output examples.
