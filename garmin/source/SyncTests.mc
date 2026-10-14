import Toybox.Application;
import Toybox.Lang;
import Toybox.Test;

(:test)
class SyncProbe extends PasKluisApp {
    var receipts = [];
    function initialize() { PasKluisApp.initialize(); }
    function fixture(owner, revision) {
        return {"schema" => 1, "owner" => owner, "revision" => revision,
            "language" => "nl", "cards" => []};
    }
    function ack(revision, owner) {
        var saved = Application.Storage.getValue("snapshot") as Lang.Dictionary;
        Test.assert(saved != null && saved["revision"] == revision);
        receipts.add(revision);
    }
}

(:test)
function repeatedSyncFromSamePhone(logger) {
    var app = new SyncProbe();
    var owner = "phone-" + "fixture";
    app.receiveSnapshot(app.fixture(owner, 1));
    app.receiveSnapshot(app.fixture(owner.substring(0, owner.length()), 2));
    Test.assert(!app.error);
    Test.assert(app.snapshot["revision"] == 2);
    Test.assert(app.receipts.size() == 2 && app.receipts[1] == 2);
    Application.Storage.deleteValue("snapshot");
    return true;
}

(:test)
function wrongOwnerCannotReplaceCards(logger) {
    var app = new SyncProbe();
    app.receiveSnapshot(app.fixture("phone-a", 1));
    app.receiveSnapshot(app.fixture("phone-b", 2));
    Test.assert(app.error && app.snapshot["revision"] == 1);
    Test.assert(app.receipts.size() == 1);
    Application.Storage.deleteValue("snapshot");
    return true;
}

(:test)
function retryAcknowledgesStoredRevision(logger) {
    var app = new SyncProbe();
    app.receiveSnapshot(app.fixture("phone-a", 2));
    app.receiveSnapshot(null);
    Test.assert(app.error);
    app.receiveSnapshot(app.fixture("phone-" + "a", 2));
    Test.assert(!app.error && app.receipts.size() == 2);
    app.receiveSnapshot(app.fixture("phone-a", 1));
    Test.assert(app.snapshot["revision"] == 2 && app.receipts.size() == 2);
    Application.Storage.deleteValue("snapshot");
    return true;
}

(:test)
function categoriesStaySeparate(logger) {
    var app = new SyncProbe();
    app.snapshot = app.fixture("phone", 1);
    app.snapshot["cards"] = [
        {"id" => "old", "name" => "Old", "code" => "001", "bits" => "a", "width" => 4, "height" => 1},
        {"id" => "qr", "name" => "QR", "code" => "001", "bits" => "a", "width" => 4, "height" => 1, "category" => "qr"},
        {"id" => "gift", "name" => "Gift", "code" => "001", "bits" => "a", "width" => 4, "height" => 1, "category" => "gift"}
    ];
    Test.assert(app.valid(app.snapshot));
    Test.assert(app.categoryCards("loyalty").size() == 1);
    Test.assert(app.categoryCards("qr")[0]["id"].equals("qr"));
    Test.assert(app.categoryCards("gift")[0]["id"].equals("gift"));
    app.snapshot["cards"][2]["category"] = "unexpected";
    Test.assert(!app.valid(app.snapshot));
    return true;
}

(:test)
function twentyWideCardsCanSync(logger) {
    var app = new SyncProbe();
    var incoming = app.fixture("phone", 1);
    var bits = "";
    for(var j = 0; j < 53; j++) { bits += "0"; }
    for(var i = 0; i < 20; i++) {
        incoming["cards"].add({"id" => i.toString(), "name" => "Test", "code" => "12345678901234567890123456789012", "bits" => bits, "width" => 211, "height" => 1, "category" => "gift"});
    }
    app.receiveSnapshot(incoming);
    Test.assert(!app.error && app.cards().size() == 20);
    Test.assert(app.receipts.size() == 1);
    Application.Storage.deleteValue("snapshot");
    return true;
}
