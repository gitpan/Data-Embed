package Data::Embed;
{
  $Data::Embed::VERSION = '0.1_01';
}

# ABSTRACT: embed arbitrary data in a file

use strict;
use warnings;
use English qw< -no_match_vars >;
use Exporter qw< import >;
use Log::Log4perl::Tiny qw< :easy :dead_if_first >;

our @EXPORT_OK = qw< writer reader embed embedded >;
our @EXPORT = ();
our %EXPORT_TAGS = (
   all => \@EXPORT_OK,
   reading => [ qw< reader embedded > ],
   writing => [ qw< writer embed    > ],
);


sub writer {
   require Data::Embed::Writer;
   return Data::Embed::Writer->new(@_);
}

sub reader {
   require Data::Embed::Reader;
   return Data::Embed::Reader->new(@_);
}

sub embed {
   my $writer = writer(shift)
      or LOGCROAK 'could not get the writer object';
   return $writer->add(@_);
}

sub embedded {
   my $reader = reader(shift)
      or LOGCROAK 'could not get the writer object';
   return $reader->files();
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Embed - embed arbitrary data in a file

=head1 VERSION

version 0.1_01

=head1 SYNOPSIS

   use Data::Embed qw< embed embedded >;

   # this is the file where thing will be embedded, at the end
   my $container = '/path/to/some/file';

   # first of all we embed an external file
   my $datafile  = '/path/to/data.tar.gz';
   embed($container, name => 'data.tar.gz', filename => $datafile);

   # we can also embed some data, directly
   use Data::Dumper;
   my $conf = { ... };
   embed($container, name => 'config.yml', data => Dumper($conf));

   # if the data is in a scalar but it's huge, use filename and
   # pass a reference to the scalar so no copy will happen
   my $huge_png = ...;
   embed($container, name => 'image.png', filename => \$huge_png);

   # to retrieve the stuff, use embedded()
   my @files = embedded($container);

   # each item in @files is a Data::Embed::File object

   # get whole contents of file
   my $config_text = $files[1]->contents();

   # otherwise, you can get a filehandle and use it, e.g. to
   # dump it on standard output
   my $data_fh = $files[0]->fh();
   binmode STDOUT;
   print {*STDOUT} <$data_fh>;

   # or save the file back, using the available name
   open my $ofh, '>:raw', $file[2]->name(); # well, do your checks!
   my $ifh = $files[2]->fh();
   while (! eof $ifh) {
      read $ifh, my $buffer, 4096
         or last; # do proper checks in production!
      print {$ofh} $buffer;
   }

=head1 DESCRIPTION

This module allows you to manage embedding data at the end of other
files, providing both means for embedding the data (L</embed> and
L</writer>) and accessing them (L</embedded> and L</reader>).

How can this be helpful? For example, suppose that you want to
bring some data along with your perl script, some of which might
be binary (e.g. an image, or a tar archive), you can embed these data
inside the perl and then retrieve them. For example, this can be the
basis for an installer.

For embedding data, you can use the L</embed> function. See the relevant
documentation or the examples in the L</SYNOPSYS> to use it properly.

For extracting the embedded data, you can use the L</embedded> function
and access each embedded file as a L<Data::Embed::File> object. You can
then use its methods C<contents> for accessing the whole data, or get
a filehandle through C<fh> and avoid getting the whole data in memory
at once.

Note: the filehandle provided by the C<fh> method of L<Data::Embed::File>
is actually a L<IO::Slice> object, so it might not support all the
functions/methods of a regular filehandle.

You can also access the lower level interface through the two functions
L</reader> and L</writer>. See the documentation
for L<Data::Embed::Reader> and L<Data::Embed::Writer>.

=head1 FUNCTIONS

=head2 B<< embed >>

Embed new data inside a container file. The calling syntax is
as follows:

   embed($container, $hashref); # OR
   embed($container, %keyvalue_pairs);

The C<$container> parameter is the target file where the new data
will be inserted.

Additional parameters can be passed as key-value pairs either
directly or through a hash reference. The following keys are
supported:

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

This function does not return anything.

=head2 B<< embedded >>

Get a list of the embedded files inside a target container. The calling
syntax is as follows:

   my $arrayref = embedded($container); # scalar context, OR
   my @files    = embedded($container); # list context

The only input parameter is the C<$container> to use as input. It can
be either a real filename, or a filehandle.

Depending on the context, a list will be returned (in list context) or
an array reference holding the list.

Whatever the context, each item in the list is a L<Data::Embed::File>
object that you can use to access the embedded file data (most notably,
you'll be probably using its C<contents> or C<fh> methods).

=head2 B<< writer >>

This is a convenience wrapper around the constructor for
L<Data::Embed::Writer>.

=head2 B<< reader >>

This is a convenience wrapper around the constructor for
L<Data::Embed::Reader>.

=head1 SEE ALSO

L<Data::Section> covers a somehow similar need but differently. In
particular, you should look at it if you want to be able to modify
the data you want to embed directly, e.g. if you are embedding some
textual templates that you want to tweak.

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
