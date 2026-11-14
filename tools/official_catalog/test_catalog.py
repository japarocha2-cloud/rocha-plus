import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import shutil

spec=importlib.util.spec_from_file_location('official_catalog',Path(__file__).with_name('catalog.py'))
catalog=importlib.util.module_from_spec(spec);spec.loader.exec_module(catalog)
ROOT=catalog.ROOT

class OfficialCatalogueTest(unittest.TestCase):
    def setUp(self):
        self.doc=catalog.frozen(ROOT)
        self.products=catalog.build(ROOT)
        self.selection=json.loads(self.products['branding/c7/selection.json'])
        self.rows=self.selection['channels']

    def test_original_bytes_csv_and_backups_are_pinned(self):
        self.assertEqual(len(self.doc['canais']),479)
        self.assertEqual(sum(r['status_historico']=='Revisar PC' for r in self.doc['canais']),71)
        self.assertEqual(catalog.read(ROOT,'catalog/official/frozen/SHA256SUMS.json'),catalog.PINS)

    def test_every_base_record_retains_name_category_status_current_url(self):
        actual=sorted([r for r in self.rows if r['sourceLayer']=='base'],key=lambda r:r['sourceIndex'])
        self.assertEqual(len(actual),479)
        for original,row in zip(self.doc['canais'],actual):
            self.assertEqual((row['name'],row['group'],row['historicalStatus'],row['url']),
                (original['nome'],original['categoria'],original['status_historico'],original['url_atual']))
        self.assertEqual(self.selection['removals'],[])

    def test_declared_additions_not_deduplicated_or_guessed(self):
        additions=sorted([r for r in self.rows if r['sourceLayer']=='addition'],key=lambda r:r['sourceIndex'])
        self.assertEqual(len(additions),4)
        self.assertEqual(len(self.rows),483)
        self.assertEqual(len({r['id'] for r in self.rows}),483)
        for original,row in zip(self.doc['adicoes_aprovadas_fora_da_base'],additions):
            self.assertEqual((original['nome'],original['url_atual']),(row['name'],row['url']))
        self.assertEqual(sum('Telecine Action' in r['name'] for r in self.rows),2)

    def test_caze_first_sport_and_all_other_base_positions_stable(self):
        self.assertEqual(next(r['name'] for r in self.rows if r['group']=='Esportes'),'CazéTV')
        self.assertEqual([r['sourceIndex'] for r in self.rows if r['sourceLayer']=='base'],list(range(479)))

    def test_ratimbum_alternatives_and_preference_are_explicit(self):
        row=next(r for r in self.rows if r['name']=='TV Rá-Tim-Bum HD')
        self.assertEqual(len(row['urls']),3)
        self.assertEqual(row['preferredUrlIndex'],1)
        self.assertEqual(row['url'],row['urls'][1])
        evidence=(ROOT/'docs/lab/CANDIDATA6_LINKS_APROVADOS_20261106.md').read_text()
        self.assertTrue(all(url in evidence for url in row['urls']))

    def test_adapters_share_exact_bytes_and_pin(self):
        android=self.products['branding/c7/selection.json']
        self.assertEqual(android,self.products[catalog.ROKU+'catalog/official-selection.json'])
        pin=catalog.sha(android)
        self.assertIn(pin.encode(),self.products['lib/src/live/official_catalog_pin.dart'])
        self.assertIn(pin.encode(),self.products[catalog.ROKU+'components/OfficialCatalogue.brs'])
        self.assertTrue(all((ROOT/path).read_bytes()==raw for path,raw in self.products.items()))

    def test_historical_inventory_and_artwork_are_not_deleted(self):
        old=catalog.read(ROOT,catalog.ROKU+'config/cover-map.json')
        new=json.loads(self.products[catalog.ROKU+'config/official-cover-map.json'])
        self.assertTrue(all(new.get(k)==v for k,v in old.items()))
        for path in old.values():
            self.assertTrue((ROOT/catalog.ROKU/path.removeprefix('pkg:/')).is_file())
        report=json.loads(self.products['docs/lab/catalogo-unico-20261108/differences.json'])
        self.assertTrue(report['platforms']['roku']['additionalPreservedInInventory'])
        self.assertFalse(report['automaticDeletion'])
        self.assertFalse(report['availabilityProbed'])

    def test_runtime_has_no_pending_exclusion_or_external_fallback(self):
        dart=(ROOT/'lib/src/live/c7_selected_catalog.dart').read_text()
        self.assertNotIn('package:http',dart)
        brs=(ROOT/catalog.ROKU/'components/HomeScene.brs').read_text()
        self.assertIn('parsed = readOfficialCatalogue()',brs)
        self.assertNotIn('ReadAsciiFile("pkg:/catalog/commercial-lab-merged.json")',brs)
        self.assertNotIn('and (m.showRemoved or not isRemoved',brs)
        self.assertIn('OfficialCatalogue.brs',(ROOT/catalog.ROKU/'components/HomeScene.xml').read_text())

    def test_approved_alternative_hosts_are_debug_only_and_pinned(self):
        spec=importlib.util.spec_from_file_location('lab_configure',ROOT/'tools/lab/configure.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        hosts=module.official_http_hosts(ROOT)
        self.assertIn('186.219.52.187',hosts)
        self.assertNotIn('186.219.52.187',(ROOT/'tools/allowed_http_hosts.txt').read_text().splitlines())
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            self.assertEqual(module.official_http_hosts(root),set())
            for name in ['branding/c7/selection.json','catalog/official/runtime.sha256']:
                target=root/name;target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(ROOT/name,target)
            self.assertEqual(module.official_http_hosts(root),hosts)
            asset=root/'branding/c7/selection.json';asset.write_bytes(asset.read_bytes()+b' ')
            with self.assertRaisesRegex(ValueError,'SHA mismatch'):
                module.official_http_hosts(root)

    def test_frozen_tampering_fails_before_regeneration(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            shutil.copytree(ROOT/'catalog/official',root/'catalog/official')
            path=root/catalog.BASE/catalog.SOURCE
            path.write_bytes(path.read_bytes()+b' ')
            with self.assertRaisesRegex(ValueError,'Frozen source bytes changed'):
                catalog.build(root)

    def test_missing_or_corrupt_adapter_is_detected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            # Preserve inputs only: output verification must reject missing products.
            for path in ['catalog/official',catalog.ROKU+'catalog',catalog.ROKU+'config','branding/lab_candidates.json']:
                src=ROOT/path;dest=root/path;dest.parent.mkdir(parents=True,exist_ok=True)
                if src.is_dir(): shutil.copytree(src,dest)
                else: shutil.copyfile(src,dest)
            with self.assertRaisesRegex(ValueError,'Generated adapter diverged'):
                catalog.run(False,root)

if __name__=='__main__':unittest.main()
