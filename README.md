Getting started

Prerequisites:
In `wrap.sh`, change the following variables to fit your environment.
All of them are self explanatory.
Path to java for Nibbler, path to Python 3 for sperf + location of the tools...
Also define your favorite web browser (firefox or chrome)

```
browser=firefox
javapath=/usr/lib/jvm/liberica-jdk8u265-full/jre/bin/java
nibblerpath=~/tools/Nibbler.jar
pythonpath=/home/romain/dev/virtualenvs/py3/bin/python
sperf=~/tools/sperf/scripts/sperf
```

Create an alias from supportWrapper. ie: `alias swrap='~/supportWrapper/wrap.sh'`
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
