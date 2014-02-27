# copyleft (CC-0) 2013 Melker "meklu" Narikka <meklu@meklu.org>
#
# a fairly manual .halp, you need to populate the thing yourself

bind msg - .halp halp:mhalp
bind pub - .halp halp:halp
bind msg - .help halp:mhalp
bind pub - .help halp:halp

# if you shove curly braces in, escape them
set halptext [subst -nocommands -novariables {
Here's yer halp.
    .halp
        Display this message.
    .btc [ [ <currency> ] [ <amount> ] ]
    	Gets the average Bitcoin price for the last 24 hours.
    .tell <user> <message>
        Leaves a message for a fellow user.
}]

proc halp:mhalp { n m h s } {
	return [halp:halp $n $m $h $n $s]
}

proc halp:halp { n m h c s } {
	global halptext
	foreach line [split $halptext "\n"] {
		if {[string length [string trim $line]] != 0} {
			putquick "PRIVMSG $n :$line"
		}
	}
	return 1
}
