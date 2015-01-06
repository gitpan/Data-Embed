package Data::Embed::OneFileAsModule;
{
  $Data::Embed::OneFileAsModule::VERSION = '0.2_03';
}

# ABSTRACT: generate a Perl module for carrying data

use Exporter qw< import >;
@EXPORT_OK   = (qw< generate_module_from_file >);
@EXPORT      = ();
%EXPORT_TAGS = (all => \@EXPORT_OK);
use strict;
use warnings;
use Log::Log4perl::Tiny qw< :easy :dead_if_first >;



{
   no strict 'refs';
#__TEMPLATE_BEGIN__
{
   my $data     = \*{__PACKAGE__ . '::DATA'};
   my $position = undef;

   use strict;
   use warnings;
   use Carp;
   use English qw< -no_match_vars >;
   use Fcntl qw< :seek >;

   sub get_fh {
      $position = tell $data unless defined $position;
      open my $fh, '<&', $data
        or croak __PACKAGE__ . "::dup() for DATA: $OS_ERROR";
      seek $fh, $position, SEEK_SET;
      return $fh;
   } ## end sub get_fh

   sub get_data {
      my $fh = get_fh();
      binmode $fh;

      # ensure we slurp all, whatever the context
      local $/ = wantarray() ? $/ : undef;
      return <$fh>;
   } ## end sub get_data
}
#__TEMPLATE_END__
}

sub _get_output_fh {
   my $output = shift;

   # if no output is defined, we will return a scalar with data
   if (! defined $output) {
      my $buffer = '';
      open my $fh, '>', \$buffer
         or LOGCROAK "open() on (scalar ref): $OS_ERROR";
      return ($fh, \$buffer);
   }

   # if filename is '-', use standard output
   if ($output eq '-') {
      open my $fh, '>&', \*STDOUT        # dup()-ing
         or LOGCROAK "dup(): $OS_ERROR";
      binmode $fh;
      return $fh;
   }

   my $ro = ref $output;
   if (! $ro) { # output is a simple filename
      open my $fh, '>', $output
         or LOGCROAK "open('$output'): $OS_ERROR";
      binmode $fh;
      return $fh;
   }

   # so we have a reference here.
   # if not a reference to a SCALAR, assume it's
   # something that supports the filehandle interface
   return $output if $ro ne 'SCALAR';

   # otherwise, open a handle to write in the scalar
   open my $fh, '>', $output
      or LOGCROAK "open('$output') (scalar ref): $OS_ERROR";
   binmode $fh;
   return $fh;
}

sub _get_input_fh {
   my $args = shift;

   return $args->{fh} if exists $args->{fh};

   if (defined $args->{filename}) {
      open my $fh, '<', $args->{filename}
         or LOGCROAK "open('$args->{filename}'): $OS_ERROR";
      binmode $fh;
      return $fh;
   }

   if (defined $args->{dataref}) {
      open my $fh, '<', $args->{dataref}
         or LOGCROAK "open('$args->{dataref}') (scalar ref): $OS_ERROR";
      binmode $fh;
      return $fh;
   }

   if (defined $args->{data}) {
      open my $fh, '<', \$args->{data}
         or LOGCROAK "open() (scalar ref): $OS_ERROR";
      binmode $fh;
      return $fh;
   }

   LOGCROAK "no input source defined";
   return;    # unreached
}

sub generate_module_from_file {
   my %args = (scalar(@_) && ref($_[0])) ? %{$_[0]} : @_;

   LOGCROAK 'no package name set'
      unless defined $args{package};
   LOGCROAK "unsupported package name '$args{module}'"
      unless $args{package} =~ m{\A (?: \w+) (:: \w+)* \z}mxs;

   my $template_fh = get_fh();
   binmode $template_fh;
   seek $template_fh, 0, SEEK_SET;

   my $in_fh = _get_input_fh(\%args);

   ($args{output} = 'lib/' . $args{package} . '.pm') =~ s{::}{/}gmxs
      if $args{output_from_package};
   my ($out_fh, $outref) = _get_output_fh($args{output});

   # package name
   print {$out_fh} "package $args{package};\n";

   # package code
   my $seen_start;
   INPUT:
   while (<$template_fh>) {
      if (! $seen_start) {
         $seen_start = m{\A \#__TEMPLATE_BEGIN__ \s*\z}mxs;
         next INPUT;
      }
      last INPUT if m{\A \#__TEMPLATE_END__ \s*\z}mxs;
      print {$out_fh} $_;
   }

   # package code ending
   print {$out_fh} "\n1;\n__DATA__\n";

   # file contents
   while (! eof $in_fh) {
      defined(my $nread = read $in_fh, my $buffer, 4096)
         or LOGCROAK "read(): $OS_ERROR";
      last unless $nread; # paranoid
      print {$out_fh} $buffer;
   }

   return $$outref if $outref;
   return;
} ## end sub generate_module_from_file

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Embed::OneFileAsModule - generate a Perl module for carrying data

=head1 VERSION

version 0.2_03

=head1 FUNCTIONS

=head2 get_fh

get a filehandle to read the data. The filehandle will be
put at the start of the data, you should not C<seek>
without taking into account that this is not at
position 0.

This function is preserved in the generated module so that
it is available to get the embedded data.

=head2 get_data

get a string with the full data provided by the carried by
the module.

This function is preserved in the generated module so that
it is available to get the embedded data.

=head2 generate_module_from_file

generate the data file contents. See full documentation
at L</Data::Embed::generate_module_from_file>.

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
