import json
from pathlib import Path
p=Path(__file__).resolve().parent
account='209556026827';region='us-east-1'
get=lambda resource: {'Fn::GetAtt':[resource,'Arn']}
trust=lambda service: {'Version':'2012-10-17','Statement':[{'Effect':'Allow','Principal':{'Service':service},'Action':'sts:AssumeRole'}]}
stmt=lambda actions,resource: {'Effect':'Allow','Action':actions,'Resource':resource}
r={}
r['Logs']={'Type':'AWS::Logs::LogGroup','Properties':{'LogGroupName':'/aws/lambda/analyticalrx-phase1-dev-schedule','RetentionInDays':14}}
r['WorkerRole']={'Type':'AWS::IAM::Role','Properties':{'AssumeRolePolicyDocument':trust('lambda.amazonaws.com'),'Policies':[{'PolicyName':'FixedDevResources','PolicyDocument':{'Version':'2012-10-17','Statement':[
 stmt(['rds:DescribeDBInstances','rds:DescribeDBProxyTargets','ec2:DescribeInstances','ssm:DescribeSessions','ssm:DescribeInstanceInformation','cloudwatch:GetMetricStatistics'],'*'),
 stmt(['cloudwatch:PutMetricData'],'*') | {'Condition':{'StringEquals':{'cloudwatch:namespace':'AnalyticalRx/DevSchedule'}}},
 stmt(['rds:StartDBInstance','rds:StopDBInstance'],f'arn:aws:rds:{region}:{account}:db:analytical-rx-phase1-dev-db'),
 stmt(['ec2:StartInstances','ec2:StopInstances'],f'arn:aws:ec2:{region}:{account}:instance/i-0ee64eae7d8505bfc'),
 stmt(['logs:CreateLogStream','logs:PutLogEvents'],f'arn:aws:logs:{region}:{account}:log-group:/aws/lambda/analyticalrx-phase1-dev-schedule:*')
]}}]}}
r['Worker']={'Type':'AWS::Lambda::Function','DependsOn':'Logs','Properties':{'FunctionName':'analyticalrx-phase1-dev-schedule','Handler':'index.handler','Runtime':'python3.12','Role':get('WorkerRole'),'Timeout':120,'MemorySize':128,'Code':{'ZipFile':(p/'handler.py').read_text()}}}
r['AsyncConfig']={'Type':'AWS::Lambda::EventInvokeConfig','Properties':{'FunctionName':{'Ref':'Worker'},'Qualifier':'$LATEST','MaximumEventAgeInSeconds':300,'MaximumRetryAttempts':0}}
r['ScheduleGroup']={'Type':'AWS::Scheduler::ScheduleGroup','Properties':{'Name':'analyticalrx-phase1-dev'}}
r['ScheduleRole']={'Type':'AWS::IAM::Role','Properties':{'AssumeRolePolicyDocument':{'Version':'2012-10-17','Statement':[{'Effect':'Allow','Principal':{'Service':'scheduler.amazonaws.com'},'Action':'sts:AssumeRole','Condition':{'StringEquals':{'aws:SourceAccount':account},'ArnEquals':{'aws:SourceArn':get('ScheduleGroup')}}}]},'Policies':[{'PolicyName':'InvokeDevWorkerOnly','PolicyDocument':{'Version':'2012-10-17','Statement':[stmt(['lambda:InvokeFunction'],get('Worker'))]}}]}}
for name,action,cron in [('Start','start','cron(30 8 ? * MON-FRI *)'),('Stop','stop','cron(0 1 * * ? *)'),('Ready','check','cron(15 9 ? * MON-FRI *)')]:
 r[name+'Schedule']={'Type':'AWS::Scheduler::Schedule','Properties':{'Name':'analyticalrx-phase1-dev-'+action,'GroupName':{'Ref':'ScheduleGroup'},'ScheduleExpression':cron,'ScheduleExpressionTimezone':'Asia/Kolkata','FlexibleTimeWindow':{'Mode':'OFF'},'State':'ENABLED','Target':{'Arn':get('Worker'),'RoleArn':get('ScheduleRole'),'Input':json.dumps({'action':action}),'RetryPolicy':{'MaximumEventAgeInSeconds':300,'MaximumRetryAttempts':2}}}}
for name,namespace,metric,dimensions in [('Failures','AWS/Lambda','Errors',[{'Name':'FunctionName','Value':{'Ref':'Worker'}}]),('Skipped','AnalyticalRx/DevSchedule','ShutdownSkipped',[])]:
 r[name+'Alarm']={'Type':'AWS::CloudWatch::Alarm','Properties':{'AlarmName':'analyticalrx-phase1-dev-schedule-'+name.lower(),'Namespace':namespace,'MetricName':metric,'Dimensions':dimensions,'Statistic':'Sum','Period':300,'EvaluationPeriods':1,'Threshold':1,'ComparisonOperator':'GreaterThanOrEqualToThreshold','TreatMissingData':'notBreaching'}}
t={'AWSTemplateFormatVersion':'2010-09-09','Description':'Guarded weekday development lifecycle for fixed Phase 1 database and tunnel. Proxies are preserved.','Resources':r,'Outputs':{'WorkerArn':{'Value':get('Worker')},'ScheduleGroup':{'Value':{'Ref':'ScheduleGroup'}}}}
(p/'stack.json').write_text(json.dumps(t,indent=2)+'\n')
compile((p/'handler.py').read_text(),str(p/'handler.py'),'exec')
print('Template and Lambda source prepared')
