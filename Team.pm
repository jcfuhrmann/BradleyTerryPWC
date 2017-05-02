#####################################################################
#  Team.pm - implementation of Team class for Bradley-Terry         #
#            sports analysis program                                #
# Copyright 2009, 2010 by Joel Fuhrmann                             #
#####################################################################

# Team class: definition of Team objects for my Bradley-Terry program
package Team;
use strict;
use warnings;
use Carp;

# class data
my $Debugging = 0;              # for debugging
my $LeagueSize = 0;             # counter

# constructor
sub new {
    my $class = shift;
    my ($name, $nick, $short, $conf, $div) = @_;
    my $self = {};
    $self->{NAME}           = defined($name) ? $name : "";
    $self->{NICKNAME}       = defined($nick) ? $nick : "";
    $self->{SHORTNAME}      = defined($short) ? $short : "";
    $self->{CONFERENCE}     = defined($conf) ? $conf : "";
    $self->{DIVISION}       = defined($div) ? $div : "";
    $self->{DIV_RESULTS}    = { };
    $self->{CONF_RESULTS}   = { }; 
    $self->{NC_RESULTS}     = { };                          # looks like [SHORTNAME WLT ...]
    $self->{FAKE}           = { fx => "T" };
    $self->{BTNUM}          = 100;                          # Bradley-Terry number
    $self->{BTCALC}         = 100;                          # interim value used in iteration
    $self->{POINTS}	    = 0;			    # used only in NHL Hockey = 2*W + OTL + SOL
    $self->{"_DEBUG"}       = \$Debugging;
    $self->{"_LEAGUESIZE"}  = \$LeagueSize;
    bless ($self, $class);
    ++${$self->{"_LEAGUESIZE"}};
    if (${$self->{"_DEBUG"}}) { 
        carp "Creating new $self: " . (defined($self->{NAME}) ? $self->{NAME} : "(no name)");
        print "Current league size: ", ${$self->{"_LEAGUESIZE"}}, "\n"; 
    }
    return $self;
}

# destructor
sub DESTROY {
    my $self = shift;
    if ($Debugging || ${$self->{"_DEBUG"}}) {
        carp "Destroying $self: " . (defined($self->{NAME}) ? $self->{NAME} : "(no name)");
    }
    --${$self->{"_LEAGUESIZE"}};
    if ($Debugging || ${$self->{"_DEBUG"}}) {
        print "Current league size: ", ${$self->{"_LEAGUESIZE"}}, "\n"; 
    }
}

# access methods: argument provided = set() else get()
sub name {
    my $self = shift;
    if (@_) { $self->{NAME} = shift }
    return $self->{NAME};
}
sub nickname {
    my $self = shift;
    if (@_) { $self->{NICKNAME} = shift }
    return $self->{NICKNAME};
}
sub shortname {
    my $self = shift;
    if (@_) { $self->{SHORTNAME} = shift }
    return $self->{SHORTNAME};
}
sub conference {
    my $self = shift;
    if (@_) { $self->{CONFERENCE} = shift }
    return $self->{CONFERENCE};
}
sub division {
    my $self = shift;
    if (@_) { $self->{DIVISION} = shift }
    return $self->{DIVISION};
}
sub results {
    my $self = shift;               # get function only, use addgame to add games to list
    my $type = 3;                   # default value 3= all games, also 1=division, 2=conference, 4=fake
    $type = shift if @_;
    my @ret;
    @ret = %{$self->{DIV_RESULTS}};
    push @ret, %{$self->{CONF_RESULTS}} if $type > 1;
    push @ret, %{$self->{NC_RESULTS}} if $type > 2;
    push @ret, %{$self->{FAKE}} if $type > 3;               # for fake game
    return @ret;
}
sub btnum {
    my $self = shift;
    if (@_) { $self->{BTNUM} = shift }
    return $self->{BTNUM};
}
sub btcalc {
    my $self = shift;
    if (@_) { $self->{BTCALC} = shift }
    return $self->{BTCALC};
}
sub points {
    my $self = shift;
    if (@_) { $self->{POINTS} = shift }
    return $self->{POINTS};
}


# game reference functions
sub addgame {
    my $self = shift;
    confess "usage: this->addgame(opponent, result, type)" unless @_ == 3;
    my ($opponent, $result, $type) = @_;
    if ($type == 1) {
        $self->{DIV_RESULTS}->{$opponent->{SHORTNAME}} .= $result;
    } elsif ($type == 2) {
        $self->{CONF_RESULTS}->{$opponent->{SHORTNAME}} .= $result;
    } elsif ($type == 3) {
        $self->{NC_RESULTS}->{$opponent->{SHORTNAME}} .= $result;
    } elsif ($type == 4) {
        $self->{FAKE}->{$opponent->{SHORTNAME}} .= $result;
    } elsif ($type == 5) {
        $self->{NC_RESULTS}->{$opponent->{SHORTNAME}."*"} .= $result;
    } else {
        carp "Unknown game type: $opponent $result $type" if ${$self->{"_DEBUG"}}; 
    }
}
sub addpoints {
    my $self = shift;
    confess "usage: this->addpoints(num)" unless @_ == 1;
    my $points = shift;
    $self->{POINTS} += $points;
}
sub wins {
    my $self = shift;
    my $type = 3;                   # default value
    $type = shift if @_;
    my $count = 0;
    my %results = $self->results($type);
    # count the 'W's
    while (my ($key, $value) = each (%results)) {
        $count += ($value =~ tr/W//);
    }
    return $count;
}
sub losses {
    my $self = shift;
    my $type = 3;                   # default value
    $type = shift if @_;
    my $count = 0;
    my %results = $self->results($type);
    # count the 'L's
    while (my ($key, $value) = each (%results)) {
        $count += ($value =~ tr/L//); 
    }
    return $count;
}
sub ties {
    my $self = shift;
    my $type = 3;                   # default value
    $type = shift if @_;
    my $count = 0;
    my %results = $self->results($type);
    # count the 'T's
    while (my ($key, $value) = each (%results)) {
        $count += ($value =~ tr/T//); 
    }
    return $count;
}
sub record {
    my $self = shift;
    my $type = 3;                   # default value
    $type = shift if @_;
    my ($w, $l, $t) = ($self->wins($type), $self->losses($type), $self->ties($type));
    my $rec = sprintf "%d-%d", $w, $l;
    $rec .= ($t == 0 ? "" : "-" . $t);
}
sub win_percentage {
    my $self = shift;
    my $type = 3;                   # default value
    $type = shift if @_;
    my $wp;
    my @wlt = split /-/, $self->record($type);
    if (@wlt == 2) {
        return 1.0 if ($wlt[0] + $wlt[1] == 0);
        $wp = $wlt[0] / ($wlt[0] + $wlt[1]);
    } elsif (@wlt == 3) {
        return 1.0 if ($wlt[0] + $wlt[1] + $wlt[2] == 0);
        $wp = ($wlt[0] + $wlt[2]/2) / ($wlt[0] + $wlt[1] + $wlt[2]);
    } else {
        return "";      # shouldn't happen
    } 
    return sprintf "%5.3f", $wp;
}

# Class data functions
sub population {
    my $self = shift;
    if (ref $self) {            # this is an object
        return ${$self->{"_LEAGUESIZE"}};
    } else {                            # this is a class
        return $LeagueSize;
    }
}

# debugging control - $level = 1 turns debugging on (0 off)
sub debug {
    my $self = shift;
    confess "usage: thing->debug(level)" unless @_ == 1;
    my $level = shift;
    if (ref($self))  {
        ${$self->{"_DEBUG"}} = $level;         # just myself
    } else {
        $Debugging = $level;         # whole class
    }
}

1;
