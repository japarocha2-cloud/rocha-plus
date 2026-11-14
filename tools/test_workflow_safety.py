"""Static contract for workflows that can reach production accounts or payments.

Text-only checks (no YAML dependency, nothing is executed). Runs in CI through
`python3 -m unittest discover -s tools`.
"""
import re
import unittest
from pathlib import Path

WORKFLOWS = Path(__file__).resolve().parents[1] / ".github" / "workflows"
PROD_SECRET = re.compile(
    r"secrets\s*(?:\.\s*|\[\s*['\"])(?:FIREBASE_SERVICE_ACCOUNT_JSON|MP_ACCESS_TOKEN)\b"
    r"|secrets:\s*inherit")
# Events that can start a run without a deliberate manual dispatch.
AUTOMATIC_EVENTS = ("push", "pull_request", "pull_request_target", "workflow_run",
                    "issue_comment", "release", "repository_dispatch")
# Scheduled read-only audits reviewed on 2026-11-14.
SCHEDULE_ALLOWLIST = {"spark-all-readiness.yml"}
WRITE_ENVIRONMENT = "environment: producao-contas-escrita"
# Workflows reviewed on 2026-11-14 that may name the production project.
PROD_PROJECT_ALLOWLIST = {
    "owner-exemption-apply.yml",
    "resolve-test-account.yml",
    "single-account-diagnosis.yml",
    "spark-all-readiness.yml",
}
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")


def workflows():
    return sorted(WORKFLOWS.glob("*.yml"))


def uses_production_secrets(text: str) -> bool:
    return bool(PROD_SECRET.search(text))


def trigger_names(text: str) -> set:
    """Event names from `on:` in block, list or scalar form."""
    match = re.search(r"^['\"]?on['\"]?\s*:(.*?)(?=^\S|\Z)", text, re.M | re.S)
    if not match:
        return set()
    block = match.group(1)
    first, _, rest = block.partition("\n")
    names = set(re.findall(r"[A-Za-z_]+", first.split("#")[0]))
    names |= set(re.findall(r"(?m)^ {2}([A-Za-z_]+)\s*:", rest))
    names |= set(re.findall(r"(?m)^ {2}-\s*([A-Za-z_]+)", rest))
    return names


class WorkflowSafetyTest(unittest.TestCase):
    def test_production_secrets_only_run_manually(self):
        for path in workflows():
            text = path.read_text(encoding="utf-8")
            if uses_production_secrets(text):
                with self.subTest(workflow=path.name):
                    names = trigger_names(text)
                    self.assertTrue(names, "could not read triggers")
                    self.assertFalse(names & set(AUTOMATIC_EVENTS), names)
                    if "schedule" in names:
                        self.assertIn(path.name, SCHEDULE_ALLOWLIST)
                        self.assertNotIn("--apply", text)

    def test_trigger_parser_reads_inline_and_list_forms(self):
        self.assertEqual(trigger_names("on: push\njobs:\n"), {"push"})
        self.assertEqual(trigger_names("on: [push, workflow_dispatch]\njobs:\n"),
                         {"push", "workflow_dispatch"})
        self.assertEqual(trigger_names("'on':\n  push:\n    branches: [main]\njobs:\n"), {"push"})

    def test_production_writes_require_reviewed_environment(self):
        for path in workflows():
            text = path.read_text(encoding="utf-8")
            if "--apply" in text and uses_production_secrets(text):
                with self.subTest(workflow=path.name):
                    self.assertIn(WRITE_ENVIRONMENT, text)

    def test_operator_uids_are_validated_before_apply(self):
        for path in workflows():
            text = path.read_text(encoding="utf-8")
            if "target_uid" in text and "--apply" in text:
                with self.subTest(workflow=path.name):
                    self.assertIn("^[a-zA-Z0-9_-]{1,128}$", text)
                    self.assertIn('"$TARGET_UID" != "$CONFIRM_UID"', text)
                    # Validation must precede checkout and every secret use.
                    validate = text.index("Validate operator input")
                    self.assertLess(validate, text.index("actions/checkout"))
                    self.assertLess(validate, PROD_SECRET.search(text).start())

    def test_no_personal_email_in_workflows(self):
        for path in workflows():
            found = [m for m in EMAIL.findall(path.read_text(encoding="utf-8"))
                     if not m.endswith(".iam.gserviceaccount.com")]
            with self.subTest(workflow=path.name):
                self.assertEqual(found, [], "store e-mails as secrets")

    def test_production_project_only_in_reviewed_workflows(self):
        for path in workflows():
            text = path.read_text(encoding="utf-8")
            if re.search(r"--project rocha-plus\b|projectId:'rocha-plus'", text):
                with self.subTest(workflow=path.name):
                    self.assertIn(path.name, PROD_PROJECT_ALLOWLIST)


if __name__ == "__main__":
    unittest.main()
