require("ICU")

module Calendar

import ICU

export CalendarTime,
       now,
       ymd,
       ymd_hms,

       # fields
       year,
       month,
       week,
       dayofyear,
       day,
       hour,
       hour12,
       minute,
       second,
       am, pm,
       tz,

       # mutate fields
       year!,
       month!,
       week!,
       dayofyear!,
       day!,
       hour!,
       hour12!,
       minute!,
       second!,
       tz!,

       # durations
       CalendarDuration,
       years,
       months,
       weeks,
       days,
       hours,
       minutes,
       seconds,
       hms,
       hm

import Base.show, Base.(+), Base.(-), Base.(<), Base.(==)
export show, (+), (-), (<), (==)

type CalendarTime
    millis::Float64
    tz
end

# default timezone
_tz = ICU.getDefaultTimeZone()

# timezone cache
_tzs = Dict()

function _get_tz(tz)
    if !has(_tzs, tz)
        _tzs[tz] = ICU.ICUCalendar(tz), ICU.ICUDateFormat(tz)
    end
    return _tzs[tz]
end
_get_cal(tz) = _get_tz(tz)[1]
_get_format(tz) = _get_tz(tz)[2]

now(tz) = CalendarTime(ICU.getNow(), tz)
now() = now(_tz)

function ymd_hms(y, mo, d, h, mi, s, tz)
    cal = _get_cal(tz)
    ICU.clear(cal)
    ICU.setDateTime(cal, y, mo, d, h, mi, s)
    CalendarTime(ICU.getMillis(cal), tz)
end
ymd_hms(y, mo, d, h, mi, s) = ymd_hms(y, mo, d, h, mi, s, _tz)

function ymd(y, m, d, tz)
    cal = _get_cal(tz)
    ICU.clear(cal)
    ICU.setDate(cal, y, m, d)
    CalendarTime(ICU.getMillis(cal), tz)
end
ymd(y, m, d) = ymd(y, m, d, _tz)

tz(t::CalendarTime) = t.tz
tz(t::CalendarTime, tz) = CalendarTime(t.millis, tz)
tz!(t::CalendarTime, tz) = (t.tz = tz; t)

for (f,k,o) in [(:year,ICU.UCAL_YEAR,0),
                (:month,ICU.UCAL_MONTH,1),
                (:week,ICU.UCAL_WEEK_OF_YEAR,0),
                (:dayofyear,ICU.UCAL_DAY_OF_YEAR,0),
                (:day,ICU.UCAL_DATE,0),
                (:hour12,ICU.UCAL_HOUR,0),
                (:hour,ICU.UCAL_HOUR_OF_DAY,0),
                (:minute,ICU.UCAL_MINUTE,0),
                (:second,ICU.UCAL_SECOND,0)]

    @eval begin
        function ($f)(t::CalendarTime)
            cal = _get_cal(t.tz)
            ICU.setMillis(cal, t.millis)
            ICU.get(cal, $k) + $o
        end

        function ($f)(t::CalendarTime, val::Integer)
            cal = _get_cal(t.tz)
            ICU.setMillis(cal, t.millis)
            ICU.set(cal, $k, val - $o)
            CalendarTime(ICU.getMillis(cal), t.tz)
        end

        function $(symbol(string(f,'!')))(t::CalendarTime, val::Integer)
            cal = _get_cal(t.tz)
            ICU.setMillis(cal, t.millis)
            ICU.set(cal, $k, val - $o)
            t.millis = ICU.getMillis(cal)
            t
        end
    end
end

function pm(t::CalendarTime)
    cal = _get_cal(t.tz)
    ICU.setMillis(cal, t.millis)
    ICU.get(cal, ICU.UCAL_AM_PM) == 1
end
am(t::CalendarTime) = !pm(t)

(-)(t1::CalendarTime, t2::CalendarTime) = (-)(t1.millis, t2.millis)*1e-3

for op in [:<, :(==)]
    @eval ($op)(t1::CalendarTime, t2::CalendarTime) = ($op)(t1.millis, t2.millis)
end

function show(io::IO, t::CalendarTime)
    s = ICU.format(_get_format(t.tz), t.millis)
    print(io, s)
end

# XXX:probably should replace w/ Dict{Symbol,Int}
type CalendarDuration
    years::Int
    months::Int
    weeks::Int
    days::Int
    hours::Int
    minutes::Int
    seconds::Int
end

CalendarDuration() = CalendarDuration(0,0,0,0,0,0,0)

for f in [:years,:months,:weeks,:days,:hours,:minutes,:seconds]
    @eval $f(x::Integer) = (d = CalendarDuration(); d.($(expr(:quote,f))) = x; d)
end
hms(h::Integer, m::Integer, s::Integer) = CalendarDuration(0,0,0,0,h,m,s)
hm(h::Integer, m::Integer) = CalendarDuration(0,0,0,0,h,m,0)

function show(io::IO, d::CalendarDuration)
    write_comma = false
    for f in [:years,:months,:weeks,:days,:hours,:minutes,:seconds]
        n = d.(f)
        if n != 0
            if write_comma write(io,", ") end
            write_comma = true
            show(io, n)
            write(io, ' ')
            sf = string(f)
            write(io, n > 1 ? sf : sf[1:end-1])
        end
    end
end

for op in [:+, :-]
    @eval begin
        ($op)(d1::CalendarDuration, d2::CalendarDuration) = CalendarDuration(
            $op(d1.years, d2.years),
            $op(d1.months, d2.months),
            $op(d1.weeks, d2.weeks),
            $op(d1.days, d2.days),
            $op(d1.hours, d2.hours),
            $op(d1.minutes, d2.minutes),
            $op(d1.seconds, d2.seconds)
        )

        function ($op)(t::CalendarTime, d::CalendarDuration)
            cal = _get_cal(t.tz)
            ICU.setMillis(cal, t.millis)
            for (f,v) in [(:years,ICU.UCAL_YEAR),
                          (:months,ICU.UCAL_MONTH),
                          (:weeks,ICU.UCAL_WEEK_OF_YEAR),
                          (:days,ICU.UCAL_DATE),
                          (:hours,ICU.UCAL_HOUR),
                          (:minutes,ICU.UCAL_MINUTE),
                          (:seconds,ICU.UCAL_SECOND)]
                n = d.(f)
                if n != 0
                    ICU.add(cal, v, $op(n))
                end
            end
            CalendarTime(ICU.getMillis(cal), t.tz)
        end

        ($op)(d::CalendarDuration, t::CalendarTime) = ($op)(t, d)
    end
end

#function (-)(d::CalendarDuration)
#    for f in [:years,:months,:weeks,:days,:hours,:minutes,:seconds]
#        d.(f) = -d.(f)
#    end
#    d
#end

end # module
