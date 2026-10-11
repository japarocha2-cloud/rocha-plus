import unittest
from tools.channel_triage import classify, analyze

class TriageTests(unittest.TestCase):
    def test_denied_is_not_dead(self):
        self.assertEqual(classify({"status":"falhou", "detail":"HTTP 403"}), "acesso_restrito")
    def test_not_found(self):
        self.assertEqual(classify({"status":"falhou", "detail":"HTTP 404"}), "link_nao_encontrado")
    def test_ok(self):
        self.assertEqual(classify({"status":"funcionando", "detail":"Mídia acessível"}), "prioridade_player")
    def test_count(self):
        _, summary = analyze([{"status":"falhou","detail":"HTTP 403"}, {"status":"falhou","detail":"HTTP 404"}])
        self.assertEqual(summary["acesso_restrito"],1)
        self.assertEqual(summary["link_nao_encontrado"],1)

if __name__ == "__main__":
    unittest.main()
