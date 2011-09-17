#!/usr/bin/perl

use Session;
use SVN;
use HTMLGenerator;
use Mailer;
use Config::Tiny;
use strict;
use warnings;

print "[KONTR] SESSION START\n";

my $session = new Session(@ARGV);

# Fetch current SVN
my $svn = new SVN();
$svn->fetch($session);
exit 1 unless $svn->result eq 'success';

# Process the current session (run tests)
$session->process();

# Generate HTML files from sources
my $generator = new HTMLGenerator();
$generator->generate($session);

# Send emails
my $Config = Config::Tiny->new;
$Config = Config::Tiny->read('config.ini');
 
my $student = new Mailer(	to => $session->user->email, 
				reply => $session->user->teacher->email,
				subject => "[".$session->class."][".$session->task."]".$Config->{Global}->{result},
				template => 'full_mail');
$student->set_param(summary => $session->summary_log);
$student->set_param(log => $session->user_log->data);
$student->send();

if ($session->run_type eq 'teacher')
{
	# Send emails
	my $teacher = new Mailer(	to => $session->user->email, 
					reply => $session->user->teacher->email,
					subject => "[".$session->class."][".$session->task."]".$Config->{Global}->{result},
					template => 'full_mail');
	$teacher->set_param(summary => $session->summary_log);
	$teacher->set_param(log => $session->teacher_log->data);

	my @param;
	foreach ($generator->files)
	{
		my $short = `basename $_`;
		chomp $short;
		push @param, $_;
		push @param, $short;
		push @param, 'text/html';
	}
	$teacher->send(@param);
}

print "[KONTR] SESSION DONE\n";				
