
package provide de1_comms 1.0

package require de1_tcp 1.0
package require de1_usb 1.0

set ::failed_attempt_count_connecting_to_de1 0
set ::successful_de1_connection_count 0

proc de1_real_machine {} {
	if {$::de1(connectivity) == "ble"} {
		return true
	} 
	if {$::de1(connectivity) == "tcp"} {
		return true
	} 
	if {$::de1(connectivity) == "usb"} {
		return true
	} 

	# "simulated" machine or any other (unexpected) fallthrough value
	return false
}

proc de1_is_connected {} {
	if {![de1_real_machine]} {
		return false
	}

	if {$::de1(connectivity) == "ble"} {
		return [de1_ble_is_connected]
	} else {
		return [de1_channel_is_connected]
	}

	return false
}

# Can use these "de1_safe_for" functions to implement safety checks as needed, in a way that works across
# different means of connectivity.  E.g. these could be written to say 'let's not allow any 
# calibrarion operations except via BLE' if that was the desired policy to be enforced
# (As it stands the policy is "stuff is safe on any "real" machine that is currently thought 
# to be connected.)
proc de1_safe_for_firmware {} {
	return [de1_is_connected]
}

proc de1_safe_for_calibration {} {
	return [de1_safe_for_firmware]
}

proc userdata_append {comment cmd} {
	lappend ::de1(cmdstack) [list $comment $cmd]
	run_next_userdata_cmd
}

proc read_de1_version {} {
	catch {
		userdata_append "read_de1_version" [list de1_comm read "Versions"]
	}
}

# repeatedly request de1 state
proc poll_de1_state {} {
	msg "poll_de1_state"
	read_de1_state
	after 1000 poll_de1_state
}

proc read_de1_state {} {
	if {[catch {
		userdata_append "read de1 state" [list de1_comm read "StateInfo"]
	} err] != 0} {
		msg "Failed to 'read de1 state' in DE1 because: '$err'"
	}
}

proc int_to_hex {in} {
	return [format %02X $in]
}

# calibration change notifications ENABLE
proc de1_enable_calibration_notifications {} {
	if {![de1_is_connected] || ![de1_safe_for_calibration]} {
		msg "DE1 not connected, cannot send command 1"
		return
	}

	userdata_append "enable de1 calibration notifications" [list de1_comm enable Calibration]
}

# calibration change notifications DISABLE
proc de1_disable_calibration_notifications {} {
	if {![de1_is_connected] || ![de1_safe_for_calibration]} {
		msg "DE1 not connected, cannot send command 2"
		return
	}

	userdata_append "disable de1 calibration notifications" [list de1_comm disable Calibration]
}

# temp changes
proc de1_enable_temp_notifications {} {
	if {![de1_is_connected]} {
		msg "DE1 not connected, cannot send command 3"
		return
	}

	# REED to JOHN: Prouction code has cuuid_0D here, but cuuid_0D looks like ShotSample not Temperatures (0A).
	# I am keeping the behavior as I found it (still 0D) but I may be preserving a bug.  
	# So take a look... and even if you don't keep this code, consider taking a look at bluetooth.tcl 
	userdata_append "enable de1 temp notifications" [list de1_comm enable ShotSample]
}

# status changes
proc de1_enable_state_notifications {} {
	if {![de1_is_connected]} {
		msg "DE1 not connected, cannot send command 4"
		return
	}

	userdata_append "enable de1 state notifications" [list de1_comm enable StateInfo]
}

proc de1_disable_temp_notifications {} {
	if {![de1_is_connected]} {
		msg "DE1 not connected, cannot send command 5"
		return
	}

	# REED to JOHN: Prouction code has cuuid_0D here, but cuuid_0D looks like ShotSample not Temperatures (0A).
	# I am keeping the behavior as I found it (still 0D) but I may be preserving a bug.  
	# So take a look... and even if you don't keep this code, consider taking a look at bluetooth.tcl 
	userdata_append "disable temp notifications" [list de1_com disable ShotSample]
}

proc de1_disable_state_notifications {} {
	if {![de1_is_connected]} {
		msg "DE1 not connected, cannot send command 6"
		return
	}

	userdata_append "disable state notifications" [list de1_comm disable StateInfo]
}

proc mmr_available {} {
	if {$::de1(connectivity) == "ble"} {
		# when the BLE adaptor is in the loop, the app determines
		# MMR-readiness using the BLE API version
		return [ble_mmr_available]
	} else {
		# when the BLE adaptor is not in the loop, we don't currently
		# get any response to the command that's equivalent to characteristic
		# A001.  Right now just assume that a machine with DAYBREAK installed
		# has sufficiently recent DE1 FW to be able to make mmr_available = true 
		# REED to JOHN: This could be a safe or unsafe assumption.  If there's some
		# other way to check for MMR-readiness (probing the FW somehow)
		# this would be the place to do ti
		set ::de1(mmr_enabled) 1
	}
	return $::de1(mmr_enabled)
}

proc de1_enable_mmr_notifications {} {

	if {[mmr_available] == 0} {
		msg "Unable to de1_enable_mmr_notifications because MMR not available"
		return
	}

	if {![de1_is_connected]} {
		msg "DE1 not connected, cannot send command 7"
		return
	}

	userdata_append "enable MMR read notifications" [list de1_comm enable ReadFromMMR]
}

# water level notifications
proc de1_enable_water_level_notifications {} {
	if {![de1_is_connected]} {
		# REED to JOHN: 2 debug messages have "command 7" in them (MMR Read & Water Level).  
		# Dunno if it matters much, but there it is.
		msg "DE1 not connected, cannot send command 7"
		return
	}

	userdata_append "enable de1 water level notifications" [list de1_comm enable WaterLevels]
}

proc de1_disable_water_level_notifications {} {
	if {![de1_is_connected]} {
		msg "DE1 not connected, cannot send command 8"
		return
	}

	userdata_append "disable state notifications" [list de1_comm disable WaterLevels]
}

# firmware update command notifications (not writing new fw, this is for erasing and switching firmware)
proc de1_enable_maprequest_notifications {} {
	if {![de1_is_connected] || ![de1_safe_for_firmware]} {
		msg "DE1 not connected, cannot send command 9"
		return
	}

	userdata_append "enable de1 state notifications" [list de1_comm enable FWMapRequest]
}

proc fwfile {} {
	
	if {$::settings(ghc_is_installed) == 1 || $::settings(ghc_is_installed) == 2 || $::settings(ghc_is_installed) == 3} {
		# new firmware for v1.3 machines and newer, that have a GHC.
		# this dual firmware aspect is temporary, only until we have improved the firmware to be able to correctly migrate v1.0 v1.1 hardware machines to the new calibration settings.
		# please do not bypass this test and load the new firmware on your v1.0 v1.1 machines yet.  Once we have new firmware is known to work on those older machines, we'll get rid of the 2nd firmware image.

		# note that ghc_is_installed=1 ghc hw is there but unused, whereas ghc_is_installed=3 ghc hw is required.
		return "[homedir]/fw/bootfwupdate2.dat"
	} else {
		return "[homedir]/fw/bootfwupdate.dat"
	}
}

proc start_firmware_update {} {
	if {![de1_is_connected] || ![de1_safe_for_firmware]} {
		msg "DE1 not connected, cannot send command 10"
		return
	}

	if {$::settings(force_fw_update) != 1} {
		set ::de1(firmware_update_button_label) "Up to date"
		return
	}


	if {$::de1(currently_erasing_firmware) == 1} {
		msg "Already erasing firmware"
		return
	}

	if {$::de1(currently_updating_firmware) == 1} {
		msg "Already updating firmware"
		return
	}

	de1_enable_maprequest_notifications
	
	set ::de1(firmware_bytes_uploaded) 0
	set ::de1(firmware_update_size) [file size [fwfile]]

# REED to JOHN: In bluetooth.tcl the following code is gated by
# 	if {$::android != 1} 
# I am not confident I correctly grasped the intent of this if statement.
# If the statement is true, it looks like we disable certain characteristics 
# then (after a delay) asynchronously call write_firmware_now.
# 
# Here I am treating that as a call to "simulate the firmware update on a fake machine". 
# But this code may be intended to do something more important like "prevent a race 
# condition" or "prevent unsafe operations from happening in the middle of an update".
#
# Assuming I'm right, WHat I've done is dropped the part where I zero out the charactieristics.
# because -- well if it's not a real BLE machine, we won't use cuuids for anything... and
# if it *is* a real BLE machine ... then the zeroing behavior isn't supposed to happen (I don't think).
#
# But, if my interpretation was wrong, we might lose an important safety check.
# So anyway, this is one spot to *definitely* check my work.
	if {[!de1_is_connected]} {
		after 100 write_firmware_now
		# bluetooth.tcl zeroed these BLE specific concepts out.  Not doing that here since "zeroing out a
		# characteristic" is not an action that has a clear analog in TCP, USB etc.
		# set ::sinstance($::de1(suuid))
		# set ::de1(cuuid_09) 0
		# set ::de1(cuuid_06) 0
		# set ::cinstance($::de1(cuuid_09)) 0
	}

	set arr(WindowIncrement) 0
	set arr(FWToErase) 1
	set arr(FWToMap) 1
	set arr(FirstError1) 0
	set arr(FirstError2) 0
	set arr(FirstError3) 0
	set data [make_packed_maprequest arr]

	set ::de1(firmware_update_button_label) "Updating"

	# it'd be useful here to test that the maprequest was correctly packed
	set ::de1(currently_erasing_firmware) 1
	userdata_append "Erase firmware: [array get arr]" [list de1_comm write FWMapRequest $data]

}

proc write_firmware_now {} {
	set ::de1(currently_updating_firmware) 1
	msg "Start writing firmware now"

	set ::de1(firmware_update_binary) [read_binary_file [fwfile]]
	set ::de1(firmware_bytes_uploaded) 0

	firmware_upload_next
}


proc firmware_upload_next {} {
	
	if {$::de1(connectivity)=="simulated"} {
		msg "firmware_upload_next connected to 'simulated' machine; updating button text (only)"
	} elseif {[de1_is_connected] && [de1_safe_for_firmware]} {
		msg "firmware_upload_next $::de1(firmware_bytes_uploaded)"
	} else {
		msg "DE1 not connected, cannot send command 11"
		return
	}

	#delay_screen_saver

	if  {$::de1(firmware_bytes_uploaded) >= $::de1(firmware_update_size)} {
		set ::settings(firmware_crc) [crc::crc32 -filename [fwfile]]
		save_settings

		if {$::de1(connectivity) == "simulated"} {
			set ::de1(firmware_update_button_label) "Updated"
			
		} else {
			set ::de1(firmware_update_button_label) "Testing"

			#set ::de1(firmware_update_size) 0
			unset -nocomplain ::de1(firmware_update_binary)
			#set ::de1(firmware_bytes_uploaded) 0

			#write_FWMapRequest(self.FWMapRequest, 0, 0, 1, 0xFFFFFF, True)		
			#def write_FWMapRequest(ctic, WindowIncrement=0, FWToErase=0, FWToMap=0, FirstError=0, withResponse=True):

			set arr(WindowIncrement) 0
			set arr(FWToErase) 0
			set arr(FWToMap) 1
			set arr(FirstError1) [expr 0xFF]
			set arr(FirstError2) [expr 0xFF]
			set arr(FirstError3) [expr 0xFF]
			set data [make_packed_maprequest arr]
			userdata_append "Find first error in firmware update: [array get arr]" [list de1_comm write FWMapRequest $data]
		}
	} else {
		set ::de1(firmware_update_button_label) "Updating"

		set data "\x10[make_U24P0 $::de1(firmware_bytes_uploaded)][string range $::de1(firmware_update_binary) $::de1(firmware_bytes_uploaded) [expr {15 + $::de1(firmware_bytes_uploaded)}]]"
		userdata_append "Write [string length $data] bytes of firmware data ([convert_string_to_hex $data])" [list de1_comm write WriteToMMR $data]
		set ::de1(firmware_bytes_uploaded) [expr {$::de1(firmware_bytes_uploaded) + 16}]
		if {$::de1(connectivity) != "simulated"} {
			after 1 firmware_upload_next
		}
	}
}


proc mmr_read {address length} {
	if {[mmr_available] == 0} {
		msg "Unable to mmr_read because MMR not available"
		return
	}


 	set mmrlen [binary decode hex $length]	
	set mmrloc [binary decode hex $address]
	set data "$mmrlen${mmrloc}[binary decode hex 00000000000000000000000000000000]"
	
	if {$::de1(connectivity) == "simulated"} {
		msg "MMR requesting read [convert_string_to_hex $mmrlen] bytes of firmware data from [convert_string_to_hex $mmrloc]: with comment [convert_string_to_hex $data]"
		return
	}

	if {![de1_is_connected]} {
		msg "DE1 not connected, cannot send BLE command 11"
		return
	}

	userdata_append "MMR requesting read [convert_string_to_hex $mmrlen] bytes of firmware data from [convert_string_to_hex $mmrloc] with '[convert_string_to_hex $data]'" [list de1_comm write ReadFromMMR $data]
}

proc mmr_write {address length value} {
	if {[mmr_available] == 0} {
		msg "Unable to mmr_read because MMR not available"
		return
	}

 	set mmrlen [binary decode hex $length]	
	set mmrloc [binary decode hex $address]
 	set mmrval [binary decode hex $value]	
	set data "$mmrlen${mmrloc}${mmrval}[binary decode hex 000000000000000000000000000000]"
	
	if {$::de1(connectivity) ==  "simulated"} {
		msg "MMR writing [convert_string_to_hex $mmrlen] bytes of firmware data to [convert_string_to_hex $mmrloc] with value [convert_string_to_hex $mmrval] : with comment [convert_string_to_hex $data]"
		return
	}

	if {![de1_is_connected]} {
		msg "DE1 not connected, cannot send BLE command 11"
		return
	}
	userdata_append "MMR writing [convert_string_to_hex $mmrlen] bytes of firmware data to [convert_string_to_hex $mmrloc] with value [convert_string_to_hex $mmrval] : with comment [convert_string_to_hex $data]" [list de1_comm write WriteToMMR $data]
}

proc set_tank_temperature_threshold {temp} {
	msg "Setting desired water tank temperature to '$temp'"

	if {$temp == 0} {
		mmr_write "80380C" "04" [zero_pad [int_to_hex $temp] 2]
	} else {
		# if the water temp is being set, then set the water temp temporarily to 60º in order to force a water circulation for 2 seconds
		# then a few seconds later, set it to the real, desired value
		set hightemp 60
		mmr_write "80380C" "04" [zero_pad [int_to_hex $hightemp] 2]
		after 4000 [list mmr_write "80380C" "04" [zero_pad [int_to_hex $temp] 2]]
	}
}

# /*
#  *  Memory Mapped Registers
#  *
#  *  RangeNum Position       Len  Desc
#  *  -------- --------       ---  ----
#  *         1 0x0080 0000      4  : HWConfig
#  *         2 0x0080 0004      4  : Model
#  *         3 0x0080 2800      4  : How many characters in debug buffer are valid. Accessing this pauses BLE debug logging.
#  *         4 0x0080 2804 0x1000  : Last 4K of output. Zero terminated if buffer not full yet. Pauses BLE debug logging.
#  *         6 0x0080 3808      4  : Fan threshold.
#  *         7 0x0080 380C      4  : Tank water threshold.
#  *        11 0x0080 381C      4  : GHC Info Bitmask, 0x1 = GHC Present, 0x2 = GHC Active
#  *
#  */



proc set_steam_flow {desired_flow} {
	#return
	msg "Setting steam flow rate to '$desired_flow'"
	mmr_write "803828" "04" [zero_pad [int_to_hex $desired_flow] 2]
}

proc get_steam_flow {} {
	msg "Getting steam flow rate"
	mmr_read "803828" "00"
}


proc set_steam_highflow_start {desired_seconds} {
	#return
	msg "Setting steam high flow rate start seconds to '$desired_seconds'"
	mmr_write "80382C" "04" [zero_pad [int_to_hex $desired_seconds] 2]
}

proc get_steam_highflow_start {} {
	msg "Getting steam high flow rate start seconds "
	mmr_read "80382C" "00"
}


proc set_ghc_mode {desired_mode} {
	msg "Setting group head control mode '$desired_mode'"
	mmr_write "803820" "04" [zero_pad [int_to_hex $desired_mode] 2]
}

proc get_ghc_mode {} {
	msg "Reading group head control mode"
	mmr_read "803820" "00"
}

proc get_ghc_is_installed {} {
	msg "Reading whether the group head controller is installed or not"
	mmr_read "80381C" "00"
}

proc get_fan_threshold {} {
	msg "Reading at what temperature the PCB fan turns on"
	mmr_read "803808" "00"
}

proc set_fan_temperature_threshold {temp} {
	msg "Setting desired water tank temperature to '$temp'"
	mmr_write "803808" "04" [zero_pad [int_to_hex $temp] 2]
}

proc get_tank_temperature_threshold {} {
	msg "Reading desired water tank temperature"
	mmr_read "80380C" "00"
}

proc de1_cause_refill_now_if_level_low {} {

	# john 05-08-19 commented out, will obsolete soon.  Turns out not to work, because SLEEP mode does not check low water setting.
	return

	# set the water level refill point to 10mm more water
	set backup_waterlevel_setting $::settings(water_refill_point)
	set ::settings(water_refill_point) [expr {$::settings(water_refill_point) + 20}]
	de1_send_waterlevel_settings

	# then set the water level refill point back to the user setting
	set ::settings(water_refill_point) $backup_waterlevel_setting

	# and in 30 seconds, tell the machine to set it back to normal
	after 30000 de1_send_waterlevel_settings
}

proc de1_send_waterlevel_settings {} {
	if {![de1_is_connected]} {
		msg "DE1 not connected, cannot send BLE command 12"
		return
	}

	set data [return_de1_packed_waterlevel_settings]
	parse_binary_water_level $data arr2
	userdata_append "Set water level settings: [array get arr2]" [list de1_comm write WaterLevels $data]
}


### REED to JOHN: I decided to retain the ::de1(wrote) logic outside the BLE connectivity code, 
### making it applicable to all communication modalities, even though the protection it provides 
### may not be of benefit to non the-BLE cases.  Even though this may come at some cost in terms
### of throughput, it seemed the safer thing to do.  It would be pretty easy to defeat the protection 
### by making this one check (here at the top of proc run_next_userdata_command) conditional on
### {$::de1(connectivity) == "ble"}, while still preserving the logic of setting and unsetting
### de1(wrote) ... which would make the "one command at a time" ve "not" an easy choice to revert.
proc run_next_userdata_cmd {} {
	# only write one command at a time.  this protection only works for BLE as it gets unset
	# by an asynchronous "ACK" of the write
	if {$::de1(connectivity) == "ble" && $::de1(wrote) == 1} {
		msg "Do not write, already writing to DE1"
		return
	}

	if {![de1_is_connected]} {
		msg "Do no write, DE1 not connected"
		return
	}

	if {$::de1(cmdstack) ne {}} {

		set cmd [lindex $::de1(cmdstack) 0]
		set cmds [lrange $::de1(cmdstack) 1 end]
		set result 0
		msg ">>> [lindex $cmd 0] (-[llength $::de1(cmdstack)])"
		set errcode [catch {
		set result [{*}[lindex $cmd 1]]
			
		}]

	    if {$errcode != 0} {
	        catch {
	            msg "run_next_userdata_cmd catch error: $::errorInfo"
	        }
	    }


		if {$result != 1} {
			msg "comm command failed, will retry ($result): [lindex $cmd 1]"

			# john 4/28/18 not sure if we should give up on the command if it fails, or retry it
			# retrying a command that will forever fail kind of kills the BLE abilities of the app
			
			#after 500 run_next_userdata_cmd
			return 
		}


		set ::de1(cmdstack) $cmds
		set ::de1(wrote) 1
		set ::de1(previouscmd) [lindex $cmd 1]
		if {[llength $::de1(cmdstack)] == 0} {
			msg "BLE command queue is now empty"
		}

	} else {
		#msg "no userdata cmds to run"
	}
}

proc close_all_comms_and_exit {} {

	close_de1

	# unconditionallly call the ble-specific close routine as a way to wrap up
	# this will disconnect the de1 if connectivity is BLE (if needed)
	# but also handles cleanly disconnecting from other potential BLE 
	# devices (scales and whatnot)
	close_all_ble_and_exit
}	

proc app_exit {} {
	close_log_file

	if {$::de1(connectivity) == "simulated"} {
		close_all_comms_and_exit
	}

	# john 1/15/2020 this is a bit of a hack to work around a firmware bug in 7C24F200 that has the fan turn on during sleep, if the fan threshold is set > 0
	set_fan_temperature_threshold 0

	set ::exit_app_on_sleep 1
	start_sleep
	
	# fail-over, if the DE1 doesn't to to sleep
	set since_last_ping [expr {[clock seconds] - $::de1(last_ping)}]
	if {$since_last_ping > 10} {
		# wait less time for the fail-over if we don't have any temperature pings from the DE1
		after 1000 close_all_comms_and_exit
	} else {
		after 5000 close_all_comms_and_exit
	}

	after 10000 "exit 0"
}

proc de1_send_state {comment msg} {
	if {![de1_is_connected]} {
		msg "DE1 not connected, cannot send command 13"
		return
	}

	#clear_timers
	delay_screen_saver
	
	#if {$::de1(device_handle) == "0"} {
	#	msg "error: de1 not connected"
	#	return
	#}

	#set ::de1(substate) -
	#msg "Sending to DE1: '$msg'"
	userdata_append $comment [list de1_comm write RequestedState "$msg"]
}


#proc send_de1_shot_and_steam_settings {} {
#	return
#	msg "send_de1_shot_and_steam_settings"
	#return
	#de1_send_shot_frames
#	de1_send_steam_hotwater_settings

#}

proc de1_send_shot_frames {} {

	set parts [de1_packed_shot]
	set header [lindex $parts 0]
	
	####
	# this is purely for testing the parser/deparser
	parse_binary_shotdescheader $header arr2
	#msg "frame header of [string length $header] bytes parsed: $header [array get arr2]"
	####


	userdata_append "Espresso header: [array get arr2]" [list de1_comm write HeaderWrite $header]

	set cnt 0
	foreach packed_frame [lindex $parts 1] {

		####
		# this is purely for testing the parser/deparser
		incr cnt
		unset -nocomplain arr3
		parse_binary_shotframe $packed_frame arr3
		#msg "frame #$cnt data parsed [string length $packed_frame] bytes: $packed_frame  : [array get arr3]"
		msg "frame #$cnt: [string length $packed_frame] bytes: [array get arr3]"
		####

		userdata_append "Espresso frame #$cnt: [array get arr3] (FLAGS: [parse_shot_flag $arr3(Flag)])"  [list de1_comm write FrameWrite $packed_frame]
	}

	# only set the tank temperature for advanced profile shots
	if {$::settings(settings_profile_type) == "settings_2c"} {
		set_tank_temperature_threshold $::settings(tank_desired_water_temperature)
	} else {
		set_tank_temperature_threshold 0
	}


	return
}

proc save_settings_to_de1 {} {
	de1_send_shot_frames
	de1_send_steam_hotwater_settings
}

proc de1_send_steam_hotwater_settings {} {

	if {![de1_is_connected]} {
		msg "DE1 not connected, cannot send command 16"
		return
	}

	set data [return_de1_packed_steam_hotwater_settings]
	parse_binary_hotwater_desc $data arr2
	userdata_append "Set water/steam settings: [array get arr2]" [list de1_comm write ShotSettings $data]

	set_steam_flow $::settings(steam_flow)
	set_steam_highflow_start $::settings(steam_highflow_start)
}

proc de1_send_calibration {calib_target reported measured {calibcmd 1} } {
	if {![de1_is_connected]} {
		msg "DE1 not connected, cannot send command 17"
		return
	}

	if {$calib_target == "flow"} {
		set target 0
	} elseif {$calib_target == "pressure"} {
		set target 1
	} elseif {$calib_target == "temperature"} {
		set target 2
	} else {
		msg "Uknown calibration target: '$calib_target'"
		return
	}

	set arr(WriteKey) [expr 0xCAFEF00D]

	# change calibcmd to 2, to reset to factory settings, otherwise default of 1 does a write
	set arr(CalCommand) $calibcmd
	
	set arr(CalTarget) $target
	set arr(DE1ReportedVal) [convert_float_to_S32P16 $reported]
	set arr(MeasuredVal) [convert_float_to_S32P16 $measured]

	set data [make_packed_calibration arr]
	parse_binary_calibration $data arr2
	userdata_append "Set calibration: [array get arr2] : [string length $data] bytes: ([convert_string_to_hex $data])" [list de1_comm write Calibration $data]
}

proc de1_read_calibration {calib_target {factory 0} } {
	if {![de1_is_connected]} {
		msg "DE1 not connected, cannot send command 18"
		return
	}


	if {$calib_target == "flow"} {
		set target 0
	} elseif {$calib_target == "pressure"} {
		set target 1
	} elseif {$calib_target == "temperature"} {
		set target 2
	} else {
		msg "Uknown calibration target: '$calib_target'"
		return
	}

	#set arr(WriteKey) [expr 0xCAFEF00D]
	set arr(WriteKey) 1

	set arr(CalCommand) 0
	set what "current"
	if {$factory == "factory"} {
		set arr(CalCommand) 3
		set what "factory"
	}
	
	set arr(CalTarget) $target
	set arr(DE1ReportedVal) 0
	set arr(MeasuredVal) 0

	set data [make_packed_calibration arr]
	parse_binary_calibration $data arr2
	userdata_append "Read $what calibration: [array get arr2] : [string length $data] bytes: ([convert_string_to_hex $data])" [list de1_comm write Calibrarion $data]

}

proc de1_read_version_obsolete {} {
	msg "LIKELY OBSOLETE BLE FUNCTION: DO NOT USE"

	#if {$::de1(device_handle) == "0"} {
	#	msg "error: de1 not connected"
	#	return
	#}

	userdata_append "read de1 version" [list de1_comm read Temperatures]
}

proc de1_read_hotwater {} {
	#if {$::de1(device_handle) == "0"} {
	#	msg "error: de1 not connected"
	#	return
	#}

	userdata_append "read de1 hot water/steam" [list de1_comm read ShotSettings]
}

proc de1_read_shot_header {} {
	#if {$::de1(device_handle) == "0"} {
	#	msg "error: de1 not connected"
	#	return
	#}

	userdata_append "read shot header" [list de1_comm read HeaderWrite]
}
proc de1_read_shot_frame {} {
	#if {$::de1(device_handle) == "0"} {
	#	msg "error: de1 not connected"
	#	return
	#}

	userdata_append "read shot frame" [list de1_comm read FrameWrite]
}

proc remove_null_terminator {instr} {
	set pos [string first "\x00" $instr]
	if {$pos == -1} {
		return $instr
	}

	incr pos -1
	return [string range $instr 0 $pos]
}

proc android_8_or_newer {} {

	if {$::runtime != "android"} {
		msg "android_8_or_newer reports: not android (0)"		
		return 0
	}

	catch {
		set x [borg osbuildinfo]
		#msg "osbuildinfo: '$x'"
		array set androidprops $x
		msg [array get androidprops]
		msg "Android release reported: '$androidprops(version.release)'"
	}
	set test 0
	catch {
		set test [expr {$androidprops(version.release) >= 8}]
	}
	#msg "Is this Android 8 or newer? '$test'"
	return $test
	

	#msg "android_8_or_newer failed and reports: 0"
	#return 0
}

proc connect_to_devices {} {
	msg "connect_to_devices"

	if {$::de1(connectivity) != "ble"} {
		connect_to_de1
	}
	# we unconditionally call bluetooth_connect_to_devices because:
	# - if BLE *is* the de1 connectivity mode, it establishes that connection
	# - if BLE is *NOT* the de1 connectivity mode, it does not disrupt whatever is already
	#   active
	# - whether or not we are using BLE to talk to the DE1, this allows other
	#   BLE devices to be connected (e.g. scale)
	# - for the latter case (scales etc) we don't want a bunch of ble-specific complexity
	#   in this file (e.g. determining which BLE connection approach to invoke, dependent
	#   on android version.) seems safer & better architecture to leave that all in one 
	#   place, with "ble" in the filename)
	bluetooth_connect_to_devices
}

proc connect_to_de1 {} {
	msg "connect_to_de1"

	set ::de1(connect_time) 0

	if {$::de1(device_handle) != 0} {
		msg "connect_to_de1: disconnecting from DE1"
		catch {
			close_de1
			set ::de1(device_handle) 0
			after 1000 connect_to_de1
			return
		}
	}

	if {[info exists ::currently_connecting_de1_handle] && $::currently_connecting_de1_handle != 0} {
		msg "connect_to_de1: terminating previous connection attempt"
		catch {
			close $::currently_connecting_de1_handle
		}
	}
	set ::currently_connecting_de1_handle 0
    set ::de1_name "DE1"

	if {$::de1(connectivity) == "ble"} {
		# because a bunch of things get initialized during BLE enumeration, we do not need to call the initialization code
		# below; this just returns immediately
		return [ble_connect_to_de1]
	} elseif {$::de1(connectivity) == "simulated"} {
		msg "simulated DE1 connection"
	    set ::de1(connect_time) [clock seconds]
	    set ::de1(last_ping) [clock seconds]

	    msg "Connected to fake DE1"
		set ::de1(device_handle) 1

		# example binary string containing binary version string
		#set version_value "\x01\x00\x00\x00\x03\x00\x00\x00\xAC\x1B\x1E\x09\x01"
		#set version_value "\x01\x00\x00\x00\x03\x00\x00\x00\xAC\x1B\x1E\x09\x01"
		set version_value "\x02\x04\x00\xA4\x0A\x6E\xD0\x68\x51\x02\x04\x00\xA4\x0A\x6E\xD0\x68\x51"
		parse_binary_version_desc $version_value arr2
		set ::de1(version) [array get arr2]

		# a simulated machine does not need as much initialization, so we do not call all of the initialization stuff
		# that is needed for "real" non-ble comms 
		return
	} elseif {$::de1(connectivity) == "tcp"} {
		# connect to DE1 via TCP
		msg "connect_to_de1: initiating TCP connection"
		return [tcp_connect_to_de1]
	} elseif {$::de1(connectivity) == "usb"} {
		msg "connect_to_de1: initiating USB connection"
		return [usb_connect_to_de1]
	} else {
		msg "connect_to_de1: unexpected connectivity type"
	}
}

# note the below is only used for non-BLE; ble has its own
# means of handling connection timeouts etc.
proc connection_timeout_handler {} {
	msg "$::de1(connectivity) connection timeout"
	catch {
		close $::currently_connecting_de1_handle
	}
	set ::currently_connecting_de1_handle 0
	after 500 de1_disconnect_handler
}


# READABILITY TODO(REED) This funcion is more like "is_connected" and should probably be renamed
proc de1_channel_is_connected {} {
	if {$::de1(device_handle) != "0" && $::de1(device_handle) != "1"} {
		if { [catch {
			if {[chan eof $::de1(device_handle)] || [chan pending input $::de1(device_handle)] == -1} {
				msg "usb channel closed"
				de1_disconnect_handler
				return 0
			} 
		} ] } {return 0} 
	} else {
		return 0
	}
	return 1
}

# USABILITY TCP USB TODO(REED) we could move this code from the bluetooth.tcl implememtation, to more generically
# show a "connection list" instead of a "bluetooth list".  So for example a TCP host:port could be shown
# see also proc scanning_state_text

#proc append_to_de1_bluetooth_list {address} {
#	set newlist $::de1_bluetooth_list
#	lappend newlist $address
#	set newlist [lsort -unique $newlist]
#
#	if {[llength $newlist] == [llength $::de1_bluetooth_list]} {
#		return
#	}
#
#	msg "Scan found DE1: $address"
#	set ::de1_bluetooth_list $newlist
#	catch {
#		fill_ble_listbox
#	}


proc close_de1 {} {
	if {$::de1(device_handle) != 0} {
		if {$::de1(connectivity) == "ble"} {
			ble_close_de1
		} elseif {$::de1(connectivity) == "tcp"} {
			tcp_close_de1
		} elseif {$::de1(connectivity) == "usb"} {
			usb_close_de1
		}
	}
	set ::de1(device_handle) 0
}

proc later_new_de1_connection_setup {} {
	# less important stuff, also some of it is dependent on BLE version

	de1_enable_mmr_notifications
	de1_send_shot_frames
	set_fan_temperature_threshold $::settings(fan_threshold)
	de1_send_steam_hotwater_settings
	get_ghc_is_installed

	de1_send_waterlevel_settings
	de1_enable_water_level_notifications

	after 5000 read_de1_state

}

proc de1_disconnect_handler {} {
	set ::de1(wrote) 0
	set ::de1(cmdstack) {}


	if {$::de1(device_handle) != 0} {
		msg "de1_disconnect_handler: de1 newly disconnected"
		catch {
			close_de1
			close $::currently_connecting_de1_handle
		}
		set ::de1(device_handle) 0
		set ::currently_connecting_de1_handle 0
	}


	if {$::currently_connecting_de1_handle == 0} {
		msg "de1_disconnect_handler: initiating new connection"
		# READABILITY TODO(REED) "ble" shouldn't really be in the settings name.
		# would be good for readability to clean that up....  but renaming settings seems annoying so I am not going to 
		# tackle it now
		set ::settings(max_ble_connect_attempts) 10

		incr ::failed_attempt_count_connecting_to_de1
		if {$::failed_attempt_count_connecting_to_de1 > $::settings(max_ble_connect_attempts) && $::successful_de1_connection_count > 0} {
			# if we have previously been connected to a DE1 but now can't connect, then make the UI go to Sleep
			# and we'll try again to reconnect when the user taps the screen to leave sleep mode

			# set this to zero so that when we come back from sleep we try several times to connect
			set ::failed_attempt_count_connecting_to_de1 0

			update_de1_state "$::de1_state(Sleep)\x0"
		} else {
			connect_to_de1
		}
	} else {
		msg "de1_disconnect_handler: reconnect attempt already active; not initiating new connection"
	}
}

proc de1_connect_handler { handle address } {
	incr ::successful_de1_connection_count
	set ::failed_attempt_count_connecting_to_de1 0

	set ::de1(wrote) 0
	set ::de1(cmdstack) {}
	#set ::de1(found) 1
	set ::de1(connect_time) [clock seconds]
	set ::de1(last_ping) [clock seconds]
	set ::currently_connecting_de1_handle 0

	#msg "Connected to DE1"
	set ::de1(device_handle) $handle
	if {$::de1(connectivity) == "ble"} {
		append_to_de1_bluetooth_list $address
	}
	# USABILITY TODO(REED) could use the "bluetooth" list to also display other connections
	# see also proc scanning_state_text, proc append_to_de1_bluetooth_list

	#msg "connected to de1 with handle $handle"
	set testing 0
	if {$testing == 1} {
		de1_read_calibration "temperature"
	} else {
		# subscribe and initialize to the various things that would otherwise happen
		# what happens during BLE enumeration.
		# this is kind of a mishmash of things found in the code as well as the 
		# recommendations from here: 
		# https://3.basecamp.com/3671212/buckets/7351439/messages/1976315941#__recording_2008131794
		# so this might not be optimal (e.g. may have needless dupes)
		de1_enable_temp_notifications
		de1_enable_water_level_notifications
		de1_send_steam_hotwater_settings
		de1_send_shot_frames
		read_de1_version
		de1_enable_state_notifications
		read_de1_state
		if {[info exists ::de1(first_connection_was_made)] != 1} {
			# on app startup, wake the machine up
			set ::de1(first_connection_was_made) 1
			start_idle
		}
		later_new_de1_connection_setup
		read_de1_version
		read_de1_state
		
		after 2000 de1_enable_state_notifications
	}
}

proc de1_event_handler { command_name value } {
	set previous_wrote 0
	set previous_wrote [ifexists ::de1(wrote)]

	#msg "Received from DE1: '[remove_null_terminator $value]'"
	# change notification or read request
	#de1_ble_new_value $cuuid $value
	# change notification or read request
	#de1_ble_new_value $cuuid $value


	if {$command_name == "ShotSample"} {
		set ::de1(last_ping) [clock seconds]
		set results [update_de1_shotvalue $value]
		#msg "Shotvalue received: $results" 
		#set ::de1(wrote) 0
		#run_next_userdata_cmd
		set do_this 0
		if {$do_this == 1} {
			# this tries to handle bad write situations, but it might have side effects if it is not working correctly.
			# probably this should be adding a command to the top of the write queue
			if {$previous_wrote == 1} {
				msg "bad write reported"
				{*}$::de1(previouscmd)
				set ::de1(wrote) 1
				return
			}
		}
	} elseif {$command_name == "Versions"} {
		# REED to JOHN: On BLE this command corresponds to characteristic A001.
		# Looking at logs it seems that characteristic is handled entirely on the BLE adaptor, meaning the 
		# DE1 serial UART isn't involved.  As such when the app uses DAYBREAK (non BLE) to send "<+A>" this isn't currently 
		# eliciting any response from the DE1.
		# There may be a smarter way to handle this -- see also proc mmr_available
		set ::de1(last_ping) [clock seconds]
		#update_de1_state $value
		parse_binary_version_desc $value arr2
		msg "version data received [string length $value] bytes: '$value' \"[convert_string_to_hex $value]\""
		set ::de1(version) [array get arr2]

		# run stuff that depends on the BLE API version
		later_new_de1_connection_setup

		set ::de1(wrote) 0
		run_next_userdata_cmd

	} elseif {$command_name == "Calibration"} {
		#set ::de1(last_ping) [clock seconds]
		calibration_received $value
	} elseif {$command_name == "WaterLevels"} {
		set ::de1(last_ping) [clock seconds]
		parse_binary_water_level $value arr2
		msg "water level data received [string length $value] bytes: $value  : [array get arr2]"

		# compensate for the fact that we measure water level a few mm higher than the water uptake point
		set mm [expr {$arr2(Level) + $::de1(water_level_mm_correction)}]
		set ::de1(water_level) $mm
		
	} elseif {$command_name == "FWMapRequest"} {
		#set ::de1(last_ping) [clock seconds]
		parse_map_request $value arr2
		if {$::de1(currently_erasing_firmware) == 1 && [ifexists arr2(FWToErase)] == 0} {
			msg "BLE recv: finished erasing fw '[ifexists arr2(FWToMap)]'"
			set ::de1(currently_erasing_firmware) 0
			write_firmware_now
		} elseif {$::de1(currently_erasing_firmware) == 1 && [ifexists arr2(FWToErase)] == 1} { 
			msg "BLE recv: currently erasing fw '[ifexists arr2(FWToMap)]'"
		} elseif {$::de1(currently_erasing_firmware) == 0 && [ifexists arr2(FWToErase)] == 0} { 
			msg "BLE firmware find error BLE recv: '$value' [array get arr2]'"
	
			if {[ifexists arr2(FirstError1)] == [expr 0xFF] && [ifexists arr2(FirstError2)] == [expr 0xFF] && [ifexists arr2(FirstError3)] == [expr 0xFD]} {
				set ::de1(firmware_update_button_label) "Updated"
			} else {
				set ::de1(firmware_update_button_label) "Update failed"
			}
			set ::de1(currently_updating_firmware) 0

		} else {
			msg "unknown firmware cmd ack recved: [string length $value] bytes: $value : [array get arr2]"
		}
	} elseif {$command_name == "ShotSettings"} {
		set ::de1(last_ping) [clock seconds]
		#update_de1_state $value
		parse_binary_hotwater_desc $value arr2
		msg "hotwater data received [string length $value] bytes: $value  : [array get arr2]"

		#update_de1_substate $value
		#msg "Confirmed a00e read from DE1: '[remove_null_terminator $value]'"
	} elseif {$command_name == "DeprecatedShotDesc"} {
		set ::de1(last_ping) [clock seconds]
		#update_de1_state $value
		parse_binary_shot_desc $value arr2
		msg "shot data received [string length $value] bytes: $value  : [array get arr2]"
	} elseif {$command_name == "HeaderWrite"} {
		set ::de1(last_ping) [clock seconds]
		#update_de1_state $value
		parse_binary_shotdescheader $value arr2
		msg "READ shot header success: [string length $value] bytes: $value  : [array get arr2]"
	} elseif {$command_name == "FrameWrite"} {
		set ::de1(last_ping) [clock seconds]
		#update_de1_state $value
		parse_binary_shotframe $value arr2
		msg "shot frame received [string length $value] bytes: $value  : [array get arr2]"
	} elseif {$command_name == "StateInfo"} {
		set ::de1(last_ping) [clock seconds]
		msg "stateinfo received [string length $value] bytes: $value  : \"[convert_string_to_hex $value]\""
		update_de1_state $value

		#if {[info exists ::globals(if_in_sleep_move_to_idle)] == 1} {
		#	unset ::globals(if_in_sleep_move_to_idle)
		#	if {$::de1_num_state($::de1(state)) == "Sleep"} {
				# when making a new connection to the espresso machine, if the machine is currently asleep, then take it out of sleep
				# but only do this check once, right after connection establisment
		#		start_idle
		#	}
		#}
		#update_de1_substate $value
		#msg "Confirmed a00e read from DE1: '[remove_null_terminator $value]'"
		set ::de1(wrote) 0
		run_next_userdata_cmd
	} elseif {$command_name == "ReadFromMMR"} {
		# MMR read
		msg "MMR recv read: '[convert_string_to_hex $value]'"

		parse_binary_mmr_read $value arr
		set mmr_id $arr(Address)
		set mmr_val [ifexists arr(Data0)]
		msg "MMR recv read from $mmr_id ($mmr_val): '[convert_string_to_hex $value]' : [array get arr]"
		if {$mmr_id == "80381C"} {
			msg "Read: GHC is installed: '$mmr_val'"
			set ::settings(ghc_is_installed) $mmr_val

			if {$::settings(ghc_is_installed) == 1 || $::settings(ghc_is_installed) == 2} {
				# if the GHC is present but not active, check back every 10 minutes to see if its status has changed
				# this is only relevant if the machine is in a debug GHC mode, where the DE1 acts as if the GHC 
				# is not there until it is touched. This allows the tablet to start operations.  If (or once) the GHC is 
				# enabled, only the GHC can start operations.
				after 600000 get_ghc_is_installed
			}

		} elseif {$mmr_id == "803808"} {
			set ::de1(fan_threshold) $mmr_val
			set ::settings(fan_threshold) $mmr_val
			msg "Read: Fan threshold: '$mmr_val'"
		} elseif {$mmr_id == "80380C"} {
			msg "Read: tank temperature threshold: '$mmr_val'"
			set ::de1(tank_temperature_threshold) $mmr_val
		} elseif {$mmr_id == "803820"} {
			msg "Read: group head control mode: '$mmr_val'"
			set ::settings(ghc_mode) $mmr_val
		} elseif {$mmr_id == "803828"} {
			msg "Read: steam flow: '$mmr_val'"
			set ::settings(steam_flow) $mmr_val
		} elseif {$mmr_id == "80382C"} {
			msg "Read: steam_highflow_start: '$mmr_val'"
			set ::settings(steam_highflow_start) $mmr_val
		} else {
			msg "Uknown type of direct MMR read on '[convert_string_to_hex $mmr_id]': $value"
		}

	} else {
		msg "Unknown command $command_name : '$value'"
	}
}

proc channel_read_handler {channel} {
	if { [catch {set inString [gets $channel]} ] || ![de1_is_connected]} {
		msg "failure during channel read - handling disconnect"
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

    msg [format "DE1 sent: %s %s" $serial_handle $inHexStr]

	set command_name $::de1_serial_handles_to_command_names($serial_handle)
    de1_event_handler $command_name $inHex
}


proc calibration_received {value} {

    #calibration_ble_received $value
	parse_binary_calibration $value arr2
	#msg "calibration data received [string length $value] bytes: $value  : [array get arr2]"

	set varname ""
	if {[ifexists arr2(CalTarget)] == 0} {
		if {[ifexists arr2(CalCommand)] == 3} {
			set varname	"factory_calibration_flow"
		} else {
			set varname	"calibration_flow"
		}
	} elseif {[ifexists arr2(CalTarget)] == 1} {
		if {[ifexists arr2(CalCommand)] == 3} {
			set varname	"factory_calibration_pressure"
		} else {
			set varname	"calibration_pressure"
		}
	} elseif {[ifexists arr2(CalTarget)] == 2} {
		if {[ifexists arr2(CalCommand)] == 3} {
			set varname	"factory_calibration_temperature"
		} else {
			set varname	"calibration_temperature"
		}
	} 

	if {$varname != ""} {
		# this command receives packets both for notifications of reads and writes, but also the real current value of the calibration setting
		if {[ifexists arr2(WriteKey)] == 0} {
			msg "$varname value received [string length $value] bytes: [convert_string_to_hex $value] $value : [array get arr2]"
			set ::de1($varname) $arr2(MeasuredVal)
		} else {
			msg "$varname NACK received [string length $value] bytes: [convert_string_to_hex $value] $value : [array get arr2] "
		}
	} else {
		msg "unknown calibration data received [string length $value] bytes: $value  : [array get arr2]"
	}

}

proc after_shot_weight_hit_update_final_weight {} {

	if {$::de1(scale_sensor_weight) > $::de1(final_water_weight)} {
		# if the current scale weight is more than the final weight we have on record, then update the final weight
		set ::de1(final_water_weight) $::de1(scale_sensor_weight)
		set ::settings(drink_weight) [round_to_one_digits $::de1(final_water_weight)]
	}

}

# USABILITY TODO(REED) Consider resurrecting this for status on the settings page.
# see also proc append_to_de1_bluetooth_list
#proc scanning_state_text {} {
#	if {$::scanning == 1} {
#		return [translate "Searching"]
#	}
#
#	if {$::currently_connecting_de1_handle != 0} {
#		return [translate "Connecting"]
#	} 
#
#	if {[expr {$::de1(connect_time) + 5}] > [clock seconds]} {
#		return [translate "Connected"]
#	}
#
#	#return [translate "Tap to select"]
#	if {[ifexists ::de1_needs_to_be_selected] == 1 || [ifexists ::scale_needs_to_be_selected] == 1} {
#		return [translate "Tap to select"]
#	}
#
#	return [translate "Search"]
#}

proc data_to_hex_string {data} {
    return [binary encode hex $data]
}

proc de1_comm {action command_name {data 0}} {
	msg "de1_comm sending action $action command $command_name ($::de1_command_names_to_serial_handles($command_name)) data \"$data\""
	if {$::de1(connectivity) == "ble"} {
		return [de1_ble_comm $action $command_name $data]
	} elseif {$::de1(connectivity) == "tcp" || $::de1(connectivity) == "usb"} {
		# TODO(REED) check for writeability and/or catch errors
		set command_handle $::de1_command_names_to_serial_handles($command_name)
		if {$action == "read" || $action == "enable"} {
			set serial_str "<+$command_handle>\n"
			puts -nonewline $::de1(device_handle) $serial_str
		} elseif {$action == "disable"} {
			set serial_str "<-$command_handle>\n"
			puts -nonewline $::de1(device_handle) $serial_str
		} elseif {$action == "write"} {
			set data_str [data_to_hex_string $data]
			set serial_str "<$command_handle>$data_str\n"
			puts -nonewline $::de1(device_handle) $serial_str
		} else {
			msg "Unknown communication action: $action $command_name"
		}
		# we don't want buffering to delay sending our messages, so force flush 
		flush $::de1(device_handle)

		# we don't get an explicit ack, but we're done now
		msg "de1_comm sent: $serial_str"
		set ::de1(wrote) 0		
		return 1
	}
}

