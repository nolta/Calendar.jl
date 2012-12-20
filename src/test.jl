require("Calendar")
using Calendar

@assert isleap(2012)
@assert !isleap(2011)
@assert !isleap(2013)
@assert isleap(2020)
@assert !isleap(1900)
@assert !isleap(1901)
@assert isleap(1904)
@assert isleap(2000)

# daylight savings time
t = ymd_hms(2013, 3, 10, 1, 59, 59)
t2 = t + seconds(1)
@assert hour(t2) == 3
@assert minute(t2) == 0
@assert second(t2) == 0

