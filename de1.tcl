#!/usr/local/bin/tclsh

encoding system utf-8

cd "[file dirname [info script]]/"
source "pkgIndex.tcl"
package require de1_main
de1_ui_startup
