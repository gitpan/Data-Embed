package Data::Embed::Util;
{
  $Data::Embed::Util::VERSION = '0.2_03';
}

# ABSTRACT: embed arbitrary data in a file - utilities

use strict;
use warnings;
use English qw< -no_match_vars >;

use Exporter qw< import >;
our @EXPORT_OK = qw< STARTER TERMINATOR escape unescape >;
our @EXPORT = (); # export nothing by default
our %EXPORT_TAGS = (
   all => \@EXPORT_OK,
   escaping => [qw< escape unescape >],
   constants => [qw< STARTER TERMINATOR >],
);


use constant STARTER    => "Data::Embed/index/begin\n";
use constant TERMINATOR => "Data::Embed/index/end\n";

sub escape {
   my $text = shift;
   $text =~ s{([^\w.-])}{'%' . sprintf('%02x', ord $1)}egmxs,
   return $text;
}

sub unescape {
   my $text = shift;
   $text =~ s{%(..)}{chr(hex($1))}egmxs;
   return $text;
}



1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Embed::Util - embed arbitrary data in a file - utilities

=head1 VERSION

version 0.2_03

=head1 DESCRIPTION

Accessor class for representing an embedded file (for reading).

=head1 FUNCTIONS

All these functions are not exported by default. You can use the
following tags for importing them:

=over

=item C<< all >>

all of them

=item C<< escaping >>

the escaping functions C<escape> and C<unescape>

=item C<< constants >>

the two constants C<STARTER> and C<TERMINATOR>

=back

=head2 B<< STARTER >>

a string indicating the start of an index section

=head2 B<< TERMINATOR >>

a string indicating the end of an index section

=head2 B<< escape >>

escape an input string. All alphanumeric characters, plus the
underscore C<_>, hyphen C<-> and full stop C<.> are preserved, while
all the others are transformed into three-characters sequences C<%XX>
where XX are two hexadecimal digits.

=head2 B<< unescape >>

unescape an input string with the reverse action performed by
L</escape>.

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
