#!/bin/bash

debug=0

usage() {
  if [ $# -ne 1 ]; then
    echo "Usage: $0 [-s] [-p] [-h] <Path to Opscenter diag>"
    echo "  -s   solr data"
    echo "  -p   GC per node"
    # TODO: Reset -r option to erase existing parsed data if you want to re-run with different options
    echo "  -h   show this help"
    exit 1
  fi
}

while getopts "sph" option; do
  case "${option}" in
    s) echo "Solr parsing requested"
       solrparse=1 ;;
    p) echo "Node per node parsing"
       pernode=1  ;;
    h) echo "Showing help"
       usage ;;
  esac
done

template=$(dirname "${BASH_SOURCE[0]}")

if [[ "${BASH_ARGV[0]}" == "." ]]; then opscdiag="$(pwd)"
# else opscdiag="$1"
# depending on what kind of path you provide, I need in any scenario to find the full path
else opscdiag="$(cd "$(dirname "${BASH_ARGV[0]}")"; pwd -P)/$(basename "${BASH_ARGV[0]}")"
fi

if [[ "$template" == "." ]]; then template="$(pwd)"
fi

if [[ -f "$template/wrap.conf" ]]; then
  source $template/wrap.conf
else
  echo "Missing wrap.conf file under $template"
  usage
  exit 1
fi

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
  elif [[ "$i" == "sperfnodegc.txt" ]]; then link=NodeGC
  elif [[ "$i" == "sperfnodestatuslog.txt" ]]; then link=NodeStatusLogger
  elif [[ "$i" == "sperfsolrcache.txt" ]]; then link=SolrCache
  elif [[ "$i" == "sperfsolrscore.txt" ]]; then link=SolrScore
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
  echo "DEBUG  Command: "$pythonpath" "$sperfpath" -x -d "$subdiag" > ./wrapper/sperfgeneral.txt"
fi
if [[ "$pyornotpy" == "1" ]]; then
  echo "Sperf summary"
  "$pythonpath" "$sperfpath" -x -d "$subdiag" > ./wrapper/sperfgeneral.txt &
  echo "Sperf GC analysis"
  "$pythonpath" "$sperfpath" -x -d "$subdiag" core gc > ./wrapper/sperfgc.txt &
  echo "Sperf StatusLogger"
  "$pythonpath" "$sperfpath" -x -d "$subdiag" core statuslogger > ./wrapper/sperfstatuslog.txt &
  echo "Sperf Slow Query"
  "$pythonpath" "$sperfpath" -x core slowquery -d "$subdiag" > ./wrapper/sperfslow.txt &
  echo "Sperf Schema"
  "$pythonpath" "$sperfpath" -x core schema -d "$subdiag" > ./wrapper/sperfschema.txt &
  if [[ "$pernode" == 1 ]]; then
    echo "Sperf GC per node"
    "$pythonpath" "$sperfpath" -x -d "$subdiag" core gc -r nodes > ./wrapper/sperfnodegc.txt &
    echo "Sperf StatusLogger per node"
    "$pythonpath" "$sperfpath" -x -d "$subdiag" core statuslogger -r histogram > ./wrapper/sperfnodestatuslog.txt &
  fi
  if [[ "$solrparse" == 1 ]]; then
    echo "Sperf Solr Filtercache"
    "$pythonpath" "$sperfpath" -x search filtercache -d "$subdiag" > ./wrapper/sperfsolrcache.txt &
    echo "Sperf Solr Queryscore"
    "$pythonpath" "$sperfpath" -x search queryscore -d "$subdiag" > ./wrapper/sperfsolrscore.txt &
  fi
else
  echo "Sperf summary"
  "$sperfpath" -x -d "$subdiag" > ./wrapper/sperfgeneral.txt &
  echo "Sperf GC analysis"
  "$sperfpath" -x -d "$subdiag" core gc > ./wrapper/sperfgc.txt &
  echo "Sperf StatusLogger"
  "$sperfpath" -x -d "$subdiag" core statuslogger > ./wrapper/sperfstatuslog.txt &
  echo "Sperf Slow Query"
  "$sperfpath" -x core slowquery -d "$subdiag" > ./wrapper/sperfslow.txt &
  echo "Sperf Schema"
  "$sperfpath" -x core schema -d "$subdiag" > ./wrapper/sperfschema.txt &
  if [[ "$pernode" == 1 ]]; then
    echo "Sperf GC per node"
    "$sperfpath" -x -d "$subdiag" core gc -r nodes > ./wrapper/sperfnodegc.txt &
    echo "Sperf StatusLogger per node"
    "$sperfpath" -x -d "$subdiag" core statuslogger -r histogram > ./wrapper/sperfnodestatuslog.txt &
  fi
  if [[ "$solrparse" == 1 ]]; then
    echo "Sperf Solr Filtercache"
    "$sperfpath" -x search filtercache -d "$subdiag" > ./wrapper/sperfsolrcache.txt &
    echo "Sperf Solr Queryscore"
    "$sperfpath" -x search queryscore -d "$subdiag" > ./wrapper/sperfsolrscore.txt &
  fi
fi
wait
}

# Time to build the content
header() {
cat > ./wrapper/left_frame.htm << EOF
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
cat >> ./wrapper/left_frame.htm << EOF
     <b>Nibbler</b><br>
EOF

for i in $(ls ./Nibbler)
do
  linkname
	printf '\t\t\t<a href="../Nibbler/%s" target = "center">%s</a><br>\n' $i $link >> ./wrapper/left_frame.htm
done
}

# Populate the frame for sperf files
sperfpop() {
cat >> ./wrapper/left_frame.htm << EOF
      <br>
    <b>Sperf</b><br>
EOF

for i in $(ls -tr ./wrapper | grep sperf*)
do
  # echo $i
  linkname
	printf '\t\t\t<a href="./%s" target = "center">%s</a><br>\n' $i $link >> ./wrapper/left_frame.htm
done
}

footer() {
cat >> ./wrapper/left_frame.htm << EOF
   </body>

</html>
EOF
}

tarball(){
   echo "Compressing the data under "$opscdiag"_parsed.tgz"
   tar -czf "$opscdiag"_parsed.tgz Nibbler wrapper
}

browseropen() {
  echo "Opening browser"
  if [[ "$(sed 's/.*microsoft.*/win/gi' /proc/version)" == "win" ]]; then opscdiag="$(wslpath -m "$opscdiag")"
  fi
  if [[ "$newwindow" == "1" ]]; then "$browser" --new-window "file:///$opscdiag$1/wrapper/index.html"
  else "$browser" "file:///$opscdiag$1/wrapper/index.html"
  fi
}

debuginfo() {
  echo "*** DEBUG ON: Dumping data ***"
  echo "Opscdiag: $opscdiag Subdiag: $subdiag"
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
if [ $(find "$opscdiag" -maxdepth 1 -name '*-diagnostics-*' -type d | wc -l) -ge 2 ]; then
  echo "Found more than one diagnostic folder in here. Please specify the exact diag. Exiting..."
  ls -ltr
  exit 1
# make sure I am in a diag folder first or abort all
elif [[ -d $(find "$opscdiag" -mindepth 2 -maxdepth 2 -name 'nodes' -type d) ]]; then
  # Expected path above the diag. Get the diag path for sperf
  subdiag="$(find "$opscdiag" -mindepth 1 -maxdepth 1 -name '*-diagnostics-*' -type d)"
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
if [[ "$debug" == "1" ]]; then
  printf 'DEBUG\t Opscdiag: "%s" Template: "%s" Subdiag: "%s"\n' "$opscdiag" "$template" "$subdiag"
fi

pushd "$opscdiag" > /dev/null
# File was already processed locally
if [[ -f "$opscdiag"/wrapper/index.html ]]; then
  browseropen
  # If parsed diag was processed and sent to ZD by a fellow supportineer and brought back by ssdownloader.
  # This will require more testing
elif [[ -f "$opscdiag"_parsed/wrapper/index.html ]]; then
  browseropen _parsed
elif [[ -f "$opscdiag"_parsed.tgz ]]; then
  # The tgz exists but wasnt uncompressed
  echo "Found parsed archive: "$opscdiag"_parsed.tgz"
  echo "Uncompressing existing parsed diag and opening it"
  echo "Will open "file:///"$opscdiag"/wrapper/index.html""
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
