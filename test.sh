#!/bin/bash

source properties.mk
APPNAME=$1
DEVICE=$2

echo
echo "*** Testing $DEVICE ***"
echo
pkill monkeydo
pkill simulator
pkill Xvfb 
pkill Xvfb 
pkill xvfb-run
DISPLAY_NUM=49
XAUTHORITY=/tmp/.XAuthority
echo "Starting Simulator"
xvfb-run -n $DISPLAY_NUM -f $XAUTHORITY $SDK_HOME/bin/connectiq &
sleep 3
until pids=$(pidof simulator)
do   
   echo "Simulator not started retrying"   
   xvfb-run -n $DISPLAY_NUM -f $XAUTHORITY $SDK_HOME/bin/connectiq &
   sleep 3
done
echo "Launching device $DEVICE"
$SDK_HOME/bin/monkeydo bin/$APPNAME.prg $DEVICE &
sleep 10 
until pids=$(pgrep -f monkeybrains)
do   
   echo "Watchface not started retrying"   
   $SDK_HOME/bin/monkeydo bin/$APPNAME.prg $DEVICE &
   sleep 10
done
echo "Taking screenshot"
XAUTHORITY=$XAUTHORITY xwd -display :$DISPLAY_NUM -root > /tmp/$APPNAME.xwd 
echo "Converting screenshot"
convert /tmp/$APPNAME.xwd ./test_results/$APPNAME.png
pgrep -f monkeybrains | xargs kill
pkill simulator
pkill Xvfb 
rm -r /tmp/GARMIN/
