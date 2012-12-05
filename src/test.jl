require("Calendar")
using Calendar

# daylight savings time
t = ymd_hms(2013, 3, 10, 1, 59, 59)
t2 = t + seconds(1)
@assert hour(t2) == 3
@assert minute(t2) == 0
@assert second(t2) == 0
