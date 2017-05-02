#####################################################################
#  Game.pm - implementation of Game class for Bradley-Terry         #
#            sports analysis program                                #
# Copyright 2010 by Joel Fuhrmann                                   #
#####################################################################
package Game;
use strict;
use warnings;
use Carp;
use Team;

# class data
my $Debugging = 0;              # for debugging
my $SetSize = 0;             # counter

# constructor
sub new {
    my $class = shift;
    my ($date, $hteam, $vteam, $hscore, $vscore, $status, $type, $comment) = @_;
    my $flag;
    my $self = {};
    $self->{DATE}           = defined($date) ? $date : "";
    $self->{HTEAM}          = defined($hteam) ? $hteam : "";
    $self->{VTEAM}          = defined($vteam) ? $vteam : "";
    $self->{HSCORE}         = defined($hscore) ? $hscore : 0;
    $self->{VSCORE}         = defined($vscore) ? $vscore : 0;
    $self->{FLAG}           = defined($flag) ? $flag : "";
    $self->{TYPE}           = defined($type) ? $type : 0;
    $self->{STATUS}         = defined($status) ? $status : "";
    $self->{COMMENT}        = defined($comment) ? $comment : "";
    $self->{POINTS}         = 0;
    $self->{"_DEBUG"}       = \$Debugging;
    $self->{"_SETSIZE"}     = \$SetSize;
    bless ($self, $class);
    ++${$self->{"_SETSIZE"}};
    if (${$self->{"_DEBUG"}}) { 
        carp "Creating new $self: " .
            defined($self->{HTEAM}) ? $self->{HTEAM} : "(no name)" .
            defined($self->{VTEAM}) ? $self->{VTEAM} : "(no name)";
        print "Current size of class: ", ${$self->{"_SETSIZE"}}, "\n"; 
    }
    return $self;
}

# destructor
sub DESTROY {
    my $self = shift;
    if ($Debugging || ${$self->{"_DEBUG"}}) {
        carp "Destroying $self: " .
            defined($self->{HTEAM}) ? $self->{HTEAM} : "(no name)" .
            defined($self->{VTEAM}) ? $self->{VTEAM} : "(no name)";
    }
    --${$self->{"_SETSIZE"}};
    if ($Debugging || ${$self->{"_DEBUG"}}) {
        print "Current size of class: ", ${$self->{"_SETSIZE"}}, "\n"; 
    }
}

# access methods: argument provided = set() else get()
sub date {
    my $self = shift;
    if (@_) { $self->{DATE} = shift }
    return $self->{DATE};
}
sub hteam {
    my $self = shift;
    if (@_) { $self->{HTEAM} = shift }
    return $self->{HTEAM};
}
sub vteam {
    my $self = shift;
    if (@_) { $self->{VTEAM} = shift }
    return $self->{VTEAM};
}
sub hscore {
    my $self = shift;
    if (@_) { $self->{HSCORE} = shift }
    return $self->{HSCORE};
}
sub vscore {
    my $self = shift;
    if (@_) { $self->{VSCORE} = shift }
    return $self->{VSCORE};
}
sub flag {
    my $self = shift;
    if (@_) { $self->{FLAG} = shift }
    return $self->{FLAG};
}
sub type {
    my $self = shift;
    if (@_) { $self->{TYPE} = shift }
    return $self->{TYPE};
}
sub status {
    my $self = shift;
    if (@_) { $self->{STATUS} = shift }
    return $self->{STATUS};
}
sub comment {
    my $self = shift;
    if (@_) { $self->{COMMENT} = shift }
    return $self->{COMMENT};
}
sub points {
    my $self = shift;
    if (@_) { $self->{POINTS} = shift }
    return $self->{POINTS};
}
sub addpoints {
    my $self = shift;
    my $n = shift;
    confess "usage: Game->addpoints(#)" unless $n =~ /^\d+$/;
    $self->{POINTS} += $n;
}

sub report {
    my $self = shift;
    my $msg;
    if ($self->status =~ /final/i) {
        $msg = sprintf "%s %d, %s %d %s%s  %s", $self->vteam, $self->vscore, $self->hteam, $self->hscore, $self->flag, $self->type, $self->comment;
    } else {
        $msg = sprintf "%s at %s  %s %s", $self->vteam, $self->hteam, $self->status, $self->comment;
    }
    return $msg;
}

sub points_report {
    my $self = shift;
    my $msg;
    $msg = sprintf "%2d  %s at %s", $self->points, $self->vteam, $self->hteam;
    return $msg;
}

sub population {
    my $self = shift;
    if (ref $self) {            # this is an object
        return ${$self->{"_SETSIZE"}};
    } else {                            # this is a class
        return $SetSize;
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



