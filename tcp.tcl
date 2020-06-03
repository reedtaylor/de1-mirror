package provide de1_tcp 1.0

proc tcp_connect_to_de1 {} {
	msg "tcp_connect_to_de1"

    set tcp_host [ifexists ::settings(de1_tcp_host)]
	if {$tcp_host == ""} {
		set tcp_host "de1"
		msg "Missing TCP hostname, using $tcp_host as a fallback"
	}

    set tcp_port [ifexists ::settings(de1_tcp_port)]
	if {$tcp_port == ""} {
		set tcp_port "9090"
		msg "Missing TCP port, using $tcp_port as a fallback"
	}

	if {$::currently_connecting_de1_handle != 0} {
		catch {
			close $::currently_connecting_de1_handle
		}
		set ::currently_connecting_de1_handle 0
	}

	catch {
		msg "initiating TCP connection to $tcp_host:$tcp_port"
		set ::currently_connecting_de1_handle [socket -async $tcp_host $tcp_port]
		set tcp_timeout_event [after 10000 connection_timeout_handler]

		# handle successful connection when this becomes writeable
		fileevent $::currently_connecting_de1_handle writable [list tcp_connect_handler $tcp_timeout_event $tcp_host $tcp_port]
	}
}

proc tcp_connect_handler {tcp_timeout_event tcp_host tcp_port} {
	# cancel the timeout
	after cancel $tcp_timeout_event

	msg "tcp_connect_handler"

	set ::de1(device_handle) $::currently_connecting_de1_handle
	set ::currently_connecting_de1_handle 0

    # check connect success or fail
    set error [fconfigure $::de1(device_handle) -error]
    if {$error ne ""} {
		msg "TCP connection failed with error: $error"
        catch {close $::de1(device_handle)}
        after 500 de1_disconnect_handler
    } else {
		# disable writable event that triggered this handler, to avoid a loop
	    fileevent $::de1(device_handle) writable ""

		# install readable event handler
		fileevent $::de1(device_handle) readable [list channel_read_handler $::de1(device_handle)]
		chan configure $::de1(device_handle) -buffering line
		chan configure $::de1(device_handle) -blocking 0

		de1_connect_handler $::de1(device_handle) "$tcp_host:$tcp_port"
	}
}

# READABILITY TODO(REED) This funcion is more like "is_connected" and should probably be renamed
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
