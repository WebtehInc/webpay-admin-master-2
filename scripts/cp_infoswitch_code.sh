#!/bin/sh
DEST=$1
cp -r lib/gateways $DEST
cp -r test/integration/infoswitch $DEST/test/integration
