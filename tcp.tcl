package provide de1_tcp 1.0


proc tcp_read_handler {sock} {
    set inString [gets $sock]

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
