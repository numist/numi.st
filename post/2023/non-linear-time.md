---
layout: page
title: Time Is Not Linear
showtitle: false
excerpt: Let's stop treating it that way
published_at: Thu Dec 14 22:15:24 PST 2023
---

Knobs are a convenient physical interface for adjusting scalar values. Compared to a 10-key they save space and make value clamping less confusing[^oven]. However, they are significantly more tedious for selecting random values within the supported range.

I wanted to mitigate this problem for my desk lamp's pomodoro timer. Having each step of the encoder wheel increment the time by a fixed interval was obviously wrong, and velocity-based solutions never feel right. Turns out, humans set timers (and generally [experience time](https://www.huffpost.com/entry/time-perception-aging_l_63973dc2e4b0169d76d92560)) on a logarithmic scale. The Timers app on watchOS understands this, with defaults for 1:00, 3:00, 5:00, 10:00, 15:00, 30:00, 1:00:00, and 2:00:00[^watch-defaults]—a huge range represented by a tiny number of values, with a relatively small perceived loss of resolution.

Expecting to reuse the pomodoro firmware for a reminders board someday, I defined a sequence of time intervals spanning from one second to one year[^dates] with two design goals:

0. One turn of the knob (24 steps) changes the time interval's order of magnitude
0. The values are maximally round.

The following Python code generates the sequence I settled on:

``` python
def time_intervals():
    minute, hour, day = 60, 60*60, 24*60*60
    start = 1                          # From 1s
    for step, end in [
        (1, 15),                       # to 15s in steps of 1s
        (5, minute+30),                # to 1m30s in steps of 5s
        (15, 5*minute),                # to 5m in steps of 15s
        (60, 20*minute),               # to 20m in steps of 1m
        (5*minute, hour+30*minute),    # to 1h30m in steps of 5m
        (15*minute, 5*hour),           # to 5h in steps of 15m
        (hour, day),                   # to 24h in steps of 1h
        (4*hour, 3*day),               # to 3d in steps of 4h
        (day, 14*day),                 # to 14d in steps of 1d
        (7*day, 91*day),               # to 91d in steps of 7d
    ]:
        for i in range(start, end, step):
            yield i
        start = i + step
    for i in range(0, 9+1, 1):         # to 1y in steps of "a month"
        yield (91+round(i*30.417))*day
```

Since the human experience of time mixes so many bases, the increments selected for different intervals are round factors of the prevailing unit—seconds and minutes by 1, 5, and 15; hours by 4; days by 1 and 7. The last range is responsible for breaking a year into "months", which are an objectively terrible unit of measure. The average length of a month is 30.417 days, but a monthlong timer should expire the same time of day[^ish] it was set, so when incrementing by month the generator rounds to the nearest day. This results in a mix of increments (either 30 or 31 days) that naturally ends at 365 days.

[^oven]: Also: less prone to errors! Our oven's timers will clock out an hour when set to 1:00, but if you punch in 60? After an hour it starts over and counts down _a second hour_. It will also accept 3:75 (I was trying to set the temperature)—what duration _that_ represents is anyone's guess.
[^watch-defaults]: [Citation](https://discussions.apple.com/thread/7665078). My watch is littered with custom intervals, but they _also_ follow this distribution.
[^dates]: Before someone links me to [Falsehoods programmers believe about time](https://infiniteundo.com/post/25326999628/falsehoods-programmers-believe-about-time), these are time intervals that compromise precision for ergonomics! _Of course_ years aren't 31,536,000 seconds long, but if you're setting a timer for "a year" it's _close enough_. Days aren't 86,400 seconds long either, but good luck convincing your kids, pets, or plants otherwise!
[^ish]: _ish_. See previous footnote.
