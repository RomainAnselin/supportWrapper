#!/bin/bash

# Shameless steal of greps from https://github.com/StevenLacerda/greps/blob/master/greps_script.sh with partial rewrite
# Romain Anselin - DataStax - 17/08/2022

grep_file="slg/1-greps.out"
config_file="slg/1-config.out"
config_file_jvm="slg/1-jvm-params.out"
solr_file="slg/1-solr.out"
#sperf_file="Nibbler/1-sperf-statuslogger.out"
#diag_file="Nibbler/1-sperf-diag.out"
sixo="slg/1-sixo.out"
slschema="slg/1-schema.out"
warn="slg/3-warnings.out"
error="slg/3-errors.out"
threads="slg/1-threads.out"
slow_queries="slg/3-slow-queries.out"
gcs="slg/1-gcs.out"
tombstone_file="slg/2-tombstones.out"
histograms="slg/2-histograms.out"
drops="slg/2-drops.out"
queues="slg/2-queues.out"
iostat="slg/1-iostat"
large_partitions="slg/2-large_partitions.out"
backups="slg/2-backups"
hash_line="=========================================================================================================="

opscdiag=$2

#echo SL diag path "$opscdiag"

function logs() {
	sysdbgls=$(find $opscdiag -name 'system.*' -o -name 'debug.*' | grep -v zip)
}

function echo_request() {
	if [ -z $2 ]
	then
		file=$grep_file
	else
		file=$2
	fi
	echo >> $file
	echo $hash_line >> $file
	echo $1 >> $file
}

function config() {
	#echo "Inside config function"
	touch $config_file
	echo_request "YAML VALUES" $config_file

	for f in `find . -type f -name cassandra.yaml`;
	do
		echo $f | grep -o '[0-9].*[0-9]' >> $config_file
		grep -E -ih "^memtable_|^#.*memtable_.*:|^concurrent_|^commitlog_segment|^commitlog_total|^#.*commitlog_total.*:|^compaction_|^incremental_backups|^tpc_cores|^disk_access_mode|^file_cache_size_in_mb|^#.*file_cache_size_in_mb.*:" $f >> $config_file
		echo >> $config_file
	done

	for f in `find . -type f -name jvm*`;
	do
		echo $f | grep -o '[0-9].*[0-9]' >> $config_file_jvm
		grep -h "^[^#;]" $f | sed s/-XX://g >> $config_file_jvm
		echo >> $config_file_jvm
	done
}
# end config file section

function greps() {
	#echo "Inside greps function"
	#touch $warn
	#echo > $warn
	#touch $error
	#echo > $error
	# touch $threads
	# echo > $threads
	#touch $slow_queries
	#touch $tombstone_file
	#touch $histograms

	echo_request "DROPPED MESSAGES"
	grep -E -icR 'DroppedMessages.java' ./ --include={system,debug}* | grep -E ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	echo_request "POSSIBLE NETWORK ISSUES - unexpected exception during request"
	grep -ciR 'Unexpected exception during request' ./ --include={system,debug}* | grep -E ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	echo_request "HINTED HANDOFFS TO ENDPOINTS"
	grep -R 'Finished hinted handoff' ./ --include={system,debug}* | awk -F'endpoint' '{print $2}' | awk '{print $1}' | sort | uniq -c | sort >> $grep_file

	# echo_request "COMMIT-LOG-ALLOCATE FLUSHES - TODAY"
	# grep -E -ciR 'commit-log-allocator.*$today.*enqueuing' ./ --include={debug,output}* | sort -k 1 | awk -F':' '{print $1,$2}' | column -t >> $grep_file

	echo_request "FLUSHES BY THREAD - refer to https://datastax.jira.com/wiki/spaces/~41089967/pages/2660761722/Flushing+by+thread+type"
	grep -E -iRh 'enqueuing flush of' ./ --include={system,debug}* | awk -F']' '{print $1}' | awk -F'[' '{print $2}' | sed 's/:.*//g' | awk -F'(' '{print $1}' | awk -F'-' '{print $1}' | sort | uniq -c | sort >> $grep_file
	# echo_request "FLUSHES BY THREAD - TODAY"
	# grep -E -iRh '$today.*enqueuing flush of' ./ --include={system,debug}* | awk -F']' '{print $1}' | awk -F'[' '{print $2}' | sed 's/:.*//g' | sort | uniq -c >> $grep_file

	echo_request "LARGEST 20 FLUSHES"
	grep -E -iR 'enqueuing flush of' ./ --include={system,debug}* | awk -F'Enqueuing' '{print $2}' | awk -F':' '{print $2}' | column -t | sort -h | tail -20 >> $grep_file

	# echo_request "SMALLEST 10 FLUSHES"
	# grep -E -iR 'enqueuing flush of' ./ --include={system,debug}* | awk -F'Enqueuing' '{print $2}' | awk -F':' '{print $2}' | column -t | sort -h | head -10 >> $grep_file

	echo_request "FLUSHING LARGEST"
	echo "Any flushes larger than .9x" >> $grep_file
	grep -E -R "Flushing largest.*\.[8-9][0-9]" ./ --include=debug.log >> $grep_file

	# echo_request "AVERAGE FLUSH SIZE"
	# grep -E -iR 'enqueuing flush of' ./ --include={system,debug}* | awk -F'Enqueuing' '{print $2}' | awk -F':' '{print $2}' | column -t | awk 'BEGIN {p=1}; {for (i=1; i<=NF;i++) total = total+$i; p=p+1}; END {print sprintf("%.0f", total/p)}' | awk '{ byte =$1 /1024/1024; print byte " MB" }' >> $grep_file
	echo_request "TOTAL COMPACTIONS"
	grep -E -ciR 'Compacted' ./ --include={system,debug}* | sort -k 1 | grep -E ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	# echo_request "TOTAL COMPACTIONS IN LAST DAY"
	# grep -E -ciR '$today.*Compacted' ./ --include={system,debug}* | sort -k 1 >> $grep_file

	# shows the number of compactions by table
	# 34113 [ disk3 c_data srm ts_sample-a35ac480045811ebab44a71fdbae4c86
	echo_request "TABLES COMPACTED"
	grep -E -R "Compacted \(" ./ --include=debug.log | awk -F'sstables to ' '{print $2}' | awk -F',' '{print $1}' | sed 's/\// /g' | awk '{$NF=""; print $0}' | sort | uniq -c | sort -hr | head -10 >> $grep_file

	# measures the longest compactions times, not by node, just overall
	# [/disk3/c_data/srm/ts_sample-a35ac480045811ebab44a71fdbae4c86/nb-1882706-big,] 5,829,323ms
	echo_request "LONGEST COMPACTION TIMES"
	grep -E -R "Compacted \(" ./ --include=debug.log | grep -E -o "\[/.*?,.*[0-9]ms" | awk '{print $1,$(NF)}' | sort -h -k2 -r | head -20 >> $grep_file

	# measures the longest compaction times with node info
	# .//nodes/10.36.27.157/logs/cassandra/debug.log	5,829,323ms
	echo_request "LONGEST COMPACTION TIMES WITH NODE INFO"
	grep -E -R "Compacted \(" ./ --include=debug.log | grep -E -o ".*?,.*[0-9]ms"  | awk '{print $1,$NF}' | sed 's/:.* /\t/g' | sort -h -r -k2 | head -20 | sort -k2 -r -h | column -t >> $grep_file

	echo_request "RATE LIMITER APPLIED"
	echo "Usually means too many operations, check concurrent reads/writes in c*.yaml" >> $grep_file
	grep -E -R "RateLimiter.*currently applied" ./ --include={system,debug}* >> $grep_file

	echo_request "GC - OVER 100ms - COUNT"
	grep -E -ciR 'gcinspector.*[0-9]{3}ms' ./ --include={system,debug}* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	echo_request "GC - OVER 100ms TODAY - COUNT"
	grep -E -ciR '$(date +%Y-%m-%d).*gcinspector.*[0-9]{3}ms' ./ --include={system,debug}* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	echo_request "GC - GREATER THAN 1s - COUNT"
	grep -E -ciR 'gcinspector.*[0-9]{4}ms' ./ --include={system,debug}* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 >> $grep_file

	echo_request "GC - GREATER THAN 1s TODAY - COUNT"
	grep -E -ciR '$(date +%Y-%m-%d).*gcinspector.*[0-9]{4}ms' ./ --include={system,debug}* | awk -F':' '($2>0){print $1,$2,$3}' | sort -k 1 >> $grep_file

	echo_request "GC GREATER THAN 1s AND BEFORE"
	grep -E -iR -B 5 'gcinspector.*[0-9]{4}ms' ./ --include={system,debug}* >> $grep_file

	echo_request "SLOW QUERIES" $slow_queries
	grep -E -iR 'select.*slow' ./ --include={system,debug}* >> $slow_queries

	schema_file=$(find . -name schema | head -1)
	if [ ! -z "$schema_file" ]
	then
		echo_request "SSTABLE COUNT"
		grep -E -Rh -A 1 'Table:' ./ --include=cfstats | awk '{key=$0; getline; print key ", " $0;}' | sed 's/[(,=]//g' | awk '$5>30 {print $1,$2,$3,"\t",$4,$5}' | column -t >> $grep_file

		echo_request "PENDING TASKS"
		grep -iR '^- ' ./ --include=compactionstats >> $grep_file

		cp $schema_file $slschema
	fi

	echo_request "MERGED COMPACTIONS COUNT"
	grep -E -Ric 'Compacted (.*).*]' ./ --include={debug,system}* | grep -E ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	echo_request "MERGED COMPACTIONS"
	grep -E -R 'Compacted (.*).*]' ./ --include={debug,system}* | awk '$0 ~ /[0-9]{2,} sstables/{print $0}' >> $grep_file

	echo_request "MERGED COMPACTIONS - TODAY"
	grep -E -R '$today.*Compacted (.*).*]' ./ --include={debug,system}* | awk '$0 ~ /[0-9]{2,} sstables/{print $0}' >> $grep_file

	# echo_request "ALERT CLASSES"
	# grep -E -R 'WARN|ERROR' --include={system,debug}* ./ | awk -F']' '{print $1}' | awk -F[ '{print $2}' | sed 's/[0-9:#]//g' | sort | uniq -c >> $grep_file

	driver_file=$(find . -name driver | tail -1)
	if [ ! -z $driver_file ]
	then
		echo_request "REPAIRS"
		grep -E -iR 'Launching' ./ --include=opscenterd.log | grep -E -o '[0-9]{1,5}.*time to complete' | cut -d' ' -f5-60 | sort | uniq >> $grep_file

		echo_request "NTP"
		grep -E -iR 'time correct|exit status' ./ --include=ntpstat | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

		echo_request "LCS TABLES"
		grep -E -iRh "create table|and compaction" $driver_file --include=schema| grep -B1 "LeveledCompactionStrategy" >> $grep_file

		echo_request "KS REPLICATION I"
		echo "$driver_file" >> $grep_file
		grep -E -iR 'create keyspace' $driver_file --include=schema | cut -d ' ' -f 3-40 | awk -F'AND' '{print $1}' | column -t | sort -k8 >> $grep_file

		echo_request "KS REPLICATION II"
		grep -E -iR 'create keyspace' $driver_file --include=schema | cut -d ' ' -f 3-40 | awk -F'AND' '{print "ALTER KEYSPACE",$1}' | sort -k1 >> $grep_file
	fi

	echo_request "PREPARED STATEMENTS DISCARDED"
	grep -E -Rc "prepared statements discarded" ./ --include={system,debug}* | grep -E ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	echo_request "AGGREGATION QUERY USED WITHOUT PARTITION KEY"
	grep -E -ciR 'Aggregation query used without partition key' ./ --include={system,debug}* | grep -E ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $grep_file

	echo_request "CHUNK CACHE ALLOCATION"
	grep -E -ciR "Maximum memory usage reached.*cannot allocate chunk of" ./ --include={system,debug}* | grep -E ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t  >> $grep_file

	echo_request "ERRORS" $error
	grep -E -R "ERROR" ./ --include={system,debug}* >> $error

	echo_request "WARN" $warn
	grep -E -R "WARN" ./ --include={system,debug}* >> $warn

	# echo_request "THREADS" $threads
	# echo "All threads from system and debug logs" >> $threads
	# grep -E -R '.*' ./ --include={system,debug}* | awk -F'[' '{print $2}' | awk -F']' '{print $1}' | sed 's|:.*||g' | sed 's|[(#].*||g' | sed 's/Repair-Task.*/Repair-Task/g' | sort -k2 | uniq -c | sort -k1 -n -r >> $threads

	echo_request "DROPPED" $drops
	echo "All dropped messages (mutation, read, hint)" >> $drops
	grep -E -R "messages were dropped in last" ./ --include={system,debug}* >> $drops
}

function solr() {
	#echo "Inside solr function"
	is_solr_enabled=`grep -E "Search" ./Nibbler/Node_Status.out`
	if [ -z "$is_solr_enabled" ]
	then
		return 1
	fi

	#touch $solr_file
	echo "Solr greps" > $solr_file

	echo_request "SOLR DELETES" $solr_file
	grep -E -iRc 'ttl.*scheduler.*expired' ./ --include={system,debug}* | grep -E ":[1-9]" >> $solr_file

	h=`grep -E -iRh 'max_docs_per_batch' ./ --include=dse.yaml | head -1 | awk '{print $2}'`
	echo_request "SOLR DELETES HITTING $h THRESHOLD" $solr_file
	grep -E -icR "ttl.*scheduler.*expired.*$h" ./ --include={system,debug}* | grep -E ":[1-9]" >> $solr_file
	
	echo_request "SOLR AUTOCOMMIT" $solr_file
	grep -E -icR 'commitScheduler.*DocumentsWriter' ./ --include={system,debug}* | grep -E ":[1-9]" >> $solr_file

	echo_request "SOLR COMMITS BY CORE" $solr_file
	grep -E -iR 'AbstractSolrSecondaryIndex.*Executing soft commit' ./ --include={system,debug}* | awk '{print $1,$(NF)}' | sort | uniq -c >> $solr_file

	echo_request "COMMITSCHEDULER" $solr_file
	grep -E -Ri "index workpool.*Solrmetricseventlistener" ./ --include=debug.log | awk -F']' '{print $1}' | awk -F'Index' '{print $1}' | sort -h | uniq -c | sort -rh >> $solr_file

	echo_request "SOLR FLUSHES" $solr_file
	grep -E -iR 'Index WorkPool.Lucene flush' ./ --include={system,debug}* | awk -F'[' '{print $2}' | awk '{print $1}' | sort | uniq -c >> $solr_file

	echo_request "SOLR FLUSHES BY THREAD" $solr_file
	grep -E -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F']' '{print $1}' | awk -F'[' '{print $2}' | sed 's/:.*//g' | sed 's/[0-9]*//g' | sed 's/\-/ /g'|  sort | uniq -c | sort >> $solr_file

	echo_request "SOLR FLUSH SIZE" $solr_file
	echo "0 - 999kB" >> $solr_file
	grep -E -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F'flushed and' '{print $2}' | awk '($1>=0.0 && $1<1){print $1,$2}' | wc -l >> $solr_file
	echo "1MB - 9MB" >> $solr_file
	grep -E -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F'flushed and' '{print $2}' | awk '($1>=1 && $1<10){print $1,$2}' | wc -l >> $solr_file
	echo "10MB - 49MB" >> $solr_file
	grep -E -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F'flushed and' '{print $2}' | awk '($1>=10 && $1<50){print $1,$2}' | wc -l >> $solr_file
	echo "50MB - 249MB" >> $solr_file
	grep -E -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F'flushed and' '{print $2}' | awk '($1>=50 && $1<250){print $1,$2}' | wc -l >> $solr_file
	echo "250MB - 1G" >> $solr_file
	grep -E -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F'flushed and' '{print $2}' | awk '($1>=250 && $1<=1000){print $1,$2}' | wc -l >> $solr_file
	echo "1G plus" >> $solr_file
	grep -E -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F'flushed and' '{print $2}' | awk '($1>=1000){print $1,$2}' | wc -l >> $solr_file

	echo_request "LARGEST 5 SOLR FLUSHES" $solr_file
	grep -E -iR 'SolrMetricsEventListener.*Lucene flush' ./ --include={system,debug}* | awk -F'flushed and' '{print $2}' | awk '{print $1,$2}' | sort -r | head -5 >> $solr_file

	#flushing issues
	echo_request "FLUSHING FAILURES" $solr_file
	grep -E -iR "Failure to flush may cause excessive growth of Cassandra commit log" ./ --include={system,debug}* >> $solr_file

	echo_request "QUERY RESPONSE TIMEOUT" $solr_file
	grep -R "Query response timeout of" ./ --include={system,debug}* >> $solr_file

	echo_request "LUCENE MERGES" $solr_file
	echo "total lucene merges" >> $solr_file
	grep -ciR "Lucene merge" ./ --include={system,debug}* | grep -E ":[1-9]" >> $solr_file

	echo >> $solr_file
	echo "100ms - 249ms" >> $solr_file
	grep -R "Lucene merge" ./ --include={system,debug}* | awk -F'took' '{print $2}' | awk '($1>=0.100 && $1<0.250){print $1}' | wc -l >> $solr_file

	echo "250ms - 499ms" >> $solr_file
	grep -R "Lucene merge" ./ --include={system,debug}* | awk -F'took' '{print $2}' | awk '($1>=0.250 && $1<0.500){print $1}' | wc -l >> $solr_file

	echo "500ms - 999ms" >> $solr_file
	grep -R "Lucene merge" ./ --include={system,debug}* | awk -F'took' '{print $2}' | awk '($1>=0.500 && $1<1){print $1}' | wc -l >> $solr_file

	echo "1s plus" >> $solr_file
	grep -R "Lucene merge" ./ --include={system,debug}* | awk -F'took' '{print $2}' | awk '($1>=1){print $1}' | wc -l >> $solr_file

	# you see above there that NTR is kicking in.. glorified backpressure but not yet hitting backpressure just slowing down commit rate
	echo_request "INCREASING SOFT COMMIT RATE - Increasing commit rate before backpressure actually kicks in" >> $solr_file
	grep -E -iR "Increasing soft commit max time" ./ --include={system,debug}* >> $solr_file

	# filter cache eviction
	echo_request "FILTER CACHE EVICTION" $solr_file
	grep -E -iR "Evicting oldest entries" ./ --include={system,debug}* >> $solr_file

	# filter cache loading issue
	# In case Johnny mentioned , we don’t see fq getting used but
	# as token ranges use fq, that is still a fit.
	# high execute latency
	# Customer uses RF=N setup. In that setup there is a known problem in 5.1.12: DSP-19800
	# The scenario is as follows:
	# A node becomes unhealthy for some reason. May be even slightly unhealthy.
	# As a result it starts redirecting (coordinating)
	# queries to another nodes. In due process it needlessly
	# requests to use an internal token filter on remote nodes.
	# This filter is not available, as it is normally not used in
	# RF=N configurations and must be loaded. Loading may take many
	# minutes on large indexes. As a result all these queries time out.
	echo >> $solr_file
	echo "execute latency" >> $solr_file
	grep -R "minutes because higher than" ./ --include={system,debug}* >> $solr_file
}

function sixO() {
	#echo "Inside sixO function"
	touch $sixo
	echo "6.x Specific greps" > $sixo

	echo_request "TOO MANY PENDING REQUESTS" $sixo
	grep -E -ciR 'Too many pending remote requests' ./ --include={system,debug}* >> $sixo

	echo_request "BACKPRESSURE REJECTION" $sixo
	grep -E -R 'Backpressure rejection while receiving' ./ --include={system,debug}* | cut -d '/' -f 1|uniq -c >> $sixo

	echo_request "TIMED OUT ASYNC READS" $sixo
	grep -E -ciR 'Timed out async read from org.apache.cassandra.io.sstable.format.AsyncPartitionReader' ./ --include={system,debug}* >> $sixo

	echo_request "WRITES.WRITE ERRORS" $sixo
	grep -E -ciR 'Unexpected error during execution of request WRITES.WRITE' ./ --include={system,debug}* >> $sixo

	echo_request "WRITES.WRITE BACKPRESSURE" $sixo
	grep -E -ciR 'backpressure rejection.*WRITES.WRITE' ./ --include={system,debug}* >> $sixo

	echo_request "READS.READ BACKPRESSURE" $sixo
	grep -E -ciR 'backpressure rejection.*READS.READ' ./ --include={system,debug}* >> $sixo

	echo_request "READS.READ ERRORS" $sixo
	grep -E -ciR 'Unexpected error during execution of request READS.READ' ./ --include={system,debug}* >> $sixo

	echo_request 'THREADS WITH PENDING' $sixo
	echo "threads with higher than 0 pending threads" >> $sixo
	grep -E -R "TPC/" ./ --include=debug.log | awk '{print $1,$3}' | sort | uniq | column -t | awk '!/N\/A/ && !/0$/' >> $sixo
}

function tombstones() {
	#echo "Inside tombstones function"
	echo_request "TOMBSTONE TABLES" $tombstone_file
	grep -E -iRh 'tombstone.*rows' ./ --include={system,debug}* | awk -F'FROM' '{print $2}' | awk -F'WHERE' '{print $1}' | sort | uniq -c | sort -nr >> $tombstone_file

	echo_request "TOMBSTONE MAX COUNT BY TABLE - max number of tombstones hit on a given query" $tombstone_file
	grep -E -iRh 'tombstone' ./ --include={system,debug}*  | grep -io 'scanned over.*\|rows and.*' | awk '{$1=$2="";print $0}' | sed 's/tombstone.*FROM//g' | awk '{print $1,$2}' | sort -nrk1 | sort -u -k2 >> $tombstone_file

	echo_request "TOMBSTONE ALERTS BY NODE - number of tombstone alerts, not max hit on a given query, but overall number of alerts in diag" $tombstone_file
	grep -E -ciR 'tombstone' ./ --include={system,debug}* | grep -E ":[1-9]" | awk -F: '{print $1,$2}' | sort -k2 -r -h | column -t >> $tombstone_file

	echo_request "TOMBSTONE QUERY ABORTS BY TABLE - max threshold hit, so query aborted" $tombstone_file
	grep -E -iRh 'tombstone' ./ --include={system,debug}* | grep "aborted" | awk '{for (I=1;I<NF;I++) if ($I == "FROM") print $(I+1)}' | sort | uniq -c >> $tombstone_file

	echo_request "TOMBSTONE PARTITIONS - number of times partition hit" $tombstone_file
	grep -E -iR "tombstone.*for" ./ --include={system.log,debug.log} | awk -F'FROM' '{print $2}' | awk -F'LIMIT' '{print $1}' | sort | uniq -c >> $tombstone_file
}

function histograms_and_queues() {
	#echo "Inside histograms_and_queue function"
	echo_request "CFHistograms > 1s" $histograms
	grep -E -iR "histograms" -A 9 ./ --include={cfhistograms,commands.txt} | grep -E "Max.*[0-9]{7,}\." -B 9 >> $histograms

	echo_request "Proxyhistograms > 1s" $histograms
	grep -E -iR "histograms" -A 9 ./ --include={proxyhistograms,commands.txt} | grep -E "Max.*[0-9]{7,}\." -B 9 >> $histograms

	echo_request "Latency waiting in Queue" $queues
	echo "Track if a queue is high from tpstats. We're looking for anything over 300ms" >> $queues
	echo "                                Message type           Dropped                  Latency waiting in queue (micros)
                                                                                50%               95%               99%               Max" >> $queues
	echo "" >> $queues
	grep -E -R "Latency waiting in queue" -A 20 ./ --include=tpstats | grep -E ".*[3-9][0-9]{5,}\." >> $queues
}

function backups() {
	touch $backups

	# 1)To check all type of backups that ran(onserver or local or s3)
	echo_request "CHECK ALL TYPES OF BACKUPS (ONSERVER, LOCAL, OR S3)" $backups
	grep -iR "Backup Service beginning synchronization" ./ --include=agent.log >> $backups

	# 2)Grep to check when the local file backups are running
	echo_request "CHECK WHEN LOCAL FILE BACKUPS ARE RUNNING" $backups
	grep -iR "Backup service synchronizing snapshot to" ./ --include=agent.log >> $backups

	# 3)To check when onserver backup tags are removed
	echo_request "CHECK WHEN ON SERVER BACKUP TAGS ARE REMOVED" $backups
	grep -iwR "Removing on server backups" ./ --include=agent.log |grep -v "Removing on server backups: ()" >> $backups

	# 4)To check when the localfile backup tag is removed
	echo_request "CHECK WHEN LOCALFILE BACKUP TAG IS REMOVED" $backups
	grep -iwR "Successfully removed backup" ./ --include=agent.log >> $backups
	grep -iR "Removing tag" ./ --include=agent.log >> $backups

	# scheduled backup successful
	echo_request "BACKUPS SUCCESSFUL" $backups
	grep -iR "backup of all keyspaces was successful" ./ --include=opscenterd.log >> $backups

	echo_request "BACKUPS OF ALL KEYSPACES FAILED" $backups
	grep -iR "backup of all keyspaces failed" ./ --include=opscenterd.log >> $backups

	echo_request "STARTING SCHEDULED BACKUP" $backups
	grep -iR "starting scheduled backup job" ./ --include=opscenterd.log >> $backups
}

function find_large_partitions() {
	#echo "Inside large_partitions function"
	touch $large_partitions
	echo_request "READING LARGE PARTITIONS" $large_partitions
	grep -E -iwR "Detected partition.*is greater than" --include={system,debug}* | cut -f1,7-25| awk '{if ($11~/GB$/) print $0}' > $large_partitions
	echo_request "WRITING LARGE PARTITIONS" $large_partitions
	grep -E -iwR "writing large partition" --include={system,debug}* | cut -f1,7-25| awk '{if ($11~/GB$/) print $0}' > $large_partitions
}

function iostat() {
	i=0
	for f in `find ./ -name iostat`;
		do
			if [ $i -eq 0 ]
			then
				touch $iostat
				echo > $iostat
			fi
			i=1
			echo $f >> $iostat
			sperf sysbottle $f >> $iostat
		done
}

############### EXEC ###############
usage() {
  if [ $# -ne 1 ]; then
    echo "Usage: $0 [-c] [-g] [-s] [-6] [-t] [-q] [-b] [-i] [-l] [-h] [-h] <Path to Opscenter diag>"
	echo "  -c	Config check"
	echo "  -g	General greps"
    echo "  -s 	Solr greps"
    echo "  -6 	DSE 6.x greps"
	echo "  -t	Tombstones greps"
	echo "  -q	Histograms and queues greps"
	echo "  -b	Backups info"
	echo "  -i	iostat sperf"
	echo "  -l	large partitions"
    echo "  -h  show this help"
    exit 1
  fi
}

### Let's begin
syslog=$( find $opscdiag -name "system.*" )
dbglog=$( find $opscdiag -name "debug.*" )

while getopts "cgs6tqbilah" option; do
  case "${option}" in
    c) echo "Config check"
       configv=1 ;;
    g) echo "General greps"
       grepsv=1 ;;
    s) echo "Solr greps"
       solrv=1 ;;
    6) echo "6.0 greps"
       sixOv=1 ;;
    t) echo "Tombstones greps"
       tombstonesv=1 ;;
    q) echo "Histograms and queues greps"
       histograms_and_queuesv=1 ;;
    b) echo "Backups info"
       backupsv=1 ;;
    i) echo "iostat sperf"
       iostatv=1 ;;
    l) echo "large partitions"
       find_large_partitionsv=1 ;;
	a) echo "run all"
	   configv=1 ;
	   grepsv=1 ;
	   solrv=1 ;
	   sixOv=1 ;
	   tombstonesv=1 ;
	   histograms_and_queuesv=1 ;
	   backupsv=1 ;
	   iostatv=1 ;
	   find_large_partitionsv=1 ;;
    h) echo "Showing help"
       usage ;;
  esac
done

if [[ $configv == 1 ]]; then config; fi
if [[ $grepsv == 1 ]]; then greps; fi
if [[ $solrv == 1 ]]; then solr; fi
if [[ $six0v == 1 ]]; then six0; fi
if [[ $tombstonesv == 1 ]]; then tombstones; fi
if [[ $histograms_and_queuesv == 1 ]]; then histograms_and_queues; fi
if [[ $backupsv == 1 ]]; then backups; fi
if [[ $iostatv == 1 ]]; then iostat; fi
if [[ $find_large_partitions == 1 ]]; then find_large_partitions; fi
