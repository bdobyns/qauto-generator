#!/bin/bash 
set -e
# context,objectType,query,articleType,granularTopic,broadTopic,date,startPage,pageLength,sortBy,showFacets,journal,showResult,logmsg
# catalyst,catalyst-article,value,Article,Value-Based Care,Alternative Payment Models (APM),past10Years,1,100,relevance,Y,carryover,short,COM-5818_automation test
PS4='$LINENO: '

echo "context,objectType,query,articleType,granularTopic,broadTopic,date,startPage,pageLength,sortBy,showFacets,journal,showResult,logmsg"

# context and objectType are fixed
CONTEXT=catalyst
OBJECTTYPE=catalyst-article
LOGMSG=QAUTO-5818-generated
BTCOUNT=2  # how many of each broad topic to select each time
MINCOUNT=2
TMPFILE=/tmp/$( basename $0 .sh).$$
GTTEMP=/tmp/gt-$( basename $0 .sh).$$
ENDPOINT=simple
QNAME=query

# ------ ARGUMENT PROCESSING ----------------------------------------

while getopts i:h:u:k:qas opt 
do
    case "$opt" in
	i)  INPUTFILE="$OPTARG" ;;
	h)  HOST="$OPTARG" ;;
	k)  APIKEY="$OPTARG" ;;
	u)  APIUSER="$OPTARG" ;;
	q)  QUOTES=noquotes ;;

	a)  ENDPOINT=advanced
	    QNAME=allwords ;;
	s)  ENDPOINT=simple
	    QNAME=query ;;
    esac
done

if [ -z $INPUTFILE ] ; then
    echo ERROR you must give a filename of the csv -i filename
    exit 1
elif [ ! -e $INPUTFILE ] ; then
    echo ERROR "'$INPUTFILE'" does not exist so, bummer.
    exit 2
elif [ -z $HOST ] ; then
    echo ERROR you must specify a hostname -h hostname
    exit 3
elif [ -k $APIKEY ] ; then
    echo ERROR you must specify an API Key -k apikey
    exit 4
elif [ -u $APIUSER ] ; then
    echo ERROR you must specify an API User -u apiuser
    exit 5
fi

# ----- METHODS --------------------------------------------------

sortBy() {
    COUNT=$1
    CMOD=$[ $COUNT % 8 ]
    case $CMOD  in
	0) echo relevance ;;
	1) echo Most+Relevant ;;
	2) echo Latest ;;
	3) echo pubdate-descending ;;
	4) echo Oldest ;;
	5) echo pubdate-ascending ;;
	6) echo citedByCount-descending ;;
	7) echo Most+Cited ;;
    esac
}

# ----- MAIN LOOP --------------------------------------------------

# start of the main loop
COUNT=0
# this gets all the labels, values, semantic codes out of the granularTopic json
cat $INPUTFILE | tr -d '{"[}],' | cut -d : -f 2 | sed -e '/^ *$/d' -e 's/^ //' | tr ' ' '+' >$GTTEMP
( echo cat-gt-004 ; grep ^cat $GTTEMP ; grep -v ^cat $GTTEMP ) | while read GRANULARTOPIC
do
  # check in both the catalyst and carryover journals.  we don't really care about the cat-non-issue and viewpoints
  for JOURNAL in catalyst cat-non-issue viewpoints carryover ""
  do
      # we loop thru article types here because we want to find just one that works, not the combinatorial of all the types
      TYPES=$( echo Article ; shuf -e Review+Article Clip Talk Conversation From+the+Editors Brief+Article In+Depth Case+Study Insights+Report Insights+Interview Survey+Snapshot Article )
      for ARTICLETYPE in  $TYPES
      do
	COUNT=$[ $COUNT + 1 ]
       for DATEARG in $( shuf -e past5Years past10Years "" )
       do
       for QUERY in $( shuf -e medicare system health care value "" )
       do
	# actually make a call to get the facets
	curl -H 'accept: application/json' -H 'apikey: 2A330F24-889C-4B9D-82C9-BE891CC2D60C'  -H 'apiuser: onesearch_tests_run' -s -m 60 -X 'GET' \
	     'https://onesearch-api.nejmgroup-qa.org/api/v1/'$ENDPOINT'?context='$CONTEXT'&objectType='$OBJECTTYPE'&'$QNAME'='$QUERY'&articleType='$ARTICLETYPE'&granularTopic='$GRANULARTOPIC'&date='$DATEARG'&journal='$JOURNAL'&showFacets=y' >$TMPFILE

	# ignore combinations that give us no results for the articleType / granularTopic / journal combination
	TOTAL=$( cat $TMPFILE | jq .total | sed -e 's/"//' )
	if [ $TOTAL == null ] ; then 
	    echo curl -H 'accept: application/json' -H 'apikey: 2A330F24-889C-4B9D-82C9-BE891CC2D60C'  -H 'apiuser: onesearch_tests_run' -s -m 60 -X 'GET' \
		 'https://onesearch-api.nejmgroup-qa.org/api/v1/'$ENDPOINT'?context='$CONTEXT'&objectType='$OBJECTTYPE'&'$QNAME'='$QUERY'&articleType='$ARTICLETYPE'&granularTopic='$GRANULARTOPIC'&date='$DATEARG'&journal='$JOURNAL'&showFacets=y' >&2
	    cat >&2 $TMPFILE ; echo "" >&2
	    continue
	elif [ $TOTAL -le $MINCOUNT ] ; then
	    continue
	else
	    break 3 # total > $MINCOUNT
	fi
       done # query
       done # datearg
      done # articleType exits with total > $MINCOUNT if we found one

      # don't bother if we didn't find one with a non-zero total
      if [ $TOTAL -le $MINCOUNT ] ; then continue ; fi

      # extract the broad topics from the facets
      # but the shuf limits how many we pick, and makes sure we pick randomly
      cat $TMPFILE | jq .facets.broadTopic.facetValues | sed -e /count/d |  tr -d '{"[}],' | cut -d : -f 2 | sed -e '/^ *$/d' -e 's/^ //' | tr ' ' + | shuf -n $BTCOUNT | while read BROADTOPIC
      do
	  SORTBY=$( sortBy $COUNT )
	  echo '"'$CONTEXT'","'$OBJECTTYPE'","'$QUERY'","'$ARTICLETYPE'","'$GRANULARTOPIC'","'$BROADTOPIC'","'$DATEARG'",1,100,"'$SORTBY'","Y","'$JOURNAL'","short","'$LOGMSG"-no-"$COUNT"-total-"$TOTAL'"'

	  # also output the same line with Article since that's almost certain to work too 
	#  if [ $ARTICLETYPE != Article ] ; then 
	#       ARTICLETYPE=Article
	#	echo '"'$CONTEXT'","'$OBJECTTYPE'","'$QUERY'","'$ARTICLETYPE'","'$GRANULARTOPIC'","'$BROADTOPIC'","'$DATEARG'",1,100,"'$SORTBY'","Y","'$JOURNAL'","short","'$LOGMSG"-total-"$TOTAL'"'
	#  fi
      done # end of each broadTopic for a particular granularTopic
  done # journal
done # granularTopic

dateArg() {
    COUNT=$1
    CMOD=$[ $COUNT % 3 ]
    case $CMOD in
#	0) echo pastYear ;;
	0) echo "" ;;
	1) echo past5Years ;;
	*) echo past10Years ;;
    esac
}

query() {
    COUNT=$1
    CMOD=$[ $COUNT % 3 ]
    case $CMOD in
#	0) echo pastYear ;;
	1) echo health ;;
	0) echo value ;;
	*) echo "" ;;
    esac
}

articleType() {
    COUNT=$1
    CMOD=$[ $COUNT % 11 ]
    case $CMOD in
	*) echo Article ;;
	1) echo Review+Article ;;
	2) echo Clip ;;
	3) echo Talk ;;
	4) echo Conversation ;;
	5) echo From+the+Editors ;;
	6) echo Brief+Article ;;
	7) echo In+Depth Case+Study ;;
	8) echo Insights+Report ;;
	9) echo Insights+Interview ;;
	10) echo Survey+Snapshot ;;
    esac
}

