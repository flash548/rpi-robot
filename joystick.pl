use strict;
use warnings;

use Linux::Joystick;
use RPi::PIGPIO ':all';

use constant O_BUTTON => 13;
use constant TRI_BUTTON => 12;
use constant X_BUTTON => 14;
use constant SQ_BUTTON => 15;
use constant LEFT_BUTTON => 7;
use constant DOWN_BUTTON => 6;
use constant RIGHT_BUTTON => 5;
use constant UP_BUTTON => 4;
use constant TOP_RIGHT_BUTTON => 11;
use constant BOTTOM_RIGHT_BUTTON => 9;
use constant TOP_LEFT_BUTTON => 10;
use constant BOTTOM_LEFT_BUTTON => 8;
use constant POWER_OFF_BTN => 0;  # 'select' button

use constant LEFT_AXIS_VERT => 1;
use constant LEFT_AXIS_HORIZ => 0;
use constant RIGHT_AXIS_HORIZ => 2;
use constant RIGHT_AXIS_VERT => 3;

use constant FORWARD => 0;
use constant REVERSE => 1;
use constant LEFT => 2;
use constant RIGHT => 3;
use constant STOP => -1;
use constant FALSE => 0;
use constant TRUE => 1;

my $keep_running = TRUE;

$SIG{'INT'} = sub {
    $keep_running = FALSE;       
}; 

my $js;
my $pi = RPi::PIGPIO->connect('127.0.0.1');

my $pgm_running = $pi->set_mode(22, PI_OUTPUT);
$pi->write(22, HI);

my $comms_good = FALSE;

my $off_count = 0;

my $joy_good = $pi->set_mode(17, PI_OUTPUT);
my $pwm1 = $pi->set_mode(12, PI_OUTPUT);
my $pwm2 = $pi->set_mode(19, PI_OUTPUT);

$pi->write(17, LOW);

my $direction = STOP;

sub done {
    if ($pi) {
        $pi->write(22, LOW);
        $pi->write(17, LOW);
    }
    stop();
}

sub stop {
 if ($pi) {
    $direction = STOP;
    $pi->write_pwm(12, 0);
    $pi->write_pwm(19, 0);
 }

}

sub apply_direction {
    my $new_dir = shift;

    if ($pi) {
        if ($new_dir == FORWARD && $direction == STOP) {
            $direction = FORWARD;
            $pi->send_command(PI_CMD_SERVO, 12, 2000);
            $pi->send_command(PI_CMD_SERVO, 19, 1000);
        } elsif ($new_dir == REVERSE && $direction == STOP) {
            $direction = REVERSE;
            $pi->send_command(PI_CMD_SERVO, 12, 1000);
            $pi->send_command(PI_CMD_SERVO, 19, 2000);
        } elsif ($new_dir == RIGHT && $direction == STOP) {
            $direction = RIGHT;
            
            $pi->send_command(PI_CMD_SERVO, 12, 2000);
            $pi->send_command(PI_CMD_SERVO, 19, 2000);
        } elsif ($new_dir == LEFT && $direction == STOP) {
            $pi->send_command(PI_CMD_SERVO, 12, 1000);
            $pi->send_command(PI_CMD_SERVO, 19, 1000);
            $direction = LEFT;
        } elsif ($new_dir == STOP) {
            $direction = STOP;
            stop();
        }
    
    }

    $off_count = 0;

}

stop();

while ($keep_running) {
    sleep 1;
    next if ! -e "/dev/input/js0";

    $js = Linux::Joystick->new(threshold => 10000, nonblocking => 1) || next;
    $pi->write(17, HI);
    $comms_good = TRUE;

    # joystick connected inner-loop
    while($keep_running) {
        
        # breakout to the seek-joystick outer loop if we loose connection
        if  (! -e "/dev/input/js0") {
            $pi->write(17, LOW);
            $comms_good = FALSE;
            stop();
            last;
        }

        my $event = $js->nextEvent;
        next if !defined($event);
        if($event->isButton) {

            if ($event->button == POWER_OFF_BTN && $event->buttonDown) {
                $off_count++;
            }
            if ($event->button == UP_BUTTON && $event->buttonDown) {
                apply_direction(FORWARD);
            } elsif ($event->button == DOWN_BUTTON && $event->buttonDown) {
                apply_direction(REVERSE);
            } elsif ($event->button == UP_BUTTON && $event->buttonUp) {
                apply_direction(STOP);
            } elsif ($event->button == DOWN_BUTTON && $event->buttonUp) {
                apply_direction(STOP);
            } elsif ($event->button == LEFT_BUTTON && $event->buttonDown) {
                apply_direction(LEFT);
            } elsif ($event->button == RIGHT_BUTTON && $event->buttonDown) {
                apply_direction(RIGHT);
            } elsif ($event->button == LEFT_BUTTON && $event->buttonUp) {
                apply_direction(STOP);
            } elsif ($event->button == RIGHT_BUTTON && $event->buttonUp) {
                apply_direction(STOP);
            } 
        }
        elsif($event->isAxis) {

        }

        if ($off_count >= 4) {
            system("sudo poweroff");
        }
        sleep 0.25;
    }

}
 
END {
    done();
}


 
