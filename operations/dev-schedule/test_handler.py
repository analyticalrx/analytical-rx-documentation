"""Safety checks without AWS credentials or lifecycle calls."""
import importlib.util
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch


class SafetyTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('schedule_worker', Path(__file__).with_name('handler.py'))
        self.worker = importlib.util.module_from_spec(spec)
        clients = {name: MagicMock() for name in ('rds', 'ec2', 'ssm', 'cloudwatch')}
        with patch.dict(sys.modules, {'boto3': types.SimpleNamespace(client=lambda name, **kw: clients[name])}):
            spec.loader.exec_module(self.worker)
        self.w = self.worker
        self.w.rds.describe_db_instances.return_value = {'DBInstances': [{'DBInstanceStatus': 'available'}]}
        self.w.ec2.describe_instances.return_value = {'Reservations': [{'Instances': [{'State': {'Name': 'running'}}]}]}
        self.w.ssm.describe_sessions.return_value = {'Sessions': []}
        self.w.cw.get_metric_statistics.side_effect = lambda **kw: {'Datapoints': [
            {'Timestamp': kw['StartTime'] + self.w.dt.timedelta(minutes=i), 'Maximum': 0} for i in range(15)
        ]}

    def assert_no_stop(self):
        self.w.rds.stop_db_instance.assert_not_called()
        self.w.ec2.stop_instances.assert_not_called()

    def test_dry_run_checks_usage_without_stopping(self):
        result = self.w.handler({'action': 'stop', 'dry_run': True}, None)
        self.assertTrue(result['safe_to_stop'])
        self.assertEqual(self.w.cw.get_metric_statistics.call_count, len(self.w.PROXIES))
        self.assert_no_stop()
        self.w.cw.put_metric_data.assert_not_called()

    def test_missing_data_blocks_shutdown(self):
        self.w.cw.get_metric_statistics.side_effect = None
        self.w.cw.get_metric_statistics.return_value = {'Datapoints': []}
        self.assertFalse(self.w.handler({'action': 'stop'}, None)['safe_to_stop'])
        self.assert_no_stop()

    def test_busy_proxy_blocks_shutdown(self):
        original = self.w.cw.get_metric_statistics.side_effect
        def busy(**kw):
            points = original(**kw)
            points['Datapoints'][4]['Maximum'] = 1
            return points
        self.w.cw.get_metric_statistics.side_effect = busy
        self.assertFalse(self.w.handler({'action': 'stop'}, None)['safe_to_stop'])
        self.assert_no_stop()

    def test_direct_developer_session_blocks_shutdown_before_metrics(self):
        self.w.ssm.describe_sessions.return_value = {'Sessions': [{'SessionId': 'developer'}]}
        self.assertFalse(self.w.handler({'action': 'stop'}, None)['safe_to_stop'])
        self.w.cw.get_metric_statistics.assert_not_called()
        self.assert_no_stop()

    def test_new_session_during_checks_blocks_shutdown(self):
        self.w.ssm.describe_sessions.side_effect = [{'Sessions': []}, {'Sessions': [{'SessionId': 'new'}]}]
        self.assertFalse(self.w.handler({'action': 'stop'}, None)['safe_to_stop'])
        self.assert_no_stop()

    def test_idle_resources_stop_only_fixed_identifiers(self):
        self.assertTrue(self.w.handler({'action': 'stop'}, None)['safe_to_stop'])
        self.w.rds.stop_db_instance.assert_called_once_with(DBInstanceIdentifier=self.w.DB)
        self.w.ec2.stop_instances.assert_called_once_with(InstanceIds=[self.w.INSTANCE])

    def test_start_running_resources_is_noop(self):
        self.w.handler({'action': 'start'}, None)
        self.w.rds.start_db_instance.assert_not_called()
        self.w.ec2.start_instances.assert_not_called()
        self.assert_no_stop()


if __name__ == '__main__':
    unittest.main()
