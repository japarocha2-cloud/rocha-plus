import unittest

from audit_tv_catalog import audit


class TvCatalogAuditTests(unittest.TestCase):
    def test_empty_approved_blocks_export(self):
        result = audit([], [{"name": "Candidate", "url": "https://example.org/live.m3u8"}])
        self.assertFalse(result["ready_for_verified_only_export"])
        self.assertEqual(result["candidate_records"], 1)

    def test_explicitly_unapproved_blocks_export(self):
        result = audit([{"url": "https://example.org/live.m3u8", "productionApproved": False}], [])
        self.assertFalse(result["ready_for_verified_only_export"])
        self.assertTrue(result["errors"])

    def test_blocked_channel_blocks_export(self):
        result = audit([{"url": "https://example.org/live.m3u8", "blocked": True}], [])
        self.assertFalse(result["ready_for_verified_only_export"])

    def test_verified_entries_are_read_only(self):
        approved = [{"name": "Example", "url": "https://example.org/live.m3u8", "productionApproved": True}]
        before = repr(approved)
        result = audit(approved, [])
        self.assertTrue(result["ready_for_verified_only_export"])
        self.assertEqual(repr(approved), before)


if __name__ == "__main__":
    unittest.main()
