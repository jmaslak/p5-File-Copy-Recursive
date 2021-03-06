use strict;
use warnings;

our $curr_unlink = sub { return CORE::unlink(@_) };    # I wish goto would work here :/

BEGIN {
    no warnings 'redefine';
    *CORE::GLOBAL::unlink = sub { goto $curr_unlink };
}

use Test::More;
use Test::Deep;
use Test::File;
use Test::Warn;

use File::Slurp;
use File::Temp;
use Path::Iter;
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove pathmk pathrm pathempty pathrmdir rcopy_glob rmove_glob);

note "functionality w/ default globals";
{
    is( $File::Copy::Recursive::DirPerms, 0777, "DirPerms default is 0777" );
    ok( !$File::Copy::Recursive::CPRFComp, "CPRFComp default is false" );
    ok( !$File::Copy::Recursive::RMTrgFil, "RMTrgFil default is false" );

    my $tmpd = _get_fresh_tmp_dir();

    # dircopy()
    {
        my $rv = dircopy( "$tmpd/orig", "$tmpd/new" );
        _is_deeply_path( "$tmpd/new", "$tmpd/orig", "dircopy() defaults as expected when target does not exist" );

        mkdir "$tmpd/newnew";
        my @dircopy_rv = dircopy( "$tmpd/orig", "$tmpd/newnew" );
        _is_deeply_path( "$tmpd/newnew", "$tmpd/orig", "dircopy() defaults as expected when target does exist" );

        $rv = dircopy( "$tmpd/orig/data", "$tmpd/new" );
        ok( !$rv, "dircopy() returns false if source is not a directory" );

        $rv = dircopy( "$tmpd/orig", "$tmpd/new/data" );
        ok( !$rv, "dircopy() returns false if target is not a directory" );
    }

    # dirmove()
    {
        my $rv = dirmove( "$tmpd/newnew", "$tmpd/moved" );
        _is_deeply_path( "$tmpd/moved", "$tmpd/orig", "dirmove() defaults as expected when target does not exist" );
        ok( !-d "$tmpd/newnew", "dirmove() removes source (when target does not exist)" );

        mkdir "$tmpd/movedagain";
        my @dirmove_rv = dirmove( "$tmpd/moved", "$tmpd/movedagain" );
        _is_deeply_path( "$tmpd/movedagain", "$tmpd/orig", "dirmove() defaults as expected when target does exist" );
        ok( !-d "$tmpd/moved", "dirmove() removes source (when target does exist)" );

        $rv = dirmove( "$tmpd/orig/data", "$tmpd/new" );
        ok( !$rv,                 "dirmove() returns false if source is not a directory" );
        ok( -e "$tmpd/orig/data", "dirmove() does not delete source if source is not a directory" );

        $rv = dirmove( "$tmpd/orig", "$tmpd/new/data" );
        ok( !$rv,            "dirmove() returns false if target is not a directory" );
        ok( -e "$tmpd/orig", "dirmove() does not delete source if target is not a directory" );
    }

    # fcopy()
    {
        # that fcopy copies files and symlinks is covered by the dircopy tests, specifically _is_deeply_path()
        my $rv = fcopy( "$tmpd/orig/data", "$tmpd/fcopy" );
        is( read_file("$tmpd/orig/data"), read_file("$tmpd/fcopy"), "fcopy() defaults as expected when target does not exist" );

        write_file( "$tmpd/fcopyexisty", "oh hai" );
        my @fcopy_rv = fcopy( "$tmpd/orig/data", "$tmpd/fcopyexisty" );
        is( read_file("$tmpd/orig/data"), read_file("$tmpd/fcopyexisty"), "fcopy() defaults as expected when target does exist" );

        $rv = fcopy( "$tmpd/orig", "$tmpd/fcopy" );
        ok( !$rv, "fcopy() returns false if source is a directory" );
    }

    # fmove() WiP
    {

        # that fmove copies files and symlinks is covered by the dirmove tests, specifically _is_deeply_path()
        write_file( "$tmpd/data", "oh hai" );
        my $rv = fmove( "$tmpd/data", "$tmpd/fmove" );
        ok( $rv && !-e "$tmpd/data", "fmove() removes source file (target does not exist)" );

        write_file( "$tmpd/existy",      "42" );
        write_file( "$tmpd/fmoveexisty", "oh hai" );
        my @fmove_rv = fmove( "$tmpd/existy", "$tmpd/fmoveexisty" );
        ok( $rv && !-e "$tmpd/existy", "fmove() removes source file (target does exist)" );

        $rv = fmove( "$tmpd/orig", "$tmpd/fmove" );
        ok( !$rv, "fmove() returns false if source is a directory" );
    }

    # rcopy()
    {
        my $rv = rcopy( "$tmpd/orig/noexist", "$tmpd/rcopy/" );
        ok !$rv, 'rcopy() returns false on non existant path';

        no warnings "redefine";
        my @dircopy_calls;
        my @fcopy_calls;
        local *File::Copy::Recursive::dircopy = sub { push @dircopy_calls, [@_] };
        local *File::Copy::Recursive::fcopy   = sub { push @fcopy_calls,   [@_] };

        File::Copy::Recursive::rcopy( "$tmpd/orig/", "$tmpd/rcopy/" );
        is( @dircopy_calls, 1, 'rcopy() dispatches directory to dircopy()' );

        File::Copy::Recursive::rcopy( "$tmpd/orig/*", "$tmpd/rcopy/" );
        is( @dircopy_calls, 2, 'rcopy() dispatches directory glob to dircopy()' );

        File::Copy::Recursive::rcopy( "$tmpd/empty", "$tmpd/rcopy/" );
        is( @fcopy_calls, 1, 'rcopy() dispatches empty file to fcopy()' );

        File::Copy::Recursive::rcopy( "$tmpd/data", "$tmpd/rcopy/" );
        is( @fcopy_calls, 2, 'rcopy() dispatches  file (w/ trailing new line)to fcopy()' );

        File::Copy::Recursive::rcopy( "$tmpd/data_tnl", "$tmpd/rcopy/" );
        is( @fcopy_calls, 3, 'rcopy() dispatches file (w/ no trailing new line) to fcopy()' );

        File::Copy::Recursive::rcopy( "$tmpd/symlink", "$tmpd/rcopy/" );
        is( @fcopy_calls, 4, 'rcopy() dispatches symlink to fcopy()' );

        File::Copy::Recursive::rcopy( "$tmpd/symlink-broken", "$tmpd/rcopy/" );
        is( @fcopy_calls, 5, 'rcopy() dispatches broken symlink to fcopy()' );

        File::Copy::Recursive::rcopy( "$tmpd/symlink-loopy", "$tmpd/rcopy/" );
        is( @fcopy_calls, 6, 'rcopy() dispatches loopish symlink to fcopy()' );
    }

    # rmove()
    {
        my $rv = rmove( "$tmpd/orig/noexist", "$tmpd/rmove/" );
        ok !$rv, 'rmove() returns false on non existant path';

        no warnings "redefine";
        my @dirmove_calls;
        my @fmove_calls;
        local *File::Copy::Recursive::dirmove = sub { push @dirmove_calls, [@_] };
        local *File::Copy::Recursive::fcopy   = sub { push @fmove_calls,   [@_] };

        File::Copy::Recursive::rmove( "$tmpd/orig/", "$tmpd/rmove/" );
        is( @dirmove_calls, 1, 'rmove() dispatches directory to dirmove()' );

        File::Copy::Recursive::rmove( "$tmpd/orig/*", "$tmpd/rmove/" );
        is( @dirmove_calls, 2, 'rmove() dispatches directory glob to dirmove()' );

        File::Copy::Recursive::rmove( "$tmpd/empty", "$tmpd/rmove/" );
        is( @fmove_calls, 1, 'rmove() dispatches empty file to fcopy()' );

        File::Copy::Recursive::rmove( "$tmpd/data", "$tmpd/rmove/" );
        is( @fmove_calls, 2, 'rmove() dispatches  file (w/ trailing new line)to fcopy()' );

        File::Copy::Recursive::rmove( "$tmpd/data_tnl", "$tmpd/rmove/" );
        is( @fmove_calls, 3, 'rmove() dispatches file (w/ no trailing new line) to fcopy()' );

        File::Copy::Recursive::rmove( "$tmpd/symlink", "$tmpd/rmove/" );
        is( @fmove_calls, 4, 'rmove() dispatches symlink to fcopy()' );

        File::Copy::Recursive::rmove( "$tmpd/symlink-broken", "$tmpd/rmove/" );
        is( @fmove_calls, 5, 'rmove() dispatches broken symlink to fcopy()' );

        File::Copy::Recursive::rmove( "$tmpd/symlink-loopy", "$tmpd/rmove/" );
        is( @fmove_calls, 6, 'rmove() dispatches loopish symlink to fcopy()' );
    }

    # rcopy_glob()
    {
        my @rcopy_srcs;
        no warnings "redefine";
        local *File::Copy::Recursive::rcopy = sub { push @rcopy_srcs, $_[0] };
        rcopy_glob( "$tmpd/orig/*l*", "$tmpd/rcopy_glob" );
        is( @rcopy_srcs, 4, "rcopy_glob() calls rcopy for each file in the glob" );
    }

    # rmove_glob()
    {
        my @rmove_srcs;
        no warnings "redefine";
        local *File::Copy::Recursive::rmove = sub { push @rmove_srcs, $_[0] };
        rmove_glob( "$tmpd/orig/*l*", "$tmpd/rmove_glob" );
        is( @rmove_srcs, 4, "rmove_glob() calls rmove for each file in the glob" );
    }

    # PATCHES WELCOME!
    #     TODO: tests for sameness behavior and it use in all of these functions
    #     TODO: @rv behavior in all of these functions
    #     TODO: test for util functions; pathmk pathrm pathempty pathrmdir
}

note "functionality w/ 'value' globals";
{
    local $File::Copy::Recursive::DirPerms = 0751;
    my $tmpd = _get_fresh_tmp_dir();
    mkdir( "$tmpd/what", 0777 );
    File::Copy::Recursive::pathmk("$tmpd/what/what/what");

    file_mode_isnt( "$tmpd/what", 0751, 'DirPerms in pathmk() does not effect existing dir' );
    file_mode_is( "$tmpd/what/what",      0751, 'DirPerms in pathmk() effects initial new dir' );
    file_mode_is( "$tmpd/what/what/what", 0751, 'DirPerms in pathmk() effects subsequent new dir' );

    local $File::Copy::Recursive::KeepMode = 0;    # overrides $DirPerms in dircopy()
    File::Copy::Recursive::dircopy( "$tmpd/orig", "$tmpd/new" );
    for my $dir ( _get_dirs() ) {
        $dir =~ s/orig/new/;
        file_mode_is( "$tmpd/$dir", 0751, "DirPerms in dircopy() effects dir ($dir)" );
    }
}

note "functionality w/ 'behavior' globals";
{
    {
        local $File::Copy::Recursive::CPRFComp = 1;
        my $tmpd = _get_fresh_tmp_dir();
        File::Copy::Recursive::dircopy( "$tmpd/orig", "$tmpd/new" );
        _is_deeply_path( "$tmpd/new", "$tmpd/orig", "CPRFComp being true effects dircopy() as expected when target does not exist" );

        mkdir "$tmpd/existy";
        File::Copy::Recursive::dircopy( "$tmpd/orig", "$tmpd/existy" );
        _is_deeply_path( "$tmpd/existy/orig", "$tmpd/orig", "CPRFComp being true effects dircopy() as expected when target exists" );

        File::Copy::Recursive::dircopy( "$tmpd/orig/*", "$tmpd/newnew" );
        _is_deeply_path( "$tmpd/newnew", "$tmpd/orig", "CPRFComp being true w/ glob path effects dircopy() as expected when target does not exist" );

        mkdir "$tmpd/existify";
        File::Copy::Recursive::dircopy( "$tmpd/orig/*", "$tmpd/existify" );
        _is_deeply_path( "$tmpd/existify", "$tmpd/orig", "CPRFComp being true w/ glob path effects dircopy() as expected when target exists" );
    }

    {
        my $tmpd = _get_fresh_tmp_dir();
        local $File::Copy::Recursive::RMTrgFil = 1;

        local $curr_unlink = sub { $! = 5; return; };
        mkdir "$tmpd/derp";
        write_file( "$tmpd/derp/data", "I exist therefor I am." );

        warning_like {
            my $rv = File::Copy::Recursive::fcopy( "$tmpd/orig/data", "$tmpd/derp/data" );
            ok( $rv, "fcopy() w/ \$RMTrgFil = 1 to file-returned true" );
        }
        qr/RMTrgFil failed/, "fcopy() w/ \$RMTrgFil = 1 to file-warned";

        warning_like {
            my $rv = File::Copy::Recursive::fcopy( "$tmpd/orig/data", "$tmpd/derp" );
            ok( $rv, "fcopy() w/ \$RMTrgFil = 1 to dir-returned true" );
        }
        qr/RMTrgFil failed/, "fcopy() w/ \$RMTrgFil = 1 to dir-warned";
    }

    {
        my $tmpd = _get_fresh_tmp_dir();
        local $File::Copy::Recursive::RMTrgFil = 2;

        local $curr_unlink = sub { $! = 5; return; };
        mkdir "$tmpd/derp";
        write_file( "$tmpd/derp/data", "I exist therefor I am." );

        warnings_are {
            my $rv = File::Copy::Recursive::fcopy( "$tmpd/orig/data", "$tmpd/derp/data" );
            ok( !$rv, "fcopy() w/ \$RMTrgFil = 2 to file-returned false" );
        }
        [], "fcopy() w/ \$RMTrgFil = 2 to file-no warning";

        warnings_are {
            my $rv = File::Copy::Recursive::fcopy( "$tmpd/orig/data", "$tmpd/derp" );
            ok( !$rv, "fcopy() w/ \$RMTrgFil = 2 to dir-returned false" );
        }
        [], "fcopy() w/ \$RMTrgFil = 2 to dir-no warning";
    }

    # TODO (this is one reason why globals are not awesome :/)
    # $MaxDepth
    # $KeepMode
    # $CopyLink
    #    $BdTrgWrn
    # $PFSCheck
    # $RemvBase
    #    ForcePth
    # $NoFtlPth
    # $ForcePth
    # $CopyLoop
    # $RMTrgDir
    # $CondCopy
    # $BdTrgWrn
    # $SkipFlop
}

done_testing;

###############
#### helpers ##
###############

sub _get_dirs {
    return (qw(orig orig/foo orig/foo/bar orig/foo/baz orig/foo/bar/wop));
}

sub _get_fresh_tmp_dir {
    my $tmpd = File::Temp->newdir;
    for my $dir ( _get_dirs() ) {
        mkdir "$tmpd/$dir" or die "Could not mkdir($tmpd/$dir) :$!\n";
        write_file( "$tmpd/$dir/empty",    "" );
        write_file( "$tmpd/$dir/data",     "oh hai\n$tmpd/$dir" );
        write_file( "$tmpd/$dir/data_tnl", "oh hai\n$tmpd/$dir\n" );
        symlink( "data",    "$tmpd/$dir/symlink" );
        symlink( "noexist", "$tmpd/$dir/symlink-broken" );
        symlink( "..",      "$tmpd/$dir/symlink-loopy" );
    }

    return $tmpd;
}

sub _is_deeply_path {
    my ( $got_dir, $expected_dir, $test_name ) = @_;

    my $got_tree_hr      = _get_tree_hr($got_dir);
    my $expected_tree_hr = _get_tree_hr($expected_dir);

    is_deeply( $got_tree_hr, $expected_tree_hr, $test_name );

    for my $path ( sort keys %{$got_tree_hr} ) {
        if ( $got_tree_hr->{$path} eq "symlink" ) {
            is( readlink("$got_dir/$path"), readlink("$expected_dir/$path"), "  - symlink target preserved (…$path)" );
        }
        elsif ( $got_tree_hr->{$path} eq "file" ) {
            is( read_file("$got_dir/$path"), read_file("$expected_dir/$path"), "  - file contents preserved (…$path)" );
        }
    }
}

sub _get_tree_hr {
    my ($dir) = @_;
    return if !-d $dir;

    my %tree;
    my $fetch = Path::Iter::get_iterator($dir);

    while ( my $next_path = $fetch->() ) {
        my $normalized_next_path = $next_path;
        $normalized_next_path =~ s/\Q$dir\E//;
        $tree{$normalized_next_path} =
            -l $next_path ? "symlink"
          : -f $next_path ? "file"
          : -d $next_path ? "directory"
          :                 "¯\_(ツ)_/¯";
    }

    return \%tree;
}
