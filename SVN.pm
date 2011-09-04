package SVN;

use strict;
use warnings;

use Moose;
use Mailer;
use Config::Tiny;
use Exec;
use Moose::Util::TypeConstraints;

enum 'SVNResult', [ qw(success cant_update cant_download missing_files) ];
has 'result' => ( is => 'rw', isa => 'SVNResult', default => 'success' );

sub fetch
{
	my $self = shift;
	my $session = shift;

	my $Config = Config::Tiny->new;
	$Config = Config::Tiny->read('config.ini');

	my $url = $Config->{SVN}->{base_url}."/".$session->user->login."_".$session->class;
	my $path = $Config->{SVN}->{base_path}."/".$session->user->login."_".$session->class;

	if (-d $path) # directory already exists - should update
	{
		if (system("svn update $path") != 0)
		{ 
			$self->result('cant_update'); 

			# report error by email
			my $mail = new Mailer(	to => $session->user->email, 
						reply => $Config->{Global}->{admin}, 
						subject => $Config->{SVN}->{cant_update_subj},
						template => 'svn_cant_update');
			$mail->set_param(repo => $url);
			$mail->send();

			return;
		}
		else
		{ $self->result('success'); }
	}
	else
	{
		if (system("svn checkout $url $path") != 0)
		{ 
			$self->result('cant_download'); 
			
			# report error by email
			my $mail = new Mailer(	to => $session->user->email, 
						reply => $Config->{Global}->{admin},
						subject => $Config->{SVN}->{cant_download_subj},
						template => 'svn_cant_download');
			$mail->set_param(repo => $url);
			$mail->send();
			
			return;
		}
		else
		{ $self->result('success'); }
	}

	$session->repo_path($path);

	if ($self->result eq 'success')
	{
		my $file_check = $Config->{Global}->{ext_bins}."/file_check";
		my $check_output = $Config->{Tests}->{stage_path}."/file_check_".$$;
		my $check_input = $Config->{Tests}->{files_path}."/".$session->class."/".$session->task."/required_files";
		my $check = new Exec(cmd => $file_check, stdout_path => $check_output); 
		$check->exec($path."/".$session->task, $check_input);

		if ($check->exit_value == 3)
		{
			my $files = `cat $check_output`;
			my $mail = new Mailer(	to => $session->user->email,
						reply => $Config->{Global}->{admin},
						subject => $Config->{SVN}->{junk_files_subj},
						template => 'svn_junk_files');
			$mail->set_param(files => $files);
			$mail->send();
		}
		elsif ($check->exit_value == 2)
		{
			my $files = `cat $check_output`;
			my $mail = new Mailer(	to => $session->user->email,
						reply => $Config->{Global}->{admin},
						subject => $Config->{SVN}->{missing_files_subj},
						template => 'svn_missing_files');
			$mail->set_param(files => $files);
			$mail->send();
			$self->result('missing_files');
		}

		unlink($check_output);
	}
}

no Moose;
__PACKAGE__->meta->make_immutable;
