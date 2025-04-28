#!/bin/bash

debug=0

usage() {
  if [ $# -ne 1 ]; then
    echo "Usage: $0 [-s] [-p] [-g] [-d] [-m {tar.gz}] [-t {ticketid}] [-h] <Path to Opscenter diag>"
    echo "  -s            solr data"
    echo "  -p            GC per node"
    echo "  -g            greps script"
    echo "  -d            Diag Viewer db creation"
    echo "  -m {tar.gz}   MonteCristo Services diag execution"
    echo "  -t {ticketid} Ticket number. Necessary for Montecristo"
    # TODO (or not, I dont like scripting removal): Reset -r option to erase existing parsed data if you want to re-run with different options
    echo "  -h   show this help"
    exit 1
  fi
}

while getopts "spgdm:t:h" option; do
  case "${option}" in
    s) echo "Solr parsing requested"
       solrparse=1 ;;
    p) echo "Node per node parsing"
       pernode=1  ;;
    g) echo "Greps requested"
       slgreps=1  ;;
    d) echo "Generating diag-viewer"
       diagv=1  ;;
    m) echo "Generating Montecristo"
       diagtgz="$OPTARG"
       montecris=1  ;;
    t) ticketid="$OPTARG" ;;
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
  #cp "$template"/datastax.png "$opscdiag"/wrapper/datastax.png
  cp "$template"/ds.svg "$opscdiag"/wrapper/ds.svg
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
  elif [[ "$i" == "sperf2gc.txt" ]]; then link=GC
  elif [[ "$i" == "sperf1general.txt" ]]; then link=General
  elif [[ "$i" == "sperf3statuslog.txt" ]]; then link=StatusLogger
  elif [[ "$i" == "sperf4slow.txt" ]]; then link=SlowQueries
  elif [[ "$i" == "sperf5schema.txt" ]]; then link=Schema
  elif [[ "$i" == "sperf6nodegc.txt" ]]; then link=NodeGC
  elif [[ "$i" == "sperf7nodestatuslog.txt" ]]; then link=NodeStatusLogger
  elif [[ "$i" == "sperf8solrcache.txt" ]]; then link=SolrCache
  elif [[ "$i" == "sperf9solrscore.txt" ]]; then link=SolrScore
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
  sperfcmd="$pythonpath $sperfpath"
  printf 'sperfcmd: %s \n' "$sperfcmd"
else
  sperfcmd="$sperfpath"
fi

echo "Sperf summary"
${sperfcmd} -x -d "$subdiag" > ./wrapper/sperf1general.txt &
echo "Sperf GC analysis"
${sperfcmd} -x -d "$subdiag" core gc > ./wrapper/sperf2gc.txt &
echo "Sperf StatusLogger"
${sperfcmd} -x -d "$subdiag" core statuslogger > ./wrapper/sperf3statuslog.txt &
echo "Sperf Slow Query"
${sperfcmd} -x core slowquery -d "$subdiag" > ./wrapper/sperf4slow.txt &
echo "Sperf Schema"
${sperfcmd} -x core schema -d "$subdiag" > ./wrapper/sperf5schema.txt &
if [[ "$pernode" == 1 ]]; then
  echo "Sperf GC per node"
  ${sperfcmd} -x -d "$subdiag" core gc -r nodes > ./wrapper/sperf6nodegc.txt &
  echo "Sperf StatusLogger per node"
  ${sperfcmd} -x -d "$subdiag" core statuslogger -r histogram > ./wrapper/sperf7nodestatuslog.txt &
fi
if [[ "$solrparse" == 1 ]]; then
  echo "Sperf Solr Filtercache"
  ${sperfcmd} -x search filtercache -d "$subdiag" > ./wrapper/sperf8solrcache.txt &
  echo "Sperf Solr Queryscore"
  ${sperfcmd} -x search queryscore -d "$subdiag" > ./wrapper/sperf9solrscore.txt &
fi

wait
}

slgrep() {
if [[ ! -d "$opscdiag"/slg ]]; then
	echo "Creating slg directory"
	pwd
	mkdir "$opscdiag"/slg
fi

if [[ -f $grepsl && $slgreps == 1 ]]; then
  echo ; echo "Running SL greps"
  $grepsl -c "$opscdiag" &
  $grepsl -g "$opscdiag" &
  $grepsl -s "$opscdiag" &
  $grepsl -6 "$opscdiag" &
  $grepsl -t "$opscdiag" &
  $grepsl -q "$opscdiag" &
  $grepsl -b "$opscdiag" &
  $grepsl -l "$opscdiag" &
  wait
else
  echo "ERROR: Grep script not found. Skipping..."
fi
}

diagviewer() {
  if [[ $diagv == 1 ]]; then
    export PYTHONPATH=$PYTHONPATH:$jbd/src
    $dvpy $dvpath/src/import $opscdiag
    echo "Run the following command to review the content of the diagviewer or access the sqlite db" > ./wrapper/diag-viewer.txt
    echo "cd $dvpath/src" >> ./wrapper/diag-viewer.txt
    echo "python -mviewer $opscdiag/diagnostics.db" >> ./wrapper/diag-viewer.txt
    # echo "DB is available under $opscdiag/diagnostics.db" >> ./wrapper/diag-viewer.txt
  fi
  }

montecristo(){
  if [ -f "$opscdiag/../$diagtgz" ] && [ -n "$ticketid" ] && [ $montecris == 1 ]; then
    export JAVA_HOME=$jvmh
    mkdir "$opscdiag"/../diagMC-$ticketid
    cp "$opscdiag/../$diagtgz" "$opscdiag"/../diagMC-$ticketid
    pushd "$mcpath"
    #pushd "$opscdiag"/../diagMC-$ticketid
    $mcpath/run.sh -d -s -c "$opscdiag"/../diagMC-$ticketid $ticketid | tee ./mctmp.txt
    mv -f ./mctmp.txt "$opscdiag"/wrapper/mc.txt
    popd
  else
    echo "MonteCristo requires both diag tgz file (-m) and ticket id (-t)"
    echo "Is the file "$opscdiag"/../"$diagtgz" available along ticket number?"
  fi
}

converter(){
  if [ -f $HOME/ds-discovery/$ticketid/reports/montecristo/content/exporter.md ]; then
    python "$template"/md2html.py $HOME/ds-discovery/$ticketid/reports/montecristo/content/exporter.md "$opscdiag"/wrapper/mc.html
  else
    echo ERROR: MonteCristo failed to generate the summary exporter.md, review above for specific issues on its execution
  fi
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
     <img src="./ds.svg" alt="DataStax"><br>
EOF
}

# Populate the frame for nibbler files
nibblerpop() {
cat >> ./wrapper/left_frame.htm << EOF
     <b>Nibbler</b><br>
EOF

for i in $(ls ./Nibbler | grep -E -v '[1-3]')
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

for i in $(ls ./wrapper | grep sperf*)
do
  # echo $i
  linkname
	printf '\t\t\t<a href="./%s" target = "center">%s</a><br>\n' $i $link >> ./wrapper/left_frame.htm
done
}

# SL greps
grepspop() {
cat >> ./wrapper/left_frame.htm << EOF
      <br>
    <b>Greps</b><br>
EOF

for i in $(ls ./slg | grep -E '[1-3]')
do
  # echo $i
  linkname
	printf '\t\t\t<a href="../slg/%s" target = "center">%s</a><br>\n' $i $link >> ./wrapper/left_frame.htm
done
}

# Diag link
dvpop() {
cat >> ./wrapper/left_frame.htm << EOF
      <br>
    <b>DiagV & MC</b><br>
EOF

  printf '\t\t\t<a href="./%s" target = "center">%s</a><br>\n' diag-viewer.txt DVinfo >> ./wrapper/left_frame.htm
  echo "Come back later, I'm working. MonteCristo generation in progress. Data will be in http://127.0.0.1:1313" > ./wrapper/mc.txt
  printf '\t\t\t<a href="./%s" target = "center">%s</a><br>\n' mc.html MC >> ./wrapper/left_frame.htm
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
elif [[ -d $(find "$opscdiag" -mindepth 1 -maxdepth 1 -name '*artifacts*' -type d | head -1) ]]; then
  # Directly in the directory containing artifacts (Services ds-collector)
  echo "Detected services collector. Let's make a prayer together"
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
  slgrep
  diagviewer
  header
  nibblerpop
  sperfpop
  grepspop
  dvpop
  footer
  # need to revisit tarball generation. Too many issues at the moment
  # tarball
  browseropen
  montecristo
  converter
fi

if [[ "$debug" == "1" ]]; then 
  debuginfo
fi

popd > /dev/null
