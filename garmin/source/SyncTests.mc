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
