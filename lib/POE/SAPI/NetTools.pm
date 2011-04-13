package POE::SAPI::NetTools;

use 5.010001;
use strict;
use warnings;

use Data::Dumper;
use POE;

my $VERSION = '0.02';

my %results = (
	ipv4		=>	{
		ipv4list	=>	[],
		updated		=>	0,
		possible	=>	0,
		primary		=>	0,
		ports		=>	{
			open	=>	[],
			used	=>	[],
			ours	=>	[],
		},
	},
	ipv6		=>	{
		ipv6list	=>	[],
		updated		=>	0,
		possible	=>	0,
		primary		=>	0,
		ports		=>	{
			open	=>	[],
			used	=>	[],
			ours	=>	[],
		},
	},
);
my @queue;

sub new {
        my $package = shift;
        my %opts    = %{$_[0]} if ($_[0]);
        $opts{ lc $_ } = delete $opts{$_} for keys %opts;       # convert opts to lower case
        my $self = bless \%opts, $package;

        $self->{start} = time;
        $self->{cycles} = 0;

        $self->{me} = POE::Session->create(
                object_states => [
                        $self => {
                                _start          =>      'initLauncher',
                                loop            =>      'keepAlive',
                                _stop           =>      'killLauncher',
				ready		=>	'ready',
				detectNET	=>	'detectNET',
				populate	=>	'populate',
                        },
                        $self => [ qw (   ) ],
                ],
        );
}

sub keepAlive { $_[KERNEL]->delay('loop' => 1); }
sub killLauncher { warn "Session halting"; }
sub initLauncher {
	my ($self,$kernel) = @_[OBJECT,KERNEL];
	$kernel->yield('loop'); 
	$kernel->post($self->{parent},'register',{ name=>'NetTools', type=>'local' });
	$kernel->alias_set('NetTools');
}
sub ready {
	my ($self,$kernel,$subsys) = @_[OBJECT,KERNEL,ARG0];

	if ($subsys) {
		if ($subsys eq 'dbcache') { $self->{needed}->{dbcache} = 1; }
	}

	if (!$self->{needed}->{dbcache}) {
		$self->{needed}->{dbcache} = 0;
		$kernel->post('Scheduler','sysready','dbcache',['NetTools','ready']);
	}

	foreach my $key (keys %{$self->{needed}}){ if ($self->{needed}->{$key} == 0) { return; } }

	$kernel->post($self->{parent},"passback",{ type=>"debug", msg=>"SubSystems are ready - starting auto config", src=>'NetTools' });
	$kernel->yield('detectNET','ipv4');
}
sub detectNET {
	my ($self,$kernel,$dtype) = @_[OBJECT,KERNEL,ARG0];

	if (!$self->{os}) { $self->{os} ||= $^O; }
	
	if ($self->{os} eq 'freebsd') { 
		if ((!$self->{ifaces}) || (!$self->{ifaces}->{updated}) || ($self->{ifaces}->{updated} > (time - 1000))) {
			$self->{ifaces}->{list} = [map m#^(\w+\d.*?):#, `ifconfig`];
			$self->{ifaces}->{updated} = time;
		}
	} else {
		warn "TODO";
	}

	# Calls
	# ipv4 = primary ipv4 address
	# ipv4_list = full list of ipv4 addresses

	my $os = $self->{os};

	if ($dtype eq 'ipv4') {
		given($os) {
			when ('freebsd') {  
				foreach my $iface (@{$self->{ifaces}->{list}}) {
					$kernel->yield('populate','freebsd','ipv4',$iface);
				}
			}
			default {
				warn "Lick jhell <jhell\@irc.freenode.net, ##freebsd>";
			}
		}
	}
}
sub populate {
	my ($self,$kernel,$os,$version,$iface) = @_[OBJECT,KERNEL,ARG0,ARG1,ARG2];

	if ($os eq 'freebsd') {
		my @iface = `ifconfig $iface`;

		foreach my $key (@iface) {
			chomp($key);
			if ($key =~ m#.*?(inet|inet6|status)#) { 
				$kernel->post($self->{parent},"passback",{ type=>"debug", msg=>"($iface) paying attention to $key", src=>'NetTools' }); 
			}
			else { $kernel->post($self->{parent},"passback",{ type=>"debug", msg=>"Unknown ifconfig option $key", src=>'NetTools', level=>"verbose" }); }
		}
	}
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

POE::SAPI::NetTools - Perl/POE Core module for POE::SAPI

=head1 SYNOPSIS

  use POE::SAPI::NetTools;

=head1 DESCRIPTION

This is a CORE module of L<POE::SAPI> and should not be called directly.

=head2 EXPORT

None by default.

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Paul G Webster, E<lt>paul@daemonrage.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Paul G Webster

All rights reserved.

Redistribution and use in source and binary forms are permitted
provided that the above copyright notice and this paragraph are
duplicated in all such forms and that any documentation,
advertising materials, and other materials related to such
distribution and use acknowledge that the software was developed
by the 'blank files'.  The name of the
University may not be used to endorse or promote products derived
from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.


=cut
