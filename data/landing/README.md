# Landing zone

Drop raw CSV files here, one folder per source table:

```
data/landing/customers/*.csv
data/landing/accounts/*.csv
data/landing/branches/*.csv
data/landing/cards/*.csv
data/landing/loans/*.csv
data/landing/merchants/*.csv
data/landing/transactions/*.csv
```

On `docker compose up`, the `minio-init` service mirrors this folder into the
`landing` MinIO bucket (`s3a://landing/<table>/`). The first `dbt run` then
creates an Iceberg table `raw.<table>` from each folder.

CSV files in this folder are git-ignored.
