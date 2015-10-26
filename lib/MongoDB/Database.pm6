use v6;
use MongoDB::Collection;

#-------------------------------------------------------------------------------
#
package MongoDB {

  #-----------------------------------------------------------------------------
  #
  class MongoDB::Database {

    has $.connection;
    has Str $.name;

    #---------------------------------------------------------------------------
    #
    submethod BUILD (
      :$connection where $connection.isa('MongoDB::Connection'),
      Str :$name
    ) {

      $!connection = $connection;

      # TODO validate name
      $!name = $name;
    }

    #---------------------------------------------------------------------------
    # Drop the database
    #
    method drop ( --> Hash ) {
      my Pair @req = dropDatabase => 1;
      my $doc =  self.run_command(@req);

      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop',
          oper-data => @req.perl,
          collection-ns => $!name
        );
      }

      return $doc;
    }

    #---------------------------------------------------------------------------
    # Select a collection. When it is new it comes into existence only
    # after inserting data
    #
    method collection ( Str:D $name --> MongoDB::Collection ) {

      if !($name ~~ m/^ <[_ A..Z a..z]> <[.\w _]>+ $/) {
        die X::MongoDB.new(
            error-text => "Illegal collection name: '$name'",
            oper-name => 'collection()',
            collection-ns => $!name
        );
      }

      return MongoDB::Collection.new: :database(self), :name($name);
    }

    #---------------------------------------------------------------------------
    # Create collection explicitly with control parameters
    #
    method create_collection ( Str:D $collection_name, Bool :$capped,
                               Bool :$autoIndexId, Int :$size,
                               Int :$max, Int :$flags
                               --> MongoDB::Collection
                             ) {

      if !($collection_name ~~ m/^ <[_ A..Z a..z]> <[.\w _]>+ $/) {
        die X::MongoDB.new(
            error-text => "Illegal collection name: '$collection_name'",
            oper-name => 'create_collection()',
            collection-ns => $!name
        );
      }

      # Setup the collection create command
      #
      my Pair @req = create => $collection_name;
      @req.push: (:$capped) if $capped;
      @req.push: (:$autoIndexId) if $autoIndexId;
      @req.push: (:$size) if $size;
      @req.push: (:$max) if $max;
      @req.push: (:$flags) if $flags;

      my Hash $doc = self.run_command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
            error-text => $doc<errmsg>,
            oper-name => 'create_collection',
            oper-data => @req.perl,
            collection-ns => $!name
        );
      }

      return MongoDB::Collection.new: :database(self), :name($collection_name);
    }

    #---------------------------------------------------------------------------
    # Return all information from system namespaces
    #
    method list_collections ( --> Array ) {

      my @docs;
      my $system-indexes = self.collection('system.namespaces');
      my $cursor = $system-indexes.find;
      while $cursor.next -> $doc {
        @docs.push($doc);
      }

      return @docs;
    }

    #---------------------------------------------------------------------------
    # Return only the user collection names in the database
    #
    method collection_names ( --> Array ) {

      my @docs;
      my $system-indexes = self.collection('system.namespaces');
      my $cursor = $system-indexes.find;
      while $cursor.next -> $doc {
        next if $doc<name> ~~ m/\$_id_/;      # Skip names with id in it
        next if $doc<name> ~~ m/\.system\./;  # Skip system collections
        $doc<name> ~~ m/\. (.+) $/;
        @docs.push($/[0].Str);
      }

      return @docs;
    }

    #---------------------------------------------------------------------------
    # Run command should ony be working on the admin database using the virtual
    # $cmd collection. Method is placed here because it works on a database be
    # it a special one.
    #
    # Possible returns are:
    # %("ok" => 0e0, "errmsg" => <Some error string>)
    # %("ok" => 1e0, ...);
    #
    multi method run_command ( Pair:D @command --> Hash ) {

      # Create a local collection structure here
      #
      my MongoDB::Collection $c .= new(
        database    => self,
        name        => '$cmd',
      );

      # Use it to do a find on it, get the doc and return it.
      #
      my MongoDB::Cursor $cursor = $c.find( @command, :number-to-return(1));
      my $doc = $cursor.fetch();
      return $doc.defined ?? $doc !! %();
    }

    #---------------------------------------------------------------------------
    # Get the last error. Returns one or more of the following keys: ok, err,
    # code, connectionId, lastOp, n, shards, singleShard, updatedExisting,
    # upserted, wnote, wtimeout, waited, wtime,
    #
    method get_last_error ( Bool :$j = True, Int :$w = 0,
                            Int :$wtimeout = 1000, Bool :$fsync = False
                            --> Hash
                          ) {

      my Pair @req = getLastError => 1;
      @req.push: |( :$j, :$fsync);
      @req.push: |( :$w, :$wtimeout) if $w and $wtimeout;

      my Hash $doc = self.run_command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'get_last_error',
          oper-data => @req.perl,
          collection-ns => $!name
        );
      }

      return $doc;
    }

    #---------------------------------------------------------------------------
    # Get errors since last reset error command
    #
    method get_prev_error ( --> Hash ) {

      my Pair @req = getPrevError => 1;
      my Hash $doc =  self.run_command(@req);

      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'get_prev_error',
          oper-data => @req.perl,
          collection-ns => $!name
        );
      }

      return $doc;
    }

    #---------------------------------------------------------------------------
    # Reset error command
    #
    method reset_error ( --> Hash ) {

      my Pair @req = resetError => 1;
      my Hash $doc = self.run_command(@req);

      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'reset_error',
          oper-data => @req.perl,
          collection-ns => $!name
        );
      }

      return $doc;
    }
  }
}
