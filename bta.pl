#####################################################################
# bta.pl -  Bradley-Terry sports analysis program                   #
# Copyright 2009, 2010 by Joel Fuhrmann                             #
#####################################################################


# bta.pl - new Object Oriented perl script for my Bradley-Terry program
use strict;
use warnings;
use Team;

my %lnames = ();
my %snames = ();
my $debugging = 0;
Team->debug(0);

sub parse_scores {
    my $sport = shift;
    my ($nm, $a, $sc, $ot, $r, $nc);
    $nm = "([-.'A-Za-z]+(?: [-A-Za-z&'.()]+)*)";
    $a = '(?:at )*';                                   # mlb baseball only
    $sc = '(\d+)';
    $ot = ' *(\(OT\)|\(SO\))*';                    # OT many sports, SO hockey only
    $r = '(?:#\d+ |\(\d+\) |No\. \d+ )*';     #college baseball, basketball, football only
    $nc = ' *(NC|EX)*';
    
    my $scores    = $sport . "\\scores.txt";         # scores file copied from espn.com
    my $log       = $sport . "\\log.txt";            # logfile (scanned copy of scores file)
    open SCORES, "<$scores" or die "Can't open $scores: $!";
    open LOG, ">$log" or die "Can't open $log: $!";

    # parse scores file and add games to existing data
    my $pattern = "^$a$r$nm $sc, $a$r$nm $sc$ot$nc.*\$";
    
    while (<SCORES>) {
        if (! /$pattern/o) {             # doesn't look like a score
            print LOG "*** $_" unless /^$/;
        } else {
            my ($team1,$score1,$team2,$score2,$otflag,$ncflag) = ($1,$2,$3,$4,$5,$6);
            print LOG "$team1 $score1, $team2 $score2";
            print LOG " $otflag" if defined $otflag;
            print LOG " $ncflag" if defined $ncflag;
            if ($sport =~ /^(mlb|nba|nfl|nhl)$/) {
                die "unrecognized team: $team1\n" if (!exists $lnames{$team1});
                die "unrecognized team: $team2\n" if (!exists $lnames{$team2});
            } else {
                $team1 = "ex" if !exists($lnames{$team1});
                $team2 = "ex" if !exists($lnames{$team2});
                next if $team1 eq $team2;
            }
            print LOG "<* INTERLEAGUE GAME *>" if $team1 eq "ex" || $team2 eq "ex";
            print LOG "\n";
            
            my $type;
            my ($c1,$d1,$c2,$d2) = ($lnames{$team1}->conference, $lnames{$team1}->division,
                                    $lnames{$team2}->conference, $lnames{$team2}->division);
            if ($ncflag && $c1 eq $c2 && $c1 ne "Independent") {
                $type = 5;
            } elsif ($d1 && $c1 eq $c2 && $c1 ne "Independent" && $d1 eq $d2) {
                $type = 1;
            } elsif ($c1 eq $c2 && $c1 ne "Independent") {
                $type = 2;
            } else {
                $type = 3;
            }
            if ($sport eq "nhl" && $score1 > $score2) {
                $lnames{$team1}->addpoints(2);
                $lnames{$team2}->addpoints(1) if (defined $otflag && ($otflag =~ /(\(OT\)|\(SO\))/));
            } elsif ($sport eq "nhl" && $score2 > $score1) {
                $lnames{$team2}->addpoints(2);
                $lnames{$team1}->addpoints(1) if (defined $otflag && ($otflag =~ /(\(OT\)|\(SO\))/));
            }                                       
            if ($score1 == $score2 || ($sport eq "nhl" && defined $otflag && $otflag eq "(SO)")) {
                $lnames{$team1}->addgame($lnames{$team2}, "T", $type);
                $lnames{$team2}->addgame($lnames{$team1}, "T", $type);
            } elsif ($score1 > $score2) {
                $lnames{$team1}->addgame($lnames{$team2}, "W", $type);
                $lnames{$team2}->addgame($lnames{$team1}, "L", $type);
            } else {
                $lnames{$team1}->addgame($lnames{$team2}, "L", $type);
                $lnames{$team2}->addgame($lnames{$team1}, "W", $type);
            }
        }
    }
    close SCORES;
    close LOG;
}

sub read_results {
    my $sport = shift;
    my $results   = $sport . "\\results.txt";        # list of teams and encoded game results for season
    my ($name, $shortname, $btnum, $games, $points, %games);
    
    open RESULTS, "<$results" or die "Can't open $results: $!\n";
    while (<RESULTS>) {
        chomp;
	# new!
	undef %games;
        if ($sport ne "nhl") {
            ($name, $shortname, $btnum, $games) = split /,/;
        } else {
            ($name, $shortname, $btnum, $points, $games) = split /,/;
        }
        %games = split / /, $games if $games;
        die "unknown team $lnames{$name} in $results!\n" if !exists $lnames{$name};
        $lnames{$name}->btnum($btnum);
        $lnames{$name}->points($points) if $sport eq "nhl";
        while (my ($key, $value) = each (%games)) {
            my $ncflag = ($key =~ s/(\*)//);
            die "unknown team $key in $results!\n" if !exists $snames{$key};
            while ($value =~ /(.)/g) {
                if ($lnames{$name}->conference ne $snames{$key}->conference || $lnames{$name}->conference eq "Independent") {
                    $lnames{$name}->addgame($snames{$key}, $1, 3);
                } elsif ($ncflag) {
                    $lnames{$name}->addgame($snames{$key}, $1, 5);
                } elsif ($lnames{$name}->division eq $snames{$key}->division) {
                    $lnames{$name}->addgame($snames{$key}, $1, 1);
                } else {
                    $lnames{$name}->addgame($snames{$key}, $1, 2);
                }
            }
        }
    }
    close RESULTS;
}

sub write_results {
    my $sport = shift;
    my $results   = $sport . "\\results.txt";        # list of teams and encoded game results for season
    my @league = sort { $a->conference cmp $b->conference
                       or $a->division cmp $b->division
                       or $a->name cmp $b-> name } values %lnames;
    
    # all done, write results file
    open RESULTS, ">$results" or die "Can't open $results: $!\n";
    for (@league) {
        if ($sport ne "nhl") {
            printf RESULTS "%s,%s,%.2f", $_->name, $_->shortname, $_->btnum;
        } else {
            printf RESULTS "%s,%s,%.2f,%d", $_->name, $_->shortname, $_->btnum, $_->points;
        }
        my %s = $_->results;
        print RESULTS "," if keys %s;
        while (my ($key, $value) = each (%s)) {
            print RESULTS "$key $value ";
        }
        print RESULTS "\n";     
    } 
    close RESULTS;
}

sub btcalc {
    my ($low, $mid, $high, $old) = (0, 100, -1, 0);
    my $anchor;
    my $crr = 0;
    my @league = sort {
        $a->win_percentage <=> $b->win_percentage
    } values %lnames;
    my $rtype;
    
    {   no strict; no warnings;
        if ($fx || $league[-1]->win_percentage == 1 || $league[0]->win_percentage == 0) {
            $anchor = 0;
            $rtype = 4;
            print "using fake game, anchor = 100\n";
        } else {
            $anchor = $league[@league/2];
            $rtype = 3;
            print "anchor = " . $anchor->shortname . ", " . $anchor->btnum . "\n";
        }
    }
    
    while ($low < $high || $high == -1) {
        my $diff = 1;
        my $eps1 = 0.00001;
        while ($diff > $eps1) {
            $diff = 0;
            my $err = 0;
            foreach (@league) {
                next if $_ == $anchor;
                my $ksum = 0;
                my %results = $_->results($rtype);
                while (my ($key, $value) = each (%results)) {
                    $key =~ s/\*$//;
                    $ksum += (length($value) / ($_->btnum + ($key eq "fx" ? 100 : $snames{$key}->btnum)));
                }
                die "division by zero\n" if ($ksum == 0);
                $_->btcalc(($_->wins($rtype) + $_->ties($rtype) / 2) / $ksum);
                $err = abs($_->btcalc - $_->btnum);
                $diff = $err if $err > $diff;
                die "data not converging - try running with -fx option\n" if $_->btcalc > 1e7;
            }
            foreach (@league) {    # copy calculated values into original slot for next pass
                next if $_ == $anchor;
                $_->btnum($_->btcalc);                                
            }
        }
        last if $anchor == 0;
        $crr = 0;
        for (@league) {         # calculate the 100-rated team's round robin winning percentage (call it crr)
            $crr += 100 / (100 + $_->btnum);
        }
        $crr /= @league;
        last if (abs($crr - 0.5) < $eps1);                      # otherwise calculate until $crr very close to 0.500.
        
        # search for the anchor number
        $old = $mid;
        if ($crr > 0.5 && $high == -1) {                                # must be higher, don't know how high, double initial guess                                                                      
            $low = $mid;
            $mid *= 2;
        } elsif ($crr > 0.5 && $high > 0) {                             # must be higher, but less than previous higher guess
            $low = $mid;
            $mid += ($high-$mid)/2;
        } elsif ($crr < 0.5) {                                                  # must be lower, but higher than previous lower guess
            $high = $mid;
            $mid -= ($mid-$low)/2;
        }
        
        for (@league) {
            $_->btnum($_->btnum * $mid/$old);
        }
        print "anchor = ",  $anchor->btnum, "\n";
    }
}

sub standings {
    my $sport = shift;
    my $group = shift || 3;                 # default - all teams in one group, 1=division, 2=conference.
    my $standings = $sport . "\\standings.txt";
    open STANDINGS, ">$standings" or die "Can't open $standings: $!";
    print uc($sport), " STANDINGS:\n";
    print STANDINGS uc($sport), " STANDINGS:\n";

    my @standings = sort {
        ($group < 3) && ($a->conference cmp $b->conference)
        or ($group == 1) && ($a->division cmp $b->division)
        or ($sport eq "nhl") && ($b->points/($b->wins+$b->losses+$b->ties || 1) <=> $a->points/($a->wins+$a->losses+$a->ties || 1))
        or ($group == 3 || $sport =~ /^(mlb|nba|nfl)$/) && ($b->win_percentage(3) <=> $a->win_percentage(3))
        or ($group < 3 && $sport =~ /^(cbb|cbk|cfb|chk|clx)$/) && ($b->win_percentage(2) <=> $a->win_percentage(2))
        or ($b->btnum <=> $a->btnum)
    } values %lnames;
    
    my $heading = "";
    for (@standings) {
        if ($group == 2 && uc($_->conference) ne $heading) {
            $heading = uc($_->conference);
            print "\n$heading\n";
            print STANDINGS "\n$heading\n";
        } elsif ($group == 1 && uc($_->conference) . " " . $_->division ne $heading) {
            $heading = uc($_->conference) . " " . $_->division;
            print "\n$heading\n";
            print STANDINGS "\n$heading\n";
        }

        if ($group < 3 && ($sport =~ /^(cbb|cbk|cfb|chk|clx)$/)) {   # college style - rank by conference results
            printf "%-31s %7s %7s %7s %7s\n", $_->name, $_->record(2), $_->win_percentage(2), $_->record(3), $_->win_percentage(3);
            printf STANDINGS "%-31s %7s %7s %7s %7s\n", $_->name, $_->record(2), $_->win_percentage(2), $_->record(3), $_->win_percentage(3);
        } elsif ($sport eq "nhl") {
            printf "%-31s %3s %10s %7s\n", $_->name, $_->points, $_->record, $_->win_percentage;
            printf STANDINGS "%-31s %3s %10s %7s\n", $_->name, $_->points, $_->record, $_->win_percentage;
        } else {                                                    # pro style - rank by all results
            printf "%-31s %7s %7s\n", $_->name, $_->record, $_->win_percentage;
            printf STANDINGS "%-31s %7s %7s\n", $_->name, $_->record, $_->win_percentage;
        }
    }
    print "\n";
    print STANDINGS "\n";
    close STANDINGS;
}

sub btrankings {
    my $sport = shift;
    my $group = shift || 3;                 # default - all teams in one group, 1=division, 2=conference.
    my $ranks = $sport . "\\ranks.txt";
    my $count = 0;
    my $groupsize;
    
    if ($sport =~ /^(cbb|cbk|cfb|chk|clx)$/) {
        $groupsize = 16;
    } else {
        $groupsize = 8;
    }
    open RANKS, ">$ranks" or die "Can't open $ranks: $!";
    my @ranks = sort {
        ($group < 3) && ($a->conference cmp $b->conference)
        or ($group == 1) && ($a->division cmp $b->division)
        or $b->btnum <=> $a->btnum 
    } values %lnames;

    if ($group == 3) {
        print "How many? (<enter> for all) ";
        chop($count = <STDIN>);
        $count = $count || @ranks;
    }
    print uc($sport), " BT RANKINGS\n";
    print RANKS uc($sport), " BT RANKINGS\n";
    my $gap = 0;
    my $heading = "";
    for (@ranks) {
        if ($group == 2 && uc($_->conference) ne $heading) {
            $heading = uc($_->conference);
            print "\n$heading\n";
            print RANKS "\n$heading\n";
            $gap = 0;
        } elsif ($group == 1 && uc($_->conference) . " " . $_->division ne $heading) {
            $heading = uc($_->conference) . " " . $_->division;
            print "\n$heading\n";
            print RANKS "\n$heading\n";
            $gap = 0;
        }
        printf "%-31s %8.1f\n", $_->name, $_->btnum;
        printf RANKS "%-31s %8.1f\n", $_->name, $_->btnum;
        last unless --$count;
        $gap++;
        if ($gap % $groupsize == 0) {
            print "\n";
            print RANKS "\n";
        }
    }
    print "\n";
    print RANKS "\n";
    close RANKS;
}

#####################################################################
{ # main() - program starts here
    my $sport;
    my ($lname, $sname);
    if (defined $ARGV[0]) {
        $sport = $ARGV[0];
    } else { 
        print "please specify a sports league: (cbb | cbk | cfb | chk | clx | mlb | nba | nfl | nhl)  ";
        $sport = <STDIN>;
        chomp $sport;
    }
    die unless $sport =~ /^(cbb|cbk|cfb|chk|clx|mlb|nba|nfl|nhl)$/;
    
    # all files used in this scripts
    my $teams     = $sport . "\\teams.txt";          # csv list of teams, nicknames, shortnames, conference, and division
    my $results   = $sport . "\\results.txt";        # results file (may not exist)
    my $scores    = $sport . "\\scores.txt";         # scores file
    
    # read input data and populate league
    open TEAMS, "<$teams" or die "Can't open $teams: $!";
    while (<TEAMS>) {
        next if /^\s*$/;
        chomp;
        my @tdesc = split /,/;
        ($lname, $sname) = @tdesc[0,2];
        $lnames{$lname} = Team->new(@tdesc);
        $snames{$sname} = $lnames{$lname};
    }
    close TEAMS;
    
    if (-e $results && -M $scores > -M $results) {
        read_results($sport);
    } else {
        # read all our scores and build a results table
        parse_scores($sport);
    
        # now we calculate the Bradley-Terry numbers
        my $runtime = "BT Calculation started at " . `time /t`;
        print "$runtime\n";
        btcalc;
        $runtime = "BT Calculation finished at " . `time /t`;
        print "$runtime\n";
    
        # write the results table out to a file with the BT numbers
        write_results($sport);
    }
    my $bydivision = 1;             # group results by division
    my $byconference = 2;           # group results by conference
    
    my $ans = "";
    print "Display standings by 1)division, 2)conference, or 3)league? ";
    while (chop($ans = <STDIN>) && ($ans ne "1" && $ans ne "2" && $ans ne "3")) {
        print "try again: enter 1, 2, or 3 ";
    }
    standings($sport, $ans);
    print "\n";
    
    if ($sport =~ /^(mlb|nba|nfl|nhl)$/) {
        btrankings($sport, $byconference);
    } else {
        btrankings($sport);
    }
}
