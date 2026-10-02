import unittest
from unittest.mock import patch
import monitor
import health


class MonitorTests(unittest.TestCase):
    def test_debounce_recovery_and_repeat(self):
        state = {}
        for tick in (0, 30):
            self.assertIsNone(monitor.transition(state, ["dns"], tick))
        self.assertIn("CRITICAL", monitor.transition(state, ["dns"], 60))
        state.update(incident=True, sent=60)
        self.assertIsNone(monitor.transition(state, ["dns"], 90))
        self.assertIn("CRITICAL", monitor.transition(state, ["dns"], 1860))
        self.assertIsNone(monitor.transition(state, [], 1890))
        self.assertIn("RECOVERY", monitor.transition(state, [], 1920))

    def test_delivery_failure_retries_without_marking_sent(self):
        state = {}
        for tick in (0, 30, 60, 90):
            event = monitor.transition(state, ["handshake"], tick)
        self.assertIn("CRITICAL", event)
        self.assertNotIn("sent", state)
        self.assertNotIn("incident", state)

    def test_health_checks_fail_closed_without_exception_details(self):
        with patch.object(health, "run", side_effect=RuntimeError("sensitive raw error")):
            result = health.health()
        self.assertEqual(result, {"handshake": False, "dns": False, "mullvad_exit": False, "tailscale": False})

    def test_all_checks_healthy(self):
        with patch.object(health, "run", side_effect=["public-peer 950\n", "1.2.3.4\n", '{"mullvad_exit_ip":true}', '{"BackendState":"Running","Self":{"Online":true}}']), patch.object(health.time, "time", return_value=1000):
            self.assertTrue(all(health.health().values()))


if __name__ == "__main__":
    unittest.main()
