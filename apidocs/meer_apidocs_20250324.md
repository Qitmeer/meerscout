# MEER 网络 API 文档

## 1. 查询网络状况

### 接口地址
`GET /api/v2/qitmeer/network/status`

### 请求参数
无

### 返回字段
| 字段名       | 类型    | 说明                     |
|-------------|--------|--------------------------|
| block_time  | float  | 网络平均出块时间（秒）   |
| tx_rate     | float  | 网络并发率（TPS）        |
| latest_block | int   | 最新区块顺序号           |
| block_height | int   | 当前区块高度             |
| total_meer  | string | MEER 总量（单位：MEER）  |
| circulation | string | 流通量（单位：MEER）     |

---

## 2. 查询全网算力与难度统计

### 接口地址
`GET /api/v2/qitmeer/network/hashrate`

### 请求参数
| 参数名  | 类型   | 说明                                  | 必填 |
|--------|-------|-------------------------------------|------|
| period | string | 时间粒度 (`hour`, `day`, `week`)   | 是  |

### 返回字段
| 字段名      | 类型   | 说明                     |
|------------|-------|--------------------------|
| timestamp  | int   | 时间戳                   |
| hashrate   | float | 全网算力（单位：TH/s）   |
| difficulty | float | 挖矿难度                 |

---

## 3. 查询账户列表（按余额排序）

### 接口地址
`GET /api/v2/qitmeer/accounts`

### 请求参数
| 参数名  | 类型  | 说明            | 必填 |
|--------|------|---------------|------|
| limit  | int  | 返回条数（默认 10） | 否  |
| offset | int  | 分页偏移量（默认 0） | 否  |

### 返回字段
| 字段名    | 类型   | 说明                |
|---------|-------|-------------------|
| rank    | int   | 排名                |
| address | string | 账户地址            |
| balance | string | 账户余额（单位：MEER）|
| tx_count | int   | 交易数              |
| utxo_count | int | UTXO 数量           |

---

## 4. 查询 UTXO 地址余额信息

### 接口地址
`GET /api/v2/qitmeer/addresses/{address}`

### 请求参数
| 参数名   | 类型   | 说明      | 必填 |
|---------|-------|---------|------|
| address | string | UTXO 地址 | 是  |

### 返回字段
| 字段名    | 类型   | 说明                  |
|---------|-------|---------------------|
| balance | string | 账户余额（单位：MEER）|
| utxos   | array  | UTXO 详细信息        |

#### `utxos` 结构
| 字段名    | 类型   | 说明            |
|---------|-------|---------------|
| txid    | string | 交易哈希        |
| index   | int   | 交易索引        |
| amount  | string | 交易金额（MEER） |
| height  | int   | 交易所在区块高度 |

---

## 5. 查询 UTXO 地址的交易记录

### 接口地址
`GET /api/v2/qitmeer/addresses/{address}/transactions`

### 请求参数
| 参数名   | 类型   | 说明            | 必填 |
|---------|-------|---------------|------|
| address | string | UTXO 地址       | 是  |
| limit   | int   | 返回条数（默认 10） | 否  |
| offset  | int   | 分页偏移量（默认 0） | 否  |

### 返回字段
| 字段名    | 类型   | 说明            |
|---------|-------|---------------|
| txid    | string | 交易哈希        |
| amount  | string | 交易金额（MEER） |
| height  | int   | 交易所在区块高度 |
| timestamp | int  | 交易时间戳      |

---

## 6. 查询全网节点状态

### 接口地址
`GET /api/v2/qitmeer/network/nodes`

### 请求参数
无

### 返回字段
| 字段名    | 类型   | 说明            |
|---------|-------|---------------|
| total_nodes | int   | 全网节点总数    |
| active_nodes | int   | 活跃节点数量    |
| peers      | array | 详细节点信息    |

#### `peers` 结构
| 字段名    | 类型   | 说明            |
|---------|-------|---------------|
| id      | string | 节点 ID         |
| ip      | string | 节点 IP 地址     |
| port    | int   | 连接端口        |
| status  | string | 在线状态 (`online` / `offline`) |

---
