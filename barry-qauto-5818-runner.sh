#!/bin/bash
# a simple script to consume the output of qauto-5815-data-generator.sh

PS4='$LINENO: '
TMPFILE=/tmp/$( basename $0 .sh).$$
DEBUGGING=0
COUNT=0
INPUTFILE=granularTopic.json
QUOTES=quotes
ENDPOINT=simple
QNAME=query
VERBOSE=0
CAT=cat

# ------ ARGUMENT PROCESSING ----------------------------------------

while getopts i:h:u:k:vqaswQ:f opt 
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
	w)  ENDPOINT=advanced
	    QNAME=withoutTheWords ;;
	Q)  QVALUES="$OPTARG" ;;
	v)  VERBOSE=1;;
	f)  CAT="tail -f"
    esac
done

if [ -z $INPUTFILE ] ; then
    echo ERROR you must give a filename of the csv -i filename
    exit 1
elif [ $INPUTFILE != - ] && [ ! -e $INPUTFILE ] ; then
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

# ----- MAIN LOOP --------------------------------------------------

$CAT "$INPUTFILE" | tr '",' ' '| while read CONTEXT OBJECTTYPE QUERY ARTICLETYPE GRANULARTOPIC BROADTOPIC DATEARG STARTPAGE PAGELENGTH SORTBY SHOWFACETS JOURNAL SHOWRESULT LOGMSG
do
  if [ $COUNT -eq 0 ] ; then # skip line 0 header line
      if [ $QUOTES == quotes ] ; then
	  echo '"'$CONTEXT'","'$OBJECTTYPE'","'$QUERY'","'$ARTICLETYPE'","'$GRANULARTOPIC'","'$BROADTOPIC'","'$DATEARG'","'$STARTPAGE','$PAGELENGTH',"'$SORTBY'","'$SHOWFACETS'","'$JOURNAL'","'$SHOWRESULT'","'$LOGMSG'"'
      else
	  echo $CONTEXT','$OBJECTTYPE','$QUERY','$ARTICLETYPE','$GRANULARTOPIC','$BROADTOPIC','$DATEARG','$STARTPAGE','$PAGELENGTH','$SORTBY','$SHOWFACETS','$JOURNAL','$SHOWRESULT','$LOGMSG
      fi
  else
    curl -H 'accept: application/json' -H 'apikey: '$APIKEY  -H 'apiuser: '$APIUSER -s -m 60 -X 'GET' \
	 'https://'$HOST'/api/v1/'$ENDPOINT'?context='$CONTEXT'&objectType='$OBJECTTYPE'&'$QNAME'='$QUERY'&articleType='$ARTICLETYPE'&granularTopic='$GRANULARTOPIC'&date='$DATEARG'&journal='$JOURNAL'&showFacets='$SHOWFACETS'&startPage='$STARTPAGE'&pageLength='$PAGELENGTH'&logMsg='$LOGMSG >$TMPFILE
    TOTAL=$( cat $TMPFILE | jq .total | sed -e 's/"//' )
    if [ -z $TOTAL ] || [ $TOTAL == null ] ; then 
	if [ $DEBUGGING -eq 1 ] ; then
	    echo curl -H 'accept: application/json' -H 'apikey: 2A330F24-889C-4B9D-82C9-BE891CC2D60C'  -H 'apiuser: onesearch_tests_run' -s -m 60 -X 'GET' \
		 'https://onesearch-api.nejmgroup-qa.org/api/v1/'$ENDPOINT'?context='$CONTEXT'&objectType='$OBJECTTYPE'&'$QNAME'='$QUERY'&articleType='$ARTICLETYPE'&granularTopic='$GRANULARTOPIC'&date='$DATEARG'&journal='$JOURNAL'&showFacets='$SHOWFACETS'&startPage='$STARTPAGE'&pageLength='$PAGELENGTH'&logMsg='$LOGMSG >$TMPFILE
	    cat >&2 $TMPFILE ; echo "" >&2
	else
	    if [ $VERBOSE -eq 1 ] ; then echo FAILED >&2 $CONTEXT $OBJECTTYPE $QUERY $ARTICLETYPE $GRANULARTOPIC $BROADTOPIC $DATEARG $STARTPAGE $PAGELENGTH $SORTBY $SHOWFACETS $JOURNAL $SHOWRESULT $LOGMSG ; fi
	fi
	    
    elif [ $TOTAL -eq 0 ] ; then
	    if [ $VERBOSE -eq 1 ] ; then echo FAILED >&2 $CONTEXT $OBJECTTYPE $QUERY $ARTICLETYPE $GRANULARTOPIC $BROADTOPIC $DATEARG $STARTPAGE $PAGELENGTH $SORTBY $SHOWFACETS $JOURNAL $SHOWRESULT $LOGMSG ; fi
    else
      if [ $QUOTES == quotes ] ; then
	  echo '"'$CONTEXT'","'$OBJECTTYPE'","'$QUERY'","'$ARTICLETYPE'","'$GRANULARTOPIC'","'$BROADTOPIC'","'$DATEARG'","'$STARTPAGE','$PAGELENGTH',"'$SORTBY'","'$SHOWFACETS'","'$JOURNAL'","'$SHOWRESULT'","'$LOGMSG'"'
      else
	  echo $CONTEXT','$OBJECTTYPE','$QUERY','$ARTICLETYPE','$GRANULARTOPIC','$BROADTOPIC','$DATEARG','$STARTPAGE','$PAGELENGTH','$SORTBY','$SHOWFACETS','$JOURNAL','$SHOWRESULT','$LOGMSG
      fi
    fi
  fi
  COUNT=$[ $COUNT + 1 ]
done
