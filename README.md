# DevOps Challenge

This repository contains a simple Flask application.
It uses PostgreSQL as the database of choice.

Application has two endpoints:
- `/users` that list users
- `/health` for healthcheck

Database schema is provided in file `source/init.sql`. You can use it to create a database schema.

Dockerize the application and push it to your choice public Docker Registry.
Deploy this application along with Postgres database to a provided Kubernetes cluster.
For deployment, choose Terraform, Ansible, or both.

---

## Solution

*Note: I have used Terraform for provisioning the infrastructure however
I'm using my private AWS resources for this task, as I wasn't able to spin up
VM's in [cloudscale.ch](https://www.cloudscale.ch/). I guess the invitation link
didn't work as expected.*

Also, due to time constraints and heavy workload in the current project, I'm
submitting the solution in a hurry and in a shabby, unpolished proof-of-concept
state. I hope you understand.

Nonetheless, I managed to complete all the tasks as per the requirements (well,
with some *major* adjustments here and there).

## What's done?

- Updated app code to work with an external PostgreSQL database and send metrics
- Dockerized the Flask application and pushed it to [Docker Hub](https://hub.docker.com/repository/docker/baduker/sherpany/general)
- Created a Kubernetes deployment and service for the Flask application
- Added an external secret operator to fetch the database credentials from AWS Secrets Manager
- Create a grafana VM with grafana agent to collect metrics from the Flask app
- Created a simple dashboard in Grafana to visualize the app metrics

## What's not done?

Well, it's shabby but everything is up and running. I just don't have the time 
to iterate and iron out the kinks. The app is in a very basic state and 
doesn't have any real-world features.

Here's a list of things that I would have done if I had more time:

- First of all, I should have used [cloudscale.ch](https://www.cloudscale.ch/)
  for provisioning the VMs.
- I'm using an out-of-the-box database solution from AWS. I wanted get things
  up and running quickly, so I went with something that I'm familiar with.
- The database is publicly accessible. I should have used a VPN or a bastion
  host to secure the database that would sit in a private subnet.
- I don't have a custom certificate for DB connection. 
I'm using the default [certificate bundle](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html).
- There's no SSL and TLS on the Prometheus and Grafana endpoints.
- The flask app is running only on `gunicon` with 1 worker. It's highly recommended
  to use a reverse proxy like `nginx` in front of the app.
- I'm using AWS Keys instead of a role for the [external-secrets-operator](https://external-secrets.io/v0.12.1/)
- I guess using a private Docker registry would have been a better choice.
- The Grafana dashboard is very basic. I should have added more metrics and
  visualizations.

## How to run?

The app is running on the provided k8s cluster, but it's consuming my private
AWS resources.

- The app is accessible [here](http://74.220.30.241/).
- The `users` endpoint is [here](http://74.220.30.241/users).
- The `health` endpoint is [here](http://74.220.30.241/health).
- THe `metrics` endpoint is [here](http://74.220.30.241/metrics).

All the secrets are stored in AWS Secrets Manager but pulled by the 
`external-secrets-operator` that's running in the cluster in its onw namespace.

You can run the app locally by following these steps:

1. Get the `rds cert bundle` from [here](https://truststore.pki.rds.amazonaws.com/eu-central-1/eu-central-1-bundle.pem)
2. Run the following commands:
3. Populate the `db.env` file with the values from an encrypted link that I'll provide by email
4. Run the following commands:

```bash
docker run -p 8080:8080 --env-file .env \
-v /PATH-TO-YOUR/eu-central-1-bundle.pem:/certs/eu-central-1-bundle.pem baduker/sherapny:latest
```
