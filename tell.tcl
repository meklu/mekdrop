# copyleft (CC-0) 2013-2014 Melker "meklu" Narikka <meklu@meklu.org>
#
# a telling tell tell for eggdrop, meant for sending messages to offline peers
# upon their reappearance
#
# sends a message to a user when they show up the next time around
# (showing up means re-joining the channel or posting a message there)
#
# also supports messaging via /msg, where messages are delivered straight to
# the recipient (activity on any channel will trigger delivery)
#
# usage: .tell <user> <message>

bind msg - .tell tell:mtell
bind pub - .tell tell:tell
bind msg n .tellclear tell:mclear
bind pub n .tellclear tell:clear
bind msg n .tellcount tell:mcount
bind pub n .tellcount tell:count
bind msgm - * tell:mpass
bind pubm - * tell:pass
bind join - * tell:jpass

set telldata {}
array set tellcounts {}

proc tell:mclear { n m h s } {
	tell:clear $n $m $h $n $s
}

proc tell:clear { n m h c s } {
	global telldata
	global tellcounts
	unset telldata
	array unset tellcounts
	set telldata {}
	array set tellcounts {}
	putserv "PRIVMSG $c :$n: Cleared all .tell messages."
}

proc tell:mcount { n m h s } {
	tell:count $n $m $h $n $s
}

proc tell:count { n m h c s } {
	global telldata
	set count [llength $telldata]
	set args [split [string trim $s]]
	set nicks 0
	set mesgs 0
	putquick "PRIVMSG $c :$n: There are $count messages in queue."
	foreach arg $args {
		if { $nicks == 0 && [string equal $arg "list"] } {
			set nicks 1
		} elseif { $mesgs == 0 && [string equal $arg "invade"] } {
			set nicks 1
			set mesgs 1
		}
	}
	# don't list anything if we're not being invasive
	if { $count == 0 || ($nicks == 0 && $mesgs == 0) } {
		return
	}
	foreach item $telldata {
		if { $nicks == 1 } {
			set channel [dict get $item channel]
			set from [dict get $item from]
			set to [dict get $item to]
			putquick "PRIVMSG $c :$n: On: $channel | From: $from | To: $to"
		}
		if { $mesgs == 1 } {
			set mesg [dict get $item mesg]
			putquick "PRIVMSG $c :$n: > $mesg"
		}
	}
}

proc tell:mtell { n m h s } {
	tell:tell $n $m $h "/msg" $s
	return 1
}

proc tell:tell { nick hmask handle channel mesg } {
	tell:savetell $nick $channel $mesg
	return 1
}

proc tell:mpass { n m h s } {
	tell:dotell $n "/msg"
	return 1
}

proc tell:pass { n m h c s } {
	tell:dotell $n $c
	tell:dotell $n "/msg"
	return 1
}

proc tell:jpass { n m h c } {
	tell:dotell $n $c
	tell:dotell $n "/msg"
	return 1
}

proc tell:savetell { fromnick channel mesg } {
	global telldata
	global tellcounts
	global botnick
	# parsing
	set tmp [split [string trimleft $mesg]]
	set tonick [lindex $tmp 0]
	set finmsg [join [lrange $tmp 1 end]]
	if {[string length $tonick] == 0} {
		putserv "PRIVMSG $channel :$fromnick: You need to specify a recipient."
		return
	}
	if {[string length $finmsg] == 0} {
		putserv "PRIVMSG $channel :$fromnick: You need to compose a message."
		return
	}
	# user, ur drunk
	if {[string equal $botnick $tonick]} {
		putserv "PRIVMSG $channel :$fromnick: I'm afraid I can't let you do that, Dave."
		return
	}
	# optimization
	set key "$channel [string tolower $tonick]"
	if {![info exists tellcounts($key)]} { set tellcounts($key) 0 }
	incr tellcounts($key)
	# saving
	set item [dict create channel $channel from $fromnick to $tonick mesg $finmsg]
	lappend telldata $item
	putlog "tell: [llength $telldata] items now in queue"
	putserv "PRIVMSG $channel :$fromnick: OK, got it."
}

proc tell:dotell { tonick channel } {
	global telldata
	global tellcounts
	set killthese {}
	set i -1
	set didstuff 0
	# optimization
	set key "$channel [string tolower $tonick]"
	# bail if the nick has no pending messages
	if {![info exists tellcounts($key)] || [array get tellcounts $key] == 0} {
		return
	}
	# handle /msg
	set sendpart "$channel :$tonick: "
	if { [string equal $channel "/msg"] } {
		set sendpart "$tonick :"
	}
	foreach item $telldata {
		incr i
		if {
			[string equal $channel [dict get $item channel]] &&
			[string equal -nocase $tonick [dict get $item to]]
		} {
			incr tellcounts($key) -1
			set didstuff 1
			set fromnick [dict get $item from]
			set finmsg [dict get $item mesg]
			# put it
			putserv "PRIVMSG $sendpart$fromnick left you this message: '$finmsg'"
			# kill the item later
			lappend killthese $i
		}
	}
	# reverse the kill list so indices are okay
	foreach j [lreverse $killthese] {
		set telldata [lreplace $telldata $j $j]
	}
	if {[array get tellcounts $key] == 0} {
		unset tellcounts($key)
	}
	if {$didstuff == 1} {
		putlog "tell: [llength $telldata] items left in queue"
	}
}
