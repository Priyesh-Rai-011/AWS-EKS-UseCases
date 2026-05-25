# TeamBoard — Local App

A team info board where users post updates stored as `.txt` files on EFS.

## Storage Summary

| Data | Local Dev | In EKS |
|---|---|---|
| User accounts | Docker named volume (Postgres) | Postgres PVC on **EBS** |
| Team posts | `./data` bind mount | **EFS** PVC |

## Run Locally

```bash
# 1. Start Postgres + TeamBoard
docker-compose up --build

# 2. Open in browser
http://localhost:8080
```

## Try It

1. Go to `http://localhost:8080/register`
2. Create user `alice` → team `devops`
3. Create user `bob` → team `devops`
4. Create user `carol` → team `qa`
5. Login as `alice`, post something
6. Login as `bob` — he sees Alice's post (same team, shared EFS folder)
7. Login as `carol` — she sees nothing (different team, different EFS folder)

## Simulate EFS Persistence (Pod Kill Demo)

```bash
# Post something as alice, then kill the container
docker-compose stop teamboard

# Start it again
docker-compose start teamboard

# Login again — your posts are still there (files persisted on bind mount / EFS)
```

## EFS Folder Structure (inside ./data locally)

```
./data/
└── teams/
    ├── devops/
    │   ├── <uuid>.txt
    │   └── <uuid>.txt
    └── qa/
        └── <uuid>.txt
```

## Post File Format

```
id: 1d0d8baf-976b-4375-a418-8e9bbf5259f3
title: Sprint planning moved
author: alice
team: devops
createdAt: 2026-05-25T10:15:30

Meeting shifted to 3pm Friday.
```

## Next Steps

See `../02_efs_static_provisioning/` to deploy this on EKS with a real EFS filesystem.
