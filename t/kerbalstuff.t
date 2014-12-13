#!/usr/bin/perl -w
use 5.010;
use strict;
use warnings;
use autodie qw(:all);
use Test::More;
use IPC::System::Simple qw(capture);
use WWW::Mechanize;

my $pr_branch = $ENV{TRAVIS_PULL_REQUEST};
my $netkan = "./netkan.exe";

if (! $pr_branch or $pr_branch eq "false") {
    plan skip_all => "Not a pull request";
}

if (! -x $netkan) {

    # If we don't already have a netkan executable, then go download the latest.
    # This includes unstable netkan.exe builds, as submissions may reference
    # experimental features.

    my $agent = WWW::Mechanize->new( agent => "NetKAN travis testing" );
    $agent->get("https://github.com/KSP-CKAN/CKAN/releases");
    $agent->follow_link(text => 'netkan.exe');

    open(my $fh, '>', $netkan);
    binmode($fh);
    print {$fh} $agent->content;
    close($fh);
    chmod(0755, $netkan);
}

# FETCH_HEAD^ should always be the branch we're merging into.
my @changed_files = capture("git diff --name-only FETCH_HEAD^");
chomp(@changed_files);

# Walk through our changed files. If any of them mention KS, then
# run netkan over them. (We have @sircmpwn's permission to make KS
# downloads during CI testing.)

foreach my $file (@changed_files) {
    if (is_ks_file($file)) {
        netkan_validate($file);
    }
}

done_testing;

sub is_ks_file {
    my ($file) = @_;

    # Not a netkan file? Not something we want to test.
    return 0 if ($file !~ m{\.netkan$});

    local $/;   # Slurp mode.

    open(my $fh, '<', $file);
    my $content = <$fh>;
    close($fh);

    return $content =~ m{#/ckan/kerbalstuff};
}

# Simply checks to see if netkan.exe runs without errors on this file
sub netkan_validate {
    my ($file) = @_;

    my $valid = eval {
        system($netkan, $file);
        return 1;
    };

    # If there was a failure, report it.
    if ($@) { warn "$file: $@" }

    ok($valid, $file);
}
