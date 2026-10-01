# Product: Reproducible Client Hosting Infrastructure

## Problem
I host freelance client websites manually on a VPS. Each new client means
repeating server setup by hand: provisioning, NGINX, SSL, firewall rules,
deployment. It is slow, error-prone, and inconsistent between clients.

## Solution
Codify the entire setup in Terraform on AWS so a secured client environment
stands up from one command and tears down just as cleanly.
Terraform makes the infrastructure reproducible; Docker makes the application
deployment reproducible.

## Audience
This is a portfolio project for junior cloud, DevOps, and security roles.
Every decision must be explainable in an interview, so clarity beats cleverness.

## Priorities, in order
1. Security (least privilege, encryption, no secrets in code or git)
2. Cost control (near zero spend; destroy when idle)
3. Readability and explainability
4. Features