require("ICU")

module Calendar

import ICU

export CalendarTime,
       format,
       now,
       today,
       parse_date,
       ymd,
       ymd_hms,

       # tests
       isAM,
       isPM,
       isleapyear,

       # fields
       year,
       month,
       week,
       dayofyear,
       dayofweek,
       day,
       hour,
       hour12,
       minute,
       second,
       tz,
       timezone,

       # deprecated
       am, pm,
       isleap,
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
       CalendarTimeRange, 

       #Constants
       Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, 
       January, February, March, April, May, June, July, August, September, October, November, December

import Base.show, Base.(+), Base.(-), Base.(<), Base.(==), Base.length,
       Base.colon, Base.ref, Base.start, Base.next, Base.done, Base.(*), Base.(.*),
       Base.size, Base.step, Base.vcat, Base.isless, Base.hash, Base.isequal

type CalendarTime
    millis::Float64
    cal::ICU.ICUCalendar
end

# needed by DataFrames
length(::CalendarTime) = 1

# support hashing
hash(ct::CalendarTime) = bitmix(hash(ct.millis),hash(ct.cal))
isequal(a::CalendarTime, b::CalendarTime) = a.millis == b.millis && a.cal == b.cal

# default timezone
_tz = ICU.getDefaultTimeZone()

const _cal_cache = Dict()
const _tz_cache = Dict()
function _get_cal(tz)
    if !haskey(_cal_cache, tz)
        cal = ICU.ICUCalendar(tz)
        _cal_cache[tz] = cal
        _tz_cache[cal] = tz
    end
    _cal_cache[tz]
end

const _format_cache = Dict()
function _get_format(cal)
    tz = _tz_cache[cal]
    if !haskey(_format_cache, tz)
        _format_cache[tz] = ICU.ICUDateFormat(ICU.UDAT_LONG, ICU.UDAT_MEDIUM, tz)
    end
    _format_cache[tz]
end
function _get_format(pattern, cal)
    tz = _tz_cache[cal]
    k = pattern,tz
    if !haskey(_format_cache, k)
        _format_cache[k] = ICU.ICUDateFormat(pattern, tz)
    end
    _format_cache[k]
end

now(tz=_tz) = CalendarTime(ICU.getNow(), _get_cal(tz))

function today()
    n = now()
    ymd(year(n), month(n), day(n))
end

function ymd_hms(y::Integer, mo::Integer, d::Integer, h::Integer, mi::Integer, s::Real, tz=_tz)
    cal = _get_cal(tz)
    ICU.clear(cal)
    is = itrunc(s)
    ms = rem(s,1)*1e3
    ICU.setDateTime(cal, y, mo, d, h, mi, is)
    CalendarTime(ICU.getMillis(cal) + ms, cal)
end

ymd(y::Integer, m::Integer, d::Integer, tz=_tz) = ymd_hms(y, m, d, 0, 0, 0, tz)

tz(t::CalendarTime) = _tz_cache[t.cal]
tz(t::CalendarTime, tz) = CalendarTime(t.millis, _get_cal(tz))
tz!(t::CalendarTime, tz) = (Base.warn_once("tz!(a,b) is deprecated, please use timezone(a,b) instead."; depth=1); t.cal = _get_cal(tz); t)
const timezone = tz

for (f,k,o) in [(:year,ICU.UCAL_YEAR,0),
                (:month,ICU.UCAL_MONTH,1),
                (:week,ICU.UCAL_WEEK_OF_YEAR,0),
                (:dayofyear,ICU.UCAL_DAY_OF_YEAR,0),
                (:dayofweek,ICU.UCAL_DAY_OF_WEEK,0),
                (:day,ICU.UCAL_DATE,0),
                (:hour12,ICU.UCAL_HOUR,0),
                (:hour,ICU.UCAL_HOUR_OF_DAY,0),
                (:minute,ICU.UCAL_MINUTE,0),
                (:second,ICU.UCAL_SECOND,0)]

    @eval begin
        function ($f)(t::CalendarTime)
            ICU.setMillis(t.cal, t.millis)
            ICU.get(t.cal, $k) + $o
        end

        function ($f)(t::CalendarTime, val::Integer)
            ICU.setMillis(t.cal, t.millis)
            ICU.set(t.cal, $k, val - $o)
            CalendarTime(ICU.getMillis(t.cal), t.cal)
        end

        function $(symbol(string(f,'!')))(t::CalendarTime, val::Integer)
            Base.warn_once(string($f,"!(a,b) is deprecated, please use ", $f, "(a,b) instead."); depth=1)
            ICU.setMillis(t.cal, t.millis)
            ICU.set(t.cal, $k, val - $o)
            t.millis = ICU.getMillis(t.cal)
            t
        end
        @vectorize_1arg CalendarTime $f
    end
end

isleapyear(t::CalendarTime) = isleapyear(year(t))
isleapyear(y::Integer) = (((y % 4 == 0) && (y % 100 != 0)) || (y % 400 == 0))
@vectorize_1arg CalendarTime isleapyear
@deprecate isleap isleapyear

function isPM(t::CalendarTime)
    ICU.setMillis(t.cal, t.millis)
    ICU.get(t.cal, ICU.UCAL_AM_PM) == 1
end
isAM(t::CalendarTime) = !isPM(t)
@vectorize_1arg CalendarTime isAM
@vectorize_1arg CalendarTime isPM

@deprecate am isAM
@deprecate pm isPM

for op in [:<, :(==), :isless]
    @eval ($op)(t1::CalendarTime, t2::CalendarTime) = ($op)(t1.millis, t2.millis)
end

function format(pattern::String, t::CalendarTime)
    utf8(ICU.format(_get_format(pattern,t.cal), t.millis))
end
format(t::CalendarTime, pattern::String) = format(pattern, t)

function parse_date(pattern::String, s::String, tz::String)
    try
        cal = _get_cal(tz)
        millis = ICU.parse(_get_format(pattern,cal), s)
        return CalendarTime(millis, cal)
    catch
        error("failed to parse '", s, "' with '", pattern, "'")
    end
end
parse_date(pattern, s) = parse_date(pattern, s, _tz)
parse_date{S<:String}(pattern::String, s::AbstractArray{S}, tz::String) = map(x -> parse_date(pattern, x, tz), s)
parse_date{S<:String}(pattern::String, s::AbstractArray{S}) = map(x -> parse_date(pattern, x, _tz), s)
const parse = parse_date

function show(io::IO, t::CalendarTime)
    s = ICU.format(_get_format(t.cal), t.millis)
    print(io, s)
end

abstract AbstractCalendarDuration

immutable CalendarDuration <: AbstractCalendarDuration
    years::Int
    months::Int
    weeks::Int
    millis::Float64
end

immutable FixedCalendarDuration <: AbstractCalendarDuration
    millis::Float64
end

CalendarDuration() = CalendarDuration(0,0,0,0.)

years(x::Integer)  = CalendarDuration(x, 0, 0, 0.)
months(x::Integer) = CalendarDuration(0, x, 0, 0.)
weeks(x::Integer)  = CalendarDuration(0, 0, x, 0.)
for f in [:years,:months,:weeks]
    @eval @vectorize_1arg Integer $f
end
for (f,a) in [(:days,86400e3),(:hours,3600e3),(:minutes,60e3),(:seconds,1e3)]
    @eval ($f)(x::Real) = FixedCalendarDuration(x*($a))
    @eval @vectorize_1arg Real $f
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
            CalendarDuration(d.years,
                             d.months,
                             d.weeks,
                             $op(d.millis, f.millis))

        ($op)(f::FixedCalendarDuration, d::CalendarDuration) =
            CalendarDuration($op(d.years),
                             $op(d.months),
                             $op(d.weeks),
                             $op(f.millis, d.millis))

        ($op)(d1::FixedCalendarDuration, d2::FixedCalendarDuration) =
            FixedCalendarDuration($op(d1.millis, d2.millis))

        function ($op)(t::CalendarTime, d::CalendarDuration)
            ICU.setMillis(t.cal, $op(t.millis, d.millis))
            for (f,v) in [(:years,ICU.UCAL_YEAR),
                          (:months,ICU.UCAL_MONTH),
                          (:weeks,ICU.UCAL_WEEK_OF_YEAR)]
                n = d.(f)
                if n != 0
                    ICU.add(t.cal, v, $op(n))
                end
            end
            CalendarTime(ICU.getMillis(t.cal), t.cal)
        end

        ($op)(t::CalendarTime, d::FixedCalendarDuration) =
            CalendarTime(($op)(t.millis, d.millis), t.cal)

        ($op)(d::AbstractCalendarDuration, t::CalendarTime) = ($op)(t, d)

        @vectorize_2arg Union(CalendarTime, AbstractCalendarDuration) $op
        # Fix up cases that @vectorize doesn't cover (without this, the result is of type Array{Any}):
        # I can't figure out how to consolidate this.
        ($op)(x::Array{CalendarTime}, y::Array{CalendarDuration}     ) = reshape(CalendarTime[ ($op)(x[i], y[i]) for i=1:length(x) ], promote_shape(size(x),size(y)))
        ($op)(x::Array{CalendarTime}, y::Array{FixedCalendarDuration}) = reshape(CalendarTime[ ($op)(x[i], y[i]) for i=1:length(x) ], promote_shape(size(x),size(y)))
        ($op)(y::Array{CalendarDuration}     , x::Array{CalendarTime}) = reshape(CalendarTime[ ($op)(x[i], y[i]) for i=1:length(x) ], promote_shape(size(x),size(y)))
        ($op)(y::Array{FixedCalendarDuration}, x::Array{CalendarTime}) = reshape(CalendarTime[ ($op)(x[i], y[i]) for i=1:length(x) ], promote_shape(size(x),size(y)))
    end
end

for op in [:*, :.*]
    @eval begin
        ($op)(d::CalendarDuration, i::Integer) = CalendarDuration(d.years*i, d.months*i, d.weeks*i, d.millis*i)
        ($op)(d::FixedCalendarDuration, x::Real) = FixedCalendarDuration(d.millis*x)
        ($op){T<:AbstractCalendarDuration}(d::Array{T}, i::Integer) = 
            reshape([ d[j] * i for j=1:length(d) ], size(d))
        ($op){I<:Integer}(d::AbstractCalendarDuration, i::Array{I}) = 
            reshape([ d * i[j] for j=1:length(i) ], size(i))
        ($op)(x, d::AbstractCalendarDuration) = ($op)(d, x)
    end
end

(-)(t1::CalendarTime, t2::CalendarTime) = FixedCalendarDuration(t1.millis - t2.millis)
@vectorize_2arg CalendarTime (-)

(-)(d::CalendarDuration) = CalendarDuration(-d.years, -d.months, -d.weeks, -d.millis)
(-)(d::FixedCalendarDuration) = FixedCalendarDuration(-d.millis)
@vectorize_1arg AbstractCalendarDuration (-)

for op in [:<, :(==)]
    @eval begin
        ($op)(d1::FixedCalendarDuration, d2::FixedCalendarDuration) =
            ($op)(d1.millis, d2.millis)
    end
end

immutable CalendarTimeRange{T<:AbstractCalendarDuration} <: Ranges{CalendarTime}
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

function colon(t1::CalendarTime, d::CalendarDuration, t2::CalendarTime)
    approx_d = (365.2425*d.years + 30.436875*d.months + 7.*d.weeks)*86400e3 + d.millis
    n = ifloor((t2.millis - t1.millis)/approx_d) + 1
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

function vcat(r::CalendarTimeRange)
    n = length(r)
    a = Array(CalendarTime,n)
    i = 1
    for x in r
        a[i] = x
        i += 1
    end
    return a
end

convert(::Type{Array{CalendarTime,1}}, r::CalendarTimeRange) = vcat(r)

const Sunday = 1
const Monday = 2
const Tuesday = 3
const Wednesday = 4
const Thursday = 5
const Friday = 6
const Saturday = 7

const January = 1
const February = 2
const March = 3
const April = 4
const May = 5
const June = 6
const July = 7
const August = 8
const September = 9
const October = 10
const November = 11
const December = 12

end # module
