# Monitoring, Logging & Observability

## Overview

This document explains the monitoring and observability strategy for the microservices application on AWS EKS.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                     EKS Cluster                          │
│  ┌────────────┐  ┌────────────┐  ┌──────────────┐      │
│  │  Frontend  │  │  Backend   │  │  PostgreSQL  │      │
│  │    Pods    │  │    Pods    │  │ StatefulSet  │      │
│  └─────┬──────┘  └─────┬──────┘  └──────┬───────┘      │
│        │               │                 │               │
│        └───────────────┴─────────────────┘               │
│                        │                                 │
│                        │ Logs & Metrics                  │
│                        ▼                                 │
│          ┌──────────────────────────┐                   │
│          │     Fluent Bit           │                   │
│          │  (DaemonSet on nodes)    │                   │
│          └────────────┬─────────────┘                   │
└───────────────────────┼──────────────────────────────────┘
                        │
                        │ Streams logs/metrics
                        ▼
        ┌────────────────────────────────┐
        │    AWS CloudWatch Logs         │
        │    - Container Insights        │
        │    - Application Logs          │
        │    - Performance Metrics       │
        └────────────┬───────────────────┘
                     │
                     │ CloudWatch Alarms
                     ▼
        ┌────────────────────────────────┐
        │    SNS / Email / Slack         │
        │    Alert Notifications         │
        └────────────────────────────────┘
```

## CloudWatch Container Insights

### Setup

Container Insights is installed via the infrastructure repository:

```bash
# Deployed via Terraform/Ansible
aws eks update-cluster-config \
  --name devsecops-dev-eks \
  --region us-east-1 \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'
```

### What Container Insights Provides

1. **Cluster-Level Metrics**
   - Node CPU/Memory utilization
   - Pod count
   - Namespace resource usage

2. **Node-Level Metrics**
   - CPU utilization per node
   - Memory utilization per node
   - Disk I/O
   - Network traffic

3. **Pod-Level Metrics**
   - CPU usage per pod
   - Memory usage per pod
   - Restart counts
   - Pod status

4. **Container-Level Metrics**
   - Per-container CPU
   - Per-container memory
   - Container restart count

### Accessing Container Insights

**AWS Console**:
```
CloudWatch → Container Insights → EKS Cluster: devsecops-dev-eks
```

**CloudWatch Logs Groups**:
```
/aws/containerinsights/devsecops-dev-eks/application
/aws/containerinsights/devsecops-dev-eks/dataplane
/aws/containerinsights/devsecops-dev-eks/host
/aws/containerinsights/devsecops-dev-eks/performance
```

## Application Logging

### Log Collection with Fluent Bit

Fluent Bit runs as a DaemonSet and forwards logs to CloudWatch.

**Installation** (via Helm/infra repo):
```bash
helm install fluent-bit eks/aws-for-fluent-bit \
  --namespace kube-system \
  --set cloudWatch.enabled=true \
  --set cloudWatch.region=us-east-1 \
  --set cloudWatch.logGroupName=/aws/eks/devsecops-dev/application
```

### Application Log Format

**Backend (Python/Flask)**:
```python
import logging
import json

# Structured logging for CloudWatch
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Log in JSON format for parsing
def log_request(request_id, user, action):
    logger.info(json.dumps({
        "request_id": request_id,
        "user": user,
        "action": action,
        "timestamp": datetime.utcnow().isoformat()
    }))
```

**Frontend (JavaScript)**:
```javascript
// Log to console (captured by Fluent Bit)
console.log(JSON.stringify({
  level: "INFO",
  message: "User action",
  userId: userId,
  timestamp: new Date().toISOString()
}));
```

### Viewing Application Logs

**CloudWatch Logs Insights**:
```
# Query backend errors
fields @timestamp, @message
| filter @logStream like /backend/
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20

# Query slow requests
fields @timestamp, request_id, duration
| filter duration > 1000
| sort duration desc
```

**CLI**:
```bash
aws logs tail /aws/eks/devsecops-dev/application --follow
```

## Metrics Collection

### Key Metrics to Monitor

#### 1. Pod Health
```yaml
Metric: kube_pod_status_phase
Alert: Pod not Running for > 5 minutes
```

#### 2. CPU Usage
```yaml
Metric: container_cpu_usage_seconds_total
Threshold: > 80% for 5 minutes
Action: Alert + consider scaling
```

#### 3. Memory Usage
```yaml
Metric: container_memory_working_set_bytes
Threshold: > 85% of limit
Action: Alert + check for memory leaks
```

#### 4. Pod Restarts
```yaml
Metric: kube_pod_container_status_restarts_total
Threshold: > 3 restarts in 10 minutes
Action: Critical alert (CrashLoopBackOff)
```

#### 5. Database Connections
```yaml
Metric: postgresql_connections_active
Threshold: > 80% of max_connections
Action: Alert + check connection pooling
```

### Custom Metrics

**Backend exposes /metrics endpoint**:
```python
from prometheus_client import Counter, Histogram, generate_latest

# Request counter
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint'])

# Request duration
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration')

@app.route('/metrics')
def metrics():
    return generate_latest()
```

**Metrics Server collects**:
```bash
kubectl top nodes
kubectl top pods -n dev
```

## CloudWatch Alarms

### Critical Alarms

#### 1. High Pod CPU
```yaml
AlarmName: HighPodCPU
MetricName: pod_cpu_utilization
Threshold: > 80%
EvaluationPeriods: 2
Period: 300 (5 minutes)
Action: SNS notification
```

#### 2. High Pod Memory
```yaml
AlarmName: HighPodMemory
MetricName: pod_memory_utilization
Threshold: > 85%
EvaluationPeriods: 2
Action: SNS + auto-scale pods
```

#### 3. Pod CrashLoopBackOff
```yaml
AlarmName: PodCrashLoop
MetricName: pod_restart_count
Threshold: > 3 restarts in 10min
Action: Critical SNS alert
```

#### 4. Database Connection Saturation
```yaml
AlarmName: DBConnectionsHigh
MetricName: postgresql_connections_percent
Threshold: > 80%
Action: SNS notification
```

#### 5. HTTP Error Rate
```yaml
AlarmName: HighErrorRate
MetricName: http_5xx_count
Threshold: > 10 errors/minute
Action: Critical alert
```

### Setting Up Alarms (Terraform)
```hcl
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "eks-pod-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "pod_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when pod CPU exceeds 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    ClusterName = "devsecops-dev-eks"
    Namespace   = "dev"
  }
}
```

## Dashboard Creation

### CloudWatch Dashboard

Create a unified dashboard:
```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "title": "Pod CPU Utilization",
        "metrics": [
          ["ContainerInsights", "pod_cpu_utilization", {"stat": "Average"}]
        ],
        "period": 300,
        "region": "us-east-1"
      }
    },
    {
      "type": "log",
      "properties": {
        "query": "SOURCE '/aws/eks/devsecops-dev/application' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20",
        "region": "us-east-1",
        "title": "Recent Errors"
      }
    }
  ]
}
```

## Optional: Prometheus + Grafana Stack

### Benefits Over CloudWatch
- More granular metrics
- Better query language (PromQL)
- Open-source, no AWS lock-in
- Rich visualization with Grafana

### Installation
```bash
# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

### Access Grafana
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open http://localhost:3000
# Default: admin / prom-operator
```

### Prebuilt Dashboards
Import these Grafana dashboards:
- Dashboard 315: Kubernetes cluster monitoring
- Dashboard 1471: Kubernetes deployment
- Dashboard 13639: PostgreSQL

## Log Aggregation Strategy

### Log Retention
```yaml
CloudWatch Log Groups:
  /aws/eks/devsecops-dev/application:
    Retention: 30 days
  
  /aws/eks/devsecops-dev/dataplane:
    Retention: 7 days
  
  /aws/eks/devsecops-dev/performance:
    Retention: 14 days
```

### Log Shipping to S3 (Long-term Storage)
```hcl
resource "aws_cloudwatch_log_subscription_filter" "logs_to_s3" {
  name            = "eks-logs-to-s3"
  log_group_name  = "/aws/eks/devsecops-dev/application"
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs.arn
}

resource "aws_kinesis_firehose_delivery_stream" "logs" {
  name        = "eks-logs-firehose"
  destination = "s3"
  
  s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = aws_s3_bucket.logs.arn
    prefix     = "eks-logs/"
  }
}
```

## Distributed Tracing (Optional)

### AWS X-Ray Integration
```yaml
# Enable X-Ray for request tracing
apiVersion: v1
kind: ConfigMap
metadata:
  name: xray-config
data:
  config.yaml: |
    region: us-east-1
    log_level: info
```

**Backend instrumentation**:
```python
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.ext.flask.middleware import XRayMiddleware

app = Flask(__name__)
xray_recorder.configure(service='backend-service')
XRayMiddleware(app, xray_recorder)
```

## Health Checks

### Liveness Probes
Defined in Helm templates:
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 5000
  initialDelaySeconds: 30
  periodSeconds: 10
```

### Readiness Probes
```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 5000
  initialDelaySeconds: 15
  periodSeconds: 5
```

### Health Endpoint Implementation
```python
@app.route('/health')
def health():
    # Basic health check
    return {'status': 'healthy'}, 200

@app.route('/ready')
def readiness():
    # Check database connection
    try:
        db.session.execute('SELECT 1')
        return {'status': 'ready', 'database': 'connected'}, 200
    except Exception as e:
        return {'status': 'not ready', 'error': str(e)}, 503
```

## Monitoring Checklist

### Daily
- [ ] Check CloudWatch dashboard
- [ ] Review error logs
- [ ] Verify pod health

### Weekly
- [ ] Analyze performance trends
- [ ] Review resource utilization
- [ ] Check alarm history

### Monthly
- [ ] Review log retention policies
- [ ] Optimize CloudWatch costs
- [ ] Update alerting thresholds

## Cost Optimization

### CloudWatch Costs
```
Logs ingestion: $0.50 per GB
Logs storage:   $0.03 per GB/month
Metrics:        $0.30 per metric/month
Alarms:         $0.10 per alarm/month
```

### Reduce Costs
1. Filter unnecessary logs in Fluent Bit
2. Aggregate metrics (1min → 5min intervals)
3. Use S3 for long-term log storage
4. Delete unused metric filters

## Conclusion

Monitoring stack provides:
- ✅ Container Insights for cluster visibility
- ✅ CloudWatch Logs for centralized logging
- ✅ Metrics for performance tracking
- ✅ Alarms for proactive alerting
- ✅ Health checks for availability
- ✅ Optional Prometheus/Grafana for advanced users

Full observability into your microservices!
