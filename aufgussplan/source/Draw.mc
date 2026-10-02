import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

module Draw {

    const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    const LEFT = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;

    function clockText() as String {
        var clock = System.getClockTime();
        return clock.hour.format("%02d") + ":" + clock.min.format("%02d");
    }

    // Kürzt den Text mit "..." so weit, bis er in maxWidth passt
    function truncate(dc as Graphics.Dc, text as String, font as Graphics.FontDefinition, maxWidth as Numeric) as String {
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) {
            return text;
        }
        for (var len = text.length() - 1; len > 1; len--) {
            var shortened = (text.substring(0, len) as String) + "...";
            if (dc.getTextWidthInPixels(shortened, font) <= maxWidth) {
                return shortened;
            }
        }
        return "";
    }

    // Zeichnet zentriert mit der größten Schrift, die in maxWidth passt; notfalls gekürzt
    function fitted(dc as Graphics.Dc, x as Number, y as Numeric, text as String, maxWidth as Numeric, fonts as Array<Graphics.FontDefinition>) as Void {
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(text, fonts[i]) <= maxWidth) {
                dc.drawText(x, y, fonts[i], text, CENTER);
                return;
            }
        }
        var smallest = fonts[fonts.size() - 1];
        dc.drawText(x, y, smallest, truncate(dc, text, smallest, maxWidth), CENTER);
    }

    function maxDrops(intensity as Object?) as Number {
        if (intensity instanceof Array && intensity.size() > 0) {
            return intensity[intensity.size() - 1] as Number;
        }
        return 0;
    }

    // Anzahl gezeichneter Tropfen: mit Skala (z. B. 5) werden auch die leeren Stufen gezeigt
    function dropCount(intensity as Object?, scale as Number) as Number {
        var max = maxDrops(intensity);
        return (max > 0 && scale > max) ? scale : max;
    }

    function dropsWidth(intensity as Object?, scale as Number, r as Number) as Number {
        var count = dropCount(intensity, scale);
        return count > 0 ? count * r * 3 - r : 0;
    }

    // Intensität als Tropfen ab der linken Kante x: sichere Tropfen kräftig, die "bis zu"-Tropfen dunkelrot,
    // nicht erreichte Stufen der Skala grau
    function drops(dc as Graphics.Dc, x as Number, y as Number, intensity as Object?, scale as Number, r as Number, dim as Boolean) as Void {
        var max = maxDrops(intensity);
        if (max == 0) {
            return;
        }
        var min = (intensity as Array)[0] as Number;
        var count = dropCount(intensity, scale);
        var cx = x + r;
        for (var i = 0; i < count; i++) {
            if (i >= max) {
                dc.setColor(dim ? 0x202020 : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            } else if (dim) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(i < min ? Graphics.COLOR_RED : Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
            }
            dc.fillCircle(cx, y + r / 2, r);
            dc.fillPolygon([[cx - r, y], [cx + r, y], [cx, y - r * 2]]);
            cx += r * 3;
        }
    }
}
