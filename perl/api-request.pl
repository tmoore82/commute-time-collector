#!/usr/bin/perl

use strict;
use warnings;

use JSON qw( decode_json );
require HTTP::Request;
use Time::Piece;
use LWP::UserAgent;

my $url_a = "https://maps.googleapis.com/maps/api/directions/json?origin=";
my $url_b = "&destination=";
my $url_c = "&departure_time=now&key=";

#check for proper number of arguments
my $num_args = $#ARGV + 1;

if ($num_args !=1) {
	print "expecting path and name of file to run--either too many or too few parameters\n";
	exit;
}

#get group id, which is the filename from the path provided as argument
my $group_id = (split '/', $ARGV[0])[-1];
my $filename = $ARGV[0];

#open the file for reading
open( my $fh, '<', $filename ) or die "Can't open $filename: $!";

#read first line from opened file, which contains the header info
my $line = <$fh>;

#parse header info, semi-colon delimited
my $header;
my @header_elements = split /;/, $line;

#api key is value of last element
my $api_key = (split /:/, $header_elements[5])[1]; #could be more dynamic by finding key-value pair, but just looking to make it work right now

#create or open results file
#name will be hash-results
my $results_file = $filename . '-results';
my $rfh; #results file handle

#if file exists, just open it
#otherwise, create it and add our header
if (-f $results_file) {	
	open $rfh, '>>', $results_file or die "Can't open $rfh: $!";
	
} else {
	open $rfh, '>>', $results_file or die "Can't open $rfh: $!";
	
	my $header = "group id;route id;date;time;direction;starting address;starting latitude;starting longitude;destination address;destination latitude;destination longitude;travel distance in meters;travel time in seconds\n";

	print $rfh $header;
}

#initialize additional variables
my $json; #variable for json results from https service request
my $decoded; #decoded json content
my $route_id; #route id, from file
my $direction; #either "from" or "to" depending on hour
my $origin; #starting lat,lng
my $dest; #ending lat,lng
my $loc_1; #destination, pulled from input file
my $loc_2; #might be redundant to origin & dest, but pretty sure it condenses code ultimately
my @line_elements; #array to capture split elements from line of file

my $t = localtime; #current datetime
my $req_date = $t->mdy; #date in MM-DD-YYYY format
my $req_time = $t->hms; #hours:minutes:seconds
my $hour = $t->hour; #current hour, for figuring out if directions should be to work or from work

#initialize variables for json results
my $travel_time_in_seconds;
my $distance_in_meters;
my $start_address;
my $start_lat;
my $start_lng;
my $end_address;
my $end_lat;
my $end_lng;
my $info; #concatenation of the above

#really just following example from tutorials on HTTP::Request here
my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 1 });
my $url; #fully formed URL for http request
my $http_header; 
my $request; 
my $response;

#read in each line of the file, process, and translate results
while ( my $line = <$fh> ) {
		#parse routes, semi-colon delimited, key:value pairs
        @line_elements = split /;/, $line;
        
        #could be more dynamic by using actual named key:value pairs, but just looking to get it working quick and dirty
        $route_id = (split /:/, $line_elements[0])[1];        
        $loc_1 = (split /:/, $line_elements[1])[1];
        $loc_2 = (split /:/, $line_elements[2])[1];
        chomp $loc_2; #get rid of trailing new line character
        
        #if it's before 1 p.m., route is to work (loc_1)
        #otherwise, route is from work (loc_1)
        if ($hour < 13) {
        	$direction = "to";
        	$origin = $loc_2;
        	$dest = $loc_1;
        } else {
	        $direction = "from";
        	$origin = $loc_1;
        	$dest = $loc_2;
        }

		#build request url, header, request, and get json object
		$url = $url_a . $origin . $url_b . $dest . $url_c . $api_key;
		
		#really just following tutorial for HTTP::Request here, not sure what all the pieces do
		$http_header = HTTP::Request->new(GET => $url);
		$request = HTTP::Request->new('GET', $url, $http_header);
		$json = $ua->request($request);
        
        #make sure request was a success and decoded it, or die
        if ($json->is_success) {
     		$decoded = decode_json($json->decoded_content);
 		}
		else {
	    	die $json->status_line;
 		}
        
        #check that proper info was actually returend
		if ( exists $decoded->{ 'routes' }[0]->{ 'legs' } && exists $decoded->{ 'routes' }[0]->{ 'legs' }[0]->{ 'duration_in_traffic' } ) {
		
			#grab values from decoded json
			$start_address = $decoded->{ 'routes' }[0]->{ 'legs' }[0]->{ 'start_address' };
			$start_lat = $decoded->{ 'routes' }[0]->{ 'legs' }[0]->{ 'start_location' }{ 'lat' };
			$start_lng = $decoded->{ 'routes' }[0]->{ 'legs' }[0]->{ 'start_location' }{ 'lng' };
			$end_address = $decoded->{ 'routes' }[0]->{ 'legs' }[0]->{ 'end_address' };
			$end_lat = $decoded->{ 'routes' }[0]->{ 'legs' }[0]->{ 'end_location' }{ 'lat' };
			$end_lng = $decoded->{ 'routes' }[0]->{ 'legs' }[0]->{ 'end_location' }{ 'lng' };
			$distance_in_meters = $decoded->{ 'routes' }[0]->{ 'legs' }[0]->{ 'distance' }{ 'value' };
			$travel_time_in_seconds = $decoded->{ 'routes' }[0]->{ 'legs' }[0]->{ 'duration_in_traffic' }{ 'value' };
						
			#concatenate into semi-colon delimited line
			$info = $group_id . ";" . $route_id . ";" . $req_date . ";" . $req_time . ";" . $direction . ";" . $start_address . ";" . $start_lat . ";" . $start_lng . ";" . $end_address . ";" . $end_lat . ";" . $end_lng . ";" . $distance_in_meters . ";" . $travel_time_in_seconds . "\n";
		
			#append results to file with group id and route id
			print $rfh $info;
			
		} else {
			print "no routes returned\n";
		}
}

close $fh;
close $rfh;

