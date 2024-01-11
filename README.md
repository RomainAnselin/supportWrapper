Getting started
# Pre-requisites
The tool uses python markdown converter. Make sure to add the module to your main python

# Known issues:
- sperf will fail to run on version 0.5.x - please update to a more recent version (tested against 0.6.5 and 0.6.6)

# TO DO:
- Text wrapping makes it hard to read but cannot be solved in current HTML frames. Refactor to HTML5 may be necessary
- Set nibbler in silent mode (current view help see parsing issues) - to be discussed with Mike/Chun?

# Updating

1- In newer versions, configuration file has been isolated
2- New parameter with ability to choose if the report should be opened in new window

```
# Open the result in a separate window
newwindow=1
```

3- the wrapper now takes 3 options:
`-s` -> add 2 Solr sperf commands
`-p` -> per node view for GC and StatusLogger (as opposed to global. Takes more time and CPU)
`-h` -> basic help menu
ie: `wrap.sh -s -p <diag>`
To update:
1- *backup your config parameters from the shell script*
2- git pull in your wrapper folder
3- copy your config params in the conf file

# For beta/debugging:
- while still implementing and making sure it can run on WSL, Mac and Linux seamlessly, in case of issue, please
1. `rm -r <path to diag>/wrapper`
2. switch `debug=1` in `wrap.sh`
If more info is required, please provide:
`bash -xv <path>/wrap.sh <path to diag>`
ie: `bash -xv ~/dev/supportWrapper/wrap.sh ./diagnostics\ \(1\) > ~/wrapper.log  2>&1`

# Prerequisites:
In `wrap.conf`, change the following variables to fit your environment.
All of them are self explanatory:
Path to java for Nibbler, path to Python 3 for sperf (optional if using sperf binaries), location sperf and nibbler tools
Also define your favorite web browser (firefox, chrome, edge...)
Added DV + Sperf

```
# WARNING: If your path contains spaces/brackets (ie: Windows), put the variable in double quotes.
# ie: nibblerpath="/mnt/c/Users/My User/Nibbler.jar"
# browser="/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
browser=firefox
# Nibbler env
javapath=/usr/lib/jvm/jdk8u352-full/jre/bin/java
nibblerpath=$HOME/dev/projects/Nibbler/out/artifacts/Nibbler_jar/Nibbler.jar
# Sperf env
pythonpath=$HOME/anaconda3/envs/ctool/bin/python
sperfpath=$HOME/tools/sperf0617/sperf/scripts/sperf
# Steve Lacerda greps embedded in supportWrapper
grepsl=$HOME/dev/supportWrapper/grepsl.sh
# Open the result in a separate window
newwindow=1

## Optional
# DiagViewer env
dvpy=$HOME/anaconda3/envs/jbdiag/bin/python3
dvpath=$HOME/tools/diag-viewer
# MonteCristo env
jvmh=/usr/lib/jvm/jdk8u352-full
mcpath=$HOME/tools/montecristo
```

# How it works:

1- Validate functionality of the tool without alias:
`<path>/wrap.sh <path to diag>`

Create an alias for supportWrapper after validation by adding the following to your `bashrc`.
ie: `alias swrap='~/supportWrapper/wrap.sh'`
Run `swrap <path to opsc diag>`

The script can be executed from one or two levels above the nodes folder of the diag. As I use ssdownloader, I prefer to use the "top" level of the diag, but both can be used.

```wrap -h                                                   INT ✘ 
Showing help
Usage: /home/romain/dev/supportWrapper/wrap.sh [-s] [-p] [-g] [-d] [-m {tar.gz}] [-t {ticketid}] [-h] <Path to Opscenter diag>
  -s            solr data
  -p            GC per node
  -g            greps script
  -d            Diag Viewer db creation
  -m {tar.gz}   MonteCristo Services diag execution
  -t {ticketid} Ticket number. Necessary for Montecristo
  -h   show this help
```

A folder called "wrapper" is created in the working dir (the diag folder choosen), which contains the sperf output as well as the html.

Below a sample of the execution result.

```
(py3) [2020-10-16 18:24:01] romain@datastax:~
$ ls -ltr "/home/romain/zd/customer/<zdid>/diagnostics (3)"
total 12
drwxrwxr-x 4 romain romain 4096 Oct 12 11:12 my-diagnostics-2020_10_12_09_04_56_UTC

(py3) [2020-10-16 18:16:32] romain@romainDSE:~/dev/supportWrapper
$ wrap.sh -s -p -g -t 1234 -m <compressed_diag.tar.gz> "clustername_diagnostics_date"
Nibbler running

Nibbler v3.0.2 is Started from CLI

   *** Step 1/4 - Initiating Nibbler
                  Started
                  Completed
       Execution Time: 1 milliseconds

   *** Step 2/4 - Reading OPSC Diag
                  Started
                  Completed
       Execution Time: 3223 milliseconds

   *** Step 3/4 - Analysing OPSC Diag
                  Started
                  Completed
       Execution Time: 21 milliseconds

   *** Step 4/4 - Outputting Analyzed Result
                  Started
                     - Outputting Analyzed Result to Files
                       Started
                          ** Saving Nibbler output files to: /home/romain/customer/<zdid>/diagnostics (3)/Nibbler/
                       Completed
                       Execution Time: 3 milliseconds
                  Completed

Total Execution time in Milliseconds:            3248 - 100.00%
      -- Initiating Time in Milliseconds:        1 - 0.03%
      -- Read OPSC Diag Time in Milliseconds:    3223 - 99.23%
      -- Analyze OPSC Diag time in Milliseconds: 21 - 0.65%
      -- Terminal Output time in Milliseconds:   0 - 0.00%
      -- File Output time in Milliseconds:       3 - 0.09%

Sperf summary
Sperf GC analysis
Sperf StatusLogger
Sperf Slow Query
Sperf Schema
```

# Fixed issues
- Handling of relative path
- Implement debug
- Opening the web browser from WSL is challenging at best. Need to detect windows and output file location for windows without executing the browser
- Simplify opscdiag/opscpath/subdiag kerfuffle to make the code easier to read

- Make opening wrapped info in new window a choice
- Source config info from separate file
- For sperf solr, add an input parameter

# 04/05/2022
- Parallelized sperf commands execution in the background
- Test vs OSS diag collector

# 19/07/2023
- MonteCristo and DiagViewer added to conf file

# 04/01/2024
- Removed the web server startup from mc and added an md to html converter