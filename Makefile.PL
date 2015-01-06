
use strict;
use warnings;

use 5.008_000;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "embed arbitrary data in a file",
  "AUTHOR" => "Flavio Poletti <polettix\@cpan.org>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "Data-Embed",
  "EXE_FILES" => [
    "bin/data-embed"
  ],
  "LICENSE" => "artistic_2",
  "NAME" => "Data::Embed",
  "PREREQ_PM" => {
    "IO::Slice" => "0.001",
    "Log::Log4perl::Tiny" => "1.002_004"
  },
  "TEST_REQUIRES" => {
    "Test::Exception" => "0.032",
    "Test::More" => "1.001008"
  },
  "VERSION" => "0.21",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "IO::Slice" => "0.001",
  "Log::Log4perl::Tiny" => "1.002_004",
  "Test::Exception" => "0.032",
  "Test::More" => "1.001008"
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



