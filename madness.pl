# madness.pl predicts tournament fields for major college sports

use strict;
use warnings;
use Team;

my %lnames;
my $sport;
my %champs;

sub read_results {
    my $results   = $sport . "\\results.txt";        # results file
    open RESULTS, "<$results" or die "Can't open $results: $!";
    while (<RESULTS>) {
        chomp;
        my ($name, $bt) = (split /,/)[0,2];
        $lnames{$name}->btnum($bt);
    }
    close RESULTS;
}

sub find_conference_champs {
    if (-e $sport . "\\champs.txt") {
        my ($conf, $team);
        open (CHAMPS, "<", $sport . "\\champs.txt") || die "cannot open champs file.\n";
        while (<CHAMPS>) {
            chomp;
            ($conf, $team) = (split /,/, $_)[3,0];
            $champs{$conf} = $lnames{$team};
        }
    }
    
    my @league = sort { $a->conference cmp $b->conference
                       or $b->btnum <=> $a->btnum} values %lnames;
    my $c = "";    
    foreach (@league) {
        next if $_->conference eq $c || $_->conference =~ /Independent|Great West|div 2|fcs/;
        next if ($sport eq "clx" && ($_->conference eq "ACC" || $_->conference eq "Big East"));
        $c = $_->conference;
        $champs{$_->conference} = $_ if !exists $champs{$_->conference};
    }
}

{ #main
    # sports: c. baseball (64), c. basketball (68),
    # c. football (12) - mock playoff!
    # c. hockey (16), c. lacrosse (16)
    
    my $lname;
    if (defined $ARGV[0]) {
        $sport = $ARGV[0];
    } else { 
        print "please specify a sports league: (cbb | cbk | cfb | chk | clx)  ";
        $sport = <STDIN>;
        chomp $sport;
    }
    die unless $sport =~ /^(cbb|cbk|cfb|chk|clx)$/;
    
    # all files used in this scripts
    my $teams     = $sport . "\\teams.txt";          # csv list of teams, nicknames, shortnames, conference, and division
    
    # read input data and populate league
    open TEAMS, "<$teams" or die "Can't open $teams: $!";
    while (<TEAMS>) {
    next if /^\s*$/;
        chomp;
        my @tdesc = split /,/;
        $lname = $tdesc[0];
        $lnames{$lname} = Team->new(@tdesc);
    }
    close TEAMS;
    
    read_results($sport);
    find_conference_champs;
    # determine number of at-large / conference champs to put in field
    # note: this selection is based on projected winner of each conference
    # basing the projection on the team with the highest BT number
    # and on at-large selections based on highest BT number
    # This is NOT the same as the NCAA/BCS Selection Committee criteria!

    my @league = sort { $b->btnum <=> $a->btnum } values %lnames;
    my @champs = sort { $b->btnum <=> $a->btnum } values %champs;
    $#champs = 7 if $sport eq "cfb";
    
    my ($field, $autobid);
    if ($sport eq "cbb") {
        # 64 teams, all conferences except Great West and Big Sky
        # 30 automatic bids, 34 at-large
        ($field, $autobid) = (64, 30);
    } elsif ($sport eq "cbk") {
        # 68 teams, all conferences
        # 32 automatic bids, 36 at-large
        ($field, $autobid) = (68, 32);
    } elsif ($sport eq "cfb") {
        # 12 teams, top 8 conferences, note this is not a real tournament!
        # 8 automatic bids, 4 at-large
        ($field, $autobid) = (12, 8);
    } elsif ($sport eq "chk") {
        # 16 teams, all conferences
        # 5 automatic bids, 11 at-large
        ($field,$autobid) = (16, 5);
    } elsif ($sport eq "clx") {
        # 16 teams, all conferences except ACC
        # 6 automatic bids, 10 at-large
        ($field, $autobid) = (16, 6);
    }
    die unless @champs == $autobid;
    my @seedlist = ();
    foreach (@league) {
        push @seedlist, $_;
        splice @champs, 0, 1 if $champs[0]->name eq $_->name;
        last if @seedlist + @champs == $field;
    }
    push @seedlist, @champs;
    for (my $i = 0; $i < @seedlist; $i++) {
        printf "%2d:  %-25s %s\n", $i+1, $seedlist[$i]->name,
            exists $champs{$seedlist[$i]->conference} && ($champs{$seedlist[$i]->conference}->name eq $seedlist[$i]->name)
                ? $seedlist[$i]->conference
                : "";
    }
}
