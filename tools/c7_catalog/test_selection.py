import json
import tempfile
import unittest
from pathlib import Path
from selection import import_selection, read_head, digest, identity, category

class SelectionTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.store=self.root/'store';self.source=self.root/'owner.json'
    def apply(self,rows,head='none',apply=True,seed=None,forbidden=None,filter_removed=False):
        self.source.write_text(json.dumps(rows,ensure_ascii=False))
        raw=self.source.read_bytes()
        return import_selection(self.store,self.source,digest(raw),head,'owner-selection','fixture owner export',seed or [],forbidden or set(),apply,filter_removed)
    def test_categories_and_caze_move_preserve_all_other_fields_and_order(self):
        rows=[{'id':'n','name':'News','url':'https://example.test/n','group':'News'},
              {'id':'e','name':'ESPN','url':'https://example.test/e','group':'Sports'},
              {'id':'c','name':'CazéTV','url':'http://138.204.86.4:8080/CAZE_TV/playlist.m3u8','group':'Esportes','logo':'https://example.test/logo'},
              {'id':'h','name':'HISTORY','url':'http://170.83.16.50/HISTORY/index.m3u8','group':'Documentary'}]
        result=self.apply(rows);_,data=read_head(self.store)
        self.assertEqual([r['id'] for r in data['channels']],['n','c','e','h'])
        self.assertEqual([r['group'] for r in data['channels']],['Notícias','Esportes','Esportes','Documentários'])
        for row in data['channels']:
            original=next(r for r in rows if r['id']==row['id'])
            self.assertEqual(row['name'],original['name']);self.assertEqual(row['url'],original['url']);self.assertEqual(row.get('logo'),original.get('logo'))
        self.assertEqual(category('Noticias'),'Notícias')
        self.assertEqual(category('Noti\u0301cias'),'Notícias')
        self.assertEqual(category('Education'),'Educação')
        self.assertEqual(category('Unknown external group'),'Outros')
        self.assertTrue((self.store/'sources'/digest(self.source.read_bytes())).is_file())
        self.assertEqual(result['selectedCount'],4)
    def test_removed_channel_never_reappears_under_new_id_or_url(self):
        rows=[{'id':'a','name':'Removed','url':'https://example.test/a'},{'id':'b','name':'Retained','url':'https://example.test/b'}]
        first=self.apply(rows)
        second=self.apply(rows[1:],first['sha256'])
        previous=(self.store/'selections'/f"{first['sha256']}.json").read_bytes()
        for removed in [rows[0],dict(rows[0],id='changed-id',url='https://example.test/alternate')]:
            with self.assertRaisesRegex(ValueError,'reinclusion'):
                self.apply([removed,rows[1]],second['sha256'])
        self.assertEqual(read_head(self.store)[0]['sha256'],second['sha256'])
        self.assertEqual((self.store/'selections'/f"{first['sha256']}.json").read_bytes(),previous)
    def test_removing_one_variant_keeps_distinct_retained_alternative(self):
        rows=[{'id':'a','name':'Channel','url':'https://example.test/a'}, {'id':'b','name':'Channel','url':'https://example.test/b'}]
        first=self.apply(rows);second=self.apply(rows[1:],first['sha256'])
        self.apply(rows[1:],second['sha256'])
        self.assertFalse(read_head(self.store)[1]['removals'][0]['blockIdentity'])
    def test_hash_tamper_stale_head_and_pending_inventory_rejected_without_activation(self):
        rows=[{'id':'a','name':'A','url':'https://example.test/a'}]
        first=self.apply(rows)
        with self.assertRaisesRegex(ValueError,'changed'):
            self.apply(rows,'none')
        self.source.write_text(json.dumps(rows))
        with self.assertRaisesRegex(ValueError,'source SHA'):
            import_selection(self.store,self.source,'0'*64,first['sha256'],'owner-selection','fixture',[],set())
        with self.assertRaisesRegex(ValueError,'pending'):
            self.apply(rows,first['sha256'],forbidden={digest(self.source.read_bytes())})
        target=self.store/'selections'/f"{first['sha256']}.json";target.write_bytes(target.read_bytes()+b' ')
        with self.assertRaisesRegex(ValueError,'stored selection SHA'):
            read_head(self.store)
    def test_reformatted_pending_inventory_cannot_be_promoted(self):
        from selection import encoded
        rows=[{'id':'a','name':'Candidate','url':'https://example.test/a','status':'pending'}]
        self.source.write_text(json.dumps(rows,indent=4))
        with self.assertRaisesRegex(ValueError,'pending'):
            import_selection(self.store,self.source,digest(self.source.read_bytes()),'none','owner-selection','not a real selection',[],{digest(encoded(rows))},True)
        self.assertFalse((self.store/'HEAD.json').exists())

    def test_duplicate_ids_invalid_urls_and_dry_run_are_not_activated(self):
        rows=[{'id':'a','name':'A','url':'https://example.test/a'}]
        self.apply(rows,apply=False)
        self.assertFalse((self.store/'HEAD.json').exists())
        for value in [rows*2,[dict(rows[0],url='file:///private')],[dict(rows[0],url='https://user:pass@example.test/a')],[dict(rows[0],url='https://:@example.test/a')],[dict(rows[0],url='https://example.test:wrong/a')]]:
            with self.assertRaises(ValueError):self.apply(value)
        self.assertFalse((self.store/'HEAD.json').exists())
    def test_authorized_removals_are_archived_not_reinstated(self):
        removed={'id':'x','identity':identity('Record (720p)'),'name':'Record (720p)','url':'https://example.test/old','blockIdentity':True}
        rows=[{'id':'changed','name':'Record (1080p)','url':'https://example.test/new'}, {'id':'k','name':'Record News','url':'https://example.test/news'}]
        with self.assertRaisesRegex(ValueError,'reinclusion'):self.apply(rows,seed=[removed])
        result=self.apply(rows,seed=[removed],filter_removed=True)
        self.assertEqual(result['authorizedExclusions'],['changed'])
        self.assertEqual(len(read_head(self.store)[1]['channels']),1)
        self.assertEqual(json.loads(next((self.store/'sources').iterdir()).read_bytes()),rows)

class SelectionCliTests(unittest.TestCase):
    def test_owner_import_export_update_and_prebuild_verify(self):
        import subprocess
        script=Path(__file__).with_name('selection.py').resolve()
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);source=root/'source.json';store=root/'store';output=root/'selection.json'
            def run(*args,ok=True):
                result=subprocess.run(['python3',str(script),*args],capture_output=True,text=True)
                if ok:self.assertEqual(result.returncode,0,result.stderr)
                else:self.assertNotEqual(result.returncode,0)
                return result
            def import_rows(rows,head):
                source.write_text(json.dumps(rows));return json.loads(run('import','--source',str(source),'--expected-source-sha256',digest(source.read_bytes()),'--expected-head',head,'--provenance','owner-selection','--reference','fixture manual selection','--store',str(store),'--apply').stdout)
            approved_caze={'id':'c','name':'CazéTV','url':'https://example.test/caze','group':'Esportes'}
            first=import_rows([{'id':'a','name':'A','url':'https://example.test/a'},{'id':'b','name':'B','url':'https://example.test/b'},approved_caze],'none')
            run('export','--store',str(store),'--output',str(output));before=output.read_bytes()
            run('verify','--store',str(store),'--asset',str(output))
            second=import_rows([{'id':'b','name':'B','url':'https://example.test/b'},approved_caze],first['sha256'])
            run('export','--store',str(store),'--output',str(output),ok=False)
            self.assertEqual(output.read_bytes(),before)
            run('export','--store',str(store),'--output',str(output),'--expected-output-sha256',first['sha256'])
            run('verify','--store',str(store),'--asset',str(output))
            self.assertEqual(digest(output.read_bytes()),second['sha256'])
            self.assertEqual((store/'selections'/f"{first['sha256']}.json").read_bytes(),before)
            output.write_bytes(output.read_bytes()+b' ')
            run('verify','--store',str(store),'--asset',str(output),ok=False)
    def test_no_source_blocks_packaging_and_never_creates_fake_approved_file(self):
        import subprocess
        with tempfile.TemporaryDirectory() as d:
            store=Path(d)/'missing'
            result=subprocess.run(['python3',str(Path(__file__).with_name('selection.py').resolve()),'verify','--store',str(store)],capture_output=True,text=True)
            self.assertNotEqual(result.returncode,0)
            self.assertFalse(store.exists())

if __name__=='__main__':unittest.main()
