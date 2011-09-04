# Copyright (c) 2011 Mgr. Simon Toth (kontakt@simontoth.cz)
#
# Lincensed under the MIT lincense:
# http://www.opensource.org/licenses/mit-license.php

package Session;

use Moose;
use Moose::Util::TypeConstraints;

use StudentInfo;
use MasterTest;
use Log::Message::Simple;
use Config::Tiny;

use warnings;
use strict;

has 'register' => ( traits => ['Hash'], is => 'rw', isa => 'HashRef[Str]', default => sub { {} }, handles => { set_value => 'set', get_value => 'get', got_value => 'exists' }, );

has 'user' => ( is => 'rw', isa => 'StudentInfo' );
has 'class' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );
has 'task' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );

enum 'RunType', [ qw(student teacher) ];
has 'run_type' => ( is => 'rw', isa => 'RunType', default => 'student' );

has 'masters' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] }, handles => { register_master => 'push', masters_count => 'count', get_master => 'get' } );

has 'required_files' => ( traits => ['Array'], is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] } );
has 'repo_path' => ( traits => ['String'], is => 'rw', isa => 'Str', default => '' );

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
	pre_test();

	# verify settings run
	my $index;
	for ($index = 0; $index < $session->masters_count; $index++)
	{
		my $master_path = $script_path."/".$session->get_master($index);
		die "Registered master script \"".$master_path."\" does not exists." unless -f $master_path;
	}
	
	# processing run
	for ($index = 0; $index < $session->masters_count; $index++)
	{
		my $master_path = $script_path."/".$session->get_master($index);
		my $master_test = new MasterTest();
		eval `cat $master_path`;
		$master_test->run_tests($session);
	}

	post_test();
}

no Moose;
1;
