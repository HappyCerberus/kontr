#!/usr/bin/perl

use FISubmission;
use Lock;
use threads;
use Moose::Util::TypeConstraints;

sub lock_dir {
	Config::Tiny->new->read('config.ini')->{Tests}->{stage_path}
}

my $lock = Lock->new(name => 'master_lock', directory => lock_dir());

if (not $lock->add_lock) { exit 1; } #If another kontr is running, exit

FISubmission->cleanup(); #Cleanup bad submissions and time locks
my @threads; #All threads

foreach (FISubmission->get_all()) { #Start threads
	my $t = threads->new(\&start, $_);
	push @threads, $t;
}

foreach (@threads) { #Wait for all threads
	$_->join(); 
}

$lock->remove_lock(); #Remove lock after it is all finished

sub start { #Asynchronous kontr start
	my $filename = shift;
	
	my $submission = find_type_constraint('FISubmission')->coerce($_);
	my $login = $submission->user->login;
	#my $class = $submission->homework->class;
	#my $task = $submission->homework->name;
	#my $type = $submission->mode;
	
	$submission->toBeCorrected(); #Correction lock
	
	#Different data source
	if (exists $submission->config->{SVN} and exists $submission->config->{SVN}->{source}) {
		$login = $submission->config->{SVN}->{source};
	}
	
	my $svnlock = Lock->new(name => "svnlock_$login", directory => lock_dir());
	$svnlock->obtain_lock(); #SVN lock
	
	#my $cmd="cd /home/xtoth1/kontrNG;/packages/run/links/bin/perl kontr.pl ".$login." ".$class." ".$task." ".$type." &>>/home/xtoth1/kontrNG/log2";
	my $cmd="cd /home/xtoth1/kontrNG;/packages/run/links/bin/perl kontr.pl ".$_." &>>/home/xtoth1/kontrNG/log2";
	system($cmd);
	
	$submission->corrected(); #Delete submission file
	$svnlock->remove_lock();
	
}
