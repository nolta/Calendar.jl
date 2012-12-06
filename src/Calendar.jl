require("ICU")

module Calendar

import ICU

export CalendarTime,
       format,
       now,
       parse,
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
       FixedCalendarDuration,
       years,
       months,
       weeks,
       days,
       hours,
       minutes,
       seconds,
       hms,
       hm,

       # ranges
       CalendarTimeRange

import Base.show, Base.(+), Base.(-), Base.(<), Base.(==), Base.length,
       Base.colon, Base.ref, Base.start, Base.next, Base.done, Base.(*),
       Base.size, Base.step

type CalendarTime
    millis::Float64
    tz
end

# needed by DataFrames
length(::CalendarTime) = 1

# default timezone
_tz = ICU.getDefaultTimeZone()

const _cal_cache = Dict()
function _get_cal(tz)
    if !has(_cal_cache, tz)
        _cal_cache[tz] = ICU.ICUCalendar(tz)
    end
    _cal_cache[tz]
end

const _format_cache = Dict()
function _get_format(tz)
    if !has(_format_cache, tz)
        _format_cache[tz] = ICU.ICUDateFormat(ICU.UDAT_LONG, ICU.UDAT_MEDIUM, tz)
    end
    _format_cache[tz]
end
function _get_format(pattern, tz)
    k = pattern,tz
    if !has(_format_cache, k)
        _format_cache[k] = ICU.ICUDateFormat(pattern, tz)
    end
    _format_cache[k]
end

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

for op in [:<, :(==)]
    @eval ($op)(t1::CalendarTime, t2::CalendarTime) = ($op)(t1.millis, t2.millis)
end

function format(pattern::String, t::CalendarTime)
    ICU.format(_get_format(pattern,t.tz), t.millis)
end

function parse(pattern::String, s::String, tz::String)
    try
        millis = ICU.parse(_get_format(pattern,tz), s)
        return CalendarTime(millis, tz)
    catch
        error("failed to parse '", s, "' with '", pattern, "'")
    end
end
parse(pattern, s) = parse(pattern, s, _tz)

function show(io::IO, t::CalendarTime)
    s = ICU.format(_get_format(t.tz), t.millis)
    print(io, s)
end

abstract AbstractCalendarDuration

type CalendarDuration <: AbstractCalendarDuration
    years::Int
    months::Int
    weeks::Int
    millis::Float64
end

type FixedCalendarDuration <: AbstractCalendarDuration
    millis::Float64
end

CalendarDuration() = CalendarDuration(0,0,0,0.)

for f in [:years,:months,:weeks]
    @eval $f(x::Integer) = (d = CalendarDuration(); d.($(expr(:quote,f))) = x; d)
end
for (f,a) in [(:days,86400e3),(:hours,3600e3),(:minutes,60e3),(:seconds,1e3)]
    @eval ($f)(x::Real) = FixedCalendarDuration(x*($a))
end
hms(h::Real, m::Real, s::Real) = FixedCalendarDuration(1e3(60(60h + m) + s))
hm(h::Real, m::Real) = hms(h, m, 0)

function print_millis(io::IO, millis::Float64, first::Bool)
    negative = millis < 0
    millis = abs(millis)
    for (x,tag) in [(86400e3," day"),(3600e3," hour"),
                    (60e3," minute"),(1e3," second")]
        if millis >= x
            n = ifloor(millis/x)
            millis -= n*x

            if first
                if negative write(io,'-') end
                first = false
            else
                write(io, negative ? " - " : " + ")
            end
            print(io, n, tag)
            if n > 1 write(io,'s') end
        end
    end
    if millis > 0
        if first
            if negative write(io,'-') end
            first = false
        else
            write(io, negative ? " - " : " + ")
        end
        n = ifloor(millis)
        print(io, n, " ms")
    end
end

function show(io::IO, d::CalendarDuration)
    first = true
    for f in [:years,:months,:weeks]
        n = d.(f)
        if n != 0
            negative = n < 0
            if first
                if negative write(io,'-') end
                first = false
            else
                write(io, negative ? " - " : " + ")
            end
            print(io, abs(n))
            write(io, ' ')
            sf = string(f)
            write(io, abs(n) > 1 ? sf : sf[1:end-1])
        end
    end
    if d.millis != 0.
        print_millis(io, d.millis, first)
    end
end

function show(io::IO, d::FixedCalendarDuration)
    print_millis(io, d.millis, true)
end

for op in [:+, :-]
    @eval begin
        ($op)(d1::CalendarDuration, d2::CalendarDuration) =
            CalendarDuration($op(d1.years, d2.years),
                             $op(d1.months, d2.months),
                             $op(d1.weeks, d2.weeks),
                             $op(d1.millis, d2.millis))

        ($op)(d::CalendarDuration, f::FixedCalendarDuration) =
            CalendarDuration($op(d.years),
                             $op(d.months),
                             $op(d.weeks),
                             $op(d.millis, f.millis))

        ($op)(f::FixedCalendarDuration, d::CalendarDuration) = $op(d, f)

        ($op)(d1::FixedCalendarDuration, d2::FixedCalendarDuration) =
            FixedCalendarDuration($op(d1.millis, d2.millis))

        function ($op)(t::CalendarTime, d::CalendarDuration)
            cal = _get_cal(t.tz)
            ICU.setMillis(cal, $op(t.millis, d.millis))
            for (f,v) in [(:years,ICU.UCAL_YEAR),
                          (:months,ICU.UCAL_MONTH),
                          (:weeks,ICU.UCAL_WEEK_OF_YEAR)]
                n = d.(f)
                if n != 0
                    ICU.add(cal, v, $op(n))
                end
            end
            CalendarTime(ICU.getMillis(cal), t.tz)
        end

        ($op)(t::CalendarTime, d::FixedCalendarDuration) =
            CalendarTime(($op)(t.millis, d.millis), t.tz)

        ($op)(d::AbstractCalendarDuration, t::CalendarTime) = ($op)(t, d)
    end
end

(*)(d::CalendarDuration, i::Integer) =
    CalendarDuration(d.years*i, d.months*i, d.weeks*i, d.millis*i)
(*)(d::FixedCalendarDuration, x::Real) = FixedCalendarDuration(d.millis*x)
(*)(x, d::AbstractCalendarDuration) = d*x

(-)(t1::CalendarTime, t2::CalendarTime) = FixedCalendarDuration(t1.millis - t2.millis)

function (-)(d::CalendarDuration)
    d2 = CalendarDuration()
    for f in [:years,:months,:weeks,:millis]
        d2.(f) = -d.(f)
    end
    d2
end
(-)(d::FixedCalendarDuration) = FixedCalendarDuration(-d.millis)

for op in [:<, :(==)]
    @eval begin
        ($op)(d1::FixedCalendarDuration, d2::FixedCalendarDuration) =
            ($op)(d1.millis, d2.millis)
    end
end

type CalendarTimeRange{T<:AbstractCalendarDuration} #<: Ranges{CalendarTime}
    start::CalendarTime
    step::T
    len::Int
end

function show{T}(io::IO, r::CalendarTimeRange{T})
    print(io, r.start, ':', r.step, ':', r.start + (r.len-1)*r.step)
end

function colon(t1::CalendarTime, d::FixedCalendarDuration, t2::CalendarTime)
    n = ifloor((t2.millis - t1.millis)/d.millis) + 1
    CalendarTimeRange(t1, d, n)
end
colon(t1::CalendarTime, t2::CalendarTime) = colon(t1, seconds(1), t2)

function ref(r::CalendarTimeRange, i::Integer)
    if !(1 <= i <= r.len); error(BoundsError); end
    r.start + (i-1)*r.step
end

size(r::CalendarTimeRange) = (r.len,)
length(r::CalendarTimeRange) = r.len
step(r::CalendarTimeRange) = r.step
start(r::CalendarTimeRange) = 0
next{T}(r::CalendarTimeRange{T}, i) = (r.start + i*r.step, i+1)
done(r::CalendarTimeRange, i) = length(r) <= i

end # module
