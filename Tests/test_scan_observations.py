"""Fixture scan evidence tests. No real OS queries or host changes."""
import subprocess
import unittest
from unittest.mock import patch

from test_guest_boundary import toolkit


class ObservationTests(unittest.TestCase):
    def test_failed_unrecognized_and_timed_out_queries_are_unknown(self):
        for code, output in [(1, 'enabled'), (127, ''), (0, ''), (0, 'unrecognized')]:
            with self.subTest(code=code, output=output), patch.object(
                    toolkit.subprocess, 'run', return_value=subprocess.CompletedProcess('fixture', code, output, '')):
                self.assertIsNone(toolkit.query_state('fixture', ['enabled'], ['disabled']))
        with patch.object(toolkit.subprocess, 'run', side_effect=subprocess.TimeoutExpired('fixture', 6)):
            self.assertIsNone(toolkit.query_state('fixture', ['enabled'], ['disabled']))

    def test_recognized_states(self):
        for output, expected in [('enabled', True), ('disabled', False), ('not enabled', False)]:
            with patch.object(toolkit.subprocess, 'run', return_value=subprocess.CompletedProcess('fixture', 0, output, '')):
                self.assertIs(toolkit.query_state('fixture', ['enabled'], ['disabled', 'not enabled']), expected)

    def test_mac_missing_checks_never_become_disabled_findings(self):
        with patch.object(toolkit, 'query_state', return_value=None), \
                patch.object(toolkit, 'run_cmd', return_value=''), \
                patch.object(toolkit, 'low_disk_finding', return_value=0), \
                patch.object(toolkit, 'risky_extensions', return_value=[]), \
                patch.object(toolkit.os.path, 'isdir', return_value=False), \
                patch.object(toolkit, 'result', side_effect=lambda *args: args):
            observed = toolkit.invoke_mac_scan()
        self.assertEqual(observed[2], [])
        self.assertTrue(all(state is None for state in observed[3].values()))

    def test_linux_missing_checks_do_not_claim_unencrypted_or_disabled(self):
        with patch.object(toolkit, 'query_state', return_value=None), \
                patch.object(toolkit, 'run_cmd', return_value=''), \
                patch.object(toolkit, 'linux_secure_boot', return_value=None), \
                patch.object(toolkit, 'low_disk_finding', return_value=0), \
                patch.object(toolkit, 'risky_extensions', return_value=[]), \
                patch.object(toolkit.os.path, 'isdir', return_value=False), \
                patch.object(toolkit, 'result', side_effect=lambda *args: args):
            observed = toolkit.invoke_linux_scan()
        self.assertEqual(observed[2], [])
        self.assertTrue(all(state is None for state in observed[3].values()))


if __name__ == '__main__':
    unittest.main()
