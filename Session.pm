# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Session;

use Moose;
use Moose::Util::TypeConstraints;
use DetailedLog;

use StudentInfo;
use MasterTest;
use Log::Message::Simple;
use Config::Tiny;
use POSIX;
use Attachment;
use Report;

use warnings;
use strict;

has 'timestamp' => (traits => ['String'], is => 'rw', isa => 'Str', default => sub { POSIX::strftime("%Y_%m%d_%H%M%S", localtime); } );

has 'register' => ( traits => ['Hash'], is => 'rw', isa => 'HashRef[Str]', default => sub { {} }, handles => { set_value => 'set', get_value => 'get', got_value => 'exists', remove_value => 'delete' }, );

has 'user' => ( is => 'rw', isa => 'StudentInfo' );
has 'class' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'task' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );

enum 'RunType', [ qw(student teacher) ];
has 'run_type' => ( is => 'rw', isa => 'RunType', default => 'student' );

has 'masters' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { register_master => 'push', masters_count => 'count', get_master => 'get' } );

has 'available_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { available_file => 'grep', add_available_file => 'push', all_available_files => 'elements' } );
has 'repo_path' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );

has 'user_log' => ( is => 'rw', isa => 'Log', default => sub { return new Log(); } );
has 'teacher_log' => ( is => 'rw', isa => 'Log', default => sub { return new Log(); } );

has 'summary_log' => ( traits => ['String'],  is => 'rw', isa => 'Str', default => '', handles => { add_summary => 'append'  } );

has 'attach_teacher' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Attachment]', default => sub { [] }, handles => { add_teacher_attach => 'push', teacher_attach_count => 'count', get_teacher_attach => 'get', teacher_attachments => 'elements' } );
has 'attach_student' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Attachment]', default => sub { [] }, handles => { add_student_attach => 'push', student_attach_count => 'count', get_student_attach => 'get', student_attachments => 'elements' } );

has 'reports' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Report]', default => sub { [] }, handles => { all_reports => 'elements', new_report => 'push' } );

has 'detailed' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef', default => sub { [] }, handles => { add_detailed => 'push' } );

# user, class, type
sub BUILDARGS
{
	my $class = shift;

	die "Wrong number of parameters for session" unless scalar @_ == 4;

	my $p_login = shift;
	my $p_class = shift;
	my $p_task = shift;
	my $p_type = shift;

	return { 'login', $p_login, 'class' , $p_class, 'task', $p_task, 'run_type', $p_type };
}

sub BUILD
{
	my $self = shift;
	my $args = shift;

	$self->user( new StudentInfo(login => $args->{'login'}, class => $args->{'class'}) );
}

sub get_script_path
{
	my $session = shift;
	my $Config = Config::Tiny->new;
	$Config = Config::Tiny->read('config.ini');

	return $Config->{Tests}->{script_path}."/".$session->class."/".$session->task;
}

sub process
{
	my $session = shift;
	my $script_path = $session->get_script_path;
	my $session_path = $script_path."/session.pl";

	our $debug = 1;

	print $session_path."\n";
	eval `cat $session_path`;
	print $@ if $@;
	pre_test();

	# verify settings run
	my $index;
	for ($index = 0; $index < $session->masters_count; $index++)
	{
		my $master_path = $script_path."/".$session->get_master($index);
		die "Registered master script \"".$master_path."\" does not exists." unless -f $master_path;
	}
	
	my $log = DetailedLog->new(session => $session);
	
	# processing run
	for ($index = 0; $index < $session->masters_count; $index++)
	{
		my $master_path = $script_path."/".$session->get_master($index);
		my $master_test = new MasterTest();
		eval `cat $master_path`;
		print $@ if $@;
		$master_test->run_tests($session, $log);
		$session->add_detailed($master_test->detailed_log);
	}

	post_test();
}

sub has_tag
{
	my $self = shift;
	my $tag = shift;
	
	return scalar grep { $_->hasTag( sub { $_ eq $tag} ) } $self->all_reports;
}

sub get_points
{
	my $self = shift;
	
	my %points = Report::sumPoints([$self->all_reports]);
	
	if (@_) {
		my $key = shift;
		
		if (exists $points{$key}) {
			return $points{$key};
		}
		return 0;
	}
	return %points;
}

sub get_tags
{
	my $self = shift;
	
	Report::sumTags([$self->all_reports]);
}

sub get_summary
{
	my $self = shift;
	
	join(' # ', map { $_->summary } $self->all_reports);
}

no Moose;
1;
