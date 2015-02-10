BEGIN { @*INC.unshift( './t' ) }
use Test-support;

use v6;
use Test;
use MongoDB;

my MongoDB::Collection $collection = get-test-collection( 'test', 'testf');

for 1..100 -> $i, $j
{
  my %d = %( code1 => 'd' ~ $i, code2 => 'n' ~ (100 -$j));
  $collection.insert(%d);
}

#show-documents( $collection, {});

#show-documents( $collection, %(code1 => 'd1'));

my MongoDB::Cursor $cursor = $collection.find(%(code1 => 'd1'));
is $cursor.count, 1, 'There is one document';

#{
  try
  $collection.ensure_index( %( code1 => 1),
                            %( name => 'testindex',
                               background => True
                             )
                          );
  say $! if $!;

#  CATCH {
#    when X::MongoDB::LastError {
#      say "Error is '$_'";
#    }
#  }
#}

my $doc = $collection.drop_index( %( code1 => 1));
say $doc.perl;

try $doc = $collection.drop_index( %( code1 => 1));
say $! ?? $! !! $doc.perl;

$doc = $collection.drop_indexes;
say $doc.perl;

#------------------------------------------------------------------------------
# Cleanup and close
#
# TODO replace with drop when available
$collection.remove( );

done();
exit(0);

#-------------------------------------------------------------------------------
# Check one document for its fields. Something like {code => 1, nofield => 0}
# use find_one()
#
sub check-document ( $criteria, %field-list, %projection = { })
{
  my %document = %($collection.find_one( $criteria, %projection));
  if +%document
  {
    for %field-list.keys -> $k
    {
      if %field-list{$k}
      {
        is( %document{$k}:exists, True, "Key '$k' exists. Check using find_one()");
      }
      
      else
      {
        is( %document{$k}:exists, False, "Key '$k' does not exist. Check using find_one()");
      }
    }
  }
}
