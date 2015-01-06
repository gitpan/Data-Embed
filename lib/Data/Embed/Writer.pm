package Data::Embed::Writer;
{
  $Data::Embed::Writer::VERSION = '0.2_02';
}

# ABSTRACT: embed arbitrary data in a file - writer class

use strict;
use warnings;
use English qw< -no_match_vars >;
use Data::Embed::Reader;
use Log::Log4perl::Tiny qw< :easy :dead_if_first >;
use Data::Embed::Util qw< :constants escape >;
use Fcntl qw< :seek >;
use Scalar::Util qw< refaddr >;



sub __output_for_new {
   my $self = shift;
   my $package = ref $self;
   my $output = $self->{output} = $self->{args}{output};
   $self->{output_same_as_input} = 0; # by default

   # The simple stuff: not present/defined, or the classical "-" string
   if ((! defined($output)) || (! length($output)) || ($output eq '-')) {
      DEBUG $package, "::__output_for_new(): output to STDOUT";
      open my $fh, '>&', \*STDOUT
         or LOGCROAK "dup(): $OS_ERROR";
      binmode $fh
         or LOGCROAK "binmode(\\*STDOUT): $OS_ERROR";
      $self->{output_name} = '<STDOUT>';
      $self->{output_fh} = $fh;
      $self->{output_type} = 'filehandle';
      return $self;
   }

   my $oref = ref $output;
   if (! $oref) { # filename
      DEBUG $package, '::__output:for_new(): output to a file';
      $self->{output_type} = 'file';
      $self->{output_name} = $output;

      # same file as input? If yes, do not clobber
      if (($self->{input_type} eq 'file') && ($output eq $self->{input})) {
         open my $fh, '+<', $output
            or LOGCROAK "open('$output'): $OS_ERROR";
         binmode $fh
            or LOGCROAK "binmode('$output'): $OS_ERROR";
         $self->{output_fh} = $fh;
         $self->{output_same_as_input} = 1;
         return $self;
      }

      open my $fh, '>', $output
         or LOGCROAK "open('$output'): $OS_ERROR";
      binmode $fh
         or LOGCROAK "binmode('$output'): $OS_ERROR";
      $self->{output_fh} = $fh;
      return $self;
   }

   if ($oref eq 'SCALAR') { # reference to a scalar, similar to filename
      DEBUG $package, '::__output:for_new(): output to a scalar ref';
      $self->{output_type} = 'scalar-ref';
      $self->{output_name} = "{$output}";

      # same file as input? If yes, do not clobber
      if (($self->{input_type} eq 'scalar-ref') && (refaddr($output) eq refaddr($self->{input}))) {
         open my $fh, '+<', $output
            or LOGCROAK "open('$output'): $OS_ERROR";
         binmode $fh
            or LOGCROAK "binmode('$output'): $OS_ERROR";
         $self->{output_fh} = $fh;
         $self->{output_same_as_input} = 1;
         return $self;
      }

      open my $fh, '>', $output
        or LOGCROAK "open('$output'): $OS_ERROR";
      binmode $fh
         or LOGCROAK "binmode('$output'): $OS_ERROR";
      $self->{output_fh} = $fh;
      return $self;
   }

   # Otherwise, we will have to assume that it is a filehandle
   $self->{output_name} = '<HANDLE>';
   $self->{output_fh} = $output;
   $self->{output_type} = 'filehandle';
   $self->{output_same_as_input} = ($self->{input_type} eq 'filehandle')
      && (refaddr($output) eq refaddr($self->{input_fh}));
   return $self;
}

sub __input_for_new {
   my $self = shift;
   my $package = ref $self;
   my $input = $self->{input} = $self->{args}{input};

   # if not defined, it just does not exist
   if (! defined($input)) {
      DEBUG $package, "::__input_for_new(): no input";
      $self->{input_name} = '*undef*';
      $self->{input_fh} = undef;
      $self->{input_type} = 'undef';
      return $self;
   }

   # the classical "-" string
   if ($input eq '-') {
      DEBUG $package, "::__input_for_new(): input from STDIN";
      open my $fh, '<&', \*STDIN
         or LOGCROAK "dup(): $OS_ERROR";
      binmode $fh
         or LOGCROAK "binmode(\\*STDIN): $OS_ERROR";
      $self->{input_name} = '<STDIN>';
      $self->{input_fh} = $fh;
      $self->{input_type} = 'filehandle';
      return $self;
   }

   my $iref = ref $input;
   if (! $iref) { # filename
      DEBUG $package, '::__input:for_new(): input from file';
      open my $fh, '<', $input
         or LOGCROAK "open('$input'): $OS_ERROR";
      binmode $fh
         or LOGCROAK "binmode('$input'): $OS_ERROR";
      $self->{input_name} = $input;
      $self->{input_fh} = $fh;
      $self->{input_type} = 'file';
      return $self;
   }

   if ($iref eq 'SCALAR') { # reference to a scalar, similar to filename
      DEBUG $package, '::__input:for_new(): input from a scalar ref';
      open my $fh, '<', $input
        or LOGCROAK "open('$input'): $OS_ERROR";
      binmode $fh
         or LOGCROAK "binmode('$input'): $OS_ERROR";
      $self->{input_name} = "{$input}";
      $self->{input_fh} = $fh;
      $self->{input_type} = 'scalar-ref';
      return $self;
   }

   # Otherwise, we will have to assume that it is a filehandle
   $self->{input_name} = '<HANDLE>';
   $self->{input_fh} = $input;
   $self->{input_type} = 'filehandle';
   return $self;
}

sub new {
   my $package = shift;
   my %args = (scalar(@_) && ref($_[0])) ? %{$_[0]} : @_;

   # Undocumented, keep additional parameters around...
   my $self = bless {args => \%args}, $package;

   # first of all, resolve the input
   $self->__input_for_new();

   # then the output (might depend on the input)
   $self->__output_for_new();

   # if there is an input, transfer to the output if it is the case
   if ($self->{input_fh}) {
      if ($self->{output_same_as_input}) {  # don't copy, assume seekable input
         my $reader = Data::Embed::Reader->new($self->{input_fh});
         my $ifile = $reader->_index(); # private method called
         my @index = $ifile->contents();
         shift @index; # eliminate STARTER
         pop   @index; # eliminate TERMINATOR
         $self->{index} = \@index; # initialize previous index
         # put output handle in right position
         seek $self->{output_fh}, $ifile->{offset}, SEEK_SET;
      }
      else {
         my $starter = STARTER;
         my $terminator = TERMINATOR;
         my (@index, $index_completed);
         my $ifh = $self->{input_fh};
         my $ofh = $self->{output_fh};
         INPUT:
         while (<$ifh>) {
            if (! @index) {
               if ($_ eq $starter) {
                  push @index, $_;
                  next INPUT;
               }
               else {
                  print {$ofh} $_;
               }
            }
            elsif (! $index_completed) { # accumulating index
               if (m{\A \s* (\d+) \s+ (\S*) \s*\z}mxs) {
                  push @index, $_;
               }
               elsif ($_ eq $terminator) {
                  push @index, $_;
                  $index_completed = 1;
               }
               else { # not a valid index, flush accumulated lines
                  print {$ofh} @index;
                  @index = ();
                  $index_completed = undef; # paranoid
               }
            }
            else { # accumulating and index completed, but other stuff...
               print {$ofh} @index; # flush and reset
               @index = ();
               $index_completed = undef;
            }
         }
         shift @index; # eliminate STARTER
         pop   @index; # eliminate TERMINATOR
         $self->{index} = \@index; # initialize previous index
      }
   }

   # now output_fh is at the right place for new stuff!

   return $self;
} ## end sub new


sub add {
   my $self = shift;
   my %args = (scalar(@_) && ref($_[0])) ? %{$_[0]} : @_;

   # DWIM!
   if (defined $args{input}) {
      if ($args{input} eq '-') {
         open my $fh, '<&', \*STDIN
            or LOGCROAK "dup(): $OS_ERROR";
         binmode $fh
            or LOGCROAK "binmode(\\*STDIN): $OS_ERROR";
         $args{fh} = $fh;
      }
      else {
         my $ref = ref $args{input};
         if ((! $ref) || ($ref eq 'SCALAR')) {
            $args{filename} = $args{input};
         }
         else {
            $args{fh} = $args{input};
         }
      }
   }

   if (defined $args{fh}) {
      return $self->add_fh(@args{qw< name fh >});
   }
   elsif (defined $args{filename}) {
      return $self->add_file(@args{qw< name filename >});
   }
   elsif (defined $args{data}) {
      return $self->add_data(@args{qw< name data >});
   }
   LOGCROAK "add() needs some input";
   return;    # unreached
} ## end sub add


sub add_file {
   my ($self, $name, $filename) = @_;
   $name = '' unless defined $name;
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

   my $output_fh   = $self->{output_fh};
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

   $name = '' unless defined $name;
   push @{$self->{index}}, sprintf "%d %s\n", $data_length, escape($name);

   return $self;
}


sub write_index {
   my $self = shift;
   my ($output_fh, $index) = @{$self}{qw< output_fh index >};
   print {$output_fh} STARTER, @$index, TERMINATOR
      or LOGCROAK "print(): $OS_ERROR";
   delete $self->{$_} for qw< output_fh index >;
   return;
} ## end sub add_fh

sub DESTROY {
   my $self = shift;
   $self->write_index() if exists $self->{output_fh};
   return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Embed::Writer - embed arbitrary data in a file - writer class

=head1 VERSION

version 0.2_02

=head1 METHODS

=head2 new

Constructor.

   my $w = Data::Embed::Writer->new(%args);
   my $w = Data::Embed::Writer->new(\%args);

The difference between the two forms is that you can
pass either key-value pairs, or a hash reference with key-value
pairs. Acceptable keys are:

=over

=item C<output>

Optional parameter, where to send output data. If not present, undefined,
empty or set to the string C<->, then standard output will be considered.

If a filehandle is provided, it is expected to be seekable and will also
be C<binmode>-d in C<:raw> mode.

=item C<input>

Optional parameters, where to get initial data:

=over

=item *

if not present, no previous input will be considered.

=item *

if equal to the string C<->, the standard input will be considered

=item *

if equal to some other string, it will be considered a filename

=item *

if a reference to a scalar, it will be C<open()>ed

=item *

otherwise it will be considered a filehandle

=back

=back

This method throws an exception in case of errors. Returns a new object
in case of success.

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

=head2 B<< write_index >>

Write the index of the contained sections out to the output channel.
Doing this invalidates the object, so you should not perform any
further action after.

This gets automatically called upon object destruction, if not previously
called.

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
