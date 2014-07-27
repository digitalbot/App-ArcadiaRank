package App::ArcadiaRank;
use 5.010;
use warnings; no warnings 'experimental';
use utf8;
use Encode;
use Getopt::Long qw/:config posix_default no_ignore_case bundling auto_help/;
use Web::Query;
use Coro;
use Coro::LWP;

our $VERSION = '0.0.1';

sub new {
    my ($class) = @_;
    bless { domain => 'http://www.mai-net.net' }, $class;
}

sub run {
    my ($self, @args) = @_;
    local @ARGV = @args;
    my %opts;
    GetOptions(\%opts, qw/
        limit|l=i
        compact|c
        precision|p
        by-score|b
        help|h
        version|v
    /) or $self->show_usage;

    $self->show_version if $opts{version};
    $self->show_usage   if $opts{help};
    $opts{limit} ||= 10;

    my $entries = $self->_fetch_entries(\%opts);
    my @sorted  = $self->_sort_entries($entries, \%opts);
    $self->show_entries([@sorted[0..$opts{limit} - 1]], \%opts);
}

sub _fetch_entries {
    my ($self, $opts) = @_;
    my $url = $self->{domain} . '/bbs/sst/sst.php?act=list&cate=original&page=1';
    my $wq = Web::Query->new($url) or die 'cannot get the url';
    my ($last_page) = $wq->find('table')->first->text =~ m!\|\s+\d+/(\d+)\s+\|!;

    my @entries;
    my @coros;
    for my $page (1..$last_page) {
        push @coros, async {
            my $url = $self->{domain} . '/bbs/sst/sst.php?act=list&cate=original&page=' . $page;
            my $wq = Web::Query->new($url) or die 'cannot get the url';

            $wq->find('.bgc')->each(sub {
                my ($bgc_i, $bgc) = @_;
                my %entry;

                $bgc->find('td')->each(sub {
                    my ($td_i, $td) = @_;
                    return if !$bgc_i && $td_i =~ /[0-2]/;

                    my $idx = $bgc_i ? $td_i : $td_i - 3;
                    given ($idx) {
                        when (0) {
                            my $e = $td->find('b a')->first;
                            $entry{title} = $e->text;
                            $entry{link}  = $self->{domain} . $e->attr('href');
                        }
                        when (1) { $entry{author}   = $td->text }
                        when (2) { $entry{pages}    = $td->find('b font')->first->text }
                        when (3) { $entry{comment}  = $td->find('b')->first->text }
                        when (4) { $entry{pv}       = $td->find('b')->first->text }
                        when (5) { $entry{updated}  = $td->find('font')->first->text }
                    }
                });
                return if !$opts->{precision} && $entry{pv} < 50000;
                $entry{score} = $entry{comment} / $entry{pages};
                push @entries, \%entry;
            });
        }
    }
    $_->join for @coros;
    return \@entries;
}

sub _sort_entries {
    my ($self, $entries, $opts) = @_;
    if ($opts->{'by-score'}) {
        return sort { $b->{score} <=> $a->{score} } @$entries;
    }
    return sort { $b->{pv} <=> $a->{pv} } @$entries;
}

sub show_entries {
    my ($self, $entries, $opts) = @_;
    die 'no entries' unless @$entries;

    my $i = 1;
    if ($opts->{compact}) {
        for my $entry (@$entries) {
            my $score = $opts->{'by-score'} ? $entry->{score} : $entry->{pv};
            say $i, ': ', encode_utf8($entry->{title}), ' (', $score, ')';
            $i++;
        }
    }
    else {
        for my $entry (@$entries) {
            my $score = $opts->{'by-score'} ? $entry->{score} : $entry->{pv};
            say '';
            say '  rank: ', $i, ' (pv: ', $score, ')';
            say '      title : ', encode_utf8($entry->{title});
            say '      author: ', encode_utf8($entry->{author});
            say '      pages : ', $entry->{pages};
            say '';
            say '----------------------------------------';
            $i++;
        }
    }
}

sub show_version {
    STDOUT->printflush("arcadiarank (App::ArcadiaRank): v$VERSION");
    die "\n";
}

sub show_usage {
    STDOUT->printflush(<<EOU);
Usage:
    arcadiarank [options]

    options:
        --limit,-l count   Control entries limit.
        --compact,-c       Show compact results.
        --precision,-p     Calc precision.
        --version,-v       Show version of this app.
        --help,-h          Show this help messages.

EOU
    die "\n";
}

1;

1;
__END__

=encoding utf-8

=head1 NAME

App::ArcadiaRank - It's new cli app of arcadia(http://www.mai-net.net/) ranking.

=head1 SYNOPSIS

only

    $ arcadiarank

=head1 DESCRIPTION

App::ArcadiaRank is a library of arcadia's ss ranking.

=head1 LICENSE

Copyright (C) kosuke a.k.a. digitalbot.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

kosuke E<lt>kosuke.n27@gmail.comE<gt>

=cut
