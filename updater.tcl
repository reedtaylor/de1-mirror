
# this file contains the minimum amount of library procedures needed
# for the DE1 software updater to run. 
# the idea is to minimize the liklihood of breaking the updater

package provide de1_updater 1.0

proc determine_if_android {} {

    set ::runtime "default"
    set ::some_droid 0



    catch {
        package require BLT
        namespace import blt::*
        namespace import -force blt::tile::*

        #sdltk android
        set ::runtime "undroid"

        package require ble
        set ::runtime "android"
    }
  
    if {$::runtime == "android" || $::runtime == "undroid"} {
        # turn the background window black as soon as possible
        # and then make it full screen on android/undroid, so as to prepare for the loading of the splash screen
        # and also to remove the displaying of the Tcl/Tk app bar, which looks weird being on Android
        . configure -bg black -bd 0
        wm attributes . -fullscreen 1
        set ::some_droid 1

        # ::android and ::undroid are deprecated -- keeping them 
        # for compatibility with skins and other weird / old stuff
        if {$::runtime == "android"} {
            set ::android 1
            set ::undroid 0
        } else {
            set ::undroid 1
            set ::android 0
        }
    }


}
determine_if_android

proc calc_sha {source} {
    set sha 0
    set tries 0

    while {$sha == 0 && $tries < 10} {
        catch {
            set sha [::sha2::sha256 -hex -filename $source]
        }
        
        # use this to test SHA failure once
        #if {$tries == 0} { set sha 0 }

        if {$sha == 0} {
            # we are trying to solve an occasional "file busy", maybe the OS is doing something in the background
            catch {
                msg "Pausing and then retrying to calculate SHA for $source"
            }
            after 1000
        }
        incr tries
    }

    if {$sha == 0} {
        catch {
            msg "Unable to calculate SHA for $source"
        }
    }

    return $sha
}


proc ifexists {fieldname2 {defvalue {}} } {
    upvar $fieldname2 fieldname
    
    if {[info exists fieldname] == 1} {
        return [subst "\$fieldname"]
    } else {
        if {$defvalue != ""} {
            set fieldname $defvalue
            return $defvalue
        } else {
            return ""
        }
    }
    #return $defvalue
}


proc fast_write_open {fn parms} {
    set success 0
    set f 0
    set errcode [catch {
        set f [open $fn $parms]
        fconfigure $f -blocking 0
        fconfigure $f -buffersize 1000000
        set success 1
    }]

    if {$errcode != 0} {
        catch {
            msg "fast_write_open $::errorInfo"
        }
    }

    return $f
    #return ""
}

proc write_file {filename data} {
    set success 0
    set errcode [catch {
        set fn [fast_write_open $filename w]
        puts $fn $data 
        close $fn
        set success 1
    }]

    if {$errcode != 0} {
        catch {
            msg "write_file '$filename' $::errorInfo"
        }
    }

    return $success
}


proc decent_http_get {url {timeout 30000}} {

    set body {}
    set token {}    
    #puts "url: $url"
    #catch {
        ::http::config -useragent "mer454"
        set token [::http::geturl $url -binary 1 -timeout $timeout]
        set body [::http::data $token]

        set cnt 0
        while {[string length $body] == 0} {
            sleep 5000
            ::http::cleanup $token
            set token [::http::geturl $url -binary 1 -timeout $timeout]
            set body [::http::data $token]
        }
        #puts "body: $body"
        
        if {[::http::error $token] != ""} {
            debug_puts "http_get error: [::http::error $token]"
        }
        if {$token != ""} {
            ::http::cleanup $token
        }
    #}z
    
    return $body
}

proc decent_http_get_to_file {url fn {timeout 30000}} {

    set body {}
    set token {}    

    set out [open $fn w]
    fconfigure $out -blocking 1 -translation binary


    ::http::config -useragent "mer454"
    #set token [::http::geturl $url -binary 1 -timeout $timeout]
    set token [::http::geturl $url -channel $out  -blocksize 4096]
    close $out

    #set body [::http::data $token]

    if {[::http::error $token] != ""} {
        debug_puts "http_get error: [::http::error $token]"
    }
    if {$token != ""} {
        ::http::cleanup $token
    }
    
    return $body
}


proc read_file {filename} {
    set data ""
    set errcode [catch {
        set fn [open $filename]
            fconfigure $fn -translation binary

        set data [read $fn]
        close $fn
    }]

    if {$errcode != 0} {
        puts "read_file $::errorInfo"
        catch {
            msg "read_file $::errorInfo"
        }
    }
    return $data
}

proc homedir {} {
    global home
    if {[info exists home] != 1} {
        set home [file normalize [file dirname [info script]]]
        msg "home = $home"
    }
    return $home
}


proc de1plus {} {
    #puts "x: [package present de1plus 1.0]"
    set x 0
    catch {
        catch {
            if {[package present de1plus 1.0] >= 1} {
            set x 1
            }
        }
    }
    return $x

}



proc pause {time} {
    global pause_end
    after $time set pause_end 1
    vwait pause_end
    unset -nocomplain pause_end
}



proc log_to_debug_file {text} {
    if {[ifexists ::settings(logfile)] != ""} {
        if {[ifexists ::logfile_handle] == "0"} {
            # do nothing, no logging is possible (such as OSX readonly file system)
            return
        }

        if {[ifexists ::logfile_handle] == ""} {

            set ::logfile_handle "0"
            catch {
                set ::logfile_handle [open "[homedir]/$::settings(logfile)" w]
                fconfigure $::logfile_handle -blocking 0 -buffering line
                #fconfigure $::logfile_handle 
                #fconfigure $::logfile_handle -buffersize 10240
                #fconfigure $::logfile_handle -buffersize 0
            }
        } 

        puts $::logfile_handle "$::debugcnt. ([clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S" ]) $text"

        # temporarily do 
        #close_log_file
    }
}


proc verify_decent_tls_certificate {} {
    
    # disabled for now until release, but does currently work
    return 1

    package require tls
    set channel [tls::socket decentespresso.com 443]
    tls::handshake $channel

    set status [tls::status $channel]
    close $channel
    
    array set status_array $status
    set sha1 [ifexists status_array(sha1_hash)]
    if {$sha1 == "CBA22B05D7D874275105AB3284E5F2CBE970603E"} {
        return 1
    }

    # if the sha_1 hash on the certificate doesn't match what we expect, return the entire array of what we received from the https connection, optionally to display it to the user
    return $status
}

proc close_log_file {} {
    if {[ifexists ::logfile_handle] != ""} {
        catch {
            close $::logfile_handle
            undef -nocomplain ::logfile_handle
        }
    }
}

# every day, check to see if an app update is available
proc scheduled_app_update_check {} {
    check_timestamp_for_app_update_available
    after 8640000 scheduled_app_update_check 
}

proc check_timestamp_for_app_update_available { {check_only 0} } {

    set host "http://decentespresso.com"
    set progname "de1plus"
    set url_timestamp "$host/download/sync/$progname/timestamp.txt"    

    set remote_timestamp {}

    set ::app_update_available 0
    

    catch {
        msg "Fetching remote update timestamp: '$url_timestamp'"
    }

    catch {
        set remote_timestamp [string trim [decent_http_get $url_timestamp]]
    }
    #puts "timestamp: '$remote_timestamp'"

    set local_timestamp [string trim [read_file "[homedir]/timestamp.txt"]]
    if {$remote_timestamp == ""} {
        puts "unable to fetch remote timestamp"
        log_to_debug_file "unable to fetch remote timestamp"

        if {$check_only != 1} {
            set ::de1(app_update_button_label) [translate "Update"];             
        }

        return -1
    } elseif {$local_timestamp == $remote_timestamp} {

        if {$check_only != 1} {
            set ::de1(app_update_button_label) [translate "Up to date"];             
        }

        puts "Local timestamp is the same as remote timestamp, so no need to update"
        log_to_debug_file "Local timestamp is the same as remote timestamp, so no need to update"
        return 0
        
        # we can return at this point, if we're very confident that the sync is correct
        # john 4/18/18 we want to check all files anyway, to fill in any missing local files, so we are going to ignore the time stamps being equal
        #set ::de1(app_update_button_label) [translate "Up to date"]; 
        #set ::app_updating 0
        #return
    }

    catch {
        msg "app update available"
    }

    set ::app_update_available 1

    if {$check_only != 1} {
        set ::de1(app_update_button_label) [translate "Update available"];     
    }
    # time stamps don't match, so update is useful
    return $remote_timestamp


}

proc start_app_update {} {

    if {[ifexists ::app_updating] == 1} {
        catch {
            msg "App is already updating, not going to run two processes"
        }
    }

    set ::app_updating 1

    if {$::runtime == "android"} {
        if {[borg networkinfo] == "none"} {
            set ::de1(app_update_button_label) [translate "No Wifi network"]; 

            catch {
                .hello configure -text $::de1(app_update_button_label)
            }

            
            set ::app_updating 0
            return $::de1(app_update_button_label)
        }
    }

    set cert_check [verify_decent_tls_certificate]
    if {$cert_check != 1} {
        puts "https certification is not what we expect, update failed"
        log_to_debug_file "https certification is not what we expect, update failed"
        foreach {k v} $cert_check {
            puts "$k : '$v'"
            log_to_debug_file "$k : '$v'"
        }
        set ::de1(app_update_button_label) [translate "Internet encryption problem"]; 
        set ::app_updating 0
        return $::de1(app_update_button_label)
    }

    set host "https://decentespresso.com"
    set host2 "https://decentespresso.com"
    #set host "http://10.0.1.200:8000"

    set has_tls 0
    catch {
        package package present tls
        set has_tls 1
    }    


    if {$has_tls == 1} {
        # undroid doesn't yet support https
        set host "http://decentespresso.com"
    }

    set progname "de1"
    if {[de1plus] == 1} {
        set progname "de1plus"
    }

    
    set remote_timestamp [check_timestamp_for_app_update_available 1]


    ##############################################################################################################
    # get manifest both as raw TXT and as gzip compressed, to detect tampering 
    #set url_manifest "$host/download/sync/$progname/manifest.txt"
    set url_manifest "$host/download/sync/$progname/manifest.tdb"

    catch {
        msg "Fetching manifest: $url_manifest"
    }

    set remote_manifest {}
    catch {
        set remote_manifest [string trim [decent_http_get $url_manifest]]

    }

    set remote_manifest_length 0
    set remote_manifest_parts_length -1
    catch {
        set remote_manifest_length [llength $remote_manifest]
        set remote_manifest_parts_length [expr {$remote_manifest_length % 4}]
    }
    catch {
        msg "Length of remote manifest: $remote_manifest_length % $remote_manifest_parts_length"
    }

    set url_manifest_gz "$host2/download/sync/$progname/manifest.gz"
    set remote_manifest_gz {}
    catch {
        set remote_manifest_gz [decent_http_get $url_manifest_gz]
        set remote_manifest_gunzip [zlib gunzip $remote_manifest_gz]
    }
    set remote_manifest_gunzip_length 0
    set remote_manifest_gunzip_parts_length -1
    catch {
        set remote_manifest_gunzip_length [llength $remote_manifest_gunzip]
        set remote_manifest_gunzip_parts_length [expr {$remote_manifest_gunzip_length % 4}]
    }

    catch {
        msg "Length of gunzip remote manifest: $remote_manifest_gunzip_length % $remote_manifest_gunzip_parts_length"
    }

    # test the remote manifest file to see that it is unmodiied and uncorrupted
    set errcode [catch {
        foreach {filename filesize filemtime filesha} $remote_manifest {}
    }]
    if {$errcode != 0} {
        msg "Corrupt manifest.tdb - using gzipped version instead"
        set remote_manifest_length ""
    }

    # if the text file is corrupted (doesn't have a x4 part structure) but the .gz file is fine, use that
    if {($remote_manifest_length == 0 || $remote_manifest_parts_length != 0) && ($remote_manifest_gunzip_length > 100 && $remote_manifest_gunzip_parts_length == 0)} {
        catch {
            msg "Remote plain text manifest.txt is corrupted, using gzipped version"
        }
        set remote_manifest $remote_manifest_gunzip
    }
    ##############################################################################################################


    set local_manifest [string trim [read_file "[homedir]/manifest.txt"]]

    catch {
        msg "Local manifest has [string length $local_manifest] bytes"
    }

    # load the local manifest into memory
    foreach {filename filesize filemtime filesha} $local_manifest {
        set filesize 0
        catch {
            set filesize [file size "[homedir]/$filename"]
        }

        if {[file exists "[homedir]/$filename"] != 1} {
            # force retrieval of any locally missing file by setting its SHA to zero
            catch {
                msg "Missing: $filename"
            }

            log_to_debug_file "Missing: $filename"
            set filesha 0
        }
        set lmanifest($filename) [list filesize $filesize filemtime $filemtime filesha $filesha]
    }

    # compare the local vs remote manifest
    foreach {filename filesize filemtime filesha} $remote_manifest {
        unset -nocomplain data
        array set data [ifexists lmanifest($filename)]
        #if {[ifexists data(filesha)] != $filesha || [ifexists data(filesize)] != $filesize} 
        if {[info exists data(filesha)] != 1} {
            set tofetch($filename) [list filesize $filesize filemtime $filemtime filesha $filesha]
            catch {
                msg "Local file is missing in local manifest: $filename"
            }
            log_to_debug_file "Local file is missing in local manifest: $filename"
        } elseif {$data(filesha) != $filesha} {
            # if the SHA doesn't match then we'll want to fetch this file
            # john 4/18/18 note that we no longer use FILESIZE to compare files, because it can vary between file systems, even if the contents are identical
            set tofetch($filename) [list filesize $filesize filemtime $filemtime filesha $filesha]
            puts "SHA256 mismatch local:'[ifexists data(filesha)]' != remote:'$filesha' : will fetch: $filename or filesize [ifexists data(filesize)] != $filesize"
            log_to_debug_file "SHA256 mismatch local:'[ifexists data(filesha)]' != remote:'$filesha' : will fetch: $filename or filesize [ifexists data(filesize)] != $filesize"
        } else {
        }
    }

    set tmpdir "[homedir]/tmp"
    catch {
        file delete -force $tmpdir
    }
    catch {
        file mkdir $tmpdir
    }


    set cnt 0
    foreach {k v} [array get tofetch] {

        set perc [expr {100.0 * ($cnt / [array size tofetch])}]
        incr cnt

        set ::de1(app_update_button_label) "$cnt/[array size tofetch]"; 
        catch {
            .hello configure -text "$cnt/[array size tofetch]"
        }

        catch { update_onscreen_variables }
        update

        unset -nocomplain arr
        array set arr $v
        set fn "$tmpdir/$arr(filesha)"
        set url "$host/download/sync/$progname/[percent20encode $k]"
        
        catch {
            decent_http_get_to_file $url $fn
        }

        # call 'update' to keep the gui responsive
        update

        set newsha [calc_sha $fn]
        if {$arr(filesha) != $newsha} {
            puts "Failed to accurately download $k"
            log_to_debug_file "Failed to accurately download $k"
            set ::app_updating 0
            return -1
        }

        update

        puts "Successfully fetched $k -> $fn ($url)"
        log_to_debug_file "Successfully fetched $k -> $fn ($url)"
        #break
    }

    #set ::de1(app_update_button_label) [translate WAIT]
    catch { update_onscreen_variables }
    update

    # after successfully fetching all files via https, copy them into place
    set success 1
    set files_moved 0
    set graphics_were_updated 0
    set files_to_delete {}
    
    foreach {k v} [array get tofetch] {
        unset -nocomplain arr
        array set arr $v
        set fn "$tmpdir/$arr(filesha)"
        set dest "[homedir]/$k"

        if {[file exists $fn] == 1} {
            set dirname [file dirname $dest]
            if {[file exists $dirname] != 1} {
                puts "Making non-existing directory: '$dirname'"
                log_to_debug_file "Making non-existing directory: '$dirname'"
                file mkdir -force $dirname
            }
            puts "Moving $fn -> $dest"
            log_to_debug_file "Moving $fn -> $dest"
            #file rename -force $fn $dest

            # john 2-16-19 we copy instead of rename in case two files have an identical SHA (ie, identical content)
            file copy -force $fn $dest
            lappend files_to_delete $fn
            incr files_moved 

            # keep track of whether any graphics were updated
            set extension [file extension $dest]
            if {$extension == ".png" || $extension == ".jpg"} {
                set graphics_were_updated 1
            }

        } else {
            puts "WARNING: unable to find file $fn to copy to destination: '$dest' - a partial app update has occured."
            log_to_debug_file "WARNING: unable to find file $fn to copy to destination: '$dest' - a partial app update has occured."
            set success 0
        }
    }

    foreach file_to_delete $files_to_delete {
        catch {
            file delete $file_to_delete
        }
    }

    if {$success == 1} {

        # if everything went well, go ahead and update the local timestamp and manifest to be the same as the remote one
        if {$graphics_were_updated == 1} {

            if {[ifexists ::screen_size_width] != 1} {
                # if we're not running this proc inside the gui, then we don't have resolution info
                set ::screen_size_width 1280
                set ::screen_size_height 800
            }

            set this_resolution "${::screen_size_width}x${::screen_size_height}"
            # if any graphics were updated, and this app is running at a nonstand resolution, then delete all cached local-resolution files, to force a remake of them all. 
            # this is inefficient, as it would be better to only delete the related files, and that would be a good improvement in a future version
            if {$this_resolution != "2560x1600" && $this_resolution != "1280x800"} {
                set saver_directory "[homedir]/saver/${::screen_size_width}x${::screen_size_height}"
                set splash_directory [glob -nocomplain "[splash_directory]/${::screen_size_width}x${::screen_size_height}"]
                puts "deleting $saver_directory"
                puts "deleting $splash_directory"
                log_to_debug_file "deleting $saver_directory"
                log_to_debug_file "deleting $splash_directory"

                catch {
                    file delete -force $saver_directory
                }
                catch {
                    file delete -force $splash_directory
                }

                set skindirs [lsort -dictionary [glob -nocomplain -tails -directory "[homedir]/skins/" *]]
                foreach d $skindirs {
                    set thisskindir "[homedir]/skins/$d/$this_resolution/"
                    puts "testing '$d' - '$thisskindir'"
                    log_to_debug_file "testing '$d' - '$thisskindir'"
                    if {[file exists $thisskindir] == 1} {
                        # skins are converted to this apps resolution only as needed, so only delete the existing dirs
                        catch {
                            file delete -force $thisskindir
                        }
                        puts "deleting $thisskindir"
                        log_to_debug_file "deleting $thisskindir"
                    }
                }
            }

        }


        # ok, all done.
        write_file "[homedir]/timestamp.txt" $remote_timestamp
        write_file "[homedir]/manifest.txt" $remote_manifest
        puts "successful update"
        log_to_debug_file "successful update"
        unset -nocomplain ::de1(firmware_crc) 

        if {$files_moved > 0} {
            set ::de1(app_update_button_label) "[translate "Updated"] $files_moved"; 
            set ::app_has_updated 1
        } else {
            set ::de1(app_update_button_label) [translate "Up to date"]; 
        }


        catch {
            .hello configure -text $::de1(app_update_button_label)
        }

        catch {
            .hello configure -command { exit }
        }

        set ::app_updating 0
        return 1
    } else {
        set ::de1(app_update_button_label) [translate "Update failed"]; 
        puts "failed update"
        log_to_debug_file "failed update"
        set ::app_updating 0


        catch {
            .hello configure -text $::de1(app_update_button_label)
            .hello configure -command { exit }
        }


        return 0
    }
}


proc read_binary_file {filename} {
    set fn ""
    set err {}
    set error [catch {set fn [open $filename]} err]
    if {$fn == ""} {
        #puts "error opening binary file: $filename / '$err' / '$error' / $fn"
        return ""
    }
    if {$fn == ""} {
        return ""
    }
    
    fconfigure $fn -translation binary
    set data [read $fn]
    close $fn
    return $data
}



proc save_array_to_file {arrname fn} {
    upvar $arrname item
    set toexport2 {}
    foreach k [lsort -dictionary [array names item]] {
        set v $item($k)
        append toexport2 [subst {[list $k] [list $v]\n}]
    }
    write_file $fn $toexport2
}

proc settings_filename {} {
    set fn "[homedir]/settings.tdb"
    #puts "sc: '$fn'"
    return $fn
}



proc reset_skin {} {
    set s "settings.tdb"
        set s [settings_filename]
    catch {
    }

    array set ::settings [encoding convertfrom utf-8 [read_binary_file $s]]
    set ::settings(skin) "Insight"
    save_array_to_file ::settings $s
}


proc percent20encode {in} {
    set out $in
    regsub -all " " $out "%20" out
    #regsub -all "&" $out "%26" out
    regsub -all {"} $out "%22" out
    regsub -all {#} $out "%23" out
    regsub -all {'} $out "%27" out
    regsub -all {!} $out "%21" out
    regsub -all {:} $out "%3A" out
    regsub -all {;} $out "%3B" out
    regsub -all {#} $out "%23" out
    #regsub -all {=} $out "%3D" out
    regsub -all {:} $out "%3A" out
    regsub -all "\\?" $out "%3F" out
    regsub -all {@} $out "%40" out
    regsub -all {>} $out "%3E" out
    regsub -all {/} $out "%2F" out
    regsub -all {<} $out "%3C" out
    regsub -all {\$} $out "%24" out
    regsub -all {`} $out "%60" out
    regsub -all {\[} $out "%5B" out
    regsub -all {\]} $out "%5D" out
    regsub -all {~} $out "%7E" out
    regsub -all {\^} $out "%5E" out
    regsub -all {\|} $out "%7C" out
    regsub -all "," $out "%2C" out
    regsub -all "\\)" $out "%29" out
    regsub -all "\\(" $out "%28" out
    
    #puts "urlenc: '$in' / '$out'"
    return $out
}
