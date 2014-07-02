#!/bin/bash
# Splunk Export script that will use the Splunk API to perform and export searches.
# Created By: Jeremy Davis
# Version: 1.0.0
OPTION='null'
DISPATCHSTATE='null'

## Obtain the first argument to determine what to run.
case "$1" in
    --help)
        echo "To perform a new search either provide no options or: --search."
        echo "To export an existing job use: --export"
        ;;
    --search)
        OPTION='search'
        ;;
    --export)
        OPTION='export'
        JOBSTATUS='RUNNING'
        ;;
    *)
        OPTION='search'
esac

## Obtain the username, password, and search query and assign it to variables.
clear
echo "Enter LDAP Username:"
read USERNAME
clear
echo "Enter Password:"
read -s PASSWD
if [ "$OPTION" = "search" ]
    then
    clear
    echo "Enter Splunk Search Query:"
    echo "NOTE: Make sure you limit the search as this will pull all logs and could take some time."
    read QUERY
fi
clear
echo "Enter Search Name:"
echo "NOTE: This name will be used to store the exported logs from Splunk under /tmp/ and be used as the Job ID. Output will be in csv format."
read FILENAME
clear

## Display what we are about to do.
echo "Your username: $USERNAME"
echo "Your Query: $QUERY"
echo "Your Query Name/Filename: $FILENAME"

## If the option is set to search start performing the search.
if [ "$OPTION" = "search" ]
    then
    echo "Scheduling Splunk Search. Please wait..."

    ## Schedule the search and obtain the run ID in order to pull data.
    JOBADDOUT=`curl -u $USERNAME:$PASSWD -d search="$QUERY" -d id="$FILENAME" -d timeout=14400 -k https://splunk.sendgrid.net:8089/services/search/jobs/ -s`

    ## Verify the username and password were correct.
    echo "$JOBADDOUT" | grep -qoi "Unauthorized"
    ## Make sure the username and password were correct and the job was actaully created.
    if [ "$?" = "0" ]
        then
            echo "Authentication Failed!"
            echo "Check your username and password and try again"
            exit 1
    fi

    ## Obtain the JobID from the JOBADDOUT data.
    TEMPJOBID=`echo "$JOBADDOUT" | xml_grep 'sid' --text_only`

    ## Verify the TEMPJOBID matches the provided search name. Set the JOBID in order to be used for further processing.
    if [ "$TEMPJOBID" = "$FILENAME" ]
        then
            JOBID="$TEMPJOBID"
            OPTION="export"
            JOBSTATUS="RUNNING"
            echo "Please make note of the Job ID in order to pull the results if you loose your connection or the script stops for some reason."
            echo "JOBID: $JOBID"
            echo " "
            echo "NOTE: The job that was created will be automaticly removed in 4 hours."
        else
            echo "The Job ID wasn't created correctly. Please check everything and try again!"
            echo "Your username: $USERNAME"
            echo "Your Query: $QUERY"
            echo "Your Query Name/Filename: $FILENAME"
            exit 1
    fi
fi

## If the option is --export just run the status code.
if [ "$OPTION" = "export" ]
    then
    JOBID="$FILENAME"
    ## Wait until the job finishes if there are any issues alert the user.
    while [ "$JOBSTATUS" = "RUNNING" ]
        do
            JOBSTATUSOUT=`curl -u $USERNAME:$PASSWD -k https://splunk.sendgrid.net:8089/services/search/jobs/$JOBID -s` 
            ## Verify the username and password were correct.
            echo "$JOBSTATUSOUT" | grep -qoi "Unauthorized"
            ## Make sure the username and password were correct and the job was actaully created.
            if [ "$?" = "0" ]
                then
                    echo "Authentication Failed!"
                    echo "Check your username and password and try again"
                    exit 1
            fi
            ## Pull the dispatchstate to determine if the search is finished.
            DISPATCHSTATE=`echo "$JOBSTATUSOUT" | grep dispatchState | cut -d">" -f2 | cut -d"<" -f1`
            case "$DISPATCHSTATE" in
                QUEUED)
                    echo "The job is queued. Please wait..."
                    sleep 30
                    ;;
                PARSING)
                    echo "The job is parsing. Please wait..."
                    sleep 30
                    ;;
                RUNNING)
                    echo "The job is running. Please wait..."
                    sleep 30
                    ;;
                PAUSED)
                    echo "The job $FILENAME has been pasued. Login to Splunk to determine what the cause is."
                    exit 1
                    ;;
                FINALIZING)
                    echo "The job is finalizing. Please wait..."
                    sleep 30
                    ;;
                FAILED)
                    echo "The job $FILENAME has failed! Login to Splunk to determine what the cause is."
                    exit 1
                    ;;
                DONE)
                    JOBSTATUS=DONE
                    ;;
                *)
                    echo "Something has gone wrong!"
                    echo "$JOBSTATUSOUT"
                    exit 1
            esac
            clear
            if [ "$JOBSTATUS" = 'RUNNING' ]
                then
                echo "Job is still processing. Please wait..."
                else
                echo "Job is being exported to /tmp/$FILENAME. Please wait..."
            fi
    done

    ## Once the job has finished its time to pull the data.
    if [ "$JOBSTATUS" = 'DONE' ]
        then
            DATAEXPORT=`curl -u $USERNAME:$PASSWD -k https://splunk.sendgrid.net:8089/services/search/jobs/$JOBID/results/ --get -d output_mode=csv -s`
            ## Verify the username and password were correct.
            echo "$DATAEXPORT" | grep -qoi "Unauthorized"
            ## Make sure the username and password were correct and the job was actaully created.
            if [ "$?" = "0" ]
                then
                    echo "Authentication Failed!"
                    echo "Check your username and password and try again"
                    echo "$DATAEXPORT"
                    exit 1
            fi
            echo "$DATAEXPORT" > /tmp/$FILENAME
    fi
fi
## If everything finished let the user know and exit clean.
echo "Finished!! Please open /tmp/$FILENAME to view the exported data."
echo "NOTE: The job that was created will be automaticly removed in 4 hours."
exit 0
