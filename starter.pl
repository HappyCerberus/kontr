#!/usr/bin/perl

use FISubmissionInternal;
use FISubmission;
use Lock;
use threads;
use Moose::Util::TypeConstraints;
use File::Copy;
use File::Slurp;

sub lock_dir {
	Config::Tiny->new->read('config.ini')->{Tests}->{stage_path}
}

sub run_new {
	threads->list(threads::running) < 5;
}

my $kontrLogFile = Config::Tiny->new->read('config.ini')->{Global}->{log_file};
my $basePath = Config::Tiny->new->read('config.ini')->{Global}->{base_path};
my $debug = 0;
my $lock = Lock->new(name => 'master_lock', directory => lock_dir());

if (not $lock->add_lock) { exit 1; } #If another kontr is running, exit

FISubmission->cleanup(); #Cleanup bad submissions and time locks
my @threads; #All threads

if ($debug) { print "Internal\n"; }
foreach (FISubmissionInternal->get_all()) { #Start threads from submissions that are already in internal directory
	if ($debug) { print $_."\n"; }
	while (not run_new()) {
		sleep (1);
	}
	my $t = threads->new(\&start, ($_, 'FISubmissionInternal') );
	push @threads, $t;
}

if ($debug) { print "Public\n"; }
foreach (FISubmission->get_all()) { #Start threads from public submissions
	if ($debug) { print $_."\n"; }
	while (not run_new()) {
		sleep (1);
	}
	my $t = threads->new(\&start, ($_, 'FISubmission') );
	push @threads, $t;
}

foreach (@threads) { #Wait for all threads
	$_->join(); 
}

$lock->remove_lock(); #Remove lock after it is all finished

sub start { #Asynchronous kontr start
	my $filename = shift;
	my $class = shift;
	
	my $submission = find_type_constraint($class)->coerce($filename);
	my $login = $submission->user->login;
	#my $class = $submission->homework->class;
	#my $task = $submission->homework->name;
	#my $type = $submission->mode;
	
	#Different data source
	if (exists $submission->config->{SVN} and exists $submission->config->{SVN}->{source}) {
		$login = $submission->config->{SVN}->{source};
	}
	
	if ($class eq 'FISubmission') {
		$submission->corrected(); #Correction lock
		$filename = $submission->obtain_export(FISubmissionInternal->get_dir()); #Obtain export file
		$submission = find_type_constraint('FISubmissionInternal')->coerce($filename);
	}
	
	my $svnlock = Lock->new(name => "svnlock_$login", directory => lock_dir());
	$svnlock->obtain_lock(); #SVN lock
	
	#my $cmd="cd /home/xtoth1/kontrNG;/packages/run/links/bin/perl kontr.pl ".$login." ".$class." ".$task." ".$type." &>>/home/xtoth1/kontrNG/log2";
	
	my $userLog;
	my $cmd = "cd $basePath; ./kontr.pl $filename";
	if ($kontrLogFile) {
		$userLog = $kontrLogFile."_$login";
		$cmd .= " $userLog.path &>>$userLog.log";
	}
	system($cmd);
	
	#If file log enabled
	if($kontrLogFile)
	{
		my $stagePath;
		my $initial;
		
		#If path file exists
		if(-e "$userLog.path")
		{	
			#Get stage path of current submission and remove path file, silence errors
			$stagePath = `cat $userLog.path 2> /dev/null; rm $userLog.path &> /dev/null`;
			$initial = $stagePath;
		}
		else
		{
			$initial = "[ERROR]: unknown path";
		}
		
		#Append number of lines to initial log line
		my @lines = read_file("$userLog.log");
		my $nol = @lines;
		$initial .= " $nol";
		
		#Lock main kontr.pl log
		my $logLock = Lock->new(name => "kontr.pl_log_lock", directory => lock_dir());
		$logLock->obtain_lock();
		
		#Append to main log
		$cmd = "echo $initial | cat - $userLog.log >> $kontrLogFile";
		system($cmd);
		
		#Remove lock asap
		$logLock->remove_lock();
		
		#Move submission-specific log to stagePath if stage dir exists
		if ($stagePath && -e $stagePath)
		{
			unless(move("$userLog.log", "$stagePath/kontr.pl"))
			{
				unlink "$userLog.log";
			}
		}
		else
		{
			unlink "$userLog.log";
		}

	}
	
	#Remove internal submission
	$submission->remove();
	
	#Remove SVN lock
	$svnlock->remove_lock();
}
