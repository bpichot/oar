#!/usr/bin/perl
# $Id$
#Almighty module which changes node state

use English;
use oar_iolib;
use Data::Dumper;
use oar_Judas qw(oar_debug oar_warn oar_error send_log_by_email set_current_log_category);
use IO::Socket::INET;
use oar_conflib qw(init_conf dump_conf get_conf is_conf);
use strict;

# Log category
set_current_log_category('main');

init_conf($ENV{OARCONFFILE});
my $Remote_host = get_conf("SERVER_HOSTNAME");
my $Remote_port = get_conf("SERVER_PORT");
my $Cpuset_field = get_conf("JOB_RESOURCE_MANAGER_PROPERTY_DB_FIELD");
my $Healing_exec_file = get_conf("SUSPECTED_HEALING_EXEC_FILE");
my @resources_to_heal;

my $Exit_code = 0;

my $base = iolib::connect();
iolib::lock_table($base,["resources","assigned_resources","jobs","job_state_logs","event_logs","event_log_hostnames","frag_jobs","moldable_job_descriptions","challenges","job_types","job_dependencies","job_resource_groups","job_resource_descriptions","resource_logs"]);

# Check event logs
my @events_to_check = iolib::get_to_check_events($base);
foreach my $i (@events_to_check){
    oar_debug("[NodeChangeState] Check event for the job $i->{job_id} with type $i->{type}\n");
    my $job = iolib::get_job($base,$i->{job_id});
    
    ####################################################
    # Check if we must expressely change the job state #
    ####################################################
    if ($i->{type} eq "SWITCH_INTO_TERMINATE_STATE"){
        iolib::set_job_state($base,$i->{job_id},"Terminated");
    }elsif ($i->{type} eq "SWITCH_INTO_ERROR_STATE"){
        iolib::set_job_state($base,$i->{job_id},"Error");
    }

    #########################################
    # Check if we must change the job state #
    #########################################
    if (
        ($i->{type} eq "PING_CHECKER_NODE_SUSPECTED") ||
        ($i->{type} eq "CPUSET_ERROR") ||
        ($i->{type} eq "PROLOGUE_ERROR") ||
        ($i->{type} eq "CANNOT_WRITE_NODE_FILE") ||
        ($i->{type} eq "CANNOT_WRITE_PID_FILE") ||
        ($i->{type} eq "USER_SHELL") ||
        ($i->{type} eq "EXTERMINATE_JOB") ||
        ($i->{type} eq "CANNOT_CREATE_TMP_DIRECTORY") ||
        ($i->{type} eq "LAUNCHING_OAREXEC_TIMEOUT") ||
        ($i->{type} eq "RESERVATION_NO_NODE") ||
        ($i->{type} eq "BAD_HASHTABLE_DUMP") ||
        ($i->{type} eq "SSH_TRANSFER_TIMEOUT") ||
        ($i->{type} eq "EXIT_VALUE_OAREXEC")
       ){
        if (($job->{reservation} eq "None") or ($i->{type} eq "RESERVATION_NO_NODE") or ($job->{assigned_moldable_job} == 0)){
            iolib::set_job_state($base,$i->{job_id},"Error");
        }elsif ($job->{reservation} ne "None"){
            if (
                ($i->{type} ne "PING_CHECKER_NODE_SUSPECTED") &&
                ($i->{type} ne "CPUSET_ERROR")
               ){
                iolib::set_job_state($base,$i->{job_id},"Error");
            }
        }
    }
    
    if (
        ($i->{type} eq "CPUSET_CLEAN_ERROR") ||
        ($i->{type} eq "EPILOGUE_ERROR")
       ){
        # At this point the job was executed normally
        # The state is changed here to avoid to schedule other jobs
        # on nodes that will be Suspected
        iolib::set_job_state($base,$i->{job_id},"Terminated");
    }
    
    #######################################
    # Check if we must suspect some nodes #
    #######################################
    if (($i->{type} eq "PING_CHECKER_NODE_SUSPECTED") ||
        ($i->{type} eq "CPUSET_ERROR") ||
        ($i->{type} eq "CPUSET_CLEAN_ERROR") ||
        ($i->{type} eq "SUSPEND_ERROR") ||
        ($i->{type} eq "RESUME_ERROR") ||
        ($i->{type} eq "PROLOGUE_ERROR") ||
        ($i->{type} eq "EPILOGUE_ERROR") ||
        ($i->{type} eq "CANNOT_WRITE_NODE_FILE") ||
        ($i->{type} eq "CANNOT_WRITE_PID_FILE") ||
        ($i->{type} eq "USER_SHELL") ||
        ($i->{type} eq "EXTERMINATE_JOB") ||
        ($i->{type} eq "CANNOT_CREATE_TMP_DIRECTORY") ||
        ($i->{type} eq "SSH_TRANSFER_TIMEOUT") ||
        ($i->{type} eq "BAD_HASHTABLE_DUMP") ||
        ($i->{type} eq "LAUNCHING_OAREXEC_TIMEOUT") ||
        ($i->{type} eq "EXIT_VALUE_OAREXEC")
       ){
        my @hosts;
        my $finaud_tag = "NO";
        # Restrict Suspected state to the first node (node really connected with OAR) for some event types
        if (($i->{type} eq "PING_CHECKER_NODE_SUSPECTED")
        ){
            @hosts = iolib::get_hostname_event($base,$i->{event_id});
            $finaud_tag = "YES";
        }elsif (($i->{type} eq "CPUSET_ERROR") ||
                ($i->{type} eq "CPUSET_CLEAN_ERROR") ||
                ($i->{type} eq "SUSPEND_ERROR") ||
                ($i->{type} eq "RESUME_ERROR")
               ){
            @hosts = iolib::get_hostname_event($base,$i->{event_id});
        }else{
            @hosts = iolib::get_job_host_log($base,$job->{assigned_moldable_job});
            if (($i->{type} ne "EXTERMINATE_JOB") &&
                ($i->{type} ne "PROLOGUE_ERROR") &&
                ($i->{type} ne "EPILOGUE_ERROR") &&
                ($i->{type} ne "CPUSET_ERROR") &&
                ($i->{type} ne "CPUSET_CLEAN_ERROR")
            ){
                @hosts = ($hosts[0]);
            }else{
                # If we exterminate a job and the cpuset feature is configured
                # then the CPUSET clean will tell us which nodes are dead
                my $cpuset_field = get_conf("JOB_RESOURCE_MANAGER_PROPERTY_DB_FIELD");
                if (defined($cpuset_field) && ($i->{type} eq "EXTERMINATE_JOB")){
                    @hosts = ($hosts[0]);
                }
            }
        }

        my %already_treated_host;
        foreach my $j (@hosts){
            next if ((defined($already_treated_host{$j}) or ($j eq "")));
            $already_treated_host{$j} = 1;
            #my @free_resources = iolib::get_current_free_resources_of_node($base, $j);
            #if ($#free_resources >= 0){
            #    foreach my $r (@free_resources){
                    #iolib::set_resource_state($base,$r,"Suspected",$finaud_tag);
                    iolib::set_node_state($base,$j,"Suspected",$finaud_tag);
                    foreach my $r (iolib::get_all_resources_on_node($base,$j)){
                      push(@resources_to_heal,"$r $j");
                    }
                    $Exit_code = 1;
            #    }
            #}
        }
        oar_warn("[NodeChangeState] error ($i->{type}) on the nodes:\n\n@hosts\n\nSo we are suspecting corresponding free resources\n");
        send_log_by_email("Suspecting nodes","[NodeChangeState] error ($i->{type}) on the nodes:\n\n@hosts\n\nSo we are suspecting corresponding free resources\n");
    }
    
    ########################################
    # Check if we must stop the scheduling #
    ########################################
    if (
        ($i->{type} eq "SERVER_PROLOGUE_TIMEOUT") ||
        ($i->{type} eq "SERVER_PROLOGUE_EXIT_CODE_ERROR") ||
        ($i->{type} eq "SERVER_EPILOGUE_TIMEOUT") ||
        ($i->{type} eq "SERVER_EPILOGUE_EXIT_CODE_ERROR")
       ){
        oar_warn("[NodeChangeState] Server admin script error so we stop all scheduling queues : $i->{type}. When the error will be fixed then you can execute : oarnotify -E\n");
        send_log_by_email("Stop all scheduling queues","[NodeChangeState] Server admin script error so we stop all scheduling queues : $i->{type}. When the error will be fixed then you can execute : oarnotify -E\n");
        iolib::stop_all_queues($base);
        iolib::set_job_state($base,$i->{job_id},"Error");
    }

    #####################################
    # Check if we must resubmit the job #
    #####################################
    if (
        ($i->{type} eq "SERVER_PROLOGUE_TIMEOUT") ||
        ($i->{type} eq "SERVER_PROLOGUE_EXIT_CODE_ERROR") ||
        ($i->{type} eq "SERVER_PROLOGUE_ERROR") ||
        ($i->{type} eq "PING_CHECKER_NODE_SUSPECTED") ||
        ($i->{type} eq "CPUSET_ERROR") ||
        ($i->{type} eq "PROLOGUE_ERROR") ||
        ($i->{type} eq "CANNOT_WRITE_NODE_FILE") ||
        ($i->{type} eq "CANNOT_WRITE_PID_FILE") ||
        ($i->{type} eq "USER_SHELL") ||
        ($i->{type} eq "CANNOT_CREATE_TMP_DIRECTORY") ||
        ($i->{type} eq "LAUNCHING_OAREXEC_TIMEOUT")
       ){
        if (($job->{reservation} eq "None") and ($job->{job_type} eq "PASSIVE") and (iolib::is_job_already_resubmitted($base, $i->{job_id}) == 0)){
            my $new_job_id = iolib::resubmit_job($base,$i->{job_id});
            oar_warn("[NodeChangeState] We resubmit the job $i->{job_id} (new id = $new_job_id) because the event was $i->{type} and the job is neither a reservation nor an interactive job.\n");
            iolib::add_new_event($base,"RESUBMIT_JOB_AUTOMATICALLY",$i->{job_id},"An ERROR occured and we cannot launch this job so we resubmit it (new id = $new_job_id).");
        }
    }

    ####################################
    # Check Suspend/Resume job feature #
    ####################################
    if (
        ($i->{type} eq "HOLD_WAITING_JOB") ||
        ($i->{type} eq "HOLD_RUNNING_JOB") ||
        ($i->{type} eq "RESUME_JOB")
       ){
        if ((($i->{type} eq "HOLD_WAITING_JOB") or ($i->{type} eq "HOLD_RUNNING_JOB")) and (($job->{state} eq "Waiting"))){
            iolib::set_job_state($base,$job->{job_id},"Hold");
            if ($job->{job_type} eq "INTERACTIVE"){
                my ($addr,$port) = split(/:/,$job->{info_type});
                oar_Tools::notify_tcp_socket($addr,$port,"Start prediction: undefined (Hold)");
            }
        }elsif ((($i->{type} eq "HOLD_WAITING_JOB") or ($i->{type} eq "HOLD_RUNNING_JOB")) and (($job->{state} eq "Resuming"))){
            iolib::set_job_state($base,$job->{job_id},"Suspended");
            oar_Tools::notify_tcp_socket($Remote_host,$Remote_port,"Term");
        }elsif (($i->{type} eq "HOLD_RUNNING_JOB") and ($job->{state} eq "Running")){
            # Launch suspend command on all nodes

            ################
            # SUSPEND PART #
            ################
            if (defined($Cpuset_field)){
                my $cpuset_name = iolib::get_job_cpuset_name($base, $i->{job_id}) if (defined($Cpuset_field));
                my $cpuset_nodes = iolib::get_cpuset_values_for_a_moldable_job($base,$Cpuset_field,$job->{assigned_moldable_job});
                my $suspend_data_hash = {
                    name => $cpuset_name,
                };
                if (defined($cpuset_nodes)){
                    my $taktuk_cmd = get_conf("TAKTUK_CMD");
                    my $openssh_cmd = get_conf("OPENSSH_CMD");
                    $openssh_cmd = oar_Tools::get_default_openssh_cmd() if (!defined($openssh_cmd));
                    if (is_conf("OAR_SSH_CONNECTION_TIMEOUT")){
                        oar_Tools::set_ssh_timeout(get_conf("OAR_SSH_CONNECTION_TIMEOUT"));
                    }
                    my $suspend_file = get_conf("SUSPEND_RESUME_FILE");
                    $suspend_file = oar_Tools::get_default_suspend_resume_file() if (!defined($suspend_file));
                    $suspend_file = "$ENV{OARDIR}/$suspend_file" if ($suspend_file !~ /^\//);
                    my ($tag,@bad) = oar_Tools::manage_remote_commands([keys(%{$cpuset_nodes})],$suspend_data_hash,$suspend_file,"suspend",$openssh_cmd,$taktuk_cmd,$base);
                    if ($tag == 0){
                        my $str = "[NodeChangeState] [SUSPEND_RESUME] [$i->{job_id}] Bad suspend/resume file : $suspend_file\n";
                        oar_error($str);
                        iolib::add_new_event($base, "SUSPEND_RESUME_MANAGER_FILE", $i->{job_id}, $str);
                    }else{
                        if (($#bad < 0)){
                            iolib::suspend_job_action($base,$i->{job_id},$job->{assigned_moldable_job});
                            
                            my $suspend_script = get_conf("JUST_AFTER_SUSPEND_EXEC_FILE");
                            my $timeout = get_conf("SUSPEND_RESUME_SCRIPT_TIMEOUT");
                            $timeout = oar_Tools::get_default_suspend_resume_script_timeout() if (!defined($timeout));
                            if (defined($suspend_script)){
                                # Launch admin script
                                my $script_error = 0;
                                eval {
                                    $SIG{ALRM} = sub { die "alarm\n" };
                                    alarm($timeout);
                                    oar_debug("[NodeChangeState] [$i->{job_id}] LAUNCH the script just after the suspend : $suspend_script $i->{job_id}\n");
                                    $script_error = system("$suspend_script $i->{job_id}");
                                    oar_debug("[NodeChangeStat]e [$i->{job_id}] END the script just after the suspend : $suspend_script $i->{job_id}\n");
                                    alarm(0);
                                };
                                if( $@ || ($script_error != 0)){
                                    my $str = "[NodeChangeState] [$i->{job_id}] Suspend script error (so we are resuming it): $@; return code = $script_error\n";
                                    oar_warn($str);
                                    send_log_by_email("Suspend script error","$str");
                                    iolib::add_new_event($base,"SUSPEND_SCRIPT_ERROR",$i->{job_id},$str);
                                    iolib::set_job_state($base,$i->{job_id},"Resuming");
                                    oar_Tools::notify_tcp_socket($Remote_host,$Remote_port,"Qresume");
                                }
                            }
                        }else{
                            my $str = "[NodeChangeState] [SUSPEND_RESUME] [$i->{job_id}] Error on several nodes : @bad\n";
                            oar_error($str);
                            iolib::add_new_event_with_host($base,"SUSPEND_ERROR",$i->{job_id},$str,\@bad);
                            iolib::frag_job($base,$i->{job_id});
                            # A Leon must be run
                            $Exit_code = 2;
                        }
                    }
                }
                oar_Tools::notify_tcp_socket($Remote_host,$Remote_port,"Term");
            }
            ######################
            # SUSPEND PART, END  #
            ######################
        }elsif (($i->{type} eq "RESUME_JOB") and ($job->{state} eq "Suspended")){
            iolib::set_job_state($base,$i->{job_id},"Resuming");
            oar_Tools::notify_tcp_socket($Remote_host,$Remote_port,"Qresume");
        }elsif (($i->{type} eq "RESUME_JOB") and ($job->{state} eq "Hold")){
            iolib::set_job_state($base,$job->{job_id},"Waiting");
            oar_Tools::notify_tcp_socket($Remote_host,$Remote_port,"Qresume");
        }
    }
    
    ####################################
    # Check if we must notify the user #
    ####################################
    if (
        ($i->{type} eq "FRAG_JOB_REQUEST")
       ){
            my ($addr,$port) = split(/:/,$job->{info_type});
            oar_Judas::notify_user($base,$job->{notify},$addr,$job->{job_user},$job->{job_id},$job->{job_name},"INFO","Your job was asked to be deleted - $i->{description}");
    }
     
    iolib::check_event($base, $i->{type}, $i->{job_id});
}


# Treate nextState field
my %resources_to_change = iolib::get_resources_change_state($base);

# A Term command must be added in the Almighty
oar_debug("[NodeChangeState] number of resources to change state = ".keys(%resources_to_change)."\n");
if (keys(%resources_to_change) > 0){
    $Exit_code = 1;
}

my %debug_info;
foreach my $i (keys(%resources_to_change)){
    my $resource_info = iolib::get_resource_info($base,$i);
    if ($resource_info->{state} ne $resources_to_change{$i}){
        iolib::set_resource_state($base,$i,$resources_to_change{$i},$resource_info->{next_finaud_decision});
        iolib::set_resource_nextState($base,$i,'UnChanged');

        $debug_info{$resource_info->{network_address}}->{$i} = $resources_to_change{$i};

        if ($resources_to_change{$i} eq 'Suspected') {
          push(@resources_to_heal,$i." ".$resource_info->{network_address});
        }
        
        if (($resources_to_change{$i} eq 'Dead') || ($resources_to_change{$i} eq 'Absent')){
            oar_debug("[NodeChangeState] Check jobs to delete on $i ($resource_info->{network_address}):\n");
            my @jobs = iolib::get_resource_job_to_frag($base,$i);
            foreach my $j (@jobs){
                oar_debug("[NodeChangeState]\tThe job $j is fragging.\n");
                iolib::frag_job($base,$j);
                # A Leon must be run
                $Exit_code = 2;
            }
            oar_debug("[NodeChangeState] Check done\n");
        }
    }else{
        oar_debug("[NodeChangeState] ($resource_info->{network_address}) $i is already in the $resources_to_change{$i} state\n");
        iolib::set_resource_nextState($base,$i,'UnChanged');
    }
}

my $str;
foreach my $h (keys(%debug_info)){
    $str .= "\n$h";
    foreach my $r (keys(%{$debug_info{$h}})){
        $str .= "\n\t$r --> $debug_info{$h}->{$r}";
    }
    $str .= "\n";
}
if (defined($str)){
    oar_warn("[NodeChangeState] Resource state changes requested:\n$str\n");
    send_log_by_email("Resource state modifications","[NodeChangeState] Resource state changes requested:\n$str\n");
}

iolib::unlock_table($base);
iolib::disconnect($base);

my $timeout_cmd = 10;
if (is_conf("SUSPECTED_HEALING_TIMEOUT")){
    $timeout_cmd = get_conf("SUSPECTED_HEALING_TIMEOUT");
}
if (defined($Healing_exec_file) && @resources_to_heal > 0){
    oar_warn("[NodeChangeState] Running healing script for suspected resources.\n");
    if (! defined(oar_Tools::fork_and_feed_stdin($Healing_exec_file, $timeout_cmd, \@resources_to_heal))){
        oar_error("[NodeChangeState] Try to launch the command $Healing_exec_file to heal resources, but the command timed out($timeout_cmd s).\n");
    }
}

exit($Exit_code);