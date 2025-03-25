# MEER Network API Documentation

## 1. Query Network Status

### API Endpoint
`GET /api/v2/qitmeer/network/status`

### Request Parameters
None

### Response Fields
| Field Name    | Type   | Description                     |
|--------------|--------|---------------------------------|
| block_time   | float  | Average block time (seconds)    |
| tx_rate      | float  | Network transaction rate (TPS)  |
| latest_block | int    | Latest block order number       |
| block_height | int    | Current block height           |
| total_meer   | string | Total MEER supply (unit: MEER) |
| circulation  | string | Circulating supply (unit: MEER) |

---

## 2. Query Network Hashrate and Difficulty

### API Endpoint
`GET /api/v2/qitmeer/network/hashrate`

### Request Parameters
| Parameter Name | Type   | Description                           | Required |
|---------------|--------|--------------------------------------|----------|
| period        | string | Time granularity (`hour`, `day`, `week`) | Yes      |

### Response Fields
| Field Name   | Type   | Description                |
|-------------|--------|----------------------------|
| timestamp   | int    | Timestamp                  |
| hashrate    | float  | Total network hashrate (TH/s) |
| difficulty  | float  | Mining difficulty          |

---

## 3. Query Account List (Sorted by Balance)

### API Endpoint
`GET /api/v2/qitmeer/accounts`

### Request Parameters
| Parameter Name | Type  | Description             | Required |
|---------------|------|------------------------|----------|
| limit         | int  | Number of results (default: 10) | No       |
| offset        | int  | Pagination offset (default: 0) | No       |

### Response Fields
| Field Name   | Type   | Description              |
|-------------|--------|--------------------------|
| rank        | int    | Ranking                   |
| address     | string | Account address           |
| balance     | string | Account balance (MEER)    |
| tx_count    | int    | Number of transactions    |
| utxo_count  | int    | Number of UTXOs           |

---

## 4. Query UTXO Address Balance

### API Endpoint
`GET /api/v2/qitmeer/addresses/{address}`

### Request Parameters
| Parameter Name | Type   | Description       | Required |
|---------------|--------|------------------|----------|
| address       | string | UTXO address      | Yes      |

### Response Fields
| Field Name | Type   | Description                 |
|-----------|--------|-----------------------------|
| balance   | string | Account balance (MEER)      |
| utxos     | array  | Detailed UTXO information   |

#### `utxos` Structure
| Field Name | Type   | Description                   |
|-----------|--------|------------------------------|
| txid      | string | Transaction hash             |
| index     | int    | Transaction index            |
| amount    | string | Transaction amount (MEER)    |
| height    | int    | Block height of transaction  |

---

## 5. Query UTXO Address Transactions

### API Endpoint
`GET /api/v2/qitmeer/addresses/{address}/transactions`

### Request Parameters
| Parameter Name | Type   | Description             | Required |
|---------------|--------|------------------------|----------|
| address       | string | UTXO address            | Yes      |
| limit         | int    | Number of results (default: 10) | No  |
| offset        | int    | Pagination offset (default: 0) | No  |

### Response Fields
| Field Name | Type   | Description                  |
|-----------|--------|------------------------------|
| txid      | string | Transaction hash             |
| amount    | string | Transaction amount (MEER)    |
| height    | int    | Block height of transaction  |
| timestamp | int    | Transaction timestamp        |

---

## 6. Query Network Node Status

### API Endpoint
`GET /api/v2/qitmeer/network/nodes`

### Request Parameters
None

### Response Fields
| Field Name     | Type
