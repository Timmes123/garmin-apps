import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:glance)
module PlanStore {

    const KEY_PLAN = "plan";

    function getPlan() as Dictionary? {
        var plan = Application.Storage.getValue(KEY_PLAN);
        if (plan instanceof Dictionary) {
            return plan;
        }
        return null;
    }

    function setPlan(plan as Dictionary) as Void {
        Application.Storage.setValue(KEY_PLAN, plan as Dictionary<Application.PropertyKeyType, Application.PropertyValueType>);
    }

    function versionOf(plan as Dictionary) as Number {
        var v = plan["version"];
        if (v instanceof Number) {
            return v;
        }
        return 0;
    }

    // Wochentag nach ISO: 1 = Montag … 7 = Sonntag
    function isoWeekday() as Number {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return (((info.day_of_week as Number) + 5) % 7) + 1;
    }

    function nowMinutes() as Number {
        var clock = System.getClockTime();
        return clock.hour * 60 + clock.min;
    }

    function todaysEntries(plan as Dictionary?) as Array {
        var result = [];
        if (plan == null) {
            return result;
        }
        var schedules = plan["schedules"];
        if (!(schedules instanceof Array)) {
            return result;
        }
        var today = isoWeekday();
        for (var i = 0; i < schedules.size(); i++) {
            var schedule = schedules[i] as Dictionary;
            var days = schedule["days"];
            var entries = schedule["entries"];
            if (days instanceof Array && entries instanceof Array && days.indexOf(today) >= 0) {
                result.addAll(entries);
            }
        }
        return result;
    }

    // Hat die Sauna heute lange geöffnet?
    function isLateDay(plan as Dictionary?) as Boolean {
        if (plan == null) {
            return true;
        }
        var lateDays = plan["lateDays"];
        if (!(lateDays instanceof Array)) {
            return true;
        }
        if (lateDays.indexOf(isoWeekday()) >= 0) {
            return true;
        }
        var ranges = plan["lateRanges"];
        if (ranges instanceof Array) {
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var today = (info.year as Number) * 10000 + (info.month as Number) * 100 + (info.day as Number);
            for (var i = 0; i < ranges.size(); i++) {
                var range = ranges[i] as Array;
                if (today >= (range[0] as Number) && today <= (range[1] as Number)) {
                    return true;
                }
            }
        }
        return false;
    }

    function isLateOnly(entry as Dictionary) as Boolean {
        return entry["l"] == 1;
    }

    // "14:10" -> 850
    function entryMinutes(entry as Dictionary) as Number {
        var t = entry["t"];
        if (!(t instanceof String)) {
            return 0;
        }
        var idx = t.find(":");
        if (idx == null) {
            return 0;
        }
        var h = t.substring(0, idx).toNumber();
        var m = t.substring(idx + 1, t.length()).toNumber();
        if (h == null || m == null) {
            return 0;
        }
        return h * 60 + m;
    }

    // Index des nächsten Aufgusses, der heute noch stattfindet, sonst -1
    function nextIndex(entries as Array, lateDay as Boolean) as Number {
        var now = nowMinutes();
        for (var i = 0; i < entries.size(); i++) {
            var entry = entries[i] as Dictionary;
            if (!lateDay && isLateOnly(entry)) {
                continue;
            }
            if (entryMinutes(entry) >= now) {
                return i;
            }
        }
        return -1;
    }

    function countdownText(minutes as Number) as String {
        if (minutes >= 60) {
            return "in " + (minutes / 60) + " h " + (minutes % 60) + " min";
        }
        if (minutes > 0) {
            return "in " + minutes + " min";
        }
        if (minutes > -15) {
            return "jetzt";
        }
        return "vorbei";
    }
}
