#!/bin/bash
# Splunk Export script that will use the Splunk API to perform and export searches.
# Created By: Jeremy Davis
# Version: 1.0.0

## Obtain the username, password, and search query and assign it to variables.
clear
echo "Enter LDAP Username:"
read USERNAME
clear
echo "Enter Password:"
read -s PASSWD
clear
echo "Enter Splunk Search Query:"
echo "NOTE: Make sure you limit the search as this will pull all logs and could take some time."
read QUERY
clear
echo "Enter Export Filename:"
echo "NOTE: This filename will be used to store the exported logs from Splunk. Output will be in csv format."
read FILENAME
clear

## Display what we are about to do.
echo "Your username: $USERNAME"
echo "Your Query: $QUERY"
echo "Performing Splunk Search. Please wait..."

## Perform the search and export.
curl  -k -u $USERNAME:$PASSWD --data-urlencode search="$QUERY" -d "output_mode=csv" https://splunk.sendgrid.net:8089/servicesNS/admin/search/search/jobs/export >> $FILENAME

## If everything finished let the user know and exit clean.
clear
echo "Finished!! Please open $FILENAME to view the exported data."
exit 0
