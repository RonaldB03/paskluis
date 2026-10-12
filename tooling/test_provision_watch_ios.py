import datetime as dt
import unittest
from provision_watch_ios import valid_profile, PHONE, WATCH


class ProfileSafetyTest(unittest.TestCase):
    def setUp(self):
        self.now = dt.datetime(2026, 10, 12)
        self.profile = {"Entitlements": {"application-identifier": "TEAM." + WATCH,
                                         "get-task-allow": False},
                        "ExpirationDate": self.now + dt.timedelta(days=30)}

    def test_exact_companion_profile_required(self):
        self.assertTrue(valid_profile(self.profile, WATCH, self.now))
        self.assertFalse(valid_profile(self.profile, PHONE, self.now))

    def test_expired_profile_rejected(self):
        self.profile["ExpirationDate"] = self.now
        self.assertFalse(valid_profile(self.profile, WATCH, self.now))

    def test_development_profile_rejected(self):
        self.profile["Entitlements"]["get-task-allow"] = True
        self.assertFalse(valid_profile(self.profile, WATCH, self.now))

    def test_ad_hoc_and_enterprise_rejected(self):
        self.profile["ProvisionedDevices"] = ["test-device"]
        self.assertFalse(valid_profile(self.profile, WATCH, self.now))
        del self.profile["ProvisionedDevices"]
        self.profile["ProvisionsAllDevices"] = True
        self.assertFalse(valid_profile(self.profile, WATCH, self.now))


if __name__ == "__main__":
    unittest.main()
