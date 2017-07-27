# commute-time-collector
Perl scripts to create cron job that pings Google Maps API for commute times to and from an address at regular intervals

# Prep and Run

1. Back up crontab

2. Edit crontab and make sure it has the following line:

   ```bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
```

3. place commute-time-collector.pl in /usr/local/bin and make sure it is executable

4. place api-request.pl in /usr/local/bin and make sure it is executable

5. Make directory /usr/local/var/commute-time-collector

6. Call `perl /usr/local/var/commute-time-collector.pl \[latitude\] \[longitude\] \[distance interval (mi)\] \[max distance (mi)\] \[time interval (min)\] \[google maps api key\] \[start time (24 hr)\] \[end time (24 hr)\]`

- latitude: latitude of your desired destination in degrees
- longitude: longitude of your desired destination in degrees
- distance interval (mi): how far out to make each new set of routes (how frequently do you want the program to draw circles around the destination--cannot be less than 5 or greater than 30)
- max distance (mi): max number of miles from desired destination. right now, cannot be greater than 30 and must be greater than or equal to the distance interval
- time interval (min): how often to check for data in minutes 
- google maps api key: self explanatory
- start time: the hour, out of 24, that you want to start each day (i.e., 6, 12, 15) -- should be hour only and not include minutes
- end time: the hour, out of 24, that you want to end each day (i.e., 9, 16, 22) -- should be hour only and not include minutes

This will create a file in /usr/local/var/commute-time-collector with a header containing the information you entered plus a number of "routes" with lat,lng pairs for origins and destinations generated from your input.

The script will then add a job to crontab to run every hour (may be updated to run at user-designated intervals in the future) during the hours designated to collect results that will be placed in a results file in /usr/local/var/commute-time-collector. Currently there is no option to designate specific days. The program will run daily and indefinitely until the entry is edited or deleted from crontab.

The `-results` file will contain semi-colon delimited values that you can import into your data analyzing program of choice.

# Troubleshooting

Crontab should contain at least one line referencing api-request.pl after you've successfully run commute-time-collector.pl. 

api-request.pl does the actual work of getting the commute times from Google Maps and translating those into legible results. If this isn't running, you'll get no results.