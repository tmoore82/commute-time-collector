#!/usr/bin/perl

use strict;
use warnings;

use Math::Trig; #for calculating lat,lng
use Digest::MD5 qw(md5_hex); #for creating hashes to name files
use Config::Crontab; #for editing crontab

#routine to check if the number of api requests is valid
sub total_is_valid {
	#requires distance interval, max distance, time program starts, time it ends, and time interval
	
	if ( calc_no_api_req( $_[0], $_[1], $_[2], $_[3], $_[4] ) <= 2500 ) {
		return 1;
	}
	
	return 0;
}

#calculate the number of api requests that will be made
sub calc_no_api_req {

	my $d_interval = $_[0]; #distance interval
	my $current_d = $d_interval; #current distance from destination
	my $max_d = $_[1]; #max distance to calculate from destination

	my $num_bearings = 4; #always start 1 mile out with 4 cardinal directions

	#when this is finished, we'll have the total number of bearings,
	#which will give us the number of items in each api request
	while ($current_d <= $max_d) {
		$num_bearings += $current_d;
		$current_d += $d_interval;
	}

	#now we need to know the number of times the request will be made to know the total number per day

	my $start_hour = $_[2]; #time to start program each day
	my $end_hour = $_[3]; #time to end program each day
	my $t_interval = $_[4];
	
	my $n_hours = $end_hour-$start_hour; #how many hours per day requests run
	
	#if end_hour and start_hour are the same, the script will still run once per day
	if ($n_hours < 1) {
		$n_hours = 1;
	}
	
	my $req_per_hour = 60/$t_interval; #number of times per hour that requests run

	my $req_per_day = $req_per_hour * $n_hours; #total requests in a day
	
	my $total = $req_per_day * $num_bearings;
	
	return $total;
	
}

my $num_req_error_msg = "\nBased on the parameters provided, total API requests would exceed 2500 per day, please adjust in one or more of the following ways:
 
	- reduce max distance 
	- increase distance interval
	- reduce time interval
	- increase start time 
	- decrease end time 
	
You can check to see if your parameters work using the following calculation: 
		
	( 4 + sum ( distances ) ) * ( ( 60 / time interval ) * total hours ) 
		
where the 'distances' are the distances in miles starting with and increasing by your distance interval until your max distance. Total hours is the difference between your end time and your start time.

Here's an example. Say you enter the following parameters:

	- distance interval: 5 
	- max distance: 10
	- time interval: 60
	- start time: 6  
	- end time: 19 

then your equation would look like this:

	( 4 + sum ( 5, 10 ) ) * ( ( 60 / 60 ) * ( 19 - 6 ) ) 
	
	which equals
	
	247
	
That fits well within the limit of 2500 per day. If your number is over 2500, however, you need to scale back somewhere.

\n";

#check for proper number of arguments
my $num_args = $#ARGV + 1;

die ( "Missing arguments. Looking for [latitude] [longitude] [distance interval (mi)] [max distance (mi)] [time interval (min)] [google maps api key] [start time (24 hr)] [end time (24 hr)]. \n" ) unless ($num_args == 8);

#initialize variables
my $phi_1_d = $ARGV[0]; #starting latitude in degrees
my $lambda_1_d = $ARGV[1]; #starting longitude in degrees
my $dist_interval = $ARGV[2]; #what distance interval to use in miles
my $max_distance = $ARGV[3]; #max distance from destination
my $time_interval = $ARGV[4]; #how often to check, in minutes
my $api_key = $ARGV[5]; #google maps API key
my $start_time = $ARGV[6]; #hour to start
my $end_time = $ARGV[7]; #hour to end

#check inputs for validity

#distance inverval must be between 5 and 30 and a whole number
die( "\nDistance interval must be a whole number between 5 and 30. Value entered: " . $dist_interval . "\n\n" ) unless ( $dist_interval >=5 && $dist_interval <= 30 && $dist_interval =~ ( /^\d+$/ ) );

#max distance must be less than 30, greater than distance interval, and a whole number
die( "\nMax distance must be a whole number less than 30 and greater than the provided distance interval. Value entered: " . $max_distance . "\n" ) unless ( $max_distance >= $dist_interval && $max_distance <= 30 && $max_distance =~ ( /^\d+$/ ) );

#time interval must be a whole number no greater than 30
die( "\nTime interval must be a whole number no greater than 60. Value entered: " . $time_interval . "\n\n" ) unless ( $time_interval >= 1 && $time_interval <= 60 && $time_interval =~ ( /^\d+$/ ) );

#start time must be a whole number between 0 and 23
die ( "\nStart time must be a whole number between 0 and 23. Value entered: " . $start_time . "\n\n"  ) unless ($start_time >= 0 && $start_time <= 23  && $start_time =~ ( /^\d+$/ ) );

#end time must be a whole number between 0 and 23
die ( "\nEnd time must be a whole number between 0 and 23. Value entered: " . $end_time . "\n\n" ) unless ( $end_time >= 0 && $end_time <= 23 && $end_time =~ ( /^\d+$/ ) );

#ensure that total number of API requests will not exceed 2500 per day
die ( $num_req_error_msg ) unless ( total_is_valid( $dist_interval, $max_distance, $start_time, $end_time, $time_interval ) );

#latitude and longitude variables
my $R = 3959; #Earth's radius in miles
my $delta; # = distance / $R;
my $phi_1_r; #starting latitude in radians
my $phi_2_r; #resulting latitude in radians
my $phi_2_d; #resulting latitude in degrees
my $lambda_1_r; #starting longitude in radians
my $lambda_2_r; #resulting longitude in radians
my $lambda_2_d; #resulting longitude in degrees

my @distances = (); #array for distances

#bearing variables
my @bearings = (); #array for bearings
my $slice; #how many degrees out of 360 to add
my $current_bearing; #where we're at on the circle

#file-related variables
my $route_id = 0; #id for generated route info
my $route_string; #string to write to file
my $group_id = md5_hex(rand); #generate random hash to name file of routes
my $dir = '/usr/local/var/commute-time-collector/'; #directory to place data

#open the directory
opendir( DIR, $dir ) or die "Could not open $dir\n";

#create empty text file to receive info
my $output_file = $dir . $group_id;

unless( open FILE, '>>'.$output_file ) {
    # Die with error message 
    # if we can't open it.
    die "\nUnable to create $output_file\n";
}

#add provided info to file
print FILE "id:" . $group_id . ";work-addr:" . $phi_1_d . "," . $lambda_1_d . ";distance-interval:" . $dist_interval . ";max-distance:" . $max_distance . ";time-interval:" . $time_interval . ";api-key:" . $api_key . "\n";

#convert degrees to radians
$phi_1_r = ( $phi_1_d * pi ) / 180;
$lambda_1_r = ( $lambda_1_d * pi ) / 180;

#need a variable to keep track of current distance from destination
#to push into the distances array
my $add_interval = 1;

while ( $add_interval <= $max_distance ) {
	
	push @distances, $add_interval;
	
	if ( $add_interval < $dist_interval ) {
		
		$add_interval = $dist_interval;
	
	} else {
	
		$add_interval += $dist_interval;
	
	}
}

#loop through distances and bearings
foreach my $distance ( @distances ) {
	
	$delta = $distance/$R;
	
	#make sure we empty out bearings
	#and free its memory
	undef @bearings;
	
	#default bearings for less than 5 miles out
	#are the four cardinal directions
	if ( $distance < 5 ) {

		@bearings = ( 0, 90, 180, 270 );

	} else {
		
		#each shift in bearing will be equal to the slice
		#generated by dividing 360 by
		#the current distance from desired location
		$slice = 360/$distance;
		$current_bearing = 0;
		
		#push bearings into the bearings array
		do {

			push @bearings, $current_bearing;
			$current_bearing += $slice;

		} while ( $current_bearing < 360 );
	}
	
	#calculate latitudes and longitudes for distance and bearing
	foreach my $bearing ( @bearings ) {

		#calculate resulting latitude
		$phi_2_r = asin( sin($phi_1_r) * cos($delta) + cos($phi_1_r) * sin($delta) * cos($bearing) );
		
		#calculate resulting longitude		
		$lambda_2_r = $lambda_1_r + atan2( sin($bearing) * sin($delta) * cos($phi_1_r), cos($delta) - sin($phi_1_r) * sin($phi_2_r) );
		
		#convert radians to degrees
		$phi_2_d = ($phi_2_r * 180) / pi;
		$lambda_2_d = ($lambda_2_r * 180) / pi;
		
		#create string of key:value pairs to print to file
		$route_string =	"route:" . $route_id . ";loc-1:" . $phi_1_d . "," . $lambda_1_d . ";loc-2:" . $phi_2_d . "," . $lambda_2_d . "\n";
		
		print FILE $route_string;
		
		#increase route id so they're easier to differentiate when slicing data
		$route_id += 1;
	}
	
}	
	
#close output file and directory
close FILE;
closedir( DIR );	

#get crontab settings
my $crontab_interval;
my $minute;
my $hour;

#convert time-interval into format crontab will understand
if ( $time_interval == 60 ) {

	$minute = 0;

} else {

	$minute = "*/" . $time_interval;

}

if ( $end_time == $start_time) {
	
	$hour = $start_time;	
	
} else {
	
	$hour = $start_time . "-" . $end_time;	
	
}

#create crontab object
my $ct = new Config::Crontab; # new crontab

#read in current contents to ensure we don't overwrite them
$ct->read; 

#create a new "block"
my $block = new Config::Crontab::Block;

#create a new "event" with the desired intpus
my $event = new Config::Crontab::Event(	-minute => $minute,
										-hour => $hour,
										-command => '/usr/local/bin/api-request.pl ' . $dir . $group_id . "\n");

#add event to block
$block->last($event);

#add block to crontab object
$ct->last($block); ## add this block to the crontab object

#write to crontab
if ( !defined $ct->write ) {

	warn "Error: " . $ct->error . "\n";

}

print "Commute time collection scheduled. Job will run indefinitely until deleted from crontab. ID: " . $group_id . "\n\n";

exit;
