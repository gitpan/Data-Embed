package Data::Embed;
{
  $Data::Embed::VERSION = '0.21';
}

# ABSTRACT: embed arbitrary data in a file

use strict;
use warnings;
use English qw< -no_match_vars >;
use Exporter qw< import >;
use Log::Log4perl::Tiny qw< :easy :dead_if_first >;

our @EXPORT_OK =
  qw< writer reader embed embedded generate_module_from_file >;
our @EXPORT      = ();
our %EXPORT_TAGS = (
   all     => \@EXPORT_OK,
   reading => [qw< reader embedded >],
   writing => [qw< writer embed    generate_module_from_file >],
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
   my %args = (@_ && ref($_[0])) ? %{$_[0]} : @_;

   my %constructor_args =
     map { $_ => delete $args{$_} } qw< input output >;
   $constructor_args{input} = $constructor_args{output} =
     delete $args{container}
     if exists $args{container};
   my $writer = writer(%constructor_args)
     or LOGCROAK 'could not get the writer object';

   return $writer->add(%args);
} ## end sub embed

sub embedded {
   my $reader = reader(shift)
     or LOGCROAK 'could not get the writer object';
   return $reader->files();
}

sub generate_module_from_file {
   require Data::Embed::OneFileAsModule;
   goto &Data::Embed::OneFileAsModule::generate_module_from_file;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Embed - embed arbitrary data in a file

=head1 VERSION

version 0.21

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

   embed($hashref); # OR
   embed(%keyvalue_pairs);

Embed new data inside a container file.

Parameters can be passed as key-value pairs either
directly or through a hash reference. The following keys are
supported:

=over

=item C<container>

shortcut to specifying the same input and output, i.e. the value will
be replicated both on the C<input> and C<output> keys below. Caller
still has to ensure that the two are compatible. Provision of a
filehandle is currently not supported.

=item C<input>

any previous container file to use as base for the generated container.
If missing, no previous data will be considered (like starting from an
empty file). Can be:

=over

=item *

the C<-> string in a plain scalar, in which case standard input is
considered

=item *

any other string in a plain scalar, considered to be a file name

=item *

a plain reference to a scalar, considered to hold the input data

=item *

something that supports the filehandle interface for reading

=back

=item C<output>

the target container for the newly generated archive. Might be the same
as the input or different; in the latter case, the input will be copied
over the output, apart from the bits regarding the management of the
inclusions. Can be:

=over

=item *

missing/undefined or the C<-> string in a plain scalar, in which case
standard output is used

=item *

any other string in a plain scalar, considered to be a file name

=item *

a plain reference to a scalar, considered to be the target scalar to
hold the data

=item *

something that supports the filehandle interface for printing. You
should not provide the same filehandle for both input and output,
even if you opened it in read-write mode. This limitation might
be removed in the future.

=back

=item C<name>

the name to associate to the section, optionally. If missing it will
be set to the empty string

=item C<fh>

the filehandle from where data should be taken. The filehandle will be
exausted starting from its current position

=item C<filename>

a filename or a reference to a scalar where data will be read from

=item C<data>

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

=head2 B<< generate_module_from_file >>

   # when %args includes details for an output channel
   generate_module_from_file(%args);

   # in case no output is provided in %args:
   my $text = generate_module_from_file(%args);

Generate a module's file contents from a file. The module contains code
of a package that has code to read the included data. Arguments are:

=over

=item package

the name of the package that will be put into the module. This
is a mandatory parameter.

=item output

the output channel. If not present, the output will be provided as
a string returned by the function, otherwise you can provide

=over

=item *

a filehandle where the output will be printed

=item *

a reference to a scalar (it will be filled with the contents)

=item *

the C<-> string, in which case the output will be printed
to STDOUT

=item *

a filename

=back

=item output_from_package

if this key is present and true, the C<output> parameters is
overridden and generated automatically from the package name
provided in key C<package>. The generated file will assume that
the file is contained in the I<normal> path under a C<lib>
directory, e.g. if the package name is C<Some::Module> then
the generated filename will be C<lib/Some/Module.pm>.

=item fh

a filehandle where data will be read from

=item filename

the input will be taken from the provided filename

=item dataref

the input will be taken from the scalar pointed by the
reference

=item data

the input is taken from the scalar provided with the data key

=back

Input keys are C<fh>, C<filename>, C<dataref> and C<data>. In case
multiple of them are present, they will be considered in the
order specified.

=head1 BUGS AND LIMITATIONS

Report bugs either through RT or GitHub (patches welcome).

Passing the same filehandle for both C<input> and C<output> in L</embed>
is not supported. This applies to C<container> too.

=head1 SEE ALSO

L<Data::Section> covers a somehow similar need but differently. In
particular, you should look at it if you want to be able to modify
the data you want to embed directly, e.g. if you are embedding some
textual templates that you want to tweak.

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
