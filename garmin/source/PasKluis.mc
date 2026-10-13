import Toybox.Application;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class PasKluisApp extends Application.AppBase {
    var snapshot = null;
    var view = null;
    var error = false;
    function initialize() { AppBase.initialize(); }
    function onStart(state) {
        var stored = Application.Storage.getValue("snapshot");
        if (valid(stored)) { snapshot = stored; }
        Communications.registerForPhoneAppMessages(method(:receive));
    }
    function getInitialView() {
        view = new CardsView(self);
        return [view, new CardsDelegate(self, view)];
    }
    function text(nl, en) { return snapshot != null && "en".equals(snapshot["language"]) ? en : nl; }
    function cards() { return snapshot == null ? [] : snapshot["cards"]; }
    function valid(s) {
        if (!(s instanceof Lang.Dictionary) || !s.hasKey("schema") || s["schema"] != 1 ||
            !s.hasKey("owner") || !(s["owner"] instanceof Lang.String) || s["owner"].length() == 0 ||
            !s.hasKey("revision") || !isInteger(s["revision"]) || s["revision"] < 0 ||
            !s.hasKey("cards") || !(s["cards"] instanceof Lang.Array) || s["cards"].size() > 12) { return false; }
        var seen = {};
        var size = 0;
        for (var ci = 0; ci < s["cards"].size(); ci++) {
            var c = s["cards"][ci];
            if (!(c instanceof Lang.Dictionary)) { return false; }
            var fields = ["id", "name", "code", "bits"];
            for (var fi = 0; fi < fields.size(); fi++) {
                var field = fields[fi];
                if (!c.hasKey(field) || !(c[field] instanceof Lang.String)) { return false; }
            }
            if (seen.hasKey(c["id"]) || c["id"].length() == 0) { return false; }
            seen[c["id"]] = true;
            if (!c.hasKey("width") || !c.hasKey("height") || !isInteger(c["width"]) || !isInteger(c["height"])) { return false; }
            var w = c["width"]; var h = c["height"];
            if (w < 1 || w > 192 || !(h == 1 || (h == w && w <= 49))) { return false; }
            if (c["bits"].length() != ((w*h+3)/4).toNumber() || c["code"].length() > 512 || c["name"].length() > 160) { return false; }
            for(var i = 0; i < c["bits"].length(); i++) {
                if ("0123456789abcdef".find(c["bits"].substring(i,i+1)) == null) { return false; }
            }
            size += c["bits"].length() + c["code"].length() + c["name"].length();
        }
        return size <= 6500;
    }
    function isInteger(value) { return value instanceof Lang.Number || value instanceof Lang.Long; }
    function receive(message as Communications.PhoneAppMessage) as Void {
        receiveSnapshot(message.data);
    }
    function receiveSnapshot(incoming) as Void {
        if (!valid(incoming)) { error = true; WatchUi.requestUpdate(); return; }
        if (snapshot != null) {
            if (!snapshot["owner"].equals(incoming["owner"])) {
                if (!snapshot.hasKey("allowNewOwner") || snapshot["allowNewOwner"] != true) { error = true; WatchUi.requestUpdate(); return; }
            } else if (incoming["revision"] <= snapshot["revision"]) {
                if (incoming["revision"] == snapshot["revision"] && !snapshot.hasKey("locallyErased")) {
                    error = false;
                    ack(snapshot["revision"],snapshot["owner"]);
                    WatchUi.requestUpdate();
                }
                return;
            }
        }
        try {
            // One property is an atomic full replacement; do not clear first.
            Application.Storage.setValue("snapshot", incoming);
            snapshot = incoming;
            error = false;
            if (view != null) { view.selected = false; view.index = 0; }
            ack(incoming["revision"], incoming["owner"]);
        } catch (e) { error = true; }
        WatchUi.requestUpdate();
    }
    function ack(revision, owner) {
        try { Communications.transmit({"ack" => revision, "owner" => owner}, null, new AckListener()); }
        catch (e) { /* The phone will retry; offline cards remain available. */ }
    }
    function erase(reset) {
        if (snapshot == null) { return; }
        var owner = snapshot["owner"];
        try {
            var empty = {"schema" => 1, "owner" => owner, "revision" => snapshot["revision"],
                "language" => snapshot["language"], "cards" => [], "locallyErased" => true, "allowNewOwner" => reset};
            Application.Storage.setValue("snapshot",empty); snapshot = empty;
            ack(-1,owner);
            view.index = 0; view.selected = false;
        } catch(e) { error = true; }
        WatchUi.requestUpdate();
    }
}
class AckListener extends Communications.ConnectionListener {
    function initialize() { ConnectionListener.initialize(); }
    function onComplete() {}
    function onError() {}
}
class CardsView extends WatchUi.View {
    var app;
    var index = 0;
    var selected = false;
    var timeout;
    function initialize(a) { View.initialize(); app = a; timeout = new Timer.Timer(); }
    function onHide() { timeout.stop(); selected = false; }
    function scan() { selected = true; timeout.start(method(:endScan),45000,false); WatchUi.requestUpdate(); }
    function endScan() as Void { selected = false; WatchUi.requestUpdate(); }
    function onUpdate(dc) {
        var w = dc.getWidth(); var h = dc.getHeight();
        var rows = app.cards();
        dc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_BLACK); dc.clear();
        if(selected && index < rows.size()) { drawCode(dc,rows[index]); return; }
        dc.drawText(w/2,25,Graphics.FONT_SMALL,"PasKluis",Graphics.TEXT_JUSTIFY_CENTER);
        if (rows.size() == 0) {
            dc.drawText(w/2,h/2-35,Graphics.FONT_XTINY,app.text("Kies pasjes in","Choose cards in"),Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(w/2,h/2-10,Graphics.FONT_XTINY,app.text("PasKluis op je telefoon","PasKluis on your phone"),Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            index = index % rows.size();
            dc.drawText(w/2,h/2-32,Graphics.FONT_SMALL,fit(dc,rows[index]["name"],w*0.8,Graphics.FONT_SMALL),Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(w/2,h/2+4,Graphics.FONT_XTINY,(index+1)+" / "+rows.size(),Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(w/2,h-65,Graphics.FONT_XTINY,app.text("START: toon pasje","START: show card"),Graphics.TEXT_JUSTIFY_CENTER);
        }
        if(app.error) { dc.drawText(w/2,h-40,Graphics.FONT_XTINY,app.text("Sync opnieuw proberen","Retry sync"),Graphics.TEXT_JUSTIFY_CENTER); }
    }
    function fit(dc,text,width,font) {
        if(dc.getTextWidthInPixels(text,font) <= width) { return text; }
        var s = text;
        while(s.length() > 0 && dc.getTextWidthInPixels(s+"...",font) > width) { s = s.substring(0,s.length()-1); }
        return s+"...";
    }
    function drawCode(dc,c) {
        var sw = dc.getWidth(); var sh = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_WHITE); dc.clear();
        var w = c["width"]; var h = c["height"];
        var q = h == 1 ? 10 : 4;
        var available = (sw*0.82).toNumber();
        var m = (available/(w+q*2)).toNumber();
        if(h != 1) { m = ((sw*0.70)/(w+q*2)).toNumber(); }
        if(m < 1) {
            dc.drawText(sw/2,sh/2,Graphics.FONT_XTINY,app.text("Gebruik je telefoon","Use your phone"),Graphics.TEXT_JUSTIFY_CENTER); return;
        }
        var barHeight = h == 1 ? (sh*0.3).toNumber() : m;
        var x0 = ((sw-w*m)/2).toNumber(); var y0 = ((sh-h*barHeight)/2).toNumber();
        var bits = c["bits"];
        for(var y = 0; y < h; y++) {
            for(var x = 0; x < w; x++) {
                var i = y*w+x; var pos = (i/4).toNumber();
                var nibble = bits.substring(pos,pos+1).toNumberWithBase(16);
                if((nibble & (1 << (3-i%4))) != 0) { dc.fillRectangle(x0+x*m,y0+y*barHeight,m,barHeight); }
            }
        }
        dc.drawText(sw/2,26,Graphics.FONT_XTINY,fit(dc,c["name"],sw*0.68,Graphics.FONT_XTINY),Graphics.TEXT_JUSTIFY_CENTER);
        // Never truncate a number into a misleading different card number.
        if(dc.getTextWidthInPixels(c["code"],Graphics.FONT_XTINY) <= sw*0.72) {
            dc.drawText(sw/2,sh-48,Graphics.FONT_XTINY,c["code"],Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
class CardsDelegate extends WatchUi.BehaviorDelegate {
    var app; var view;
    function initialize(a,v) { BehaviorDelegate.initialize(); app = a; view = v; }
    function onSelect() { if(app.cards().size() > 0) { view.scan(); } return true; }
    function onNextPage() { move(1); return true; }
    function onPreviousPage() { move(-1); return true; }
    function move(delta) {
        var n = app.cards().size();
        if(n > 0) { view.index = (view.index+delta+n)%n; view.selected = false; WatchUi.requestUpdate(); }
    }
    function onBack() {
        if(view.selected) { view.selected = false; WatchUi.requestUpdate(); return true; }
        return false;
    }
    function onMenu() {
        var menu = new WatchUi.Menu2({:title => "PasKluis"});
        menu.addItem(new WatchUi.MenuItem(app.text("Pasjes wissen","Erase cards"),null,"erase",null));
        menu.addItem(new WatchUi.MenuItem(app.text("Opnieuw koppelen","Reconnect"),null,"reset",null));
        WatchUi.pushView(menu,new EraseDelegate(app),WatchUi.SLIDE_UP); return true;
    }
}
class EraseDelegate extends WatchUi.Menu2InputDelegate {
    var app;
    function initialize(a) { Menu2InputDelegate.initialize(); app = a; }
    function onSelect(item) { app.erase("reset".equals(item.getId())); WatchUi.popView(WatchUi.SLIDE_DOWN); }
}
