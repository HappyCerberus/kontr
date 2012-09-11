#!/packages/run/links/bin/perl

use Session;
use SVN;
use HTMLGenerator;
use Mailer;
use Config::Tiny;
use strict;
use warnings;
use FISubmissionInternal;
use Lock;
use Moose::Util::TypeConstraints;

print "[KONTR] SESSION START\n";

my $submission = find_type_constraint('FISubmissionInternal')->coerce($ARGV[0]);
my $session = new Session($submission->user->login, $submission->homework->class, $submission->homework->name, $submission->runType);

my $different_submitter = 0;
#Different data source
if (exists $submission->config->{SVN} and exists $submission->config->{SVN}->{source}) {
	my $source_user = $submission->config->{SVN}->{source};
	print "<user>".$session->user->login." with source from ".$source_user."\n";
	$different_submitter = $session->user->login;
	$session->user(new StudentInfo(login => $source_user, class => $session->{'class'}));
}
else {
	print "<user>".$session->user->login."\n";
}

# Fetch data from SVN
my $svn = new SVN();
#Add revision if needed
if (exists $submission->config->{SVN} and exists $submission->config->{SVN}->{revision}) {
	$svn->revision($submission->config->{SVN}->{revision});
}
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
my $filepath = $Config->{Tests}->{stage_path}."/".$session->class."/".
	$session->task."/".$session->user->login."_".$session->timestamp; #Base path for emails saved into file

#Student email
my $subj;
if ($session->run_type eq 'student')
{ $subj = $Config->{Global}->{student_subj}; }
else { $subj = $Config->{Global}->{result_subj}; }
 
my $student = new Mailer(	to => ($different_submitter ? $different_submitter : $session->user->email), 
				reply => $session->user->teacher->email,
				subject => "[".$session->class."][".$session->task."]".$subj,
				template => 'full_mail');
$student->set_param(summary => $session->summary_log);
$student->set_param(log => $session->user_log->data);
$student->set_param(student => $session->user->name);
$student->set_param(uco => $session->user->uco);
$student->set_param(login => $session->user->login);
$student->set_param(cvicici => $session->user->teacher->name);

my @sparam;
foreach ($session->student_attachments)
{
	push @sparam, $_->filename;
	push @sparam, $_->name;
	push @sparam, $_->mime;
}
$student = $student->message(@sparam);

#Save student email into file
open my $student_email, ">$filepath/student_email";
$student->print_body($student_email); 
close $student_email;

#Send student email
$student->send;

#Teacher email
my $teacher = new Mailer(	to => ($different_submitter ? $different_submitter : $session->user->teacher->email), 
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
foreach ($session->teacher_attachments)
{
	push @param, $_->filename;
	push @param, $_->name;
	push @param, $_->mime;
}
$teacher = $teacher->message(@param);

#Save teacher email into file
open my $teacher_email, ">$filepath/teacher_email";
$teacher->print_body($teacher_email); 
close $teacher_email;

#But send it only if needed
if ($session->run_type eq 'teacher' or $different_submitter) {	$teacher->send; }

#Log output from reporter
my $report_log = Config::Tiny->new->read('config.ini')->{Global}->{report_log};
if ($report_log) {
	my $report = $session->timestamp.' '.$submission->user->login.' '.$svn->revision.' '.
		$submission->homework->class.' '.$submission->homework->name.' '.$submission->runType.' '.
		$different_submitter.': '.join(' ', $session->get_tags).'; '.
		join(' ', sub { my %points = $session->get_points(); map { $_.'='.$points{$_} } keys %points; }->() ).
		' # '.$session->get_summary;
	open my $report_file, ">$filepath/report";
	print $report_file $report;
	close $report_file;
	my $lock = Lock->new(name => 'report_lock', directory => '.');
	$lock->obtain_lock;
	open $report_file, ">>$report_log";
	print $report_file $report;
	close $report_file;
	$lock->remove_lock;
}

print "[KONTR] SESSION DONE\n";
$submission->remove();
