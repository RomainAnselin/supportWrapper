Getting started

# Known issues:
- sperf will fail to run on version 0.5.x - please update to a more recent version (tested against 0.6.5 and 0.6.6)

# TO DO:
Ongoing:
- Make opening wrapped info in new window a choice
- Source config info from separate file
Todo:
- For sperf solr, add an input parameter
- Test vs OSS diag collector
- Text wrapping makes it hard to read but cannot be solved in current HTML frames. Refactor to HTML5 may be necessary
- Set nibbler in silent mode (current view help see parsing issues) - to be discussed with Mike/Chun?

# For beta/debugging:
- while still implementing and making sure it can run on WSL, Mac and Linux seamlessly, in case of issue, please
1. `rm -r <path to diag>/wrapper`
2. switch `debug=1` in `wrap.sh`
If more info is required, please provide:
`bash -xv <path>/wrap.sh <path to diag>`
ie: `bash -xv ~/dev/supportWrapper/wrap.sh ./diagnostics\ \(1\) > ~/wrapper.log  2>&1`

# Prerequisites:
In `wrap.sh`, change the following variables to fit your environment.
All of them are self explanatory.
Path to java for Nibbler, path to Python 3 for sperf + location of the tools...
Also define your favorite web browser (firefox, chrome, edge...)

```
# WARNING: If your path contains spaces/brackets, put the variable in double quotes.
# ie: nibblerpath="/mnt/c/Users/My User/Nibbler.jar"
# browser="/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
browser=firefox
javapath=/usr/lib/jvm/liberica-jdk8u265-full/jre/bin/java
nibblerpath=~/tools/Nibbler.jar
pythonpath=~/dev/virtualenvs/py3/bin/python
sperfpath=~/tools/sperf/scripts/sperf
```

1- Validate functionality of the tool without alias:
`<path>/wrap.sh <path to diag>`

Create an alias for supportWrapper after validation by adding the following to your `bashrc`.
ie: `alias swrap='~/supportWrapper/wrap.sh'`
Run `swrap <path to opsc diag>`

The script can be executed from one or two levels above the nodes folder of the diag. As I use ssdownloader, I prefer to use the "top" level of the diag, but both can be used.

A folder called "wrapper" is created in the working dir (the diag folder choosen), which contains the sperf output as well as the html.

Below a sample of the execution result.

```
(py3) [2020-10-16 18:24:01] romain@datastax:~
$ ls -ltr "/home/romain/zd/customer/<zdid>/diagnostics (3)"
total 12
drwxrwxr-x 4 romain romain 4096 Oct 12 11:12 my-diagnostics-2020_10_12_09_04_56_UTC

(py3) [2020-10-16 18:16:32] romain@romainDSE:~/dev/wrapperOneTool
$ wrap.sh "/home/romain/zd/customer/<zdid>/diagnostics (3)"
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
- Implement debug - (in progress)
- Opening the web browser from WSL is challenging at best. Need to detect windows and output file location for windows without executing the browser
- Simplify opscdiag/opscpath/subdiag kerfuffle to make the code easier to read
