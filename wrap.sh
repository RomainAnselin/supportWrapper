#!/bin/bash

### TO DO:
# - For sperf solr, add an input parameter
# - Test vs OSS diag collector
# - What if there are multiple diags under the same folder?
# - Opening the web browser from WSL is challenging at best. Need to detect windows and output file location for windows without executing the browser

template=$(dirname "${BASH_SOURCE[0]}")

if [ $# -ne 1 ]; then
    echo "Usage: $0 <Path to Opscenter diag>"
    exit 1
fi

if [[ "$1" == "." ]]; then opscdiag="$(pwd)"
else opscdiag="$1"
fi

# WARNING: If your path contains spaces/brackets, put the variable in double quotes.
# ie: nibblerpath="/mnt/c/Users/My User/Nibbler.jar"
browser=firefox
javapath=/usr/lib/jvm/liberica-jdk8u265-full/jre/bin/java
nibblerpath=~/tools/Nibbler.jar
pythonpath=~/dev/virtualenvs/py3/bin/python
sperfpath=~/tools/sperf/scripts/sperf
# Consider implementing a GC viewer tool maybe

prep() {
  mkdir "$opscdiag"/wrapper
  cp "$template"/index.html "$opscdiag"/wrapper/index.html
  cp "$template"/datastax.png "$opscdiag"/wrapper/datastax.png
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
"$javapath" -jar "$nibblerpath" "$opscdiag"
}

sperfcheck() {
# sperf come in 2 different format. Need to identify to run accordingly
if [[ $(file "$sperfpath" | sed -E 's/.*: ([A-Za-z]+) .*/\1/g') == 'ELF' ]]; then pyornotpy=
elif [[ $(file "$sperfpath" | sed -E 's/.*: ([A-Za-z]+) .*/\1/g') == 'Python' ]]; then pyornotpy="$pythonpath"
else
  echo "Sorry but I do not recognize sperf as binary or python. Skipping sperf"
  sperffail=1
fi
}

sperfrun() {
sperfcheck
echo "Sperf summary"
"$pyornotpy" "$sperfpath" -x -d "$subdiag" > "$opscdiag"/wrapper/sperfgeneral.txt
echo "Sperf GC analysis"
"$pyornotpy" "$sperfpath" -x -d "$subdiag" core gc > "$opscdiag"/wrapper/sperfgc.txt
echo "Sperf StatusLogger"
"$pyornotpy" "$sperfpath" -x -d "$subdiag" core statuslogger > "$opscdiag"/wrapper/sperfstatuslog.txt
echo "Sperf Slow Query"
"$pyornotpy" "$sperfpath" -x core slowquery -d "$subdiag" > "$opscdiag"/wrapper/sperfslow.txt
echo "Sperf Schema"
"$pyornotpy" "$sperfpath" -x core schema -d "$subdiag" > "$opscdiag"/wrapper/sperfschema.txt
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
	# printf '<a href="%s/Nibbler/%s" target = "center">%s</a><br>\n' "$opscdiag" $i $link >> "$opscdiag"/wrapper/left_frame.htm
  printf '\t\t\t<a href="../Nibbler/%s" target = "center">%s</a><br>\n' $i $link >> "$opscdiag"/wrapper/left_frame.htm
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
	# printf '<a href="%s/wrapper/%s" target = "center">%s</a><br>\n' "$opscdiag" $i $link >> "$opscdiag"/wrapper/left_frame.htm
  printf '\t\t\t<a href="./%s" target = "center">%s</a><br>\n' $i $link >> "$opscdiag"/wrapper/left_frame.htm
done
}

footer() {
cat >> "$opscdiag"/wrapper/left_frame.htm << EOF
   </body>

</html>
EOF
}

tarball(){
   echo "Compressing the data under "$opscdiag"_parsed.tgz"
   tar -czf "$opscdiag"_parsed.tgz Nibbler wrapper
}

openexist() {
  echo "No need to run me, the tool was previously executed,"
  echo "Opening the existing file. If you want to reprocess, delete the folder "$opscdiag"$1/wrapper"
  echo "let's save the planet some CPU cycles"
  $browser --new-window "file:///$opscdiag$1/wrapper/index.html"
}

openfail() {
  echo "Found the "$opscdiag"$1/wrapper folder but no index.html"
  echo "Delete the folder "$opscdiag"$1/wrapper and run me again"
}

### Execution
# Is there multiple diags in there? That may be a problem
if [ $(find "$opscdiag" -maxdepth 1 -name '*-diagnostics-*' -type d | wc -l) -ge 2 ]; then
  echo "Found more than one diagnostic folder in here. Please specify the exact diag. Exiting..."
  exit 1
fi
# make sure I am in a diag folder first or abort all
if [[ -d $(find "$opscdiag" -mindepth 2 -maxdepth 2 -name 'nodes' -type d) ]]; then
  # Expected path above the diag. Get the diag path for sperf
  subdiag="$(find "$opscdiag" -maxdepth 1 -name '*-diagnostics-*' -type d | head -1)"
  if [[ -z "$subdiag" ]]; then
    echo "Cannot find the diagnostics folder. Exiting..."
    exit 1
  fi
elif [[ -d $(find "$opscdiag" -mindepth 1 -maxdepth 1 -name 'nodes' -type d) ]]; then
  # Directly in the directory containing the nodes folder. Setting subdiag as per the current diag.
  subdiag="$opscdiag"
else
  echo "Cannot find the nodes folder. Exiting..."
  exit 1
fi

# Open existing report or process the request
pushd "$opscdiag" > /dev/null
# File was already processed locally
if [[ -f "$opscdiag"/wrapper/index.html ]]; then
    openexist
# If parsed diag was processed and sent to ZD by a fellow supportineer and brought back by ssdownloader.
# This will require more testing
elif [[ -f "$opscdiag"_parsed/wrapper/index.html ]]; then
    openexist _parsed
elif [[ -f "$opscdiag"_parsed.tgz ]]; then
    # The tgz exists but wasnt uncompressed
    echo "Found parsed archive: "$opscdiag"_parsed.tgz"
    echo "Uncompressing existing parsed diag and opening it"
    echo "Will open "file:///"$opscdiag"/wrapper/index.html""
    tar zxf "$opscdiag"_parsed.tgz
    $browser --new-window "file:///$opscdiag/wrapper/index.html"
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
  $browser --new-window "file:///$opscdiag/wrapper/index.html"
fi
popd > /dev/null
