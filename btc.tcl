# copyleft (CC-0) 2013-2014 Melker "meklu" Narikka <meklu@meklu.org>
#
# a bitcoin rate reader thing
# data courtesy of bitcoinaverage.com <3
#
# dependencies: json, http, somewhat optionally tls
#
# usage: .btc [ [ <currency> ] [ <amount> ] ]

package require json
package require http
set protocol http

# comment out the three lines below if you want to use plain http
package require tls
::http::register https 443 ::tls::socket
set protocol https

bind msg - .btc btc:mbtc
bind pub - .btc btc:btc

proc btc:currency { new } {
	set currency [string toupper $new]
	# set the currency
	if { [string length $currency] == 3 } {
		set rangestart [scan A %c]
		set rangeend [scan Z %c]
		foreach char [split $currency ""] {
			set charnum [scan $char %c]
			if { $charnum < $rangestart || $charnum > $rangeend } {
				return -1
			}
		}
		return $currency
	}
	return -1
}

proc btc:amount { new } {
	if { [catch {set amount [expr $new]} err] } {
		return -1
	}
	return $amount
}

proc btc:mbtc { n m h s } {
	return [btc:btc $n $m $h $n $s]
}

proc btc:btc { n m h c s } {
	global protocol
	set currency USD
	set amount 1
	# parse args
	set args [regexp -all -inline {\S+} $s]
	if { [llength $args] > 0 } {
		# one arg
		if { [llength $args] == 1 } {
			# first try amount
			set tmp [btc:amount [lindex $args 0]]
			if { $tmp <= 0 } {
				# something failed, try currency
				set tmp [btc:currency [lindex $args 0]]
				if { $tmp == -1 } {
					putserv "PRIVMSG $c :$n: Check your syntax, silly."
					return
				} else {
					set currency $tmp
				}
			} else {
				set amount $tmp
			}
		# two args
		} elseif { [llength $args] == 2 } {
			# currency is arg 0
			set tmp [btc:currency [lindex $args 0]]
			if { $tmp == -1 } {
				putserv "PRIVMSG $c :$n: Check your syntax, silly."
				return
			} else {
				set currency $tmp
			}
			# amount is arg 1
			set tmp [btc:amount [lindex $args 1]]
			if { $tmp <= 0 } {
				putserv "PRIVMSG $c :$n: Check your syntax, silly."
				return
			} else {
				set amount $tmp
			}
		# random amount of args
		} else {
			putserv "PRIVMSG $c :$n: Check your syntax, silly."
			return
		}
	}
	set api_url $protocol://api.bitcoinaverage.com/ticker/$currency/
	set token [::http::geturl $api_url]
	set httpstatus [split [::http::code $token]]
	if { [lindex $httpstatus 1] != "200" } {
		putserv "PRIVMSG $c :$n: There is no such currency as $currency."
		return 1
	}
	set data [::http::data $token]
	set jsondata [::json::json2dict $data]
	dict get $jsondata 24h_avg
	set rate [dict get $jsondata 24h_avg]
	set msg [format "$amount BTC = %.2f %s" [expr $rate * $amount] $currency]
	putserv "PRIVMSG $c :$n: $msg"
	return 1
}
