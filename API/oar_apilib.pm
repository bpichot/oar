#!/usr/bin/perl -w
package apilib;
require Exporter;

my $VERSION="0.1.6";

use strict;
#use oar_conflib qw(init_conf dump_conf get_conf is_conf);
use CGI qw/:standard/;


##############################################################################
# INIT
##############################################################################

# Try to load XML module
my $XMLenabled = 1;
unless ( eval "use XML::Simple qw(XMLout);1" ) {
  $XMLenabled = 0;
}

# Try to load YAML module
my $YAMLenabled = 1;
unless ( eval "use YAML;1" ) {
  $YAMLenabled = 0;
}

# Try to load JSON module
my $JSONenabled = 1;
unless ( eval "use JSON;1" ) {
  $JSONenabled = 0;
}

# Try to load URI (LWP) module
my $URIenabled = 1;
unless ( eval "use URI;1" ) {
  $URIenabled = 0;
}

# CGI handler
my $q = new CGI;

# Activate debug mode when the script name contains "debug" or when a
# debug parameter is found.
my $DEBUG_MODE=0;
if ( $q->url(-relative=>1) =~ /.*debug.*/ ) { $DEBUG_MODE = 1; };
if ( defined( $q->param('debug') ) && $q->param('debug') eq "1" ) {
  $DEBUG_MODE = 1;
}

# Check a possible extension
sub set_ext($$); # defined later
my $extension;
if ( $q->path_info =~ /^$/ ) { $extension = "html"; }
elsif ( $q->path_info =~ /.*\.(yaml|json|html)$/ ) { $extension = $1; };
$extension=set_ext($q,$extension);

# Declared later with REST functions
sub ERROR($$$);

##############################################################################
# Data conversion functions
##############################################################################

# Load YAML data into a hashref
sub import_yaml($) {
  my $data         = shift;
  check_yaml();
  # Try to load the data and exit if there's an error
  my $hashref = eval { YAML::Load($data) };
  if ($@) {
    ERROR 400, 'YAML data not understood', $@;
    exit 0;
  }
  return $hashref;
}

# Load JSON data into a hashref
sub import_json($) {
  my $data         = shift;
  check_json();
  # Try to load the data and exit if there's an error
  my $hashref = eval { JSON::decode_json($data) };
  if ($@) {
    ERROR 400, 'JSON data not understood', $@;
    exit 0;
  }
  return $hashref;
}

# Load Dumper data into a hashref
sub import_dumper($) {
  my $data         = shift;
  my $hash = eval($data);
  if ($@) {
    ERROR 400, 'Dumper data not understood', $@ . $data;
    exit 0;
  }
  return $hash;
}

# Load HTML data into a hashref
sub import_html_form($) {
  my $data         = shift;
  return $data;
}

# Load data into a hashref
sub import($$) {
  (my $data, my $format) = @_;
  if ($format eq "yaml") { import_yaml($data); }
  elsif ($format eq "dumper") { import_dumper($data); }
  elsif ($format eq "json") { import_json($data); }
  else {
    ERROR 400, "Unknown $format format", $@;
    exit 0;
  }
}

# Export a hash into YAML
sub export_yaml($) {
  my $hashref = shift;
  check_yaml();
  return YAML::Dump($hashref)
} 
  
# Export a hash into JSON
sub export_json($) {
  my $hashref = shift;
  check_json();
  return JSON->new->pretty(1)->encode($hashref);
}

# Export a hash into HTML (YAML in fact, as it is human readable)
sub export_html($) {
  my $hashref = shift;
  check_yaml();
  return "<PRE>\n". YAML::Dump($hashref) ."\n</PRE>";
}

# Export data to the specified content_type
sub export($$) {
  my $data         = shift;
  my $format = shift;
  if ( $format eq 'yaml' ) {
    return export_yaml($data);
  }elsif ( $format eq 'json' ) {
    return export_json($data)."\n";
  }elsif ( $format eq 'html' ) {
    return export_html($data)."\n";
  }else {
    ERROR 406, "Unknown $format format",
      "The $format format is not known.";
    exit 0;
  }
}

##############################################################################
# Oargrid functions
##############################################################################

# Get infos of clusters, by site hierarchy
sub get_sites($) {
  my $dbh      = shift;
  my %clusters = oargrid_lib::get_cluster_names($dbh);
  my $sites;
  my $site;
  foreach my $i ( keys(%clusters) ) {
    if ( defined( $clusters{$i}{parent} ) ) {
      $site=$clusters{$i}{parent};
      $sites->{$site}->{frontend}=$clusters{$i}{hostname};
      push @{ $sites->{$site}->{deprecated} }, $i if (defined($clusters{$i}{deprecated}));;
      push @{ $sites->{$site}->{clusters} }, $i;
    }
  }
  return $sites;
}

# Get all the infos about the clusters (oargridlib)
sub get_clusters($) {
  my $dbh = shift;
  my %clusters = oargrid_lib::get_cluster_names($dbh);
  return(\%clusters);
}

##############################################################################
# URI generation functions
# For each structure having an uri, also add an api_timestamp giving the date
# at which the entry has been generated by the api.
##############################################################################

# Return the url (absolute if the third argument is 1). The .html
# extension is added if the second argument is equal to "html".
sub make_uri($$$) {
  my $path = shift;
  my $ext = shift;
  my $absolute = shift;
  if ($ext eq "html") { $path.=".html"; }
  if ($absolute == 1) {
    return $q->url(-full => 1). $path;
  }
  else {
    return $path;
  }
}

# Return an html href of an uri if the type is "html"
sub htmlize_uri($$) {
  my $uri=shift;
  my $type=shift;
  if ($type eq "html") {
    if ($URIenabled) {
      my $base = $q->path_info;
      $base =~ s/\.html$// ;
      $base = "http://bidon".$base;
      my $goal = "http://bidon".$uri;
      return "<A HREF=".URI->new($goal)->rel($base).">$uri</A>";
    }
    else { 
      ERROR (500,
             "LWP URI module not enabled",
             "I cannot make uris without LWP URI module!" );
      exit 0;
    }
  }
  else { return $uri; }
}

# Get the api uri base in relative
sub get_api_uri_relative_base() {
  if ($URIenabled) {
    my $base = $q->path_info;
    $base =~ s/\.html$// ;
    $base =~ s/\/$// ;
    $base = "http://bidon".$base;
    my $goal = "http://bidon";
    return URI->new($goal)->rel($base);
  }
  else {
    ERROR (500,
           "LWP URI module not enabled",
           "I cannot make uris without LWP URI module!" );
    exit 0;
  }
}

# Add uris to a oar job list
sub add_joblist_uris($$) {
  my $jobs = shift;
  my $ext = shift;
    foreach my $job ( keys( %{$jobs} ) ) {
      $jobs->{$job}->{uri}=apilib::make_uri("/jobs/$job",$ext,0);
      $jobs->{$job}->{uri}=apilib::htmlize_uri($jobs->{$job}->{uri},$ext);
      $jobs->{$job}->{api_timestamp}=time();
  }
}

# Add uris to a oar job list for oargrid
sub add_joblist_griduris($$$) {
  my $jobs = shift;
  my $ext = shift;
  my $site = shift;
    foreach my $job ( keys( %{$jobs} ) ) {
      $jobs->{$job}->{uri}=apilib::make_uri("/sites/$site/jobs/$job",$ext,0);
      $jobs->{$job}->{uri}=apilib::htmlize_uri($jobs->{$job}->{uri},$ext);
      $jobs->{$job}->{api_timestamp}=time();
  }
}

# Add uris to a resources list
sub add_resources_uris($$$) {
  my $resources = shift;
  my $ext = shift;
  my $prefix = shift;
  foreach my $node ( keys( %{$resources} ) ) {
    foreach my $id ( keys( %{$resources->{$node}} ) ) {
      # This test should make this function work for "oarstat -s"
      if (ref($resources->{$node}->{$id}) ne "HASH") {
        my $state = $resources->{$node}->{$id};
        $resources->{$node}->{$id}={};
        $resources->{$node}->{$id}->{state}=$state;
      }
      $resources->{$node}->{$id}->{uri}=apilib::make_uri("$prefix/resources/$id",$ext,0);
      $resources->{$node}->{$id}->{uri}=apilib::htmlize_uri($resources->{$node}->{$id}->{uri},$ext);
    }
    $resources->{$node}->{uri}=apilib::make_uri("$prefix/resources/nodes/$node",$ext,0);
    $resources->{$node}->{uri}=apilib::htmlize_uri($resources->{$node}->{uri},$ext);
    $resources->{$node}->{api_timestamp}=time();
  }
}

# Add uris to a grid sites list
sub add_sites_uris($$) {
  my $sites = shift;
  my $ext = shift;
  foreach my $site ( keys( %{$sites} ) ) {
      $sites->{$site}->{uri}=apilib::htmlize_uri(
                               apilib::make_uri("/sites/$site",$ext,0),
                               $ext
                             );
      $sites->{$site}->{resources_uri}=apilib::htmlize_uri(
                               apilib::make_uri("/sites/$site/resources",$ext,0),
                               $ext
                             );
      $sites->{$site}->{api_timestamp}=time();
  }
}

# Add uris to a grid job list
sub add_gridjobs_uris($$) {
  my $jobs = shift;
  my $ext = shift;
  foreach my $job ( keys( %{$jobs} ) ) {
      $jobs->{$job}->{uri}=apilib::htmlize_uri(
                               apilib::make_uri("/grid/jobs/$job",$ext,0),
                               $ext
                             );
      $jobs->{$job}->{nodes_uri}=apilib::htmlize_uri(
                               apilib::make_uri("/grid/jobs/$job/resources/nodes",$ext,0),
                               $ext
                             );
      $jobs->{$job}->{api_timestamp}=time();
  }
}

# Add uris to a grid job
sub add_gridjob_uris($$) {
  my $job = shift;
  my $ext = shift;
  # Timestamp
  $job->{api_timestamp}=time();
  # List of resources
  $job->{resources_uri}=apilib::htmlize_uri(
                               apilib::make_uri("/grid/jobs/". $job->{id} ."/resources",$ext,0),
                               $ext
                             );
  # List of resources without details (nodes only)
  $job->{nodes_uri}=apilib::htmlize_uri(
                               apilib::make_uri("/grid/jobs/". $job->{id} ."/resources/nodes",$ext,0),
                               $ext
                             );
  # Link to the batch job on the corresponding cluster
  foreach my $cluster (keys %{$job->{clusterJobs}}) {
    foreach my $cluster_job (keys %{$job->{clusterJobs}->{$cluster}}) {
      $job->{clusterJobs}->{$cluster}->{$cluster_job}->{uri}=apilib::htmlize_uri(
              apilib::make_uri("/sites/$cluster/jobs/" 
                 .$job->{clusterJobs}->{$cluster}->{$cluster_job}->{batchId},$ext,0),
              $ext
              );
    }
  }
  # Ssh keys
  $job->{ssh_private_key_uri}=apilib::htmlize_uri(
                               apilib::make_uri("/grid/jobs/".$job->{id}."/keys/private",$ext,0),
                               $ext
                             );
  $job->{ssh_public_key_uri}=apilib::htmlize_uri(
                               apilib::make_uri("/grid/jobs/".$job->{id}."/keys/public",$ext,0),
                               $ext
                             );
 
}

##############################################################################
# Data structure functions
# (functions for shaping data depending on $STRUCTURE)
##############################################################################

# EMPTY DATA
sub struct_empty($) {
  my $structure = shift;
  if    ($structure eq 'oar')    { return {}; }
  elsif ($structure eq 'simple') { return []; }
}

# OAR JOB
sub struct_job($$) {
  my $job = shift;
  my $structure = shift;
  my $result;
  if    ($structure eq 'oar')    { return $job; }
  elsif ($structure eq 'simple') { 
    if ($job->{(keys(%{$job}))[0]} ne "HASH") {
      return $job;
    }else {
      return $job->{(keys(%{$job}))[0]}; 
    }}
}

# OAR JOB LIST
sub struct_job_list($$) {
  my $jobs = shift;
  my $structure = shift;
  my $result;
  foreach my $job ( keys( %{$jobs} ) ) {
    my $hashref = {
                  state => $jobs->{$job}->{state},
                  owner => $jobs->{$job}->{owner},
                  name => $jobs->{$job}->{name},
                  queue => $jobs->{$job}->{queue},
                  submission => $jobs->{$job}->{submissionTime},
                  uri => $jobs->{$job}->{uri},
                  api_timestamp => $jobs->{$job}->{api_timestamp}
    };
    if ($structure eq 'oar') {
      $result->{$job} = $hashref;
    }
    elsif ($structure eq 'simple') {
      $hashref->{id}=$job;
      push (@$result,$hashref);
    } 
  }
  return $result;
}

# OAR RESOURCES
sub struct_resource_list($$) {
  my $resources = shift;
  my $structure = shift;
  my $result;
  if ($structure eq 'oar') {
    return $resources ;
  }
  elsif ($structure eq 'simple') {
    foreach my $node ( keys( %{$resources} ) ) {
      foreach my $id ( keys( %{$resources->{$node}} ) ) {
        if ($id ne "uri" && $id ne "api_timestamp") {
          $resources->{$node}->{$id}->{id}=$id;
          $resources->{$node}->{$id}->{node}=$node;
          $resources->{$node}->{$id}->{node_uri}=$resources->{$node}->{uri};
          $resources->{$node}->{$id}->{api_timestamp}=$resources->{$node}->{api_timestamp};
          push(@$result,$resources->{$node}->{$id});
        }
      }
    }
    return $result; 
  }
}

# GRID SITE LIST
sub struct_sites_list($$) {
  my $sites = shift;
  my $structure = shift;
  my $result;
  my $uri;
  foreach my $s ( keys( %{$sites} ) ) {
    if ($structure eq "simple") { push(@$result,{ site => $s, 
                                                  uri => $sites->{$s}->{uri},
                                                  api_timestamp => $sites->{$s}->{api_timestamp} });}
    else                        { $result->{$s}->{uri} = $sites->{$s}->{uri};
                                  $result->{$s}->{api_timestamp} = $sites->{$s}->{api_timestamp}; }
  }
  return $result; 
}

# GRID SITE
sub struct_site($$) {
  my $site = shift;
  my $structure = shift;
  if ($structure eq "simple") { 
    my $s=(keys( %{$site}))[0];
    $site->{$s}->{site}=$s; 
    return $site->{$s}; 
  }
  else { return $site; }
}

# GRID JOB
sub struct_gridjob($$) {
  my $job = shift;
  my $structure = shift;
  my @cluster_jobs;
  foreach my $cluster (keys %{$job->{clusterJobs}}) {
    foreach my $cluster_job (keys %{$job->{clusterJobs}->{$cluster}}) {
      # Cleaning
      delete $job->{clusterJobs}->{$cluster}->{$cluster_job}->{weight};
      delete $job->{clusterJobs}->{$cluster}->{$cluster_job}->{nodes};
      delete $job->{clusterJobs}->{$cluster}->{$cluster_job}->{env};
      delete $job->{clusterJobs}->{$cluster}->{$cluster_job}->{name};
      delete $job->{clusterJobs}->{$cluster}->{$cluster_job}->{queue};
      delete $job->{clusterJobs}->{$cluster}->{$cluster_job}->{part};
      # For the simple data structure
      push (@cluster_jobs, 
         { 'cluster' => $cluster,
           'id' => $job->{clusterJobs}->{$cluster}->{$cluster_job}->{batchId},
           'properties' => $job->{clusterJobs}->{$cluster}->{$cluster_job}->{properties},
           'rdef' => $job->{clusterJobs}->{$cluster}->{$cluster_job}->{rdef},
           'uri' => $job->{clusterJobs}->{$cluster}->{$cluster_job}->{uri},
           'api_timestamp' => $job->{clusterJobs}->{$cluster}->{$cluster_job}->{api_timestamp}
          })
    }
  }
  if ($structure eq "simple") {
    delete $job->{clusterJobs};
    $job->{cluster_jobs}=\@cluster_jobs;
  }
  return $job;
}

# GRID JOB LIST
sub struct_gridjobs_list($$) {
  my $jobs = shift;
  my $structure = shift;
  my $result;
  foreach my $job ( keys( %{$jobs} ) ) {
    my $hashref = {
                  nodes => $jobs->{$job}->{nodes},
                  uri => $jobs->{$job}->{uri},
                  api_timestamp => $jobs->{$job}->{api_timestamp},
    };
    if ($structure eq 'oar') {
      $result->{$job} = $hashref;
    }
    elsif ($structure eq 'simple') {
      $hashref->{id}=$job;
      push (@$result,$hashref);
    }
  }
  return $result;
}

# GRID JOB RESOURCES
sub struct_gridjob_resources($$) {
  my $resources = shift;
  my $structure = shift;
  my $result;
  if ($structure eq "simple") {
    foreach my $resource ( keys( %{$resources} ) ) {
      push (@$result,{ site => $resource, jobs => $resources->{$resource} });
    }
    return $result;
  }
  else {
    return $resources;
  } 
}

# LIST OF NODES FOR A GRID JOB
sub struct_gridjob_nodes($$) {
  my $resources = shift;
  my $structure = shift;
  my @result;
  foreach my $site ( keys( %{$resources} ) ) {
    foreach my $job ( keys( %{$resources->{$site}} ) ) {
      my $nodes=$resources->{$site}->{$job}->{nodes};
      foreach my $node (@$nodes) {
        @result=(@result,$node);
      }
    }
  }
  return \@result;
}

##############################################################################
# Content type functions
##############################################################################

# Get a suitable extension depending on the content-type
sub get_ext($) {
  my $content_type = shift;
  # content_type may be of the form "application/json; charset=UTF-8"
  ($content_type)=split(/\s*;\s*/,$content_type);
  if    ($content_type eq "text/yaml")  { return "yaml"; }
  elsif ($content_type eq "text/html")  { return "html"; }
  elsif ($content_type eq "application/json")  { return "json"; }
  #elsif ($content_type eq "application/x-www-form-urlencoded")  { return "json"; }
  else                                  { return "UNKNOWN_TYPE"; }
}

# Get a suitable content-type depending on the extension
sub get_content_type($) {
  my $format = shift;
  if    ( $format eq "yaml" ) { return "text/yaml"; } 
  elsif ( $format eq "html" ) { return "text/html"; } 
  elsif ( $format eq "json" ) { return "application/json"; } 
  else                        { return "UNKNOWN_TYPE"; }
}

# Set oar output option and header depending on the format given
sub set_output_format($) {
  my $format=shift;
  my $type = get_content_type($format);
  my $header=$q->header( -status => 200, -type => "$type" );
  return ($header,$type);
}

# Return the extension (second parameter) if defined, or the
# corresponding one if the content_type if set.
sub set_ext($$) {
  my $q=shift;
  my $ext=shift;
  if (defined($ext) && $ext ne "") { $ext =~ s/^\.*//; return $ext; }
  else {
    if (defined($q->http('Accept'))) {
      if (get_ext($q->http('Accept')) ne "UNKNOWN_TYPE") {
         return get_ext($q->http('Accept'));
      }
      elsif (defined($q->content_type)) {
        if (get_ext($q->content_type) ne "UNKNOWN_TYPE") {
          return get_ext($q->content_type);
        }
        else {
          ERROR 406, 'Invalid content type ',
          "Valid types are text/yaml, application/json or text/html";
        }
      }
      else {
        ERROR 406, 'Invalid content type required ' .$q->http('Accept'),
        "Valid types are text/yaml, application/json or text/html";
      }
    }
    elsif (defined($q->content_type)) {
      if (get_ext($q->content_type) ne "UNKNOWN_TYPE") { 
         return get_ext($q->content_type);
      }
      else { 
        ERROR 406, 'Invalid content type ' .$q->content_type,
        "Valid types are text/yaml, application/json or text/html";
      }
    }
    else { 
      ERROR 406, 'Invalid content type ',
      "Valid types are text/yaml, application/json or text/html";
    }
  }
}

##############################################################################
# REST Functions
##############################################################################

sub GET($$);
sub POST($$);
sub DELETE($$);
sub PUT($$);
sub ERROR($$$);

sub GET($$) {
  ( my $q, my $path ) = @_;
  if   ( $q->request_method eq 'GET' && $q->path_info =~ /$path/ ) { return 1; }
  else                                                             { return 0; }
}

sub POST($$) {
  my ( $q, $path ) = @_;
  if   ( $q->request_method eq 'POST' && $q->path_info =~ $path ) { return 1; }
  else                                                            { return 0; }
}

sub DELETE($$) {
  my ( $q, $path ) = @_;
  if   ( $q->request_method eq 'DELETE' && $q->path_info =~ $path ) { return 1; }
  else                                                              { return 0; }
}

sub PUT($$) {
  my ( $q, $path ) = @_;
  if   ( $q->request_method eq 'PUT' && $q->path_info =~ $path ) { return 1; }
  else                                                           { return 0; }
}

sub ERROR($$$) {
  ( my $status, my $title, my $message ) = @_;
  if ($DEBUG_MODE) {
    $title  = "ERROR $status - " . $title ;
    $status = "200";
  }

  # This is to prevent a loop as the export function may call ERROR!
  if (!defined($extension) || get_content_type($extension) eq "UNKNOW_TYPE") {  $extension = "json"; }

  $status=$status+0; # To convert the status to an integer
  print $q->header( -status => $status, -type => get_content_type($extension) );
  if ($extension eq "html") {
    print $q->title($title) ."\n";
    print $q->h1($title) ."\n";
    print $q->p("<PRE>\n". $message ."\n</PRE>");
  }
  else {
    my $error = { code => $status,
                  message => $message,
                  title => $title
                };

    print export($error,$extension);
    exit 0;
  }
}

##############################################################################
# Posted resources
##############################################################################

# Check the consistency of a posted job and load it into a hashref
sub check_job($$) {
  my $data         = shift;
  my $content_type = shift;
  my $job;
  
  # content_type may be of the form "application/json; charset=UTF-8"
  ($content_type)=split(/\s*;\s*/,$content_type);

  # If the data comes in the YAML format
  if ( $content_type eq 'text/yaml' ) {
    $job=import_yaml($data);
  }

  # If the data comes in the JSON format
  elsif ( $content_type eq 'application/json') {
    $job=import_json($data);
  }

  # If the data comes from an html form
  elsif ( $content_type eq 'application/x-www-form-urlencoded' ) {
    $job=import_html_form($data);
  }

  # We expect the data to be in YAML or JSON format
  else {
    ERROR 406, 'Job description must be in YAML or JSON',
      "The correct format for a job request is text/yaml or application/json. "
      . $content_type;
    exit 0;
  }

  # Job must have a "script" or script_path field
  unless ( $job->{script} or $job->{script_path} ) {
    ERROR 400, 'Missing Required Field',
      'A job must have a script or a script_path!';
    exit 0;
  }

  # Clean options with an empty parameter that is normaly required
  foreach my $option ("resources",   "name",
                      "property",    "script",
                      "script_path", "type",
                      "reservation", "directory"
                     ) { parameter_option($job,$option) }
    

  return $job;
}

# Check the consistency of a job update and load it into a hashref
sub check_job_update($$) {
  my $data         = shift;
  my $content_type = shift;
  my $job;

  # content_type may be of the form "application/json; charset=UTF-8"
  ($content_type)=split(/\s*;\s*/,$content_type);

  # If the data comes in the YAML format
  if ( $content_type eq 'text/yaml' ) {
    $job=import_yaml($data);
  }

  # If the data comes in the JSON format
  elsif ( $content_type eq 'application/json' ) {
    $job=import_json($data);
  }

  # If the data comes from an html form
  elsif ( $content_type eq 'application/x-www-form-urlencoded' ) {
    $job=import_html_form($data);
  }

  # We expect the data to be in YAML or JSON format
  else {
    ERROR 406, 'Job description must be in YAML or JSON',
      "The correct format for a job request is text/yaml or application/json. "
      . $content_type;
    exit 0;
  }

  # Job must have a "method" field
  unless ( $job->{method} ) {
    ERROR 400, 'Missing Required Field',
      'A job update must have a "method" field!';
    exit 0;
  }

  return $job;
}

# Check the consistency of a posted oar resource and load it into a hashref
sub check_resource($$) {
  my $data         = shift;
  my $content_type = shift;
  my $resource;

  # content_type may be of the form "application/json; charset=UTF-8"
  ($content_type)=split(/\s*;\s*/,$content_type);

  # If the data comes in the YAML format
  if ( $content_type eq 'text/yaml' ) {
    $resource=import_yaml($data);
  }

  # If the data comes in the JSON format
  elsif ( $content_type eq 'application/json' ) {
    $resource=import_json($data);
  }

  # If the data comes from an html form
  elsif ( $content_type eq 'application/x-www-form-urlencoded' ) {
    $resource=import_html_form($data);
  }

  # We expect the data to be in YAML or JSON format
  else {
    ERROR 406, 'Job description must be in YAML or JSON',
      "The correct format for a job request is text/yaml or application/json. "
      . $content_type;
    exit 0;
  }

  # Resource must have a "hostname" or "network_address" field
  unless ( $resource->{hostname} or $resource->{properties}->{network_address} ) {
    ERROR 400, 'Missing Required Field',
      'A resource must have a hosname field or a network_address property!';
    exit 0;
  }

  # Fill hostname with network_address if provided
  if ( ! $resource->{hostname} && $resource->{properties}->{network_address} ) {
    $resource->{hostname}=$resource->{properties}->{network_address};
  }

  return $resource;
}


# Check the consistency of a posted grid job and load it into a hashref
sub check_grid_job($$) {
  my $data         = shift;
  my $content_type = shift;
  my $job;

  # content_type may be of the form "application/json; charset=UTF-8"
  ($content_type)=split(/\s*;\s*/,$content_type);

  # If the data comes in the YAML format
  if ( $content_type eq 'text/yaml' ) {
    $job=import_yaml($data);
  }

  # If the data comes in the JSON format
  elsif ( $content_type eq 'application/json' ) {
    $job=import_json($data);
  }

  # If the data comes from an html form
  elsif ( $content_type eq 'application/x-www-form-urlencoded' ) {
    $job=import_html_form($data);
  }

  # We expect the data to be in YAML or JSON format
  else {
    ERROR 406, 'Job description must be in YAML or JSON',
      "The correct format for a job request is text/yaml or application/json. "
      . $content_type;
    exit 0;
  }

  # Job must have a "resources" or "file" field
  unless ( $job->{resources} or $job->{file} ) {
    ERROR 400, 'Missing Required Field',
      'A grid job must have a resources or file field!';
    exit 0;
  }

  # Clean options with an empty parameter that is normaly required
  parameter_option($job,"walltime");
  parameter_option($job,"queue");
  parameter_option($job,"identity_file");
  parameter_option($job,"timeout");
  parameter_option($job,"program");
  parameter_option($job,"type");
  parameter_option($job,"start_date");
  parameter_option($job,"directory");

  # Manage toggle options (no parameter)
  toggle_option($job,"FORCE");
  toggle_option($job,"verbose");

  return $job;
}

##############################################################################
# Other functions
##############################################################################

# APILIB Version
sub get_version() {
  return $VERSION;
}

# Return the cgi handler
sub get_cgi_handler() {
  return $q;
}

# Check if YAML is enabled or exits with an error
sub check_yaml() {
  unless ($YAMLenabled) {
    ERROR 400, 'YAML not enabled', 'YAML perl module not loaded!';
    exit 0;
  }
}

# Check if JSON is enabled or exits with an error
sub check_json() {
  unless ($JSONenabled) {
    ERROR 400, 'JSON not enabled', 'JSON perl module not loaded!';
    exit 0;
  }
}

# Clean a hash from a key having an empty value (for options with parameter)
sub parameter_option($$) {
  my $hash = shift;
  my $key = shift;
  if ( defined($hash->{"$key"}) && $hash->{"$key"} eq "" ) {
    delete($hash->{"$key"})
  }
}

# Remove a toggle option if value is 0
sub toggle_option($$) {
  my $job = shift;
  my $option = shift;
  if (defined($job->{$option})) {
    if ($job->{$option} eq "0" ) {
      delete($job->{$option});
    }
    else { $job->{$option}="" ; };
  }
}

# Send a command and returns the output or exit with an error
sub send_cmd($$) {
  my $cmd=shift;
  my $error_name=shift;
  my $cmdRes = `$cmd 2>&1`;
  my $err    = $?;
  if ( $err != 0 ) {
    #$err = $err >> 8;
    ERROR(
      400,
      "$error_name error",
      "$error_name command exited with status $err: $cmdRes"
    );
    exit 0;
  }
  else { return $cmdRes; }
}

# Get a ssh key file
sub get_key($$$) {
  my $file=shift;
  my $key_type=shift;
  my $OARDODO_CMD=shift;
  if ($key_type ne "private") { 
    $file = $file.".pub";
  }
  my $cmdRes = apilib::send_cmd("$OARDODO_CMD cat $file","Cat keyfile");
  if ($key_type eq "private" && ! $cmdRes =~ m/.*BEGIN.*KEY/ ) {
    apilib::ERROR( 400, "Error reading file",
      "The keyfile is unreadable or incorrect" );
  }
  else {
    return $cmdRes;
  }
}

return 1;
