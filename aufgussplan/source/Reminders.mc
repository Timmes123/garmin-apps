import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Offene Erinnerungen liegen als [[epoch, "18:00 Name"], …] aufsteigend im Speicher,
// damit der Hintergrunddienst ohne den Plan auskommt.
(:background)
module Reminders {

    const KEY_PENDING = "pending";
    const KEY_FIRED = "fired";

    function pending() as Array {
        var list = Application.Storage.getValue(KEY_PENDING);
        if (list instanceof Array) {
            return list;
        }
        return [];
    }

    // Entfernt alle fälligen Erinnerungen aus dem Speicher und gibt ihre Texte zurück
    function takeDue(lookahead as Number) as Array<String> {
        var limit = Time.now().value() + lookahead;
        var list = pending();
        var due = [] as Array<String>;
        var rest = [];
        for (var i = 0; i < list.size(); i++) {
            var item = list[i] as Array;
            if ((item[0] as Number) <= limit) {
                due.add(item[1] as String);
            } else {
                rest.add(item);
            }
        }
        if (due.size() > 0) {
            Application.Storage.setValue(KEY_PENDING, rest as Array<Application.PropertyValueType>);
        }
        return due;
    }

    // Weckt den Hintergrunddienst zur nächsten offenen Erinnerung
    function schedule() as Void {
        var list = pending();
        if (list.size() == 0) {
            Background.deleteTemporalEvent();
            return;
        }
        var when = (list[0] as Array)[0] as Number;
        var now = Time.now().value();
        // Garmin erlaubt höchstens ein Ereignis alle 5 Minuten
        var last = Background.getLastTemporalEventTime();
        if (last != null && when < last.value() + 300) {
            when = last.value() + 300;
        }
        if (when < now + 2) {
            when = now + 2;
        }
        try {
            Background.registerForTemporalEvent(new Time.Moment(when));
        } catch (e) {
        }
    }
}

(:background)
class SaunaService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var due = Reminders.takeDue(30);
        if (due.size() > 0) {
            Application.Storage.setValue(Reminders.KEY_FIRED, due as Array<Application.PropertyValueType>);
            var text = "Gleich: " + due[0];
            for (var i = 1; i < due.size(); i++) {
                text += "\n" + due[i];
            }
            Background.requestApplicationWake(text);
        }
        Reminders.schedule();
        Background.exit(null);
    }
}
