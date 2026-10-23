import unittest
from import_verified_catalog import reason, generate
from pathlib import Path
class CatalogTests(unittest.TestCase):
 def sample(self,**changes):
  row=dict(name='SBT',url='https://example.com/live.m3u8',v4_status='completou_teste',v4_exit_code='0',probe_status='video_e_audio',v4_decoded_seconds='30');row.update(changes);return row
 def test_nonapproval_and_incomplete_decoding_are_rejected(self):
  for status in ['tempo_esgotado','erro_decodificacao_ou_rede','terminou_antes_do_prazo']:
   self.assertEqual(reason(self.sample(v4_status=status)),status)
  self.assertEqual(reason(self.sample(v4_decoded_seconds='5')),'insufficient_decoding_evidence')
 def test_existing_blocks_and_record_are_never_restored(self):
  for name in ['RecordTV Nacional','Band Sports (720p)','1001 Noites (1080p)']:
   self.assertEqual(reason(self.sample(name=name)),'previously_blocked')
 def test_hls_approval_accepts_exact_source_without_rewriting(self):
  self.assertIsNone(reason(self.sample()))
  self.assertEqual(reason(self.sample(url='http://example.com/live.m3u8')),'insecure_http_transport')
  self.assertEqual(reason(self.sample(url='https://example.com/mpegts')),'format_not_integrated_across_platforms')
if __name__=='__main__':unittest.main()
