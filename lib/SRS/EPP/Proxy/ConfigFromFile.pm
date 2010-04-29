package SRS::EPP::Proxy::ConfigFromFile;

use Moose::Role;
with 'MooseX::ConfigFromFile', { -excludes => "new_with_config" };

sub new_with_config {
    my ($class, %opts) = @_;

    my $configfile;

    if(defined $opts{configfile}) {
        $configfile = $opts{configfile}
    }
    else {
        $configfile = $class->configfile
    }

    if(defined $configfile) {
        %opts = (%{$class->get_config_from_file($configfile)}, %opts);
    }

    $class->new(%opts);
}

no Moose::Role; 1;

__END__

=pod

=head1 NAME

MooseX::ConfigFromFile - An abstract Moose role for setting attributes from a configfile

=head1 SYNOPSIS

  ########
  ## A real role based on this abstract role:
  ########

  package MooseX::SomeSpecificConfigRole;
  use Moose::Role;
  
  with 'MooseX::ConfigFromFile';
  
  use Some::ConfigFile::Loader ();

  sub get_config_from_file {
    my ($class, $file) = @_;

    my $options_hashref = Some::ConfigFile::Loader->load($file);

    return $options_hashref;
  }


  ########
  ## A class that uses it:
  ########
  package Foo;
  use Moose;
  with 'MooseX::SomeSpecificConfigRole';

  # optionally, default the configfile:
  has +configfile ( default => '/tmp/foo.yaml' );

  # ... insert your stuff here ...

  ########
  ## A script that uses the class with a configfile
  ########

  my $obj = Foo->new_with_config(configfile => '/etc/foo.yaml', other_opt => 'foo');

=head1 DESCRIPTION

This is an abstract role which provides an alternate constructor for creating 
objects using parameters passed in from a configuration file.  The
actual implementation of reading the configuration file is left to
concrete subroles.

It declares an attribute C<configfile> and a class method C<new_with_config>,
and requires that concrete roles derived from it implement the class method
C<get_config_from_file>.

Attributes specified directly as arguments to C<new_with_config> supercede those
in the configfile.

L<MooseX::Getopt> knows about this abstract role, and will use it if available
to load attributes from the file specified by the commandline flag C<--configfile>
during its normal C<new_with_options>.

=head1 Attributes

=head2 configfile

This is a L<Path::Class::File> object which can be coerced from a regular pathname
string.  This is the file your attributes are loaded from.  You can add a default
configfile in the class using the role and it will be honored at the appropriate time:

  has +configfile ( default => '/etc/myapp.yaml' );

=head1 Class Methods

=head2 new_with_config

This is an alternate constructor, which knows to look for the C<configfile> option
in its arguments and use that to set attributes.  It is much like L<MooseX::Getopts>'s
C<new_with_options>.  Example:

  my $foo = SomeClass->new_with_config(configfile => '/etc/foo.yaml');

Explicit arguments will overide anything set by the configfile.

=head2 get_config_from_file

This class method is not implemented in this role, but it is required of all subroles.
Its two arguments are the classname and the configfile, and it is expected to return
a hashref of arguments to pass to C<new()> which are sourced from the configfile.

=head2 meta

The Moose meta stuff, included here because otherwise pod tests fail sometimes

=head1 BUGS

=head1 AUTHOR

Brandon L. Black, E<lt>blblack@gmail.comE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
