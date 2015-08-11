#`{{
  Testing;
    database.set_pw_security            username and password check init
    database.create_user()
    database.drop_user()
    database.drop_all_users_from_database()
    database.users_info()
}}

use v6;
use Test;
use MongoDB::Connection;

my MongoDB::Connection $connection .= new();

# Drop database first then create new databases
#
$connection.database('test').drop;

my MongoDB::Database $database = $connection.database('test');
#-------------------------------------------------------------------------------
subtest {
  my Hash $doc = $database.create_user(
    :user('mt'),
    :password('mt++'),
    :custom_data({license => 'to_kill'}),
    :roles(['readWrite'])
  );

  ok $doc<ok>, 'User mt created';

  if 1 {
    $doc = $database.create_user(
      :user('mt'),
      :password('mt++'),
      :custom_data({license => 'to_kill'}),
      :roles(['readWrite'])
    );

    CATCH {
      when X::MongoDB::Database {
        ok .error-text eq 'User "mt@test" already exists', .error-text;
      }
    }
  }

  $doc = $database.drop_user(:user('mt'));
  ok $doc<ok>, 'User mt dropped';

}, "Test user management";

#-------------------------------------------------------------------------------
#
subtest {
  my Hash $doc;
  $database.set_pw_security(
    :min_un_length(5),
    :min_pw_length(6),
    :pw_attribs($MongoDB::Database::PW-OTHER-CHARS)
  );

  if 1 {
    $doc = $database.create_user(
      :user('mt'),
      :password('mt++'),
      :custom_data({license => 'to_kill'}),
      :roles(['readWrite'])
    );

    CATCH {
      when X::MongoDB::Database {
        ok .error-text eq 'Username too short, must be >= 5', .error-text;
      }
    }
  }

  if 1 {
    $doc = $database.create_user(
      :user('mt-and-another-few-chars'),
      :password('mt++'),
      :custom_data({license => 'to_kill'}),
      :roles(['readWrite'])
    );

    CATCH {
      when X::MongoDB::Database {
        ok .error-text eq 'Password too short, must be >= 6', .error-text;
      }
    }
  }

if 1 {
  if 1 {
    $doc = $database.create_user(
      :user('mt-and-another-few-chars'),
      :password('mt++tdt'),
      :custom_data({license => 'to_kill'}),
      :roles(['readWrite'])
    );

    CATCH {
      when X::MongoDB::Database {
        ok .error-text eq 'Password does not have the proper elements',
           .error-text;
      }
    }
  }

  if 1 {
    $doc = $database.create_user(
      :user('mt-and-another-few-chars'),
      :password('mt++tdt0A'),
      :custom_data({license => 'to_kill'}),
      :roles(['readWrite'])
    );

    ok $doc<ok>, 'User mt-and-another-few-chars created';
  }

  $doc = $database.drop_user(:user('mt-and-another-few-chars'));
  ok $doc<ok>, 'User mt-and-another-few-chars dropped';
}

}, "Test username and password checks";

#-------------------------------------------------------------------------------
subtest {
  my Hash $doc;
  $database.set_pw_security(:min_un_length(2), :min_pw_length(2));
  $doc = $database.create_user(
    :user('mt'),
    :password('mt++'),
    :custom_data({license => 'to_kill'}),
    :roles(['readWrite'])
  );

  ok $doc<ok>, 'User mt created';
  
  $doc = $database.users_info(:user('mt'));
  my $u = $doc<users>[0];
  is $u<_id>, 'test.mt', $u<_id>;
  is $u<roles>[0]<role>, 'readWrite', $u<roles>[0]<role>;

  $doc = $database.drop_all_users_from_database();
  ok $doc<ok>, 'All users dropped';
  
  $doc = $database.users_info(:user('mt'));
  is $doc<users>.elems, 0, 'No users in database';
}, 'account info and drop all users';

#-------------------------------------------------------------------------------
# Cleanup
#
$connection.database('test').drop;

done();
exit(0);