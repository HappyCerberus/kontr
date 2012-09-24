#!/usr/bin/perl

use FISubmissionInternal;
use FISubmission;
use Lock;
use threads;
use Moose::Util::TypeConstraints;

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
	my $cmd="cd $basePath; ./kontr.pl ".$filename;
	if ($kontrLogFile) {
		$cmd .= " &>>$kontrLogFile";
	}
	system($cmd);
	
	#Remove internal submission
	$submission->remove();
	
	#Remove SVN lock
	$svnlock->remove_lock();
}
