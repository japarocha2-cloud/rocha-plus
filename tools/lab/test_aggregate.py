import unittest
from aggregate import aggregate


class AggregateTest(unittest.TestCase):
    def test_missing_shards_stay_pending_and_inconclusive_is_not_unavailable(self):
        candidate = lambda url: {'url': url, 'name': url, 'eligible': True,
          'origins': ['br'], 'group': 'Infantil'}
        inventory = {'candidates': [candidate('a'), candidate('b'), candidate('c')],
          'sources': {'br': {}}, 'complete': True, 'sourceFailures': {}, 'summary': {}}
        report = [{'channelUrl': 'a', 'testedAt': '2026-10-20T00:00:00Z', 'automaticAudiovisualPass': False},
                  {'channelUrl': 'b', 'testedAt': '2026-10-20T00:00:00Z', 'automaticAudiovisualPass': True}]
        result = aggregate(inventory, [report])
        self.assertEqual([r['status'] for r in result['channels']], ['failed_or_inconclusive', 'automatic_audiovisual_pass', 'pending'])
        self.assertEqual(result['summary']['tested'], 2)
        self.assertEqual(result['summary']['productionApproved'], 0)
        self.assertEqual(result['summary']['approvedByCategory'], {'Infantil': 1})


if __name__ == '__main__':
    unittest.main()
