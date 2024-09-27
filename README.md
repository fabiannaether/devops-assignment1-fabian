# DevOps UE: Assignment 2<br>Docker and Dockerfile deploy to a local K8s cluster

## Objective

**Assignment objective:** Gain insights into Kubernetes and container orchestration.<br>
**Key concepts:** Pods, ReplicaSets, and Deployments in Kubernetes.<br>
**Requirements:** Utilize a local Kubernetes cluster (e.g., Kind, Rancher).

## Task

- Deploy a containerized web application on your local Kubernetes cluster.
- Implement a rolling update strategy for zero-downtime deployments.
- Scale the application by adjusting replica counts using Kubernetes commands.
- The application should be accessed by your local machine.

## Solution

### 1. Add a liveness / health endpoint in the web app

- Add a `health.ts` file to provide a liveness and readiness check for Kubernetes

  - Created file at `src/pages/api/health.ts` with the following content:

  ```
  export default function handler(req, res) {
    res.status(200).json({ status: "ok" });
  }
  ```

  - Update `next.config.js` to include the health endpoint rewrite:

  ```
  rewrites: async () => {
    return [
      {
        source: "/health",
        destination: "/api/health",
      },
    ];
  },
  ```

### 2. Push the web app to a image registry (DockerHub)

**Merge pull request from f/assignment2 to release pipeline using GitHub Actions:**

- Build the Docker image for the web app
- Push the Docker image to DockerHub, ensuring it is available for the Kubernetes cluster deployment

### 3. Scaling strategies

1. Rolling update strategy

- The deployment is configured with a rolling update strategy to gradually replace Pods, ensuring zero downtime during the process.

2. Horizontal Pod Autoscaler (HPA)

- Configure a `nextjs-hpa.yaml` file to monitor CPU utilization and automatically scale the number of replicas between 3 and 10.
- This ensures that the application can handle increased traffic without downtime while maintaining optimal resource utilization.

### 4. How to assert that the deployment works as expected?

1. Apply Kubernetes configuration files

```
kubectl apply -f k8s/nextjs-deployment.yaml
kubectl apply -f k8s/nextjs-service.yaml
kubectl apply -f k8s/nextjs-hpa.yaml
```

2. Access test

- Open `http://localhost:3000` in a browser to confirm that the web application is accessible on my local machine.

3. Health check

- Access the `/health` endpoint (`http://localhost:3000/health`) to ensure that the web application is running and healthy.

4. Benchmarking the application

- Use Apache Benchmark (`ab`) to test the application's performance:
  ```
  ab -n 10000 -c 100 http://localhost:3000/
  ```
- There were no failed requests and the application handled the load efficiently.

  ```
  Benchmarking localhost (be patient)
  Completed 1000 requests
  Completed 2000 requests
  Completed 3000 requests
  Completed 4000 requests
  Completed 5000 requests
  Completed 6000 requests
  Completed 7000 requests
  Completed 8000 requests
  Completed 9000 requests
  Completed 10000 requests
  Finished 10000 requests

  Server Software:
  Server Hostname:        localhost
  Server Port:            3000

  Document Path:          /
  Document Length:        176788 bytes

  Concurrency Level:      100
  Time taken for tests:   41.527 seconds
  Complete requests:      10000
  Failed requests:        0
  Total transferred:      1771270000 bytes
  HTML transferred:       1767880000 bytes
  Requests per second:    240.81 [#/sec] (mean)
  Time per request:       415.266 [ms] (mean)
  Time per request:       4.153 [ms] (mean, across all concurrent requests)
  Transfer rate:          41654.12 [Kbytes/sec] received

  Connection Times (ms)
                min   mean[+/-sd]   median   max
  Connect:        0       0   0.5        0     2
  Processing:    10     407 301.7      393  3029
  Waiting:        8     403 300.2      390  3025
  Total:         10     407 301.7      393  3029

  Percentage of the requests served within a certain time (ms)
    50%    393
    66%    488
    75%    530
    80%    553
    90%    633
    95%    726
    98%    908
    99%   1668
    100%  3029 (longest request)
  ```

5. Scaling verification

- Monitor the Horizontal Pod Autoscaler using `kubectl get hpa` to verify that the number of replicas adjusted correctly based on CPU usage.

```
NAME                 REFERENCE                          TARGETS         MINPODS   MAXPODS   REPLICAS
startup-nextjs-hpa   Deployment/startup-nextjs-fabian   <unknown>/50%   3         10        0
```

### 5. YAML files

1. Deployment YAML (`k8s/nextjs-deployment.yaml`)

- The `nextjs-deployment.yaml` defines the deployment with a rolling update strategy, liveness and readiness probes.

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: startup-nextjs-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: startup-nextjs-fabian
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: startup-nextjs-fabian
    spec:
      containers:
        - name: startup-nextjs-fabian
          image: fabiannaether/startup-nextjs-fabian:latest
          ports:
            - containerPort: 3000
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 15
            periodSeconds: 20
```

2. Service YAML (`k8s/nextjs-service.yaml`)

- The `nextjs-service.yaml` defines a LoadBalancer service to expose the application, enabling access from outside the Kubernetes cluster.

```
apiVersion: v1
kind: Service
metadata:
  name: startup-nextjs-service
spec:
  selector:
    app: startup-nextjs-fabian
  ports:
    - protocol: TCP
      port: 3000
      targetPort: 3000
  type: LoadBalancer
```

3. Horizontal Pod Autoscaler YAML (`k8s/nextjs-hpa.yaml`)

- The `nextjs-hpa.yaml` configures the HPA to scale based on CPU utilization.

```
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: startup-nextjs-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: startup-nextjs-fabian
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 50
```

**Desired behaviour:**

The desired behaviour for this deployment is to have a responsive, scalable web application that maintains zero-downtime and adjusts according to traffic:

1. Zero downtime

- The `RollingUpdate` strategy with `maxSurge: 1` and `maxUnavailable: 0` ensures that at least one new Pod is created before an old Pod is terminated, preventing any service disruption.

2. Scalability

- The `HorizontalPodAutoscaler` (HPA) is set up to monitor CPU usage and scale replicas between 3 and 10, ensuring that the application can handle varying traffic loads efficiently.

3. Liveness and Readiness Probes

- The liveness and readiness probes monitor the application's health at `/health` to ensure that the Pods are ready to serve traffic.

4. Monitoring the HPA

- By running `kubectl get hpa`, I can verify that the HPA is scaling the application correctly based on the CPU utilization metrics.

## Contributor

Fabian Näther
