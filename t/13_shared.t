#!/usr/bin/perl

use warnings;
use strict;
use Test::More;
use POSIX;
use FindBin;
use Mojo::File qw(tempfile tempdir path);
use lib ("$FindBin::Bin/lib", "../lib", "lib");

use Mojo::IOLoop::ReadWriteProcess
  qw(process queue shared_memory lock semaphore);
use Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore;
use Mojo::IOLoop::ReadWriteProcess::Shared::Memory;
use Data::Dumper;

subtest 'semaphore' => sub {

  my $sem_key = 33131;

  my $sem = Mojo::IOLoop::ReadWriteProcess::Shared::Semaphore::semaphore(
    key => $sem_key);

  ok(defined $sem->id, ' We have semaphore id ( ' . $sem->id . ' )');
  ok(defined $sem->stat,
    ' We have semaphore stats ( ' . Dumper($sem->stat) . ' )');
  is($sem->stat->[7], 1, 'Default semaphore size is 1');

  $sem->setval(0, 1);
  is $sem->getval(0), 1, 'Semaphore value set to 1';
  $sem->setval(0, 0);
  is $sem->getval(0), 0, 'Semaphore value set 0';
  $sem->setval(0, 1);
  is $sem->getval(0), 1, 'Semaphore value set to 1';
  $sem->setall(0);
  is $sem->getval(0), 0, 'Semaphore value set 0';
  $sem->setval(0, 1);

  is $sem->getall,  1, 'We have one semaphore, which is free to go';
  is $sem->getncnt, 0, '0 Processes waiting for the semaphore';

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $sem = semaphore->new(key => $sem_key);
        my $e = 1;
        if ($sem->acquire({wait => 1, undo => 0})) {
          $e = 0;
          $sem->release();
        }
        Devel::Cover::report() if Devel::Cover->can('report');
        exit($e);
      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  is $q->done->size, 20, '20 Processes consumed';

  $q->done->each(
    sub {
      is $_[0]->exit_status, 0,
          "Process: "
        . shift->pid
        . " exited with 0 (semaphore acquired at least once)";
    });

  $sem->remove;
};

subtest 'lock' => sub {
  my $k = 2342385;
  my $lock = lock(key => $k);

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $l = lock(key => $k);
        my $e = 1;
        if ($l->lock) {
          $e = 0;
          $l->unlock;
        }
        Devel::Cover::report() if Devel::Cover->can('report');
        exit($e);
      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  is $q->done->size, 20, '20 Processes consumed';
  $q->done->each(
    sub {
      is $_[0]->exit_status, 0,
          "Process: "
        . shift->pid
        . " exited with 0 (semaphore acquired at least once)";
    });

  $lock->remove();

};

subtest 'lock section' => sub {

  my $lock = lock(key => 3331);

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {
        my $l = lock(key => 3331);
        my $e = 1;
        $l->section(sub { $e = 0 });

        Devel::Cover::report() if Devel::Cover->can('report');
        exit($e);
      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();
  is $q->done->size, 20, '20 Processes consumed';
  $q->done->each(
    sub {
      is $_[0]->exit_status, 0,
          "Process: "
        . shift->pid
        . " exited with 0 (semaphore acquired at least once)";
    });
  $lock->remove;
};

subtest 'concurrent memory read/write' => sub {
  use IPC::SysV 'ftok';

  my $k = ftok($0, 0);
  my $mem = shared_memory(key => $k);
  $mem->_lock->remove;
  my $default = shared_memory;
  is $default->key, $k, "Default memory key is : $k";

  $mem = shared_memory(key => $k);
  $mem->clean;
  $mem->_lock->remove;

  $mem = shared_memory(key => $k);
  $mem->lock_section(sub { $mem->buffer('start') });

  my $q = queue;
  $q->pool->maximum_processes(10);
  $q->queue->maximum_processes(50);

  $q->add(
    process(
      sub {

        my $mem = shared_memory(key => $k);

        $mem->lock_section(
          sub {
            # Random sleeps to try to make threads race into lock section
            #    do { warn "$$: sleeping"; sleep rand(int(2)) }
            #        for 1 .. 5;
            my $b = $mem->buffer;
            $mem->buffer($$ . " $b");
            Devel::Cover::report() if Devel::Cover->can('report');
          });
      }
    )->set_pipes(0)->internal_pipes(0)) for 1 .. 20;

  $q->consume();

  $mem = shared_memory(key => $k);
  $mem->lock_section(
    sub {
      ok((length $mem->buffer > 0), 'Buffer is there');
    });
  $mem->lock_section(
    sub {
      my @pids = split(/ /, $mem->buffer);
      is scalar @pids, 21, 'There are 20 pids and the start word (21)';
    });

  $mem->_lock->remove;
};

done_testing();