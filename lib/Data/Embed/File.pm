package Data::Embed::File;
{
  $Data::Embed::File::VERSION = '0.2_02';
}

# ABSTRACT: embed arbitrary data in a file

use strict;
use warnings;
use English qw< -no_match_vars >;
use IO::Slice;
use Fcntl qw< :seek >;
use Log::Log4perl::Tiny qw< :easy >;


sub new {
   my $package = shift;
   my $self = {(scalar(@_) && ref($_[0])) ? %{$_[0]} : @_};
   for my $feature (qw< offset length >) {
      LOGCROAK "$package new(): missing required field $feature"
        unless defined($self->{$feature})
        && $self->{$feature} =~ m{\A\d+\z}mxs;
   }
   LOGDIE "$package new(): either filename or fh are required"
     unless defined($self->{fh}) || defined($self->{filename});
   return bless $self, $package;
} ## end sub new


sub fh {
   my $self = shift;
   if (!exists $self->{slicefh}) {
      my %args = map { $_ => $self->{$_} }
        grep { defined $self->{$_} } qw< fh filename offset length >;
      $self->{slicefh} = IO::Slice->new(%args);
   }
   return $self->{slicefh};
} ## end sub fh


sub contents {
   my $self = shift;
   my $fh   = $self->fh();
   my $current = tell $fh;
   seek $fh, 0, SEEK_SET;

   local $/ = wantarray() ? $/ : undef;
   my @retval = <$fh>;
   seek $fh, $current, SEEK_SET;
   return @retval if wantarray();
   return $retval[0];
} ## end sub contents


sub name { return shift->{name}; }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Embed::File - embed arbitrary data in a file

=head1 VERSION

version 0.2_02

=head1 DESCRIPTION

Accessor class for representing an embedded file (for reading).

=head1 METHODS

=head2 B<< new >>

Constructor. It will act lazily, just storing the input data
for later usage by other methods, providing validation.

Input data can be provided as key-value pairs of through a
reference to a hash.

For proper functioning of the object, the following keys
should be provided:

=over

=item C<< fh >>

a filehandle for the stream where the data are contained

=item C<< filename >>

the name of the file where the data are. This parameter is
optional if C<fh> above is already provided.

=item C<< offset >>

the offset within the stream where the real data for this
file begins. C<0> means the very beginning of the file.

=item C<< length >>

the length of the data belonging to this C<File>.

=back

=head2 B<< fh >>

Get a filehandle suitable for accessing the embedded file. It provides
back a filehandle through L<IO::Slice>, providing the illusion of
working on a file per-se instead of a slice inside a bigger file.

=head2 B<< contents >>

Convenience method to slurp the whole contents of the embedded file
in one single shot. It always provides the full contents, independently
of whether data had been read before, although it restores the filehandle
to the previous position.

=head2 B<< name >>

Get the name associated to the file, whatever it is. L<Data::Embed::Reader>
sets it from what is read in the index file

=head1 AUTHOR

Flavio Poletti <polettix@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014-2015 by Flavio Poletti <polettix@cpan.org>

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
