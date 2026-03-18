#!/bin/sh

goimports <&0 | gci print "$@"
