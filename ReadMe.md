# barry-qauto-5818-data-generator.sh

* generates csv lines that ought to work with the qa automation test qauto-5818
* it takes as arguments -h -u -k just like the acceptance test (so you can use $DEVCREDENTIALS the same way)
* it also takes -i filename to get granularTopics.json
* it takes -a or -s to use /advanced or /simple search
* barry-qauto-5818-data-generator.sh $DEVCREDENTIALS -i granularTopics.json | tee filename.csv 

# barry-qauto-5818-runner.sh

* takes the same arguments, but processes a csv file to make sure it works.
* barry-qauto-5818-runner.sh $DEVCREDENTIALS -i filename.csv | tee filtered.csv
