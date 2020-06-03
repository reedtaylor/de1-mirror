package provide de1_usb 1.0

proc usb_connect_to_de1 {} {
	msg "usb_connect_to_de1"

    set usb_path [ifexists ::settings(de1_usb_path)]
	if {$usb_path == ""} {
		set usb_path "/dev/cu.SLAB_USBtoUART"
		msg "Missing USB path, using $usb_path as a fallback"
	}

	if {$::currently_connecting_de1_handle != 0} {
		catch {
			close $::currently_connecting_de1_handle
		}
		set ::currently_connecting_de1_handle 0
	}

	catch {
		msg "initiating USB connection to $usb_path"

		if {$::runtime == "android"} {
			# assume OTG
			set ::currently_connecting_de1_handle [usbserial $usb_path]
		} else {
			# assume non OTG
			set ::currently_connecting_de1_handle [open $usb_path r+]
		}
	}

	if {$::currently_connecting_de1_handle > 0} {
		usb_connect_handler $usb_path
	} else {
		connection_timeout_handler
	}
}


proc usb_connect_handler {usb_path} {
	msg "usb_connect_handler"

	set ::de1(device_handle) $::currently_connecting_de1_handle
	set ::currently_connecting_de1_handle 0

	# install readable event handler
	fileevent $::de1(device_handle) readable [list channel_read_handler $::de1(device_handle)]
	fconfigure $::de1(device_handle) -mode 115200,n,8,1
	chan configure $::de1(device_handle) -translation {auto lf}
	chan configure $::de1(device_handle) -buffering line
	chan configure $::de1(device_handle) -blocking 0

	de1_connect_handler $::de1(device_handle) "$usb_path"
}

proc usb_close_de1 {} {
    catch {
		close $::de1(device_handle)
	}
	set ::de1(device_handle) 0
}
