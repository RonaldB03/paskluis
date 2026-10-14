import Toybox.Application;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
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
    function category(c) { return c.hasKey("category") ? c["category"] : "loyalty"; }
    function categoryCards(group) {
        var result = [];
        var all = cards();
        for(var i = 0; i < all.size(); i++) { if(group.equals(category(all[i]))) { result.add(all[i]); } }
        return result;
    }
    function valid(s) {
        if (!(s instanceof Lang.Dictionary) || !s.hasKey("schema") || s["schema"] != 1 ||
            !s.hasKey("owner") || !(s["owner"] instanceof Lang.String) || s["owner"].length() == 0 ||
            !s.hasKey("revision") || !isInteger(s["revision"]) || s["revision"] < 0 ||
            !s.hasKey("cards") || !(s["cards"] instanceof Lang.Array)) { return false; }
        var seen = {};
        var size = 0;
        for (var ci = 0; ci < s["cards"].size(); ci++) {
            var c = s["cards"][ci];
            if (!(c instanceof Lang.Dictionary)) { return false; }
            var group = category(c);
            if (!(group instanceof Lang.String) || !("loyalty".equals(group) || "qr".equals(group) || "gift".equals(group))) { return false; }
            var fields = ["id", "name", "code", "bits"];
            for (var fi = 0; fi < fields.size(); fi++) {
                var field = fields[fi];
                if (!c.hasKey(field) || !(c[field] instanceof Lang.String)) { return false; }
            }
            if (seen.hasKey(c["id"]) || c["id"].length() == 0) { return false; }
            seen[c["id"]] = true;
            if (!c.hasKey("width") || !c.hasKey("height") || !isInteger(c["width"]) || !isInteger(c["height"])) { return false; }
            var w = c["width"]; var h = c["height"];
            if (w < 1 || w > 211 || !(h == 1 || (h == w && w <= 73))) { return false; }
            if (c["bits"].length() != ((w*h+3)/4).toNumber() || c["code"].length() > 1024 || c["name"].length() > 160) { return false; }
            for(var i = 0; i < c["bits"].length(); i++) {
                if ("0123456789abcdef".find(c["bits"].substring(i,i+1)) == null) { return false; }
            }
            size += c["bits"].length() + c["code"].length() + c["name"].length();
        }
        return size <= 6500;
    }
    function isInteger(value) { return value instanceof Lang.Number || value instanceof Lang.Long; }
    function receive(message as Communications.PhoneAppMessage) as Void {
        var data = message.data;
        if(data instanceof Lang.Dictionary && data.hasKey("kind") && "logo".equals(data["kind"])) { receiveLogo(data); return; }
        receiveSnapshot(data);
    }
    function receiveLogo(data) {
        if(snapshot == null || (snapshot.hasKey("locallyErased") && snapshot["locallyErased"]) ||
           !data.hasKey("owner") || !snapshot["owner"].equals(data["owner"]) ||
           !data.hasKey("revision") || snapshot["revision"] != data["revision"] ||
           !data.hasKey("id") || !data.hasKey("pixels") || !(data["pixels"] instanceof Lang.String) || data["pixels"].length() != 576) { return; }
        var pixels = data["pixels"];
        for(var p=0; p<pixels.length(); p++) {
            var v = colorIndex(pixels.substring(p,p+1));
            if(v == null) { return; }
        }
        for(var i=0; i<cards().size(); i++) {
            if(cards()[i]["id"].equals(data["id"])) {
                try { Application.Storage.setValue("logo"+i,data); } catch(e) { return; }
                WatchUi.requestUpdate(); return;
            }
        }
    }
    function logo(card) {
        for(var i=0; i<cards().size(); i++) {
            if(cards()[i]["id"].equals(card["id"])) {
                var value = Application.Storage.getValue("logo"+i);
                if(value instanceof Lang.Dictionary && value["owner"].equals(snapshot["owner"]) && value["revision"] == snapshot["revision"] && value["id"].equals(card["id"])) { return value["pixels"]; }
            }
        }
        return null;
    }
    function clearLogos() {
        for(var i=0; i<cards().size(); i++) { Application.Storage.deleteValue("logo"+i); }
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
            clearLogos();
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
            Application.Storage.setValue("snapshot",empty); clearLogos(); snapshot = empty;
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
    var choosingCategory = true;
    var categoryIndex = 0;
    var groups = ["loyalty", "qr", "gift"];
    function rows() { return app.categoryCards(groups[categoryIndex]); }
    function categoryName(i) { return i == 0 ? app.text("Klantenkaarten","Loyalty cards") : i == 1 ? app.text("QR-codes","QR codes") : app.text("Cadeaukaarten","Gift cards"); }
    var timeout;
    var logo;
    function initialize(a) { View.initialize(); app = a; timeout = new Timer.Timer(); logo = WatchUi.loadResource(Rez.Drawables.HeaderLogo); }
    function onHide() { timeout.stop(); selected = false; }
    function scan() { selected = true; timeout.start(method(:endScan),45000,false); WatchUi.requestUpdate(); }
    function endScan() as Void { selected = false; WatchUi.requestUpdate(); }
    function onUpdate(dc) {
        var w = dc.getWidth(); var h = dc.getHeight();
        var rows = rows();
        dc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_BLACK); dc.clear();
        if(selected && index < rows.size()) { drawCode(dc,rows[index]); return; }
        var lx = (w/2-16).toNumber();
        dc.drawBitmap(lx,20,logo);
        dc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_BLACK);
        for(var ly = 0; ly < 32; ly++) {
            var dy = ly-15.5;
            var edge = (16-Math.sqrt(256-dy*dy)).toNumber();
            if(edge > 0) { dc.fillRectangle(lx,20+ly,edge,1); dc.fillRectangle(lx+32-edge,20+ly,edge,1); }
        }
        dc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_BLACK);
        if (choosingCategory) {
            for(var ci = 0; ci < 3; ci++) {
                var yy = h/2-45+ci*32;
                if(ci == categoryIndex) { dc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_BLACK); dc.fillRoundedRectangle(w*0.10,yy-2,w*0.80,30,8); dc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_WHITE); }
                else { dc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_BLACK); }
                dc.drawText(w/2,yy,Graphics.FONT_XTINY,categoryName(ci),Graphics.TEXT_JUSTIFY_CENTER);
            }
            return;
        }
        dc.drawText(w/2,58,Graphics.FONT_XTINY,categoryName(categoryIndex),Graphics.TEXT_JUSTIFY_CENTER);
        if (rows.size() == 0) {
            dc.drawText(w/2,h/2-35,Graphics.FONT_XTINY,app.text("Kies pasjes in","Choose cards in"),Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(w/2,h/2-10,Graphics.FONT_XTINY,app.text("PasKluis op je telefoon","PasKluis on your phone"),Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            index = index % rows.size();
            var first = index > 0 ? index-1 : 0;
            if(first+3 > rows.size()) { first = rows.size() > 3 ? rows.size()-3 : 0; }
            for(var ri = first; ri < rows.size() && ri < first+3; ri++) {
                var yy = h/2-35+(ri-first)*30;
                if(ri == index) { dc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_BLACK); dc.fillRoundedRectangle(w*0.1,yy-2,w*0.8,29,7); dc.setColor(Graphics.COLOR_BLACK,Graphics.COLOR_WHITE); }
                else { dc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_BLACK); }
                var pixels = app.logo(rows[ri]);
                if(pixels != null) {
                    drawLogo(dc,pixels,(w*0.13).toNumber(),yy.toNumber());
                    dc.setColor(ri == index ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE,ri == index ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK);
                    dc.drawText(w*0.26,yy,Graphics.FONT_XTINY,fit(dc,rows[ri]["name"],w*0.60,Graphics.FONT_XTINY),Graphics.TEXT_JUSTIFY_LEFT);
                } else { dc.drawText(w/2,yy,Graphics.FONT_XTINY,fit(dc,rows[ri]["name"],w*0.72,Graphics.FONT_XTINY),Graphics.TEXT_JUSTIFY_CENTER); }
            }
            dc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_BLACK);
            dc.drawText(w/2,h-44,Graphics.FONT_XTINY,(index+1)+" / "+rows.size()+"  START",Graphics.TEXT_JUSTIFY_CENTER);
        }
        if(app.error) { dc.drawText(w/2,h-40,Graphics.FONT_XTINY,app.text("Sync opnieuw proberen","Retry sync"),Graphics.TEXT_JUSTIFY_CENTER); }
    }
    function drawLogo(dc,pixels,left,top) {
        for(var y=0;y<24;y++) { for(var x=0;x<24;x++) {
            if((x-11.5)*(x-11.5)+(y-11.5)*(y-11.5)>144) { continue; }
            var i=y*24+x; var v=colorIndex(pixels.substring(i,i+1));
            var color=(((v>>4)&3)*85<<16)|(((v>>2)&3)*85<<8)|((v&3)*85);
            dc.setColor(color,Graphics.COLOR_TRANSPARENT); dc.fillRectangle(left+x,top+y,1,1);
        } }
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
        // A centered band 24% of screen height fits inside the circular display
        // at 97% width, including both ten-module quiet zones.
        var available = (sw*0.97).toNumber();
        var m = (available/(w+q*2)).toNumber();
        if(h != 1) { m = ((sw*0.70)/(w+q*2)).toNumber(); }
        if(m < (h == 1 ? 1 : 2)) {
            dc.drawText(sw/2,sh/2,Graphics.FONT_XTINY,app.text("Gebruik je telefoon","Use your phone"),Graphics.TEXT_JUSTIFY_CENTER); return;
        }
        var barHeight = h == 1 ? (sh*0.24).toNumber() : m;
        var x0 = ((sw-w*m)/2).toNumber(); var y0 = ((sh-h*barHeight)/2).toNumber();
        var bits = c["bits"];
        for(var y = 0; y < h; y++) {
            for(var x = 0; x < w; x++) {
                var i = y*w+x; var pos = (i/4).toNumber();
                var nibble = bits.substring(pos,pos+1).toNumberWithBase(16);
                if((nibble & (1 << (3-i%4))) != 0) { dc.fillRectangle(x0+x*m,y0+y*barHeight,m,barHeight); }
            }
        }
        dc.drawText(sw/2,h == 1 ? 26 : 6,Graphics.FONT_XTINY,fit(dc,c["name"],sw*(h == 1 ? 0.68 : 0.30),Graphics.FONT_XTINY),Graphics.TEXT_JUSTIFY_CENTER);
        // Never truncate a number into a misleading different card number.
        if(h == 1 && dc.getTextWidthInPixels(c["code"],Graphics.FONT_XTINY) <= sw*0.72) {
            dc.drawText(sw/2,sh-48,Graphics.FONT_XTINY,c["code"],Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
class CardsDelegate extends WatchUi.BehaviorDelegate {
    var app; var view;
    function initialize(a,v) { BehaviorDelegate.initialize(); app = a; view = v; }
    function onSelect() {
        if(view.choosingCategory) { view.choosingCategory = false; view.index = 0; WatchUi.requestUpdate(); }
        else if(view.rows().size() > 0) { view.scan(); }
        return true;
    }
    function onNextPage() { move(1); return true; }
    function onPreviousPage() { move(-1); return true; }
    function move(delta) {
        if(view.choosingCategory) { view.categoryIndex = (view.categoryIndex+delta+3)%3; WatchUi.requestUpdate(); return; }
        var n = view.rows().size();
        if(n > 0) { view.index = (view.index+delta+n)%n; if(view.selected) { view.scan(); } else { WatchUi.requestUpdate(); } }
    }
    function onBack() {
        if(view.selected) { view.selected = false; WatchUi.requestUpdate(); return true; }
        if(!view.choosingCategory) { view.choosingCategory = true; WatchUi.requestUpdate(); return true; }
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

function colorIndex(pixel) { return "0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmno".find(pixel); }
