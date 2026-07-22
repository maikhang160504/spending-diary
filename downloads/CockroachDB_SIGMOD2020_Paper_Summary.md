# CockroachDB: The Resilient Geo-Distributed SQL Database (SIGMOD 2020) - Reference Summary

## IEEE Full Citation
[17] R. Taft, I. Sharif, A. Matei, N. VanBenschoten, J. Lewis, T. Grieger, K. Niemi, A. Woods, A. B. Roy, A. Cockroach, et al., "CockroachDB: The Resilient Geo-Distributed SQL Database," in *Proceedings of the 2020 ACM SIGMOD International Conference on Management of Data*, Portland, OR, USA, 2020, pp. 1493–1508. DOI: 10.1145/3318464.3389706.

## Abstract & Core Contributions
CockroachDB is a scalable, geo-distributed SQL database designed to combine the horizontal scalability of NoSQL systems with the strong ACID guarantees and relational data structures of traditional SQL DBMSs. The paper presents the multi-layered architecture of CockroachDB, focusing on:
1. **SQL Layer & Distributed Query Engine:** Translates standard SQL queries—including complex Window Functions (`OVER (PARTITION BY ... ORDER BY ... ROWS BETWEEN ...)` into distributed execution flows across multiple nodes.
2. **Transactional Layer:** Implements decentralized multi-version concurrency control (MVCC) and distributed transactions using standard two-phase commit (2PC) combined with consensus.
3. **Replication & Consensus Layer:** Utilizes the Raft consensus algorithm (`O(log N)` consensus groups across ranges) to ensure high availability, fault tolerance, and linearizability without single points of failure.
4. **Storage Layer:** Stores underlying data in ordered key-value pairs (`Pebble` / `RocksDB`), allowing efficient range scans and distributed aggregations directly at the local storage nodes.

## Application in Spending Diary Thesis (Section 2.8)
In the **Cumulative Budget Report (`CumulativeBudgetReportScreen`)**, calculating real-time cumulative cashflow over tens of thousands of historical transactions across user wallets requires heavy aggregation. Instead of pulling raw data into Node.js application memory (which creates OOM bottlenecks), the Spending Diary architecture offloads the computation to CockroachDB using distributed SQL Window Functions:
```sql
SELECT to_char(date_trunc('day', occurred_at), 'YYYY-MM-DD') AS day,
       SUM(amount) OVER (
         PARTITION BY wallet_id 
         ORDER BY occurred_at 
         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS cumulative_amount
FROM transactions
WHERE wallet_id = $1 AND is_deleted = FALSE;
```
CockroachDB executes this window aggregation across distributed storage ranges using Raft-backed indices, achieving high throughput and single-pass latency (`O(N log N)` sorting and `O(N)` window evaluation) at the database layer.
