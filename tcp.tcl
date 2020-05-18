package provide de1_tcp 1.0


proc tcp_read_handler {sock} {
    set inString [gets $sock]

	if {![regexp -nocase {^\[[A-R]\]([0-9A-F][0-9A-F])+$} $inString]} {
		msg "Dropping invalid message: $inString"
		return
	}

    set command [string index $inString 1]
    set inHexStr [string range $inString 3 end]
    set inHex [binary format H* $inHexStr]

    msg [format "Desire: %s %s" $command $inHexStr]

    de1_ble_handler_wrapper $command $inHex
}

proc tcp_connect_to_de1 {} {
	msg "tcp_connect_to_de1"

    set tcp_host [ifexists ::settings(de1_tcp_host)]
    set tcp_port [ifexists ::settings(de1_tcp_port)]

	if {$tcp_host == ""} {
		msg "Missing TCP hostname, using 'de1' as a fallback"
		set tcp_host "de1"
	}

	if {$tcp_port == ""} {
		msg "Missing TCP port, using 9090 as a fallback"
		set tcp_port "9090"
	}

    set ::de1(device_handle) [socket $tcp_host $tcp_port]
    fileevent $::de1(device_handle) readable [list tcp_read_handler $::de1(device_handle)]
    fconfigure $::de1(device_handle) -buffering line

	# borrowed from fast_write_open -- need to make sure this plays nicely with flush()
	fconfigure $::de1(device_handle) -blocking 0

	# TCP TODO(REED) check if connection was successful and then call this
	# (also need to fix this up, e.g. figure what "address" should be)
	de1_connect_handler $::de1(device_handle) "$tcp_host:$tcp_port"
}

proc tcp_de1_connected {} {
	# TCP TODO(REED) TCP is_connected check should really check if the socket is still open
	if {[$::de1(device_handle) != "0" && $::de1(device_handle) != "1"} {
		return true
	} 
	return false
}

proc tcp_close_de1 {} {
	# TCP TODO(REED) close
}



## this gets called by the callback from our TCP socket reader
## and it is used to reconstruct what a BLE callback would have gotten, then fires the BLE callback
## to do the actual work
proc de1_ble_handler_wrapper { command val } {
    ### we need to fake up a dict as though it came from BLE, so that the "real" BLE code can process it

    ### the actual ble dict has these fields in the dict
    # handle h address a state s rssi r suuid su sinstance si cuuid ci cinstance ci permissions p properties q writetype w access a value v
    
    ### here are the ones I actually found to be used in the handler:
    # event = "characteristic"
    #   state = "connected"
    #    access = "r" (read -- ready for a command?)
    #             "c" (change notification)
    #                cuuid_0D shotvalue
    #                cuuid_01 version data
    #                cuuid_12 calibration
    #                cuuid_11 water_level
    #                cuuid_09 firmware
    #                cuuid_0B hotwater
    #                cuuid_0C shot desc
    #                cuuid_0F shot desc header
    #                cuuid_10 shot frame
    #                cuuid_0E state
    #             "w"
    #                cuuid_10 shot frame confirmed
    #                cuuid_11 water level confirmed
    #                   $address = $::settings(bluetooth_address)
    #                       cuuid_02 state change confirmed
    #                       cuuid_06 firmware ack
    # event = descriptor
    #   state = "connected"
    #       access = "w"
    #                cuuid_0D temp notifications
    #                cuuid_0E state chane notifications
    #                cuuid_12 calibration notifications
    
    set event "characteristic"
    dict set data state "connected"
    dict set data access "c"
    dict set data value $val
    switch -- $command {
	A { 
	    # A001 A R    Versions See T_Versions
	    dict set data cuuid $::de1(cuuid_01) 
	} 
	B { 
	    # A002 B RW   RequestedState See T_RequestedState    
	    dict set data cuuid $::de1(cuuid_02) 
	} 
	C { 
	    # A003 C RW   SetTime Set current time
	    dict set data cuuid $::de1(cuuid_03) 
	} 
	D { 
	    # A004 D R    ShotDirectory View shot directory
	    dict set data cuuid $::de1(cuuid_04) 
	} 
	E { 
	    # A005 E RW   ReadFromMMR Read bytes from data mapped into the memory mapped region.
	    dict set data cuuid $::de1(cuuid_05) 
	} 
	J { 
	    # A00A J R    Temperatures See T_Temperatures
	    dict set data cuuid $::de1(cuuid_0A) 
	} 
	K { 
	    # A00B K RW   ShotSettings See T_ShotSettings
	    dict set data cuuid $::de1(cuuid_0B) 
	} 
	L { 
	    # A00C L RW   Deprecated Was T_ShotDesc. Now deprecated.
	    dict set data cuuid $::de1(cuuid_0C) 
	} 
	M { 
	    # A00D M R    ShotSample Use to monitor a running shot. See T_ShotSample
	    dict set data cuuid $::de1(cuuid_0D) 
	}
	N { 
	    dict set data cuuid $::de1(cuuid_0E) 
	    # A00E N R    StateInfo The current state of the DE1
	} 	
	O { 
	    # A00F O RW   HeaderWrite Use this to change a header in the current shot description
	    dict set data cuuid $::de1(cuuid_0F) 
	} 
	P { 
	    # A010 P RW   FrameWrite Use this to change a single frame in the current shot description
	    dict set data cuuid $::de1(cuuid_10) 
	} 
	Q { 	
	    # A011 Q RW   WaterLevels Use this to adjust and read water level settings
	    dict set data cuuid $::de1(cuuid_11) 
	} 
	R { 
	    # A012 R RW   Calibration Use this to adjust and read calibration
	    dict set data cuuid $::de1(cuuid_12) 
	} 
	default { dict set data ""; msg "Bad message type $command" }
    }
    de1_ble_handler $event $data
}
