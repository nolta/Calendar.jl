Calendar.jl: Calendar time for Julia
====================================

The design is heavily influenced by Hadley Wickham's lubridate package for R.

Installation
------------

To install the package:

    julia> Pkg.update()
    julia> Pkg.add("Calendar")

Then, to load into your session:

    julia> require("Calendar")
    julia> using Calendar

Creating times
--------------

```jlcon
julia> t = now()
Dec 3, 2012 12:58:52 PM EST

julia> t = ymd_hms(2013, 5, 2, 13, 45, 7)
May 2, 2013 1:45:07 PM EDT

julia> t = ymd_hms(2013, 5, 2, 13, 45, 7, "PST")
May 2, 2013 1:45:07 PM PDT
```

Extracting fields
-----------------

```jlcon
julia> t
May 2, 2013 1:45:07 PM PDT

julia> month(t)
5

julia> week(t)
18

julia> am(t)
false
```

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
 
Durations
---------

```jlcon
julia> t
May 2, 2013 1:45:07 PM PDT

julia> t + months(2)
Jul 2, 2013 1:45:07 PM PDT

julia> t + days(60)
Jul 1, 2013 1:45:07 PM PDT

julia> d = years(1) + minutes(44)
1 year, 44 minutes

julia> t + d
May 2, 2014 2:29:07 PM PDT
```

Available durations: `years, months, weeks, days, hours, minutes, seconds`

Timezones
---------

```jlcon
julia> est = ymd_hms(2013, 3, 10, 1, 59, 59)
Mar 10, 2013 1:59:59 AM EST

julia> pst = with_tz(est, "PST")  # change timezone
Mar 9, 2013 10:59:59 PM PST

julia> est + seconds(1)
Mar 10, 2013 3:00:00 AM EDT

julia> pst + seconds(1)
Mar 9, 2013 11:00:00 PM PST
```

Formatting
----------
