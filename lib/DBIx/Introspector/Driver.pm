package
   DBIx::Introspector::Driver;

use Moo;

has name => (
   is => 'ro',
   required => 1,
);

has _dbh_determination_strategy => (
   is => 'ro',
   default => sub { sub { 1 } },
   init_arg => 'dbh_determination_strategy',
);

has _dsn_determination_strategy => (
   is => 'ro',
   default => sub { sub { 1 } },
   init_arg => 'dsn_determination_strategy',
);

has _dbh_options => (
   is => 'ro',
   builder => sub {
      +{
         _introspector_driver => sub { $_[0]->name },
      }
   },
   init_arg => 'dbh_options',
);

has _dsn_options => (
   is => 'ro',
   builder => sub {
      +{
         _introspector_driver => sub { $_[0]->name },
      }
   },
   init_arg => 'dsn_options',
);

has _parents => (
   is => 'ro',
   default => sub { +[] },
   init_arg => 'parents',
);

sub _add_dbh_option {
   my ($self, $key, $value) = @_;

   $self->_dbh_options->{$key} = $value
}

sub _add_dsn_option {
   my ($self, $key, $value) = @_;

   $self->_dsn_options->{$key} = $value
}

sub _determine {
   my ($self, $dbh, $dsn) = @_;

   my $dbh_strategy = $self->_dbh_determination_strategy;

   return $self->$dbh_strategy($dbh) if $dbh;

   my $dsn_strategy = $self->_dsn_determination_strategy;
   $self->$dsn_strategy($dsn)
}

sub _get_via_dsn {
   my ($self, $args) = @_;

   my $drivers_by_name = $args->{drivers_by_name};
   my $key = $args->{key};

   my $option = $self->_dsn_options->{$key};

   if ($option) {
      return $option->($self, $args->{dbh})
        if ref $option && ref $option eq 'CODE';
      return $option;
   }
   elsif (@{$self->_parents}) {
      my @p = @{$self->_parents};
      for my $parent (@p) {
         my $driver = $drivers_by_name->{$parent};
         die "no such driver <$parent>" unless $driver;
         my $ret = $driver->_get_via_dsn($args);
         return $ret if defined $ret
      }
   }
   return undef
}

sub _get_via_dbh {
   my ($self, $args) = @_;

   my $drivers_by_name = $args->{drivers_by_name};
   my $key = $args->{key};

   my $option = $self->_dbh_options->{$key};

   if ($option) {
      return $option->($self, $args->{dbh})
        if ref $option && ref $option eq 'CODE';
      return $option;
   }
   elsif (@{$self->_parents}) {
      my @p = @{$self->_parents};
      for my $parent (@p) {
         my $driver = $drivers_by_name->{$parent};
         die "no such driver <$parent>" unless $driver;
         my $ret = $driver->_get_via_dbh($args);
         return $ret if $ret
      }
   }
   return undef
}

sub _get_info_from_dbh {
  my ($self, $dbh, $info) = @_;

  if ($info =~ /[^0-9]/) {
    require DBI::Const::GetInfoType;
    $info = $DBI::Const::GetInfoType::GetInfoType{$info};
    die "Info type '$_[1]' not provided by DBI::Const::GetInfoType"
      unless defined $info;
  }

  $dbh->get_info($info);
}

1;
