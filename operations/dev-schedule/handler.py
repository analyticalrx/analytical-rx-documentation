"""Scheduled lifecycle of the two fixed Phase 1 dev resources."""
import datetime as dt
import json
import boto3

REGION = 'us-east-1'
DB = 'analytical-rx-phase1-dev-db'
INSTANCE = 'i-0ee64eae7d8505bfc'
PROXIES = ('processor-lambda-iam-auth-proxy',)
rds = boto3.client('rds', region_name=REGION)
ec2 = boto3.client('ec2', region_name=REGION)
ssm = boto3.client('ssm', region_name=REGION)
cw = boto3.client('cloudwatch', region_name=REGION)


def idle_check():
    now = dt.datetime.now(dt.timezone.utc)
    # Exclude the newest two minutes to allow CloudWatch publication to finish.
    end = (now - dt.timedelta(minutes=2)).replace(second=0, microsecond=0)
    start = end - dt.timedelta(minutes=15)
    for proxy in PROXIES:
        points = cw.get_metric_statistics(
            Namespace='AWS/RDS', MetricName='ClientConnections',
            Dimensions=[{'Name': 'ProxyName', 'Value': proxy}],
            StartTime=start, EndTime=end, Period=60, Statistics=['Maximum'],
        )['Datapoints']
        # Require all completed minutes. A missing minute is not proof of idleness.
        stamps = {p['Timestamp'] for p in points}
        expected = {start + dt.timedelta(minutes=i) for i in range(15)}
        if not expected.issubset(stamps):
            return False, f'{proxy}: incomplete recent client-connection data'
        if any(p['Maximum'] > 0 for p in points):
            return False, f'{proxy}: recent client connections detected'
    return True, 'The processor proxy has reported zero clients for the completed window'


def sessions_active():
    return bool(ssm.describe_sessions(
        State='Active', Filters=[{'key': 'Target', 'value': INSTANCE}], MaxResults=1
    ).get('Sessions'))


def handler(event, context):
    action = event.get('action')
    if action not in ('start', 'stop', 'check'):
        raise ValueError('action must be start, stop, or check')
    dry_run = event.get('dry_run', False)
    if not isinstance(dry_run, bool):
        raise ValueError('dry_run must be boolean')
    database = rds.describe_db_instances(DBInstanceIdentifier=DB)['DBInstances'][0]['DBInstanceStatus']
    instance = ec2.describe_instances(InstanceIds=[INSTANCE])['Reservations'][0]['Instances'][0]['State']['Name']
    result = {'action': action, 'dry_run': dry_run, 'database': database, 'tunnel': instance}
    if action == 'start':
        if database not in ('available', 'starting', 'stopped'):
            raise RuntimeError(f'Database in unexpected state: {database}')
        if instance not in ('running', 'pending', 'stopped'):
            raise RuntimeError(f'Tunnel in unexpected state: {instance}')
        if not dry_run:
            if database == 'stopped':
                rds.start_db_instance(DBInstanceIdentifier=DB)
            if instance == 'stopped':
                ec2.start_instances(InstanceIds=[INSTANCE])
    elif action == 'check':
        ready = database == 'available' and instance == 'running'
        for proxy in PROXIES:
            targets = rds.describe_db_proxy_targets(DBProxyName=proxy)['Targets']
            ready = ready and bool(targets) and all(t.get('TargetHealth', {}).get('State') == 'AVAILABLE' for t in targets)
        agents = ssm.describe_instance_information(Filters=[{'Key': 'InstanceIds', 'Values': [INSTANCE]}])['InstanceInformationList']
        ready = ready and bool(agents) and agents[0].get('PingStatus') == 'Online'
        if not ready:
            raise RuntimeError('Morning readiness check failed: ' + json.dumps(result))
        result['ready'] = True
    else:
        safe, reason = (False, 'Active SSM tunnel session') if sessions_active() else (True, 'No active SSM sessions')
        if safe and database == 'available':
            safe, reason = idle_check()
        elif database not in ('available', 'stopped'):
            safe, reason = False, f'Database is {database}'
        # Last session check immediately before issuing lifecycle operations.
        if safe and sessions_active():
            safe, reason = False, 'SSM session started during activity checks'
        result.update(safe_to_stop=safe, reason=reason)
        if not dry_run:
            cw.put_metric_data(Namespace='AnalyticalRx/DevSchedule', MetricData=[
                {'MetricName': 'ShutdownSkipped', 'Value': 0 if safe else 1, 'Unit': 'Count'}
            ])
            if safe:
                if database == 'available':
                    rds.stop_db_instance(DBInstanceIdentifier=DB)
                if instance == 'running':
                    ec2.stop_instances(InstanceIds=[INSTANCE])
    print(json.dumps(result))
    return result
