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

my $subj;
if ($session->run_type eq 'student')
{ $subj = $Config->{Global}->{student_subj}; }
else { $subj = $Config->{Global}->{result_subj}; }
 
my $student = new Mailer(	to => $session->user->email, 
				reply => $session->user->teacher->email,
				subject => "[".$session->class."][".$session->task."]".$subj,
				template => 'full_mail');
$student->set_param(summary => $session->summary_log);
$student->set_param(log => $session->user_log->data);
$student->set_param(student => $session->user->name);
$student->set_param(uco => $session->user->uco);
$student->set_param(login => $session->user->login);
$student->set_param(cvicici => $session->user->teacher->name);
$student->send();

if ($session->run_type eq 'teacher')
{
	# Send emails
	my $teacher = new Mailer(	to => $session->user->teacher->email, 
					reply => $session->user->email,
					subject => "[".$session->class."][".$session->task."]".$subj,
					template => 'full_mail');
	$teacher->set_param(summary => $session->summary_log);
	$teacher->set_param(log => $session->teacher_log->data);
	$teacher->set_param(student => $session->user->name);
	$teacher->set_param(uco => $session->user->uco);
	$teacher->set_param(login => $session->user->login);
	$teacher->set_param(cvicici => $session->user->teacher->name);

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
