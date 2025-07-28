Example to run a simple PostgreSQL server for local development and testing, using a
standard Kubernetes manifest (`Deployment + Service + PersistentVolumeClaim`).

- **Pros:**
  - Simple to set up
  - No extra dependencies
  - Good for quick prototyping
- **Cons:**
  - No automated failover, backups, or scaling
  - Not suitable for production
