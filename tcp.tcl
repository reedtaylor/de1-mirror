package provide de1_tcp 1.0


proc tcp_read_handler {sock} {
	if { [catch {set inString [gets $sock]} ] || ![tcp_de1_connected]} {
		msg "failure during TCP socket read"
		de1_disconnect_handler
		return
	}

	# TODO(REED) maybe check for chan blocking

	if {![regexp -nocase {^\[[A-R]\]([0-9A-F][0-9A-F])+$} $inString]} {
		msg "Dropping invalid message: $inString"
		return
	}

    set serial_handle [string index $inString 1]
    set inHexStr [string range $inString 3 end]
    set inHex [binary format H* $inHexStr]

    msg [format "TCP: %s %s" $serial_handle $inHexStr]

	set command_name $::de1_serial_handles_to_command_names($serial_handle)
    de1_event_handler $command_name $inHex
}

proc tcp_connect_to_de1 {} {
	msg "tcp_connect_to_de1"

    set tcp_host [ifexists ::settings(de1_tcp_host)]
	if {$tcp_host == ""} {
		msg "Missing TCP hostname, using 'de1' as a fallback"
		set tcp_host "de1"
	}

    set tcp_port [ifexists ::settings(de1_tcp_port)]
	if {$tcp_port == ""} {
		msg "Missing TCP port, using 9090 as a fallback"
		set tcp_port "9090"
	}

	catch {
    set ::de1(device_handle) [socket $tcp_host $tcp_port]
    fileevent $::de1(device_handle) readable [list tcp_read_handler $::de1(device_handle)]
    chan configure $::de1(device_handle) -buffering line
	chan configure $::de1(device_handle) -blocking 0
	}
	
	# check if connection was successful and then call connect handler


	after 500 de1_check_new_connection $::de1(device_handle) "$tcp_host:$tcp_port"
}

proc tcp_de1_connected {} {
	if {$::de1(device_handle) != "0" && $::de1(device_handle) != "1"} {
		if { [catch {
			if {[chan eof $::de1(device_handle)] || [chan pending input $::de1(device_handle)] == -1} {
				msg "tcp channel closed by remote host"
				de1_disconnect_handler
				return 0
			} 
		} ] } {return 0} 
	} else {
		return 0
	}
	return 1
}

proc tcp_close_de1 {} {
    catch {
		close $::de1(device_handle)
	}
	set ::de1(device_handle) 0
}
