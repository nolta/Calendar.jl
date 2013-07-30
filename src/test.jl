include("Calendar.jl")
using Calendar

@assert isleapyear(2012)
@assert !isleapyear(2011)
@assert !isleapyear(2013)
@assert isleapyear(2020)
@assert !isleapyear(1900)
@assert !isleapyear(1901)
@assert isleapyear(1904)
@assert isleapyear(2000)

# daylight savings time
t = ymd_hms(2013, 3, 10, 1, 59, 59)
t2 = t + seconds(1)
@assert hour(t2) == 3
@assert minute(t2) == 0
@assert second(t2) == 0

@assert years(4) - hours(1) == CalendarDuration(4,0,0,-3600e3)
@assert hours(1) - years(4) == CalendarDuration(-4,0,0,3600e3)
