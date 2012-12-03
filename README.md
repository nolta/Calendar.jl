Calendar.jl: Calendar time for Julia
====================================

Installation
------------

    julia> Pkg.update()
    julia> Pkg.add("Calendar")

Usage
-----

    julia> require("Calendar")
    julia> using Calendar

### Create times

    julia> t = now()
    "Dec 3, 2012 12:01:38 AM EST"

    julia> t = ymd_hms(2013, 5, 2, 13, 45, 7)
    "May 2, 2013 1:45:07 PM EDT"

### Extract fields

    julia> t
    "May 2, 2013 1:45:07 PM EDT"

    julia> month(t)
    5

    julia> week(t)
    18

    julia> am(t)
    false

Available fields:

    year(d)
    month(d)      # numbered 1-12
    week(d)       # week of year
    day(d)        # day of month
    dayofyear(d)
    hour24(d)     # 24hr clock
    hour12(d)     # 12hr clock
    minute(d)
    second(d)
    am(d)         # is time before noon?
    pm(d)         # is time after noon?
 
### Durations

    julia> t
    "May 2, 2013 1:45:07 PM EDT"

    julia> t + months(2)
    "Jul 2, 2013 1:45:07 PM EDT"

    julia> t + days(60)
    "Jul 1, 2013 1:45:07 PM EDT"

    julia> d = years(1) + minutes(44)
    1 year, 44 minutes

    julia> t + d
    "May 2, 2014 2:29:07 PM EDT"

Available durations:

     years
     months
     weeks
     days
     hours
     minutes
     seconds

### Timezones

    julia> est = ymd_hms(2013, 3, 10, 1, 59, 59)
    "Mar 10, 2013 1:59:59 AM EST"

    julia> pst = with_tz(est, "PST")  # change timezone
    "Mar 9, 2013 10:59:59 PM PST"

    julia> est + seconds(1)           # note DST change
    "Mar 10, 2013 3:00:00 AM EDT"

    julia> pst + seconds(1)
    "Mar 9, 2013 11:00:00 PM PST"

