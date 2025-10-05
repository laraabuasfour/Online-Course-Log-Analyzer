#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${1:-$(dirname "$0")/data}"
LOG_FILE="$DATA_DIR/logs.csv"

if ! command -v gawk >/dev/null 2>&1; then
  echo "Error: gawk is required. Please install 'gawk' and try again." >&2
  exit 1
fi

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Error: logs file not found at $LOG_FILE" >&2
  exit 1
fi

prompt() {
  local msg="$1"; shift
  local def="${1:-}"
  local val
  if [[ -n "$def" ]]; then
    read -rp "$msg [$def]: " val || exit 1
    echo "${val:-$def}"
  else
    read -rp "$msg: " val || exit 1
    echo "$val"
  fi
}

# (1) Number of sessions per course
sessions_per_course() {
  local course="$1"
  gawk -v FS=", *" -v C="$course" '
    NR>1 && $6==C { seen[$6 FS $9]=1 }
    END{ for(k in seen) c++; print (c+0) }
  ' "$LOG_FILE"
}

# (2) Average attendance per course
avg_attendance_course() {
  local course="$1"
  gawk -v FS=", *" -v C="$course" '
    NR>1 && $6==C { cnt[$9]++ }
    END{ for(s in cnt){ sum+=cnt[s]; n++ } if(n) printf("%.2f
", sum/n); else print 0 }
  ' "$LOG_FILE"
}

# (3) Absent students per course
absent_students_course() {
  local course="$1"
  local reg="$DATA_DIR/$course.reg"
  gawk -v FS=", *" -v C="$course" -v REG="$reg" '
    BEGIN{
      FS=","; OFS=",";
      while((getline line < REG) > 0){
        if(line ~ /^StudentID/) continue
        n=split(line,a,/ *, */)
        sid=a[1]; fn=a[2]; ln=a[3]
        regsid[sid]=fn","ln
      }
      close(REG)
    }
    NR>1 && $6==C { present[$2]=1 }
    END{
      print "StudentID,FirstName,LastName"
      for(sid in regsid){
        if(!(sid in present)){
          split(regsid[sid],b,/,/)
          print sid, b[1], b[2]
        }
      }
    }
  ' "$LOG_FILE"
}

awk_time_lib='
  function toMin(hhmm,   p){ split(hhmm,p,":"); return (p[1]+0)*60+(p[2]+0) }
  function startMin(dt,  parts){ n=split(dt, parts, /[ ]/); return toMin(parts[n]) }
'

# (4) Late arrivals
late_arrivals() {
  local course="$1" sid="$2" X="$3"
  gawk -v FS=", *" -v C="$course" -v S="$sid" -v X="$X" "$awk_time_lib
    NR>1 && $6==C && $9==S {
      st=startMin($7); jb=toMin($10)
      if(jb-st>=X) printf "%s,%s,%s,%d\n",$2,$3,$4,(jb-st)
    }' "$LOG_FILE" | gawk -F, 'BEGIN{print "StudentID,FirstName,LastName,DelayMinutes"}{print}'
}

# (5) Early leavers
early_leavers() {
  local course="$1" sid="$2" Y="$3"
  gawk -v FS=", *" -v C="$course" -v S="$sid" -v Y="$Y" "$awk_time_lib
    NR>1 && $6==C && $9==S {
      st=startMin($7); end=st+($8+0); jl=toMin($11)
      if(end-jl>=Y) printf "%s,%s,%s,%d\n",$2,$3,$4,(end-jl)
    }' "$LOG_FILE" | gawk -F, 'BEGIN{print "StudentID,FirstName,LastName,EarlyLeaveMinutes"}{print}'
}

# (6) Avg attendance time per student
avg_time_per_student() {
  local course="$1"
  gawk -v FS=", *" -v C="$course" "$awk_time_lib
    NR==1{next}
    $6==C{
      sid=$2; name=$3" "$4
      dur=toMin($11)-toMin($10); if(dur<0) dur=0
      sum[sid]+=dur; cnt[sid]++; fullname[sid]=name; sess[$9]=1
    }
    END{
      total_sessions=0; for(s in sess) total_sessions++
      print "StudentID,Name,SessionsAttended,TotalMinutes,AvgMinutes(AttendedOnly),TotalSessionsInCourse"
      for(sid in sum){
        avg=(cnt[sid]?sum[sid]/cnt[sid]:0)
        printf "%s,%s,%d,%d,%.2f,%d\n",sid,fullname[sid],cnt[sid],sum[sid],avg,total_sessions
      }
    }
  ' "$LOG_FILE"
}

# (7) Avg attendance per instructor
avg_attendance_per_instructor() {
  gawk -v FS=", *" '
    NR==1{next}
    { key=$5 FS $6 FS $9
      if(!(key in seen)){ seen[key]=1; sess_count[$5]++ }
      attendees[key]++ }
    END{
      print "InstructorID,AvgAttendanceAcrossSessions"
      for(k in attendees){ split(k,a,/ *, */); ins=a[1]; sum[ins]+=attendees[k] }
      for(ins in sum){ printf "%s,%.2f\n",ins,(sum[ins]/sess_count[ins]) }
    }' "$LOG_FILE"
}

# (8) Most-used tool
most_used_tool() {
  gawk -v FS=", *" '
    NR==1{next}
    { key=$1 FS $6 FS $9
      if(!(key in seen)){ seen[key]=1; tool_count[$1]++ } }
    END{
      print "Tool,DistinctSessions"
      for(t in tool_count){ printf "%s,%d\n",t,tool_count[t]; if(tool_count[t]>maxc){maxc=tool_count[t]; maxtool=t} }
      print ""; if(maxtool!="") print "Most used tool by distinct sessions: " maxtool " (" maxc ")"
    }' "$LOG_FILE"
}

main_menu() {
  while true; do
    cat <<'MENU'
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
MENU
    read -rp "Choose [1-9]: " choice || exit 1
    case "$choice" in
      1) course=$(prompt "Enter CourseID" "ENCS101"); echo -n "Sessions in $course: "; sessions_per_course "$course";;
      2) course=$(prompt "Enter CourseID" "ENCS101"); echo -n "Average attendance in $course: "; avg_attendance_course "$course";;
      3) course=$(prompt "Enter CourseID" "ENCS101"); echo "Absent students in $course:"; absent_students_course "$course";;
      4) course=$(prompt "Enter CourseID" "ENCS101"); sid=$(prompt "Enter SessionID" "S1"); X=$(prompt "Late threshold minutes (X)" "10"); echo "Late arrivals (>= ${X} min) in $course / $sid:"; late_arrivals "$course" "$sid" "$X";;
      5) course=$(prompt "Enter CourseID" "ENCS101"); sid=$(prompt "Enter SessionID" "S1"); Y=$(prompt "Early-leave threshold minutes (Y)" "10"); echo "Early leavers (>= ${Y} min) in $course / $sid:"; early_leavers "$course" "$sid" "$Y";;
      6) course=$(prompt "Enter CourseID" "ENCS101"); echo "Avg attendance time per student (attended sessions only):"; avg_time_per_student "$course";;
      7) echo "Average attendance per instructor:"; avg_attendance_per_instructor;;
      8) echo "Most-used tool (by distinct sessions):"; most_used_tool;;
      9) echo "Bye!"; exit 0;;
      *) echo "Invalid choice." ;;
    esac
    echo
  done
}
main_menu
