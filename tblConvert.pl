#!/usr/bin/perl
#===============================================================================
#
#         FILE:  tblConvert.pl
#
#        USAGE:  ./tblConvert.pl  
#
#  DESCRIPTION:  Convert tables from and to column difference values
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Paul DeStefano
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  10/11/2011 11:31:23 AM
#     REVISION:  ---
#   SOURCE URI:  http://github.com/PaulDeStefano/tblConvert
#      LICENSE:  GPL3
#
#   Copyright 2011 Paul DeStefano
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#===============================================================================

use strict;
use warnings;
use Data::Dumper ;
use Getopt::Long ;

my %OPT = (
  debug     => 0  ,
  params    => 0 ,
  delim     => "," ,
  skip      => 0 ,
  points    => undef ,
);

sub showHelp {
  print( STDOUT "
tblConvert.pl [options] -i|--intputlabel <label> -o|--outputlabel <label>
  Description: tblConvert.pl reads standard input, interpreting each line as
              a table record.  Both input and output labels (or column headings
              are quired.  tblConvert uses the given labels to determine and
              perform the requested calculations.  Possible caculations include
              the sum or difference of two input fields but it can also reorder
              fields in a record, remove fields, and add blank fields.
              
  Label Specification: A record label is a list of comma separated field labels
              or column headers.

      ,,    : Two adjacent commas represent an empty field.  An empty input 
              field will not be given a name, but will obtain the default label
              of the integer number of field's order within the input record.
              An empty output field will always be blank.
      ,N,   : (Output label only.) A single integer, N, means output the (N-1)th
              column of the input record.  The left-most column is the 0th
              column.  (Do not use numbers to label input records.  Numbers 
              alway refer to the column or field of the intput record.)
      ,A,   : A single (non-numeric) letter character is a column label or
              header.
      ,A-B, : The difference of column A and column B.
      ,A-N, : The difference of column A and column #N.
      ,A+B, : The sum of column A and B.
      ,N+B, : The sum of column #N and B.

      e.g.  : -i 'S,,V,B-V,U-B,V-R,V-I' -o 'S,U,V,B,R,I,1' --> Output records
              will be the first input column (unchanged), followed by the sum of
              the fifth, fourth and third colums (U=U-B+B-V+V), followed by the 
              third column, unchanged, follwed by the sum of the fourth and 
              thrid columns (B=B-V+V), followed by the difference of the third 
              and sixth columns (V-(V-R)), followed by the difference of thrid 
              and seventh columns V-(V-I), followed by the first column.

  Options:
      -h|--help                 : show this message
      -s|--skip <#>             : skip # lines of input
      -d|--delimiter <delim|#>  : use <delim> as delimiter character between
          data columns OR <#> as width of fixed-width columns in units of
          characters spaces.
      -p|--precision <#>        : set precision of floating point output values
          in fixed-width tables.  Only effective with -d <#> .  Does not affect
          interger values or delimited tables.
      --debug <#>               : set debug level to # (default=0, max 4)

  \n" );
}

sub stringToMap {
  # convert a string to a heading->column map
  my $string = shift ;
  if($OPT{debug}>3) { print( STDERR "DEBUG: stringToMap: $string \n" ); }
  my %map = () ;
  my $i = 0;
  for my $inst ( split( /,/ , $string , -1 ) ) {
    if($OPT{debug}>3) { print( STDERR "DEBUG: stringToMap: $inst \n" ); }
    if( $inst eq '' ) {
      # anon field
      $inst = $i ;
    }
    if( !defined( $map{$inst}) ) {
      # if this map is NOT already set, set it
      # map uses left-most field with any label, ignores
      # subsequent fields with the same label
      $map{$inst} = $i ;
      $map{$i} = $i ;
    }
    $i++;
  }

  return \%map ;

}

sub strToNum {
  # convert string to number value
  my $s = shift;
  if($OPT{debug}>3) { print( STDERR "DEBUG: strToNum: got string: $s","\n" ); }
  my $num = $s ;

  # clean value as much as possible
  $num =~ s/[^\w.-]+//g ;
  if( $num =~ m/^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/ ) {
    # is a number
    return $num - 0;
  }

  return undef ;
}

sub parseInst {
  # interpret a user instruction
  my $inst = shift ;
  my ( $o1, $opr, $o2 , @rest) = split( //, $inst );
    if($inst eq '') {
      #print blank field if there the instruction is empty
      if($OPT{debug}>3) { print( STDERR "DEBUG: empty column\n" ); }
      $opr = "empty" ;
    } 
    if( @rest ) { 
      # otherwise, instructions are: column#,operator,column#
      #catch and skip wierd instructions
      print( STDERR "ERROR: parseInst: unrecongnized instruction: $inst\n" );
      $opr = undef ; 
    }
  return $opr , $o1 , $o2 ;

}

sub doOp {
  my $opr = shift ;
  my $o1 = shift ;
  my $o2 = shift ;

  # make sure we have numbers before doing a calculation
  $o1 = strToNum( $o1 );
  $o2 = strToNum( $o2 );
  unless( defined($o1) and defined($o2) ) {
    if($OPT{debug}>3) { print( STDERR "DEBUG: doOp: found NAN field \n" ); }
    return 'NAN' ;
  }

  my $val = undef ;
  for( $opr ) {
    /^\+/     and do { $val = $o1 + $o2; last;};
    /^\-/     and do { $val = $o1 - $o2; last;};
  }

  if($OPT{debug}>3) { print( STDERR "DEBUG: doOp: $val = $o1 $opr $o2 \n" ); }
  return $val ;
}

sub revCalc {
  my $header = shift ;
  my $colVal = shift ;
  my $catRef = shift ;

  # disect the expression
  my ($opr, $oh1, $oh2 ) = parseInst( $header );
  if( !defined( $opr ) ) {
    # error
    if($OPT{debug}>3) { print( STDERR "ERROR: revCalc: cannot calculate $header\n" ); }
    return undef, undef ;
  }
  # find out which, if any of the operands are known values
  my $v1 = $catRef->{values}{$oh1} ;
  my $v2 = $catRef->{values}{$oh2} ;
    # Four possible cases given equation: $colVal = $oh1 $opr $oh2
    # 1) $name = $oh1 & $opr = subtraction  --> $colVal + $oh2
    # 2) $name = $oh1 & $opr = addition     --> $colVal - $oh2
    # 3) $name = $oh2 & $opr = subtraction  --> $oh1 - $colVal
    # 4) $name = $oh2 & $opr = addition     --> $colVal - $oh1 
  my $value = undef ;
  my $operand = undef ;
  if( defined($v1) ) {
        # we have oh1, can find oh2 (cases 3&4)
        $operand = $oh2 ;
        if($OPT{debug}>3) { print( STDERR "DEBUG: revCalc: trying to calc $operand, $oh1 = $v1 \n" ); }
        for( $opr ) {
          /\+/    and do { $value = doOp( "-", $colVal , $v1) ; last; };
          /\-/    and do { $value = doOp( "-", $v1 , $colVal) ; last; };
        }
  } elsif( defined($v2) ) {
        # we have oh2, need to find oh1 (cases 1&2)
        $operand = $oh1 ;
        if($OPT{debug}>3) { print( STDERR "DEBUG: revCalc: trying to calc $operand, $oh2 = $v2 \n" ); }
        for( $opr ) {
          /\+/    and do { $value = doOp( "-" , $colVal , $v2 ); last; };
          /\-/    and do { $value = doOp( "+" , $colVal , $v2 ); last; };
        }
  } 

  return $operand , $value ;
}

sub processInput {
  my $catRef = shift ;

  my %values = ();
  $catRef->{values} = \%values ;
  if($OPT{debug}>3) { print( STDERR "DEBUG: processing input with catalog: ",Dumper($catRef),"\n" ); }

  # Go through the input record and try to calculate everything possible
  # For each field, store the value and, if it's an instruction, try to
  # calculate it with what we already have stored.

  my @inputFields = keys %{$catRef->{inMap}} ;
  if($OPT{debug}>3) { print( STDERR "DEBUG: processing input: fields from inMap: ",join( ':' , @inputFields),"\n" ); }

  # process single char fields, first
  my $i = undef ;
  my $val = undef ;
  for my $field ( grep { m/^\w$/ } @inputFields ) {
    if($OPT{debug}>3) { print( STDERR "DEBUG: processing input: working on field: $field ","\n" ); }
    $i = $catRef->{inMap}{$field} ;
    $val = $catRef->{inRec}[$i] ;
    $values{$field} = $val ;
  }
  
  @inputFields = grep { ! m/^\w$/ } @inputFields ;
  if($OPT{debug}>3) { print( STDERR "DEBUG: processing input: fields remaining: ",join( ':' , @inputFields),"\n" ); }

  # process the rest until we cannot calculate more things
  while( @inputFields ) {
    if($OPT{debug}>3) { print( STDERR "DEBUG: processing input: fields remaining: ",join( ':' , @inputFields),"\n" ); }
    for my $field ( @inputFields ) {
      if($OPT{debug}>3) { print( STDERR "DEBUG: processing input: working on field $field ","\n" ); }
      # always store this value
      $i = $catRef->{inMap}{$field} ;
      $val = $catRef->{inRec}[$i] ;
      $values{$field} = $val ;
      if($OPT{debug}>3) { print( STDERR "DEBUG: processing input: $field = $values{$field} ","\n" ); }

      if( $field =~ m/^.[+-].$/ ) {
        # split and see what we have
        my ($opr,$o1,$o2) = parseInst( $field ) ;
        if( grep { m/^($o1|$o2)$/ } keys %values ) {
          # we can caculate a new value as long as one of the two operands is known
          my( $newName, $val ) = revCalc( $field , $values{$field} , $catRef );
          if( defined($val) and defined($newName) ) {
            # store new results
            $values{$newName} = $val ;
            # remove it from ilst of fields to process
            @inputFields = grep{ ! m/^$field$/ } @inputFields ;
            if($OPT{debug}>3) { print( STDERR "DEBUG: processing input: completed $field ","\n" ); }
          } else {
            if($OPT{debug}>3) { print( STDERR "DEBUG: processing input: failed for $field ","\n" ); }
          }
        } else {
          # cannot calculate
        }
      }
    }
  }

  return @inputFields ;
}

sub buildOutputRec {
  my $catRef = shift ;
  if($OPT{debug}>3) { print( STDERR "DEBUG: processing record with catalog:",Dumper($catRef),"\n" ); }

  # now, just populate the output record with the known values.
  my $result = undef ;
  my $value = undef ;
  for my $col ( split( /,/ , $OPT{output} ) ) {
    # for each column of the requested output...
    $value = undef ;
    if( $col eq '' ) {
      # field should be empty, skip field
      $result = push( @{$catRef->{outRec}} , '' ) ;
    } else {
      # field should not be empty
      # try to find it in the known values hash
      if( grep { m/^$col$/ } keys %{$catRef->{values}} ) {
        # good, we have it
        $value = $catRef->{values}{$col} ;
        $result = push( @{$catRef->{outRec}} , $value ) ;
      } elsif( $col =~ m/.[+-]./ ) {
        # field is not known, but it's an instruction/calculation, just try to do it
        $value = doOp( parseInst( $col ) );
        if( defined($value) ) {
          $result = push( @{$catRef->{outRec}} , $value ) ;
        } else {
          $result = push( @{$catRef->{outRec}} , "NAN" ) ;
        }
      } else {
        # uh oh, this is an error
        print( STDERR "ERROR: cannot produce requseted output data: $col\n" );
        $result = push( @{$catRef->{outRec}} , '' ) ;
      }
    }
  }

  return $result;
}


sub strToRec {
  # convert a string to a record with the appropriate delimiter
  my $line = shift ;
  my $delim = shift ;

  my @rec = () ;
  for ( $delim ) {
    # if $delim is a number of some kind, assume fix-length fields
    /[1-9][0-9]?/     and 
    do {
        for ( my $n = 0; $n < length($line); $n += $delim ) {
          if($OPT{debug}>3) { print( STDERR "DEBUG: stringToRec: n=$n, len=",length($line),"\n" ); }
          push( @rec , substr( $line, $n, $delim ) );
        }
        last;
    };

    # or, if it's characters, just split on that
    /\W/              and do { @rec = split( /$delim/ , $line ); last; };

    # otherwise, error
    do { die "ERROR: cannot interpret delimiter: $delim"; };

  }

  return @rec ;
}

sub recToStr {
  my $recRef = shift ;
  my $catRef = shift ;

  my $string  = "" ;
  my $delim   = $OPT{delim};
  my $points  = $OPT{points};
  for ( $delim ) {
    # if $delim is a number of some kind, assume fix-length fields
    /[1-9][0-9]?/     and 
    do {
        for my $f ( @{$recRef} ) {
          if($OPT{debug}>3) { print( STDERR "DEBUG: recToStr: f=$f","\n" ); }
          # if it's a float...
          if( $f =~ m/\.[0-9]/ ) {
            if( $points ) {
              # and points are set, use fixed precision
              $string .= sprintf( "%${delim}.${points}f" , $f );
            } else {
              # otherwise, just fit inside fixed-width field
              $string .= sprintf( "%${delim}G" , $f );
            }
          } else {
            # not a float, just print in fixed-width field
            $string .= sprintf( "%${delim}s" , $f );
          }
        }
        last;
    };

    # or, if it's characters, just join
    /\W/              and do { $string = join( $delim , @{$recRef} ); last; };

    # otherwise, error
    do { die "ERROR: cannot interpret delimiter: $delim"; };

  }

  return $string;

}


## MAIN ##

# parse options
# TODO: reject number labels in input map
my %inMap = () ;
my %outMap = () ;
GetOptions( 's|skip=i'          => \$OPT{skip} ,
            'd|delim=s'         => \$OPT{delim} ,
            'p|precision=s'     => \$OPT{points} ,
            'debug=i'           => \$OPT{debug} ,
            'h|help'            => \$OPT{showHelp} ,
            'i|inputlabel=s'    => \$OPT{input} ,
            'o|outputlabel=s'   => \$OPT{output} ,
#            'b|blank|ignore=s'  => \$OPT{ignore} ,
);

if($OPT{debug}>2) { print( STDERR Dumper(\%OPT) ); }
showHelp && exit 0 if( $OPT{showHelp} );


if($OPT{debug}>3) { print( STDERR "DEBUG: starting...\n" ); }

# make header->column maps based on input/output header strings
# provided by user
%inMap = %{ stringToMap( $OPT{input} ) };
#%outMap = %{ stringToMap( $OPT{output} ) };
if($OPT{debug}>3) { print( STDERR "DEBUG: in map:",Dumper(\%inMap),"\n" ); }
if($OPT{debug}>3) { print( STDERR "DEBUG: out map:",Dumper(\%outMap),"\n" ); }

my @rec ;
my @out ;
my $lines = 0;
# create a structure for passing all data to subroutines
my %catalog = (
    inMap    => \%inMap ,
    outMap   => \%outMap ,
    inRec    => \@rec,
    outRec   => \@out ,
    options  => \%OPT ,
);

# Read STDIN, proces line-by-line
while(<STDIN>) {
  chomp ;
  @out = () ;
  @rec = () ;
  #$lines++;
  if( 0 < $OPT{skip}-- ) { next; }
  if($OPT{debug}>2) { print( STDERR "NOTICE: input line: $_\n" ); }
  @rec = strToRec( $_, $OPT{delim} ) ;
  if($OPT{debug}>2) { print( STDERR "NOTICE: input record:",Dumper(\@rec),"\n" ); }
  processInput( \%catalog );
  buildOutputRec( \%catalog );
  if($OPT{debug}>2) { print( STDERR "NOTICE: output record:",Dumper(\@out),"\n" ); }
  print( STDOUT recToStr( \@out , \%catalog ) , "\n" ) ;
}

1;
