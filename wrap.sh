#!/bin/bash

### TO DO:
# - Verify subdiag call. If people dont use ssdownloader, they may not have 2 levels of folders for the diag
# - If solr, may need extra param for it to add extra sperf output
# - push to git
# - Test vs OSS diag collector

template=$(dirname "${BASH_SOURCE[0]}")

if [ $# -ne 1 ]; then
    echo "Usage: $0 <Path to Opscenter diag>"
    exit 1
fi

opscdiag="$1"
browser=firefox
javapath=/usr/lib/jvm/liberica-jdk8u265-full/jre/bin/java
nibblerpath=~/tools/Nibbler.jar
pythonpath=/home/romain/dev/virtualenvs/py3/bin/python
sperf=~/tools/sperf/scripts/sperf
# Consider implementing a GC viewer tool maybe

prep() {
  mkdir "$opscdiag"/wrapper
  cp $template/index.html "$opscdiag"/wrapper/index.html
  cp $template/datastax.png "$opscdiag"/wrapper/datastax.png
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
$javapath -jar $nibblerpath "$opscdiag"
}

getdiagname() {
# The tool runs in the top diag directory. However, sperf requires the actual diag folder
# !!! need to double check that brings a valid result !!!
  subdiag="$(find "$opscdiag" -maxdepth 1 -name '*-diagnostics-*' -type d | head -1)"
  #echo $subdiag
}

sperfrun() {
echo "Sperf summary"
$pythonpath $sperf -x -d "$subdiag" > "$opscdiag"/wrapper/sperfgeneral.txt
echo "Sperf GC analysis"
$pythonpath $sperf -x -d "$subdiag" core gc > "$opscdiag"/wrapper/sperfgc.txt
echo "Sperf StatusLogger"
$pythonpath $sperf -x -d "$subdiag" core statuslogger > "$opscdiag"/wrapper/sperfstatuslog.txt
echo "Sperf Slow Query"
$pythonpath $sperf -x core slowquery -d "$subdiag" > "$opscdiag"/wrapper/sperfslow.txt
echo "Sperf Schema"
$pythonpath $sperf -x core schema -d "$subdiag" > "$opscdiag"/wrapper/sperfschema.txt
}

# Time to build the content
header() {
cat > "$opscdiag"/wrapper/left_frame.htm << EOF
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
cat >> "$opscdiag"/wrapper/left_frame.htm << EOF
     <b>Nibbler</b><br>
EOF

for i in $(ls "$opscdiag"/Nibbler)
do
  linkname
	printf '<a href="%s/Nibbler/%s" target = "center">%s</a><br>\n' "$opscdiag" $i $link >> "$opscdiag"/wrapper/left_frame.htm
done
}

# Populate the frame for sperf files
sperfpop() {
cat >> "$opscdiag"/wrapper/left_frame.htm << EOF
      <br>
    <b>Sperf</b><br>
EOF

for i in $(ls -tr "$opscdiag"/wrapper | grep sperf*)
do
  # echo $i
  linkname
	printf '<a href="%s/wrapper/%s" target = "center">%s</a><br>\n' "$opscdiag" $i $link >> "$opscdiag"/wrapper/left_frame.htm
done
}

footer() {
cat >> "$opscdiag"/wrapper/left_frame.htm << EOF
   </body>

</html>
EOF
}

### Execution
# make sure I am in the right place first or abort all
if [[ -d $(find "$opscdiag" -mindepth 2 -maxdepth 2 -name 'nodes' -type d) ]]; then
  # Expected path above the diag. Get the diag path for sperf
  #subdiag="$(find "$opscdiag" -maxdepth 1 -name '*-diagnostics-*' -type d | head -1)"
  subdiag="$(find "$opscdiag" -maxdepth 1 -name '*-diagnostics-*' -type d | head -1)"
  if [[ -z "$subdiag" ]]; then
    echo "Cannot find the diagnostic folder. Exiting..."
    exit 1
  fi
elif [[ -d $(find "$opscdiag" -mindepth 1 -maxdepth 1 -name 'nodes' -type d) ]]; then
  # Directly in the directory containing the nodes folder. Setting subdiag as per the current diag.
  subdiag="$opscdiag"
else
  echo "Cannot find the nodes folder. Exiting..."
  exit 1
fi

if [[ -d "$opscdiag"/wrapper ]]; then
  echo "No need to run, the tool has previously executed,"
  echo "let's save the planet some CPU consumption"
  echo "If you need to rerun the wrapper, delete "$opscdiag"/wrapper"
  # echo "Run $browser --new-window \"file:///$opscdiag/wrapper/index.html\""
else
  pushd "$opscdiag" > /dev/null
  prep
  nibblerrun
  sperfrun
  header
  nibblerpop
  sperfpop
  footer
  popd > /dev/null
fi

$browser --new-window "file:///$opscdiag/wrapper/index.html"
