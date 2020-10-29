#!/bin/bash

### TO DO:
# - For sperf solr, add an input parameter
# - Test vs OSS diag collector
# - Opening the web browser from WSL is challenging at best. Need to detect windows and output file location for windows without executing the browser (in progress)
# - Implement debug
# - Handling of relative path (as it stands using ./diag lead to failure)

debug=0
template=$(dirname "${BASH_SOURCE[0]}")

if [ $# -ne 1 ]; then
    echo "Usage: $0 <Path to Opscenter diag>"
    exit 1
fi

if [[ "$1" == "." ]]; then opscdiag="$(pwd)"
else opscdiag="$1"
fi

if [[ "$template" == "." ]]; then template="$(pwd)"
fi

# WARNING: If your path contains spaces/brackets (ie: Windows), put the variable in double quotes.
# ie: nibblerpath="/mnt/c/Users/My User/Nibbler.jar"
# browser="/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
browser=firefox
javapath=/usr/lib/jvm/liberica-jdk8u265-full/jre/bin/java
nibblerpath=~/tools/Nibbler.jar
pythonpath=~/dev/virtualenvs/py3/bin/python
sperfpath=~/tools/sperf/scripts/sperf
# Consider implementing a GC viewer tool maybe

prep() {
  mkdir "$opscpath"/wrapper
  cp "$template"/index.html "$opscpath"/wrapper/index.html
  cp "$template"/datastax.png "$opscpath"/wrapper/datastax.png
}

linkname() {
  if [[ "$i" == "Cluster_Configuration_Summary.out" ]]; then link=Summary
  elif [[ "$i" == "Node_Configuration_Files_Info.out" ]]; then link=Conf
  elif [[ "$i" == "Node_Info.out" ]]; then link=Info
  elif [[ "$i" == "Node_Resource_Usage_Info.out" ]]; then link=Resource
  elif [[ "$i" == "Node_Status.out" ]]; then link=Status
  elif [[ "$i" == "System_Log_Event_Info.out" ]]; then link=SystemLog
  elif [[ "$i" == "Table_Statistics.out" ]]; then link=TableStats
  elif [[ "$i" == "Thread_Pool_Statistics.out" ]]; then link=ThreadPool
  elif [[ "$i" == "sperfgc.txt" ]]; then link=GC
  elif [[ "$i" == "sperfgeneral.txt" ]]; then link=General
  elif [[ "$i" == "sperfstatuslog.txt" ]]; then link=StatusLogger
  elif [[ "$i" == "sperfslow.txt" ]]; then link=SlowQueries
  elif [[ "$i" == "sperfschema.txt" ]]; then link=Schema
  else link=$i
fi
# echo $link
}

# Run tools
nibblerrun() {
echo "Nibbler running"
"$javapath" -jar "$nibblerpath" "$opscpath"
}

sperfcheck() {
  # sperf come in different format and is declared differently on various OS. Need to identify to run accordingly
if [[ "$OSTYPE" == "darwin"* ]]; then
  if [[ $(file "$sperfpath" | sed -E 's/.*: ([A-Za-z0-9\-]+) .*/\1/g') == 'Mach-O' ]]; then pyornotpy=0
  fi
elif [[ $(file "$sperfpath" | sed -E 's/.*: ([A-Za-z]+) .*/\1/g') == 'ELF' ]]; then pyornotpy=0
elif [[ $(file "$sperfpath" | sed -E 's/.*: ([A-Za-z]+) .*/\1/g') == 'Python' ]]; then pyornotpy=1
fi
if [[ "$debug" == "1" ]]; then
  filetype=$(file "$sperfpath")
  sedout=$(file "$sperfpath" | sed -E 's/.*: ([A-Za-z0-9\-]+) .*/\1/g')
  printf 'DEBUG\t OS: %s FileSperf: %s Sed: %s \n' "$OSTYPE" "$filetype" "$sedout"
fi
}

sperfrun() {
sperfcheck
if [[ "$debug" == "1" ]]; then
  printf 'DEBUG\t Pyornotpy: %s\n' "$pyornotpy"
  echo "DEBUG  Command: "$pythonpath" "$sperfpath" -x -d "$subdiag" > "$opscpath"/wrapper/sperfgeneral.txt"
fi
if [[ "$pyornotpy" == "1" ]]; then
  echo "Sperf summary"
  "$pythonpath" "$sperfpath" -x -d "$subdiag" > "$opscpath"/wrapper/sperfgeneral.txt
  echo "Sperf GC analysis"
  "$pythonpath" "$sperfpath" -x -d "$subdiag" core gc > "$opscpath"/wrapper/sperfgc.txt
  echo "Sperf StatusLogger"
  "$pythonpath" "$sperfpath" -x -d "$subdiag" core statuslogger > "$opscpath"/wrapper/sperfstatuslog.txt
  echo "Sperf Slow Query"
  "$pythonpath" "$sperfpath" -x core slowquery -d "$subdiag" > "$opscpath"/wrapper/sperfslow.txt
  echo "Sperf Schema"
  "$pythonpath" "$sperfpath" -x core schema -d "$subdiag" > "$opscpath"/wrapper/sperfschema.txt
else
  echo "Sperf summary"
  "$sperfpath" -x -d "$subdiag" > "$opscpath"/wrapper/sperfgeneral.txt
  echo "Sperf GC analysis"
  "$sperfpath" -x -d "$subdiag" core gc > "$opscpath"/wrapper/sperfgc.txt
  echo "Sperf StatusLogger"
  "$sperfpath" -x -d "$subdiag" core statuslogger > "$opscpath"/wrapper/sperfstatuslog.txt
  echo "Sperf Slow Query"
  "$sperfpath" -x core slowquery -d "$subdiag" > "$opscpath"/wrapper/sperfslow.txt
  echo "Sperf Schema"
  "$sperfpath" -x core schema -d "$subdiag" > "$opscpath"/wrapper/sperfschema.txt
fi
}

# Time to build the content
header() {
cat > "$opscpath"/wrapper/left_frame.htm << EOF
<!DOCTYPE html>
<html>

   <head>
      <title>Diag files</title>
   </head>

   <body>
     <img src="./datastax.png" alt="DataStax"><br><br>
EOF
}

# Populate the frame for nibbler files
nibblerpop() {
cat >> "$opscpath"/wrapper/left_frame.htm << EOF
     <b>Nibbler</b><br>
EOF

for i in $(ls "$opscpath"/Nibbler)
do
  linkname
	# printf '<a href="%s/Nibbler/%s" target = "center">%s</a><br>\n' "$opscpath" $i $link >> "$opscpath"/wrapper/left_frame.htm
  printf '\t\t\t<a href="../Nibbler/%s" target = "center">%s</a><br>\n' $i $link >> "$opscpath"/wrapper/left_frame.htm
done
}

# Populate the frame for sperf files
sperfpop() {
cat >> "$opscpath"/wrapper/left_frame.htm << EOF
      <br>
    <b>Sperf</b><br>
EOF

for i in $(ls -tr "$opscpath"/wrapper | grep sperf*)
do
  # echo $i
  linkname
	# printf '<a href="%s/wrapper/%s" target = "center">%s</a><br>\n' "$opscpath" $i $link >> "$opscpath"/wrapper/left_frame.htm
  printf '\t\t\t<a href="./%s" target = "center">%s</a><br>\n' $i $link >> "$opscpath"/wrapper/left_frame.htm
done
}

footer() {
cat >> "$opscpath"/wrapper/left_frame.htm << EOF
   </body>

</html>
EOF
}

tarball(){
   echo "Compressing the data under "$opscpath"_parsed.tgz"
   tar -czf "$opscpath"_parsed.tgz Nibbler wrapper
}

browseropen() {
  echo "Opening browser"
  if [[ "$(sed 's/.*microsoft.*/win/gi' /proc/version)" == "win" ]]; then opscpath="$(wslpath -m "$opscpath")"
  fi
  "$browser" --new-window "file:///$opscpath$1/wrapper/index.html"
}

debuginfo() {
  echo "*** DEBUG ON: Dumping data ***"
  echo "Opscdiag: $opscdiag Subdiag: $subdiag"
  echo "Opscpath: $opscpath"
  echo "Browser: $browser"
  echo "Java: $javapath"
  $javapath -version
  echo "Nibbler: $nibblerpath"
  echo "Python: $pythonpath"
  $pythonpath -V
  echo "Sperf: $sperfpath"
  printf 'Current path: "%s"\n' "$(pwd)"
}

### Execution
# Is there multiple diags in there? That may be a problem
if [ $(find "$opsdiag" -maxdepth 1 -name '*-diagnostics-*' -type d | wc -l) -ge 2 ]; then
  echo "Found more than one diagnostic folder in here. Please specify the exact diag. Exiting..."
  exit 1
# make sure I am in a diag folder first or abort all
elif [[ -d $(find "$opscdiag" -mindepth 2 -maxdepth 2 -name 'nodes' -type d) ]]; then
  # Expected path above the diag. Get the diag path for sperf
  subdiag="$(find "$opscdiag" -maxdepth 1 -name '*-diagnostics-*' -type d | head -1)"
  if [[ -z "$subdiag" ]]; then
    echo "Cannot find the diagnostics folder. Exiting..."
    exit 1
  fi
elif [[ -d $(find "$opscdiag" -mindepth 1 -maxdepth 1 -name 'nodes' -type d) ]]; then
  # Directly in the directory containing the nodes folder. Setting subdiag as per the current diag.
  subdiag="$opscpath"
else
  echo "Cannot find the nodes folder. Exiting..."
  exit 1
fi

# Open existing report or process the request
if [[ "$debug" == "1" ]]; then
  printf 'DEBUG\t Opscdiag: "%s" Template: "%s" Subdiag: "%s"\n' "$opscpath" "$template" "$subdiag"
fi

pushd "$opscdiag" > /dev/null
opscpath="$(pwd)"
# File was already processed locally
if [[ -f "$opscpath"/wrapper/index.html ]]; then
  browseropen
  # If parsed diag was processed and sent to ZD by a fellow supportineer and brought back by ssdownloader.
  # This will require more testing
elif [[ -f "$opscpath"_parsed/wrapper/index.html ]]; then
  browseropen _parsed
elif [[ -f "$opscpath"_parsed.tgz ]]; then
  # The tgz exists but wasnt uncompressed
  echo "Found parsed archive: "$opscdiag"_parsed.tgz"
  echo "Uncompressing existing parsed diag and opening it"
  echo "Will open "file:///"$opscpath"/wrapper/index.html""
  tar zxf "$opscdiag"_parsed.tgz
  browseropen
else
  prep
  nibblerrun
  sperfrun
  header
  nibblerpop
  sperfpop
  footer
  # need to revisit tarball generation. Too many issues at the moment
  # tarball
  browseropen
fi

if [[ "$debug" == "1" ]]; then debuginfo
fi
popd > /dev/null
