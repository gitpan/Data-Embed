package Data::Embed::Writer;
{
  $Data::Embed::Writer::VERSION = '0.1_02';
}

# ABSTRACT: embed arbitrary data in a file - writer class

use strict;
use warnings;
use English qw< -no_match_vars >;
use Data::Embed::Reader;
use Log::Log4perl::Tiny qw< :easy :dead_if_first >;
use Data::Embed::Util qw< :constants escape >;
use Fcntl qw< :seek >;


sub new {
   my $package = shift;
   my $input   = shift;

   # Undocumented, keep additional parameters around...
   my %args = (scalar(@_) && ref($_[0])) ? %{$_[0]} : @_;
   my $self = bless {args => \%args}, $package;

   # If a GLOB, just assign a default filename for logs and set
   # binary mode :raw
   if (ref($input) eq 'GLOB') {
      DEBUG $package, ': input is a GLOB';
      $self->{filename} = '<GLOB>';
      binmode $input, ":raw"
        or LOGCROAK "binmode() to ':raw' failed";
      $self->{fh} = $input;
   } ## end if (ref($input) eq 'GLOB')
   else {    # otherwise... it's a filename
      DEBUG $package, ': input is a file or other thing that can be open-ed';
      $self->{filename} = $input;
      open my $tmpfh, '>>:raw', $input
        or LOGCROAK "open('$input'): $OS_ERROR";
      close $tmpfh;
      open $self->{fh}, '+<:raw', $input
        or LOGCROAK "open('$input'): $OS_ERROR";
   } ## end else [ if (ref($input) eq 'GLOB')]
   $self->{reader} = Data::Embed::Reader->new($input, @_);

   return $self;
} ## end sub new


sub add {
   my $self = shift;
   my %args = (scalar(@_) && ref($_[0])) ? %{$_[0]} : @_;
   if (exists $args{fh}) {
      return $self->add_fh(@args{qw< name fh >});
   }
   elsif (exists $args{filename}) {
      return $self->add_file(@args{qw< name filename >});
   }
   elsif (exists $args{data}) {
      return $self->add_data(@args{qw< name data >});
   }
   LOGCROAK "add() needs either fh or filename parameter";
   return;    # unreached
} ## end sub add


sub add_file {
   my ($self, $name, $filename) = @_;
   my $print_name =
     (ref($filename) eq 'SCALAR') ? 'internal data' : $filename;
   DEBUG "add_file(): $name => $filename";

   # To make it work with references to scalars in perl pre-5.14
   # we split open() and binmode()
   open my $fh, '<', $filename
     or LOGCROAK "open('$print_name'): $OS_ERROR";
   binmode $fh
     or LOGCROAK "binmode('$print_name') failed";

   return $self->add_fh($name, $fh);
} ## end sub add_file


sub add_data {
   my ($self, $name) = @_;
   return $self->add_file($name, \$_[2]);
}


sub add_fh {
   my ($self, $name, $input_fh) = @_;
   $name = '' unless defined $name;
   binmode $input_fh, ':raw'
     or LOGCROAK "binmode(): $OS_ERROR";

   my $reader      = $self->{reader};
   DEBUG "reader: ", sub { require Data::Dumper; Data::Dumper::Dumper($reader) };
   my $index       = $reader->_index();
   my $index_fh    = $index->fh();
   my @index_lines = <$index_fh>;
   if (!@index_lines) {    # no previous Data::Embed stuff
      push @index_lines, STARTER;
   }
   else {
      pop @index_lines;    # get rid of TERMINATOR
   }
   $reader->reset();

   my $output_fh = $self->{fh};    # ready...
   seek $output_fh, $index->{offset}, SEEK_SET;    # set...
   my $data_length = 0;                            # go!
   while (!eof $input_fh) {
      my $buffer;
      defined(my $nread = read $input_fh, $buffer, 4096)
        or LOGCROAK "read(): $OS_ERROR";
      last unless $nread;                          # safe side?
      print {$output_fh} $buffer
        or LOGCROAK "print(): $OS_ERROR";
      $data_length += $nread;
   } ## end while (!eof $input_fh)

   # Add separator, not really needed but might come handy for
   # peeking into the file
   print {$output_fh} "\n\n"
     or LOGCROAK "print(): $OS_ERROR";

   push @index_lines, sprintf "%d %s\n", $data_length, escape($name);
   push @index_lines, TERMINATOR;
   print {$output_fh} join '', @index_lines
     or LOGCROAK "print(): $OS_ERROR";

   return;
} ## end sub add_fh

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Embed::Writer - embed arbitrary data in a file - writer class

=head1 VERSION

version 0.1_02

=head1 METHODS

=head2 new

Constructor. Takes one positional parameter, that can be either
a filename or a filehandle (in particular, a GLOB).

If a filename is provided, is it opened for read in C<:raw> mode; an
exception will be thrown if errors arise.

If a filehandle is provided, it is expected to be seekable and will also
be C<binmode>-d in C<:raw> mode; again, an exception is thrown in case
of errors.

=head2 B<< add >>

Catchall method for adding a section into the target file.

Expects a list of key-value pairs or a hash reference in input. The
recognised keys are:

=over

=item C<name>

the name to associate to the section, optionally. If missing it will
be set to the empty string

=item C<fh>

the filehandle from where data should be taken. The filehandle will be
exausted starting from its current position

=item C<filename>

a filename or a reference to a scalar where data will be read from

=item c<data>

a scalar from where data will be read. If you have a huge amount of
data, it's better to use the C<filename> key above passing a reference
to the scalar holding the data.

=back

Options C<fh>, C<filename> and C<data> are exclusive and will be considered
in the order above (first come, first served).

This method does not return anything.

=head2 B<< add_file >>

Add one section from either a file or a reference to a scalar holding the
data (whatever suits C<open> anyway).

Takes two positional parameters:

=over

=item * name of the section (set to the empty string if undefined)

=item * filename or reference to the data

=back

Returns nothing.

=head2 B<< add_data >>

Add one section from a scalar holding the data.

Takes two positional parameters:

=over

=item * name of the section (set to the empty string if undefined)

=item * scalar holding the data to be added

=back

Returns nothing.

=head2 B<< add_fh >>

Add one section from a filehandle holding the data. The filehandle
will be read from its current position up to the end.

Takes two positional parameters:

=over

=item * name of the section (set to the empty string if undefined)

=item * filehandle

=back

Returns nothing.

=head1 AUTHOR

Flavio Poletti <polettix@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Flavio Poletti <polettix@cpan.org>

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.

This program is distributed in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
