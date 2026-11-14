# VDPCHK テスト項目一覧

このファイルは `gen_vdpchk.py` が生成します。直接編集しないでください。

- 全 769 項目。VDPCHK.COM は失敗した項目の番号を最後に表示します。
- 期待値は openMSX の VDPCmdEngine (実機で確認された動作) とデータブックに準拠した参照モデルで生成しています。
- 各項目は試験範囲を既知のパターンで埋めてから実行し、CPU で VRAM を読み戻して CRC で比較します。範囲はコマンドが触れるライン全体と、その上下 1 ラインです。
- 「V9968 のみ」の節は V9968 を検出できない場合 (V9958 実機など) はスキップし、全数に含めません。
- 番号の後ろの `T` はタイムアウト (CE または TR が落ちなかった) を表します。

## CPU による VRAM 読み書き

### CPU VRAM 読み書き (R#14)

| No. | モード | 内容 |
|---:|---|---|
| 1 | SCREEN5 | R#14=0: 0x01230 から 512 バイト書いて読む |
| 2 | SCREEN5 | R#14=1: 0x05230 から 512 バイト書いて読む |
| 3 | SCREEN5 | R#14=3: 0x0D230 から 512 バイト書いて読む |
| 4 | SCREEN5 | R#14=4: 0x11230 から 512 バイト書いて読む |
| 5 | SCREEN5 | R#14=6: 0x19230 から 512 バイト書いて読む |
| 6 | SCREEN5 | R#14=7: 0x1D230 から 512 バイト書いて読む |
| 7 | SCREEN5 | R#14=0: 16KB 境界をまたぐ連続書き込み (SCREEN5, 17 ビット) |
| 8 | SCREEN5 | R#14=3: 16KB 境界をまたぐ連続書き込み (SCREEN5, 17 ビット) |
| 9 | SCREEN5 | R#14=7: 16KB 境界をまたぐ連続書き込み (SCREEN5, 17 ビット) |
| 10 | SCREEN1 | R#14=2: SCREEN1 では 16KB 内で折り返す |
| 11 | SCREEN1 | R#14=5: SCREEN1 では 16KB 内で折り返す |
| 12 | SCREEN5 | SCREEN7 で書いて SCREEN5 で読む (インターリーブ) |
| 13 | SCREEN7 | SCREEN7: R#14=7 の読み書き |
| 14 | SCREEN5 | SCREEN8 で書いて SCREEN5 で読む (インターリーブ) |
| 15 | SCREEN8 | SCREEN8: R#14=7 の読み書き |

## SCREEN5 のコマンド

### HMMV

| No. | モード | 内容 |
|---:|---|---|
| 16 | SCREEN5 | HMMV 基本 (DX/NX 奇数) |
| 17 | SCREEN5 | HMMV 方向 DIX=0 DIY=0 |
| 18 | SCREEN5 | HMMV 方向 DIX=1 DIY=0 |
| 19 | SCREEN5 | HMMV 方向 DIX=0 DIY=1 |
| 20 | SCREEN5 | HMMV 方向 DIX=1 DIY=1 |
| 21 | SCREEN5 | HMMV 右端はみ出し |
| 22 | SCREEN5 | HMMV 左端はみ出し DIX=1 |
| 23 | SCREEN5 | HMMV NX=0 (右端まで) |
| 24 | SCREEN5 | HMMV NX=0 DIX=1 (左端まで) |
| 25 | SCREEN5 | HMMV NX=1 |
| 26 | SCREEN5 | HMMV NY=0 DIY=1 (上端で停止) |
| 27 | SCREEN5 | HMMV 上端はみ出し DIY=1 |
| 28 | SCREEN5 | HMMV 下端から折り返し |
| 29 | SCREEN5 | HMMV NX=0 NY=0 (VRAM 全域) |

### LMMV

| No. | モード | 内容 |
|---:|---|---|
| 30 | SCREEN5 | LMMV IMP |
| 31 | SCREEN5 | LMMV AND |
| 32 | SCREEN5 | LMMV OR |
| 33 | SCREEN5 | LMMV XOR |
| 34 | SCREEN5 | LMMV NOT |
| 35 | SCREEN5 | LMMV TIMP |
| 36 | SCREEN5 | LMMV TAND |
| 37 | SCREEN5 | LMMV TOR |
| 38 | SCREEN5 | LMMV TXOR |
| 39 | SCREEN5 | LMMV TNOT |
| 40 | SCREEN5 | LMMV TIMP 色0 (書かれない) |
| 41 | SCREEN5 | LMMV IMP 色0 |
| 42 | SCREEN5 | LMMV TXOR 色0 (書かれない) |
| 43 | SCREEN5 | LMMV 方向 DIX=0 DIY=0 |
| 44 | SCREEN5 | LMMV 方向 DIX=1 DIY=0 |
| 45 | SCREEN5 | LMMV 方向 DIX=0 DIY=1 |
| 46 | SCREEN5 | LMMV 方向 DIX=1 DIY=1 |
| 47 | SCREEN5 | LMMV 右端はみ出し |
| 48 | SCREEN5 | LMMV 左端はみ出し DIX=1 |
| 49 | SCREEN5 | LMMV NX=0 |
| 50 | SCREEN5 | LMMV NY=0 DIY=1 (上端で停止) |
| 51 | SCREEN5 | LMMV 下端から折り返し |
| 52 | SCREEN5 | LMMV DX>=幅 (1 ドットのみ) |

### LMMM

| No. | モード | 内容 |
|---:|---|---|
| 53 | SCREEN5 | LMMM IMP (SX 奇数, DX 偶数) |
| 54 | SCREEN5 | LMMM AND (SX 奇数, DX 偶数) |
| 55 | SCREEN5 | LMMM OR (SX 奇数, DX 偶数) |
| 56 | SCREEN5 | LMMM XOR (SX 奇数, DX 偶数) |
| 57 | SCREEN5 | LMMM NOT (SX 奇数, DX 偶数) |
| 58 | SCREEN5 | LMMM TIMP (SX 奇数, DX 偶数) |
| 59 | SCREEN5 | LMMM TAND (SX 奇数, DX 偶数) |
| 60 | SCREEN5 | LMMM TOR (SX 奇数, DX 偶数) |
| 61 | SCREEN5 | LMMM TXOR (SX 奇数, DX 偶数) |
| 62 | SCREEN5 | LMMM TNOT (SX 奇数, DX 偶数) |
| 63 | SCREEN5 | LMMM 方向 DIX=0 DIY=0 |
| 64 | SCREEN5 | LMMM 方向 DIX=1 DIY=0 |
| 65 | SCREEN5 | LMMM 方向 DIX=0 DIY=1 |
| 66 | SCREEN5 | LMMM 方向 DIX=1 DIY=1 |
| 67 | SCREEN5 | LMMM 重なり 右へずらし DIX=0 |
| 68 | SCREEN5 | LMMM 重なり 右へずらし DIX=1 |
| 69 | SCREEN5 | LMMM 重なり 下へずらし DIY=0 |
| 70 | SCREEN5 | LMMM 重なり 下へずらし DIY=1 |
| 71 | SCREEN5 | LMMM 転送元が右端はみ出し |
| 72 | SCREEN5 | LMMM 転送先が右端はみ出し |
| 73 | SCREEN5 | LMMM 左端はみ出し DIX=1 |
| 74 | SCREEN5 | LMMM NX=0 |
| 75 | SCREEN5 | LMMM NY=0 DIY=1 (上端で停止) |
| 76 | SCREEN5 | LMMM 下端から折り返し |

### HMMM

| No. | モード | 内容 |
|---:|---|---|
| 77 | SCREEN5 | HMMM 基本 (SX/DX 奇数) |
| 78 | SCREEN5 | HMMM 方向 DIX=0 DIY=0 |
| 79 | SCREEN5 | HMMM 方向 DIX=1 DIY=0 |
| 80 | SCREEN5 | HMMM 方向 DIX=0 DIY=1 |
| 81 | SCREEN5 | HMMM 方向 DIX=1 DIY=1 |
| 82 | SCREEN5 | HMMM 重なり 下へずらし DIY=0 |
| 83 | SCREEN5 | HMMM 重なり 上へずらし DIY=1 |
| 84 | SCREEN5 | HMMM 重なり 右へずらし DIX=1 |
| 85 | SCREEN5 | HMMM 転送元が右端はみ出し |
| 86 | SCREEN5 | HMMM 転送先が右端はみ出し |
| 87 | SCREEN5 | HMMM 左端はみ出し DIX=1 |
| 88 | SCREEN5 | HMMM NX=0 |
| 89 | SCREEN5 | HMMM NX=1 |
| 90 | SCREEN5 | HMMM NY=0 DIY=1 (上端で停止) |

### YMMM

| No. | モード | 内容 |
|---:|---|---|
| 91 | SCREEN5 | YMMM 方向 DIX=0 DIY=0 |
| 92 | SCREEN5 | YMMM 方向 DIX=1 DIY=0 |
| 93 | SCREEN5 | YMMM 方向 DIX=0 DIY=1 |
| 94 | SCREEN5 | YMMM 方向 DIX=1 DIY=1 |
| 95 | SCREEN5 | YMMM 重なり 1 ライン下へ |
| 96 | SCREEN5 | YMMM NY=0 DIY=1 (上端で停止) |

### LMCM

| No. | モード | 内容 |
|---:|---|---|
| 97 | SCREEN5 | LMCM 基本 |
| 98 | SCREEN5 | LMCM 方向 DIX=0 DIY=0 |
| 99 | SCREEN5 | LMCM 方向 DIX=1 DIY=0 |
| 100 | SCREEN5 | LMCM 方向 DIX=0 DIY=1 |
| 101 | SCREEN5 | LMCM 方向 DIX=1 DIY=1 |
| 102 | SCREEN5 | LMCM 右端はみ出し |
| 103 | SCREEN5 | LMCM 左端はみ出し DIX=1 |
| 104 | SCREEN5 | LMCM NY=0 DIY=1 (上端で停止) |

### LMMC

| No. | モード | 内容 |
|---:|---|---|
| 105 | SCREEN5 | LMMC IMP |
| 106 | SCREEN5 | LMMC XOR |
| 107 | SCREEN5 | LMMC TIMP |
| 108 | SCREEN5 | LMMC NOT |
| 109 | SCREEN5 | LMMC 方向 DIX=1 DIY=0 |
| 110 | SCREEN5 | LMMC 方向 DIX=0 DIY=1 |
| 111 | SCREEN5 | LMMC 方向 DIX=1 DIY=1 |
| 112 | SCREEN5 | LMMC 右端はみ出し |
| 113 | SCREEN5 | LMMC 左端はみ出し DIX=1 |

### HMMC

| No. | モード | 内容 |
|---:|---|---|
| 114 | SCREEN5 | HMMC 基本 (DX 奇数) |
| 115 | SCREEN5 | HMMC 方向 DIX=1 DIY=0 |
| 116 | SCREEN5 | HMMC 方向 DIX=0 DIY=1 |
| 117 | SCREEN5 | HMMC 方向 DIX=1 DIY=1 |
| 118 | SCREEN5 | HMMC 右端はみ出し |
| 119 | SCREEN5 | HMMC 左端はみ出し DIX=1 |

### PSET / POINT

| No. | モード | 内容 |
|---:|---|---|
| 120 | SCREEN5 | PSET IMP |
| 121 | SCREEN5 | PSET AND |
| 122 | SCREEN5 | PSET OR |
| 123 | SCREEN5 | PSET XOR |
| 124 | SCREEN5 | PSET NOT |
| 125 | SCREEN5 | PSET TIMP |
| 126 | SCREEN5 | PSET TAND |
| 127 | SCREEN5 | PSET TOR |
| 128 | SCREEN5 | PSET TXOR |
| 129 | SCREEN5 | PSET TNOT |
| 130 | SCREEN5 | PSET 右端 X=255 |
| 131 | SCREEN5 | PSET 左端 X=0 |
| 132 | SCREEN5 | POINT X=0 |
| 133 | SCREEN5 | POINT X=1 |
| 134 | SCREEN5 | POINT X=255 |
| 135 | SCREEN5 | POINT X=131 |

### LINE

| No. | モード | 内容 |
|---:|---|---|
| 136 | SCREEN5 | LINE X 主軸 DIX=0 DIY=0 |
| 137 | SCREEN5 | LINE Y 主軸 DIX=0 DIY=0 |
| 138 | SCREEN5 | LINE X 主軸 DIX=1 DIY=0 |
| 139 | SCREEN5 | LINE Y 主軸 DIX=1 DIY=0 |
| 140 | SCREEN5 | LINE X 主軸 DIX=0 DIY=1 |
| 141 | SCREEN5 | LINE Y 主軸 DIX=0 DIY=1 |
| 142 | SCREEN5 | LINE X 主軸 DIX=1 DIY=1 |
| 143 | SCREEN5 | LINE Y 主軸 DIX=1 DIY=1 |
| 144 | SCREEN5 | LINE 45 度 |
| 145 | SCREEN5 | LINE NY=0 (水平) |
| 146 | SCREEN5 | LINE NX=0 (1 点) |
| 147 | SCREEN5 | LINE 浅い傾き 255:7 |
| 148 | SCREEN5 | LINE 右端で停止 |
| 149 | SCREEN5 | LINE 左端で停止 DIX=1 |
| 150 | SCREEN5 | LINE Y 主軸 上端で停止 |
| 151 | SCREEN5 | LINE X 主軸 上端で停止 |
| 152 | SCREEN5 | LINE NY>NX (X 主軸指定) |
| 153 | SCREEN5 | LINE XOR |
| 154 | SCREEN5 | LINE TIMP 色0 (書かれない) |
| 155 | SCREEN5 | LINE Y 主軸 1:1 MAJ=1 |
| 156 | SCREEN5 | LINE Y 主軸 下端から折り返し |

### SRCH

| No. | モード | 内容 |
|---:|---|---|
| 157 | SCREEN5 | SRCH EQ=0 発見 DIX=0 |
| 158 | SCREEN5 | SRCH EQ=0 未発見 DIX=0 |
| 159 | SCREEN5 | SRCH EQ=0 発見 DIX=1 |
| 160 | SCREEN5 | SRCH EQ=0 未発見 DIX=1 |
| 161 | SCREEN5 | SRCH EQ=1 発見 |
| 162 | SCREEN5 | SRCH EQ=1 未発見 |
| 163 | SCREEN5 | SRCH 開始点で発見 |
| 164 | SCREEN5 | SRCH 右端 X=255 で発見 |
| 165 | SCREEN5 | SRCH 色の上位ビットは無視 |
| 166 | SCREEN5 | SRCH EQ=1 DIX=1 未発見 |

## SCREEN8 のコマンド

### HMMV

| No. | モード | 内容 |
|---:|---|---|
| 167 | SCREEN8 | HMMV 基本 (DX/NX 奇数) |
| 168 | SCREEN8 | HMMV 方向 DIX=0 DIY=0 |
| 169 | SCREEN8 | HMMV 方向 DIX=1 DIY=0 |
| 170 | SCREEN8 | HMMV 方向 DIX=0 DIY=1 |
| 171 | SCREEN8 | HMMV 方向 DIX=1 DIY=1 |
| 172 | SCREEN8 | HMMV 右端はみ出し |
| 173 | SCREEN8 | HMMV 左端はみ出し DIX=1 |
| 174 | SCREEN8 | HMMV NX=0 (右端まで) |
| 175 | SCREEN8 | HMMV NX=0 DIX=1 (左端まで) |
| 176 | SCREEN8 | HMMV NX=1 |
| 177 | SCREEN8 | HMMV NY=0 DIY=1 (上端で停止) |
| 178 | SCREEN8 | HMMV 上端はみ出し DIY=1 |
| 179 | SCREEN8 | HMMV 下端から折り返し |
| 180 | SCREEN8 | HMMV NX=0 NY=0 (VRAM 全域) |

### LMMV

| No. | モード | 内容 |
|---:|---|---|
| 181 | SCREEN8 | LMMV IMP |
| 182 | SCREEN8 | LMMV AND |
| 183 | SCREEN8 | LMMV OR |
| 184 | SCREEN8 | LMMV XOR |
| 185 | SCREEN8 | LMMV NOT |
| 186 | SCREEN8 | LMMV TIMP |
| 187 | SCREEN8 | LMMV TAND |
| 188 | SCREEN8 | LMMV TOR |
| 189 | SCREEN8 | LMMV TXOR |
| 190 | SCREEN8 | LMMV TNOT |
| 191 | SCREEN8 | LMMV TIMP 色0 (書かれない) |
| 192 | SCREEN8 | LMMV IMP 色0 |
| 193 | SCREEN8 | LMMV TXOR 色0 (書かれない) |
| 194 | SCREEN8 | LMMV 方向 DIX=0 DIY=0 |
| 195 | SCREEN8 | LMMV 方向 DIX=1 DIY=0 |
| 196 | SCREEN8 | LMMV 方向 DIX=0 DIY=1 |
| 197 | SCREEN8 | LMMV 方向 DIX=1 DIY=1 |
| 198 | SCREEN8 | LMMV 右端はみ出し |
| 199 | SCREEN8 | LMMV 左端はみ出し DIX=1 |
| 200 | SCREEN8 | LMMV NX=0 |
| 201 | SCREEN8 | LMMV NY=0 DIY=1 (上端で停止) |
| 202 | SCREEN8 | LMMV 下端から折り返し |
| 203 | SCREEN8 | LMMV DX>=幅 (1 ドットのみ) |

### LMMM

| No. | モード | 内容 |
|---:|---|---|
| 204 | SCREEN8 | LMMM IMP (SX 奇数, DX 偶数) |
| 205 | SCREEN8 | LMMM AND (SX 奇数, DX 偶数) |
| 206 | SCREEN8 | LMMM OR (SX 奇数, DX 偶数) |
| 207 | SCREEN8 | LMMM XOR (SX 奇数, DX 偶数) |
| 208 | SCREEN8 | LMMM NOT (SX 奇数, DX 偶数) |
| 209 | SCREEN8 | LMMM TIMP (SX 奇数, DX 偶数) |
| 210 | SCREEN8 | LMMM TAND (SX 奇数, DX 偶数) |
| 211 | SCREEN8 | LMMM TOR (SX 奇数, DX 偶数) |
| 212 | SCREEN8 | LMMM TXOR (SX 奇数, DX 偶数) |
| 213 | SCREEN8 | LMMM TNOT (SX 奇数, DX 偶数) |
| 214 | SCREEN8 | LMMM 方向 DIX=0 DIY=0 |
| 215 | SCREEN8 | LMMM 方向 DIX=1 DIY=0 |
| 216 | SCREEN8 | LMMM 方向 DIX=0 DIY=1 |
| 217 | SCREEN8 | LMMM 方向 DIX=1 DIY=1 |
| 218 | SCREEN8 | LMMM 重なり 右へずらし DIX=0 |
| 219 | SCREEN8 | LMMM 重なり 右へずらし DIX=1 |
| 220 | SCREEN8 | LMMM 重なり 下へずらし DIY=0 |
| 221 | SCREEN8 | LMMM 重なり 下へずらし DIY=1 |
| 222 | SCREEN8 | LMMM 転送元が右端はみ出し |
| 223 | SCREEN8 | LMMM 転送先が右端はみ出し |
| 224 | SCREEN8 | LMMM 左端はみ出し DIX=1 |
| 225 | SCREEN8 | LMMM NX=0 |
| 226 | SCREEN8 | LMMM NY=0 DIY=1 (上端で停止) |
| 227 | SCREEN8 | LMMM 下端から折り返し |

### HMMM

| No. | モード | 内容 |
|---:|---|---|
| 228 | SCREEN8 | HMMM 基本 (SX/DX 奇数) |
| 229 | SCREEN8 | HMMM 方向 DIX=0 DIY=0 |
| 230 | SCREEN8 | HMMM 方向 DIX=1 DIY=0 |
| 231 | SCREEN8 | HMMM 方向 DIX=0 DIY=1 |
| 232 | SCREEN8 | HMMM 方向 DIX=1 DIY=1 |
| 233 | SCREEN8 | HMMM 重なり 下へずらし DIY=0 |
| 234 | SCREEN8 | HMMM 重なり 上へずらし DIY=1 |
| 235 | SCREEN8 | HMMM 重なり 右へずらし DIX=1 |
| 236 | SCREEN8 | HMMM 転送元が右端はみ出し |
| 237 | SCREEN8 | HMMM 転送先が右端はみ出し |
| 238 | SCREEN8 | HMMM 左端はみ出し DIX=1 |
| 239 | SCREEN8 | HMMM NX=0 |
| 240 | SCREEN8 | HMMM NX=1 |
| 241 | SCREEN8 | HMMM NY=0 DIY=1 (上端で停止) |

### YMMM

| No. | モード | 内容 |
|---:|---|---|
| 242 | SCREEN8 | YMMM 方向 DIX=0 DIY=0 |
| 243 | SCREEN8 | YMMM 方向 DIX=1 DIY=0 |
| 244 | SCREEN8 | YMMM 方向 DIX=0 DIY=1 |
| 245 | SCREEN8 | YMMM 方向 DIX=1 DIY=1 |
| 246 | SCREEN8 | YMMM 重なり 1 ライン下へ |
| 247 | SCREEN8 | YMMM NY=0 DIY=1 (上端で停止) |

### LMCM

| No. | モード | 内容 |
|---:|---|---|
| 248 | SCREEN8 | LMCM 基本 |
| 249 | SCREEN8 | LMCM 方向 DIX=0 DIY=0 |
| 250 | SCREEN8 | LMCM 方向 DIX=1 DIY=0 |
| 251 | SCREEN8 | LMCM 方向 DIX=0 DIY=1 |
| 252 | SCREEN8 | LMCM 方向 DIX=1 DIY=1 |
| 253 | SCREEN8 | LMCM 右端はみ出し |
| 254 | SCREEN8 | LMCM 左端はみ出し DIX=1 |
| 255 | SCREEN8 | LMCM NY=0 DIY=1 (上端で停止) |

### LMMC

| No. | モード | 内容 |
|---:|---|---|
| 256 | SCREEN8 | LMMC IMP |
| 257 | SCREEN8 | LMMC XOR |
| 258 | SCREEN8 | LMMC TIMP |
| 259 | SCREEN8 | LMMC NOT |
| 260 | SCREEN8 | LMMC 方向 DIX=1 DIY=0 |
| 261 | SCREEN8 | LMMC 方向 DIX=0 DIY=1 |
| 262 | SCREEN8 | LMMC 方向 DIX=1 DIY=1 |
| 263 | SCREEN8 | LMMC 右端はみ出し |
| 264 | SCREEN8 | LMMC 左端はみ出し DIX=1 |

### HMMC

| No. | モード | 内容 |
|---:|---|---|
| 265 | SCREEN8 | HMMC 基本 (DX 奇数) |
| 266 | SCREEN8 | HMMC 方向 DIX=1 DIY=0 |
| 267 | SCREEN8 | HMMC 方向 DIX=0 DIY=1 |
| 268 | SCREEN8 | HMMC 方向 DIX=1 DIY=1 |
| 269 | SCREEN8 | HMMC 右端はみ出し |
| 270 | SCREEN8 | HMMC 左端はみ出し DIX=1 |

### PSET / POINT

| No. | モード | 内容 |
|---:|---|---|
| 271 | SCREEN8 | PSET IMP |
| 272 | SCREEN8 | PSET AND |
| 273 | SCREEN8 | PSET OR |
| 274 | SCREEN8 | PSET XOR |
| 275 | SCREEN8 | PSET NOT |
| 276 | SCREEN8 | PSET TIMP |
| 277 | SCREEN8 | PSET TAND |
| 278 | SCREEN8 | PSET TOR |
| 279 | SCREEN8 | PSET TXOR |
| 280 | SCREEN8 | PSET TNOT |
| 281 | SCREEN8 | PSET 右端 X=255 |
| 282 | SCREEN8 | PSET 左端 X=0 |
| 283 | SCREEN8 | POINT X=0 |
| 284 | SCREEN8 | POINT X=1 |
| 285 | SCREEN8 | POINT X=255 |
| 286 | SCREEN8 | POINT X=131 |

### LINE

| No. | モード | 内容 |
|---:|---|---|
| 287 | SCREEN8 | LINE X 主軸 DIX=0 DIY=0 |
| 288 | SCREEN8 | LINE Y 主軸 DIX=0 DIY=0 |
| 289 | SCREEN8 | LINE X 主軸 DIX=1 DIY=0 |
| 290 | SCREEN8 | LINE Y 主軸 DIX=1 DIY=0 |
| 291 | SCREEN8 | LINE X 主軸 DIX=0 DIY=1 |
| 292 | SCREEN8 | LINE Y 主軸 DIX=0 DIY=1 |
| 293 | SCREEN8 | LINE X 主軸 DIX=1 DIY=1 |
| 294 | SCREEN8 | LINE Y 主軸 DIX=1 DIY=1 |
| 295 | SCREEN8 | LINE 45 度 |
| 296 | SCREEN8 | LINE NY=0 (水平) |
| 297 | SCREEN8 | LINE NX=0 (1 点) |
| 298 | SCREEN8 | LINE 浅い傾き 255:7 |
| 299 | SCREEN8 | LINE 右端で停止 |
| 300 | SCREEN8 | LINE 左端で停止 DIX=1 |
| 301 | SCREEN8 | LINE Y 主軸 上端で停止 |
| 302 | SCREEN8 | LINE X 主軸 上端で停止 |
| 303 | SCREEN8 | LINE NY>NX (X 主軸指定) |
| 304 | SCREEN8 | LINE XOR |
| 305 | SCREEN8 | LINE TIMP 色0 (書かれない) |
| 306 | SCREEN8 | LINE Y 主軸 1:1 MAJ=1 |
| 307 | SCREEN8 | LINE Y 主軸 下端から折り返し |

### SRCH

| No. | モード | 内容 |
|---:|---|---|
| 308 | SCREEN8 | SRCH EQ=0 発見 DIX=0 |
| 309 | SCREEN8 | SRCH EQ=0 未発見 DIX=0 |
| 310 | SCREEN8 | SRCH EQ=0 発見 DIX=1 |
| 311 | SCREEN8 | SRCH EQ=0 未発見 DIX=1 |
| 312 | SCREEN8 | SRCH EQ=1 発見 |
| 313 | SCREEN8 | SRCH EQ=1 未発見 |
| 314 | SCREEN8 | SRCH 開始点で発見 |
| 315 | SCREEN8 | SRCH 右端 X=255 で発見 |
| 316 | SCREEN8 | SRCH 色の上位ビットは無視 |
| 317 | SCREEN8 | SRCH EQ=1 DIX=1 未発見 |

## SCREEN6 のコマンド

### HMMV

| No. | モード | 内容 |
|---:|---|---|
| 318 | SCREEN6 | HMMV 基本 (DX/NX 奇数) |
| 319 | SCREEN6 | HMMV 方向 DIX=1 DIY=1 |
| 320 | SCREEN6 | HMMV 右端はみ出し |
| 321 | SCREEN6 | HMMV 左端はみ出し DIX=1 |
| 322 | SCREEN6 | HMMV NX=0 (右端まで) |
| 323 | SCREEN6 | HMMV NY=0 DIY=1 (上端で停止) |

### LMMV

| No. | モード | 内容 |
|---:|---|---|
| 324 | SCREEN6 | LMMV IMP |
| 325 | SCREEN6 | LMMV XOR |
| 326 | SCREEN6 | LMMV TIMP |
| 327 | SCREEN6 | LMMV TIMP 色0 (書かれない) |
| 328 | SCREEN6 | LMMV 方向 DIX=1 DIY=1 |
| 329 | SCREEN6 | LMMV 右端はみ出し |
| 330 | SCREEN6 | LMMV 左端はみ出し DIX=1 |

### LMMM

| No. | モード | 内容 |
|---:|---|---|
| 331 | SCREEN6 | LMMM IMP (SX 奇数, DX 偶数) |
| 332 | SCREEN6 | LMMM TIMP (SX 奇数, DX 偶数) |
| 333 | SCREEN6 | LMMM 方向 DIX=1 DIY=1 |
| 334 | SCREEN6 | LMMM 重なり 右へずらし DIX=0 |
| 335 | SCREEN6 | LMMM 重なり 右へずらし DIX=1 |
| 336 | SCREEN6 | LMMM 転送元が右端はみ出し |
| 337 | SCREEN6 | LMMM 転送先が右端はみ出し |

### HMMM

| No. | モード | 内容 |
|---:|---|---|
| 338 | SCREEN6 | HMMM 基本 (SX/DX 奇数) |
| 339 | SCREEN6 | HMMM 方向 DIX=1 DIY=1 |
| 340 | SCREEN6 | HMMM 重なり 下へずらし DIY=0 |
| 341 | SCREEN6 | HMMM 転送元が右端はみ出し |
| 342 | SCREEN6 | HMMM 転送先が右端はみ出し |

### YMMM

| No. | モード | 内容 |
|---:|---|---|
| 343 | SCREEN6 | YMMM 方向 DIX=0 DIY=0 |
| 344 | SCREEN6 | YMMM 方向 DIX=1 DIY=1 |

### LMCM

| No. | モード | 内容 |
|---:|---|---|
| 345 | SCREEN6 | LMCM 基本 |
| 346 | SCREEN6 | LMCM 方向 DIX=1 DIY=1 |
| 347 | SCREEN6 | LMCM 右端はみ出し |

### LMMC

| No. | モード | 内容 |
|---:|---|---|
| 348 | SCREEN6 | LMMC IMP |
| 349 | SCREEN6 | LMMC TIMP |
| 350 | SCREEN6 | LMMC 方向 DIX=1 DIY=1 |
| 351 | SCREEN6 | LMMC 右端はみ出し |

### HMMC

| No. | モード | 内容 |
|---:|---|---|
| 352 | SCREEN6 | HMMC 基本 (DX 奇数) |
| 353 | SCREEN6 | HMMC 方向 DIX=1 DIY=1 |
| 354 | SCREEN6 | HMMC 右端はみ出し |

### PSET / POINT

| No. | モード | 内容 |
|---:|---|---|
| 355 | SCREEN6 | PSET IMP |
| 356 | SCREEN6 | PSET XOR |
| 357 | SCREEN6 | PSET 右端 X=511 |
| 358 | SCREEN6 | PSET 左端 X=0 |
| 359 | SCREEN6 | POINT X=0 |
| 360 | SCREEN6 | POINT X=1 |

### LINE

| No. | モード | 内容 |
|---:|---|---|
| 361 | SCREEN6 | LINE X 主軸 DIX=0 DIY=0 |
| 362 | SCREEN6 | LINE Y 主軸 DIX=0 DIY=0 |
| 363 | SCREEN6 | LINE X 主軸 DIX=1 DIY=1 |
| 364 | SCREEN6 | LINE Y 主軸 DIX=1 DIY=1 |
| 365 | SCREEN6 | LINE 45 度 |
| 366 | SCREEN6 | LINE NY=0 (水平) |
| 367 | SCREEN6 | LINE 右端で停止 |
| 368 | SCREEN6 | LINE 左端で停止 DIX=1 |

### SRCH

| No. | モード | 内容 |
|---:|---|---|
| 369 | SCREEN6 | SRCH EQ=0 発見 DIX=0 |
| 370 | SCREEN6 | SRCH EQ=0 未発見 DIX=0 |
| 371 | SCREEN6 | SRCH EQ=0 発見 DIX=1 |
| 372 | SCREEN6 | SRCH EQ=0 未発見 DIX=1 |
| 373 | SCREEN6 | SRCH EQ=1 発見 |

## SCREEN7 のコマンド

### HMMV

| No. | モード | 内容 |
|---:|---|---|
| 374 | SCREEN7 | HMMV 基本 (DX/NX 奇数) |
| 375 | SCREEN7 | HMMV 方向 DIX=1 DIY=1 |
| 376 | SCREEN7 | HMMV 右端はみ出し |
| 377 | SCREEN7 | HMMV 左端はみ出し DIX=1 |
| 378 | SCREEN7 | HMMV NX=0 (右端まで) |
| 379 | SCREEN7 | HMMV NY=0 DIY=1 (上端で停止) |

### LMMV

| No. | モード | 内容 |
|---:|---|---|
| 380 | SCREEN7 | LMMV IMP |
| 381 | SCREEN7 | LMMV XOR |
| 382 | SCREEN7 | LMMV TIMP |
| 383 | SCREEN7 | LMMV TIMP 色0 (書かれない) |
| 384 | SCREEN7 | LMMV 方向 DIX=1 DIY=1 |
| 385 | SCREEN7 | LMMV 右端はみ出し |
| 386 | SCREEN7 | LMMV 左端はみ出し DIX=1 |

### LMMM

| No. | モード | 内容 |
|---:|---|---|
| 387 | SCREEN7 | LMMM IMP (SX 奇数, DX 偶数) |
| 388 | SCREEN7 | LMMM TIMP (SX 奇数, DX 偶数) |
| 389 | SCREEN7 | LMMM 方向 DIX=1 DIY=1 |
| 390 | SCREEN7 | LMMM 重なり 右へずらし DIX=0 |
| 391 | SCREEN7 | LMMM 重なり 右へずらし DIX=1 |
| 392 | SCREEN7 | LMMM 転送元が右端はみ出し |
| 393 | SCREEN7 | LMMM 転送先が右端はみ出し |

### HMMM

| No. | モード | 内容 |
|---:|---|---|
| 394 | SCREEN7 | HMMM 基本 (SX/DX 奇数) |
| 395 | SCREEN7 | HMMM 方向 DIX=1 DIY=1 |
| 396 | SCREEN7 | HMMM 重なり 下へずらし DIY=0 |
| 397 | SCREEN7 | HMMM 転送元が右端はみ出し |
| 398 | SCREEN7 | HMMM 転送先が右端はみ出し |

### YMMM

| No. | モード | 内容 |
|---:|---|---|
| 399 | SCREEN7 | YMMM 方向 DIX=0 DIY=0 |
| 400 | SCREEN7 | YMMM 方向 DIX=1 DIY=1 |

### LMCM

| No. | モード | 内容 |
|---:|---|---|
| 401 | SCREEN7 | LMCM 基本 |
| 402 | SCREEN7 | LMCM 方向 DIX=1 DIY=1 |
| 403 | SCREEN7 | LMCM 右端はみ出し |

### LMMC

| No. | モード | 内容 |
|---:|---|---|
| 404 | SCREEN7 | LMMC IMP |
| 405 | SCREEN7 | LMMC TIMP |
| 406 | SCREEN7 | LMMC 方向 DIX=1 DIY=1 |
| 407 | SCREEN7 | LMMC 右端はみ出し |

### HMMC

| No. | モード | 内容 |
|---:|---|---|
| 408 | SCREEN7 | HMMC 基本 (DX 奇数) |
| 409 | SCREEN7 | HMMC 方向 DIX=1 DIY=1 |
| 410 | SCREEN7 | HMMC 右端はみ出し |

### PSET / POINT

| No. | モード | 内容 |
|---:|---|---|
| 411 | SCREEN7 | PSET IMP |
| 412 | SCREEN7 | PSET XOR |
| 413 | SCREEN7 | PSET 右端 X=511 |
| 414 | SCREEN7 | PSET 左端 X=0 |
| 415 | SCREEN7 | POINT X=0 |
| 416 | SCREEN7 | POINT X=1 |

### LINE

| No. | モード | 内容 |
|---:|---|---|
| 417 | SCREEN7 | LINE X 主軸 DIX=0 DIY=0 |
| 418 | SCREEN7 | LINE Y 主軸 DIX=0 DIY=0 |
| 419 | SCREEN7 | LINE X 主軸 DIX=1 DIY=1 |
| 420 | SCREEN7 | LINE Y 主軸 DIX=1 DIY=1 |
| 421 | SCREEN7 | LINE 45 度 |
| 422 | SCREEN7 | LINE NY=0 (水平) |
| 423 | SCREEN7 | LINE 右端で停止 |
| 424 | SCREEN7 | LINE 左端で停止 DIX=1 |

### SRCH

| No. | モード | 内容 |
|---:|---|---|
| 425 | SCREEN7 | SRCH EQ=0 発見 DIX=0 |
| 426 | SCREEN7 | SRCH EQ=0 未発見 DIX=0 |
| 427 | SCREEN7 | SRCH EQ=0 発見 DIX=1 |
| 428 | SCREEN7 | SRCH EQ=0 未発見 DIX=1 |
| 429 | SCREEN7 | SRCH EQ=1 発見 |

## SCREEN10 のコマンド

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 430 | SCREEN10 | HMMV 基本 |
| 431 | SCREEN10 | HMMV 右端はみ出し DIY=1 |
| 432 | SCREEN10 | LMMV XOR DIX=1 |
| 433 | SCREEN10 | LMMV TIMP |
| 434 | SCREEN10 | LMMM DIX=1 DIY=1 |
| 435 | SCREEN10 | HMMM 基本 (SX/DX 奇数) |
| 436 | SCREEN10 | YMMM DIX=1 |
| 437 | SCREEN10 | LMCM 右端はみ出し |
| 438 | SCREEN10 | LMMC TIMP DIX=1 |
| 439 | SCREEN10 | HMMC 基本 (DX 奇数) |
| 440 | SCREEN10 | PSET OR |
| 441 | SCREEN10 | POINT X=1 |
| 442 | SCREEN10 | LINE X 主軸 |
| 443 | SCREEN10 | LINE Y 主軸 DIX=1 DIY=1 |
| 444 | SCREEN10 | SRCH 発見 |
| 445 | SCREEN10 | SRCH 未発見 |

## SCREEN12 のコマンド

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 446 | SCREEN12 | HMMV 基本 |
| 447 | SCREEN12 | HMMV 右端はみ出し DIY=1 |
| 448 | SCREEN12 | LMMV XOR DIX=1 |
| 449 | SCREEN12 | LMMV TIMP |
| 450 | SCREEN12 | LMMM DIX=1 DIY=1 |
| 451 | SCREEN12 | HMMM 基本 (SX/DX 奇数) |
| 452 | SCREEN12 | YMMM DIX=1 |
| 453 | SCREEN12 | LMCM 右端はみ出し |
| 454 | SCREEN12 | LMMC TIMP DIX=1 |
| 455 | SCREEN12 | HMMC 基本 (DX 奇数) |
| 456 | SCREEN12 | PSET OR |
| 457 | SCREEN12 | POINT X=1 |
| 458 | SCREEN12 | LINE X 主軸 |
| 459 | SCREEN12 | LINE Y 主軸 DIX=1 DIY=1 |
| 460 | SCREEN12 | SRCH 発見 |
| 461 | SCREEN12 | SRCH 未発見 |

## SCREEN0-4 で R#25 CMD=1 (SCREEN8 相当)

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 462 | SCREEN0(W40) CMD=1 | HMMV 基本 |
| 463 | SCREEN0(W40) CMD=1 | HMMV 右端はみ出し DIY=1 |
| 464 | SCREEN0(W40) CMD=1 | LMMV XOR DIX=1 |
| 465 | SCREEN0(W40) CMD=1 | LMMV TIMP |
| 466 | SCREEN0(W40) CMD=1 | LMMM DIX=1 DIY=1 |
| 467 | SCREEN0(W40) CMD=1 | HMMM 基本 (SX/DX 奇数) |
| 468 | SCREEN0(W40) CMD=1 | YMMM DIX=1 |
| 469 | SCREEN0(W40) CMD=1 | LMCM 右端はみ出し |
| 470 | SCREEN0(W40) CMD=1 | LMMC TIMP DIX=1 |
| 471 | SCREEN0(W40) CMD=1 | HMMC 基本 (DX 奇数) |
| 472 | SCREEN0(W40) CMD=1 | PSET OR |
| 473 | SCREEN0(W40) CMD=1 | POINT X=1 |
| 474 | SCREEN0(W40) CMD=1 | LINE X 主軸 |
| 475 | SCREEN0(W40) CMD=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 476 | SCREEN0(W40) CMD=1 | SRCH 発見 |
| 477 | SCREEN0(W40) CMD=1 | SRCH 未発見 |

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 478 | SCREEN0(W80) CMD=1 | HMMV 基本 |
| 479 | SCREEN0(W80) CMD=1 | HMMV 右端はみ出し DIY=1 |
| 480 | SCREEN0(W80) CMD=1 | LMMV XOR DIX=1 |
| 481 | SCREEN0(W80) CMD=1 | LMMV TIMP |
| 482 | SCREEN0(W80) CMD=1 | LMMM DIX=1 DIY=1 |
| 483 | SCREEN0(W80) CMD=1 | HMMM 基本 (SX/DX 奇数) |
| 484 | SCREEN0(W80) CMD=1 | YMMM DIX=1 |
| 485 | SCREEN0(W80) CMD=1 | LMCM 右端はみ出し |
| 486 | SCREEN0(W80) CMD=1 | LMMC TIMP DIX=1 |
| 487 | SCREEN0(W80) CMD=1 | HMMC 基本 (DX 奇数) |
| 488 | SCREEN0(W80) CMD=1 | PSET OR |
| 489 | SCREEN0(W80) CMD=1 | POINT X=1 |
| 490 | SCREEN0(W80) CMD=1 | LINE X 主軸 |
| 491 | SCREEN0(W80) CMD=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 492 | SCREEN0(W80) CMD=1 | SRCH 発見 |
| 493 | SCREEN0(W80) CMD=1 | SRCH 未発見 |

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 494 | SCREEN1 CMD=1 | HMMV 基本 |
| 495 | SCREEN1 CMD=1 | HMMV 右端はみ出し DIY=1 |
| 496 | SCREEN1 CMD=1 | LMMV XOR DIX=1 |
| 497 | SCREEN1 CMD=1 | LMMV TIMP |
| 498 | SCREEN1 CMD=1 | LMMM DIX=1 DIY=1 |
| 499 | SCREEN1 CMD=1 | HMMM 基本 (SX/DX 奇数) |
| 500 | SCREEN1 CMD=1 | YMMM DIX=1 |
| 501 | SCREEN1 CMD=1 | LMCM 右端はみ出し |
| 502 | SCREEN1 CMD=1 | LMMC TIMP DIX=1 |
| 503 | SCREEN1 CMD=1 | HMMC 基本 (DX 奇数) |
| 504 | SCREEN1 CMD=1 | PSET OR |
| 505 | SCREEN1 CMD=1 | POINT X=1 |
| 506 | SCREEN1 CMD=1 | LINE X 主軸 |
| 507 | SCREEN1 CMD=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 508 | SCREEN1 CMD=1 | SRCH 発見 |
| 509 | SCREEN1 CMD=1 | SRCH 未発見 |

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 510 | SCREEN2 CMD=1 | HMMV 基本 |
| 511 | SCREEN2 CMD=1 | HMMV 右端はみ出し DIY=1 |
| 512 | SCREEN2 CMD=1 | LMMV XOR DIX=1 |
| 513 | SCREEN2 CMD=1 | LMMV TIMP |
| 514 | SCREEN2 CMD=1 | LMMM DIX=1 DIY=1 |
| 515 | SCREEN2 CMD=1 | HMMM 基本 (SX/DX 奇数) |
| 516 | SCREEN2 CMD=1 | YMMM DIX=1 |
| 517 | SCREEN2 CMD=1 | LMCM 右端はみ出し |
| 518 | SCREEN2 CMD=1 | LMMC TIMP DIX=1 |
| 519 | SCREEN2 CMD=1 | HMMC 基本 (DX 奇数) |
| 520 | SCREEN2 CMD=1 | PSET OR |
| 521 | SCREEN2 CMD=1 | POINT X=1 |
| 522 | SCREEN2 CMD=1 | LINE X 主軸 |
| 523 | SCREEN2 CMD=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 524 | SCREEN2 CMD=1 | SRCH 発見 |
| 525 | SCREEN2 CMD=1 | SRCH 未発見 |

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 526 | SCREEN3 CMD=1 | HMMV 基本 |
| 527 | SCREEN3 CMD=1 | HMMV 右端はみ出し DIY=1 |
| 528 | SCREEN3 CMD=1 | LMMV XOR DIX=1 |
| 529 | SCREEN3 CMD=1 | LMMV TIMP |
| 530 | SCREEN3 CMD=1 | LMMM DIX=1 DIY=1 |
| 531 | SCREEN3 CMD=1 | HMMM 基本 (SX/DX 奇数) |
| 532 | SCREEN3 CMD=1 | YMMM DIX=1 |
| 533 | SCREEN3 CMD=1 | LMCM 右端はみ出し |
| 534 | SCREEN3 CMD=1 | LMMC TIMP DIX=1 |
| 535 | SCREEN3 CMD=1 | HMMC 基本 (DX 奇数) |
| 536 | SCREEN3 CMD=1 | PSET OR |
| 537 | SCREEN3 CMD=1 | POINT X=1 |
| 538 | SCREEN3 CMD=1 | LINE X 主軸 |
| 539 | SCREEN3 CMD=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 540 | SCREEN3 CMD=1 | SRCH 発見 |
| 541 | SCREEN3 CMD=1 | SRCH 未発見 |

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 542 | SCREEN4 CMD=1 | HMMV 基本 |
| 543 | SCREEN4 CMD=1 | HMMV 右端はみ出し DIY=1 |
| 544 | SCREEN4 CMD=1 | LMMV XOR DIX=1 |
| 545 | SCREEN4 CMD=1 | LMMV TIMP |
| 546 | SCREEN4 CMD=1 | LMMM DIX=1 DIY=1 |
| 547 | SCREEN4 CMD=1 | HMMM 基本 (SX/DX 奇数) |
| 548 | SCREEN4 CMD=1 | YMMM DIX=1 |
| 549 | SCREEN4 CMD=1 | LMCM 右端はみ出し |
| 550 | SCREEN4 CMD=1 | LMMC TIMP DIX=1 |
| 551 | SCREEN4 CMD=1 | HMMC 基本 (DX 奇数) |
| 552 | SCREEN4 CMD=1 | PSET OR |
| 553 | SCREEN4 CMD=1 | POINT X=1 |
| 554 | SCREEN4 CMD=1 | LINE X 主軸 |
| 555 | SCREEN4 CMD=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 556 | SCREEN4 CMD=1 | SRCH 発見 |
| 557 | SCREEN4 CMD=1 | SRCH 未発見 |

### コマンド無効

| No. | モード | 内容 |
|---:|---|---|
| 558 | SCREEN1 | CMD=0 では HMMV が実行されない |

### コマンド無効

| No. | モード | 内容 |
|---:|---|---|
| 559 | SCREEN4 | CMD=0 では HMMV が実行されない |

## SCREEN0(W40) で FG4=1 (SCREEN5 相当, V9968 のみ)

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 560 | SCREEN0(W40) CMD=1 FG4=1 | HMMV 基本 |
| 561 | SCREEN0(W40) CMD=1 FG4=1 | HMMV 右端はみ出し DIY=1 |
| 562 | SCREEN0(W40) CMD=1 FG4=1 | LMMV XOR DIX=1 |
| 563 | SCREEN0(W40) CMD=1 FG4=1 | LMMV TIMP |
| 564 | SCREEN0(W40) CMD=1 FG4=1 | LMMM DIX=1 DIY=1 |
| 565 | SCREEN0(W40) CMD=1 FG4=1 | HMMM 基本 (SX/DX 奇数) |
| 566 | SCREEN0(W40) CMD=1 FG4=1 | YMMM DIX=1 |
| 567 | SCREEN0(W40) CMD=1 FG4=1 | LMCM 右端はみ出し |
| 568 | SCREEN0(W40) CMD=1 FG4=1 | LMMC TIMP DIX=1 |
| 569 | SCREEN0(W40) CMD=1 FG4=1 | HMMC 基本 (DX 奇数) |
| 570 | SCREEN0(W40) CMD=1 FG4=1 | PSET OR |
| 571 | SCREEN0(W40) CMD=1 FG4=1 | POINT X=1 |
| 572 | SCREEN0(W40) CMD=1 FG4=1 | LINE X 主軸 |
| 573 | SCREEN0(W40) CMD=1 FG4=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 574 | SCREEN0(W40) CMD=1 FG4=1 | SRCH 発見 |
| 575 | SCREEN0(W40) CMD=1 FG4=1 | SRCH 未発見 |

## SCREEN0(W80) で FG4=1 (SCREEN5 相当, V9968 のみ)

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 576 | SCREEN0(W80) CMD=1 FG4=1 | HMMV 基本 |
| 577 | SCREEN0(W80) CMD=1 FG4=1 | HMMV 右端はみ出し DIY=1 |
| 578 | SCREEN0(W80) CMD=1 FG4=1 | LMMV XOR DIX=1 |
| 579 | SCREEN0(W80) CMD=1 FG4=1 | LMMV TIMP |
| 580 | SCREEN0(W80) CMD=1 FG4=1 | LMMM DIX=1 DIY=1 |
| 581 | SCREEN0(W80) CMD=1 FG4=1 | HMMM 基本 (SX/DX 奇数) |
| 582 | SCREEN0(W80) CMD=1 FG4=1 | YMMM DIX=1 |
| 583 | SCREEN0(W80) CMD=1 FG4=1 | LMCM 右端はみ出し |
| 584 | SCREEN0(W80) CMD=1 FG4=1 | LMMC TIMP DIX=1 |
| 585 | SCREEN0(W80) CMD=1 FG4=1 | HMMC 基本 (DX 奇数) |
| 586 | SCREEN0(W80) CMD=1 FG4=1 | PSET OR |
| 587 | SCREEN0(W80) CMD=1 FG4=1 | POINT X=1 |
| 588 | SCREEN0(W80) CMD=1 FG4=1 | LINE X 主軸 |
| 589 | SCREEN0(W80) CMD=1 FG4=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 590 | SCREEN0(W80) CMD=1 FG4=1 | SRCH 発見 |
| 591 | SCREEN0(W80) CMD=1 FG4=1 | SRCH 未発見 |

## SCREEN1 で FG4=1 (SCREEN5 相当, V9968 のみ)

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 592 | SCREEN1 CMD=1 FG4=1 | HMMV 基本 |
| 593 | SCREEN1 CMD=1 FG4=1 | HMMV 右端はみ出し DIY=1 |
| 594 | SCREEN1 CMD=1 FG4=1 | LMMV XOR DIX=1 |
| 595 | SCREEN1 CMD=1 FG4=1 | LMMV TIMP |
| 596 | SCREEN1 CMD=1 FG4=1 | LMMM DIX=1 DIY=1 |
| 597 | SCREEN1 CMD=1 FG4=1 | HMMM 基本 (SX/DX 奇数) |
| 598 | SCREEN1 CMD=1 FG4=1 | YMMM DIX=1 |
| 599 | SCREEN1 CMD=1 FG4=1 | LMCM 右端はみ出し |
| 600 | SCREEN1 CMD=1 FG4=1 | LMMC TIMP DIX=1 |
| 601 | SCREEN1 CMD=1 FG4=1 | HMMC 基本 (DX 奇数) |
| 602 | SCREEN1 CMD=1 FG4=1 | PSET OR |
| 603 | SCREEN1 CMD=1 FG4=1 | POINT X=1 |
| 604 | SCREEN1 CMD=1 FG4=1 | LINE X 主軸 |
| 605 | SCREEN1 CMD=1 FG4=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 606 | SCREEN1 CMD=1 FG4=1 | SRCH 発見 |
| 607 | SCREEN1 CMD=1 FG4=1 | SRCH 未発見 |

### コマンド無効

| No. | モード | 内容 |
|---:|---|---|
| 608 | SCREEN1 FG4=1 | CMD=0 では HMMV が実行されない |

## SCREEN2 で FG4=1 (SCREEN5 相当, V9968 のみ)

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 609 | SCREEN2 CMD=1 FG4=1 | HMMV 基本 |
| 610 | SCREEN2 CMD=1 FG4=1 | HMMV 右端はみ出し DIY=1 |
| 611 | SCREEN2 CMD=1 FG4=1 | LMMV XOR DIX=1 |
| 612 | SCREEN2 CMD=1 FG4=1 | LMMV TIMP |
| 613 | SCREEN2 CMD=1 FG4=1 | LMMM DIX=1 DIY=1 |
| 614 | SCREEN2 CMD=1 FG4=1 | HMMM 基本 (SX/DX 奇数) |
| 615 | SCREEN2 CMD=1 FG4=1 | YMMM DIX=1 |
| 616 | SCREEN2 CMD=1 FG4=1 | LMCM 右端はみ出し |
| 617 | SCREEN2 CMD=1 FG4=1 | LMMC TIMP DIX=1 |
| 618 | SCREEN2 CMD=1 FG4=1 | HMMC 基本 (DX 奇数) |
| 619 | SCREEN2 CMD=1 FG4=1 | PSET OR |
| 620 | SCREEN2 CMD=1 FG4=1 | POINT X=1 |
| 621 | SCREEN2 CMD=1 FG4=1 | LINE X 主軸 |
| 622 | SCREEN2 CMD=1 FG4=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 623 | SCREEN2 CMD=1 FG4=1 | SRCH 発見 |
| 624 | SCREEN2 CMD=1 FG4=1 | SRCH 未発見 |

## SCREEN3 で FG4=1 (SCREEN5 相当, V9968 のみ)

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 625 | SCREEN3 CMD=1 FG4=1 | HMMV 基本 |
| 626 | SCREEN3 CMD=1 FG4=1 | HMMV 右端はみ出し DIY=1 |
| 627 | SCREEN3 CMD=1 FG4=1 | LMMV XOR DIX=1 |
| 628 | SCREEN3 CMD=1 FG4=1 | LMMV TIMP |
| 629 | SCREEN3 CMD=1 FG4=1 | LMMM DIX=1 DIY=1 |
| 630 | SCREEN3 CMD=1 FG4=1 | HMMM 基本 (SX/DX 奇数) |
| 631 | SCREEN3 CMD=1 FG4=1 | YMMM DIX=1 |
| 632 | SCREEN3 CMD=1 FG4=1 | LMCM 右端はみ出し |
| 633 | SCREEN3 CMD=1 FG4=1 | LMMC TIMP DIX=1 |
| 634 | SCREEN3 CMD=1 FG4=1 | HMMC 基本 (DX 奇数) |
| 635 | SCREEN3 CMD=1 FG4=1 | PSET OR |
| 636 | SCREEN3 CMD=1 FG4=1 | POINT X=1 |
| 637 | SCREEN3 CMD=1 FG4=1 | LINE X 主軸 |
| 638 | SCREEN3 CMD=1 FG4=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 639 | SCREEN3 CMD=1 FG4=1 | SRCH 発見 |
| 640 | SCREEN3 CMD=1 FG4=1 | SRCH 未発見 |

## SCREEN4 で FG4=1 (SCREEN5 相当, V9968 のみ)

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 641 | SCREEN4 CMD=1 FG4=1 | HMMV 基本 |
| 642 | SCREEN4 CMD=1 FG4=1 | HMMV 右端はみ出し DIY=1 |
| 643 | SCREEN4 CMD=1 FG4=1 | LMMV XOR DIX=1 |
| 644 | SCREEN4 CMD=1 FG4=1 | LMMV TIMP |
| 645 | SCREEN4 CMD=1 FG4=1 | LMMM DIX=1 DIY=1 |
| 646 | SCREEN4 CMD=1 FG4=1 | HMMM 基本 (SX/DX 奇数) |
| 647 | SCREEN4 CMD=1 FG4=1 | YMMM DIX=1 |
| 648 | SCREEN4 CMD=1 FG4=1 | LMCM 右端はみ出し |
| 649 | SCREEN4 CMD=1 FG4=1 | LMMC TIMP DIX=1 |
| 650 | SCREEN4 CMD=1 FG4=1 | HMMC 基本 (DX 奇数) |
| 651 | SCREEN4 CMD=1 FG4=1 | PSET OR |
| 652 | SCREEN4 CMD=1 FG4=1 | POINT X=1 |
| 653 | SCREEN4 CMD=1 FG4=1 | LINE X 主軸 |
| 654 | SCREEN4 CMD=1 FG4=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 655 | SCREEN4 CMD=1 FG4=1 | SRCH 発見 |
| 656 | SCREEN4 CMD=1 FG4=1 | SRCH 未発見 |

### コマンド無効

| No. | モード | 内容 |
|---:|---|---|
| 657 | SCREEN4 FG4=1 | CMD=0 では HMMV が実行されない |

## SCREEN5 で FG4=1 (SCREEN5 相当, V9968 のみ)

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 658 | SCREEN5 FG4=1 | HMMV 基本 |
| 659 | SCREEN5 FG4=1 | HMMV 右端はみ出し DIY=1 |
| 660 | SCREEN5 FG4=1 | LMMV XOR DIX=1 |
| 661 | SCREEN5 FG4=1 | LMMV TIMP |
| 662 | SCREEN5 FG4=1 | LMMM DIX=1 DIY=1 |
| 663 | SCREEN5 FG4=1 | HMMM 基本 (SX/DX 奇数) |
| 664 | SCREEN5 FG4=1 | YMMM DIX=1 |
| 665 | SCREEN5 FG4=1 | LMCM 右端はみ出し |
| 666 | SCREEN5 FG4=1 | LMMC TIMP DIX=1 |
| 667 | SCREEN5 FG4=1 | HMMC 基本 (DX 奇数) |
| 668 | SCREEN5 FG4=1 | PSET OR |
| 669 | SCREEN5 FG4=1 | POINT X=1 |
| 670 | SCREEN5 FG4=1 | LINE X 主軸 |
| 671 | SCREEN5 FG4=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 672 | SCREEN5 FG4=1 | SRCH 発見 |
| 673 | SCREEN5 FG4=1 | SRCH 未発見 |

## SCREEN6 で FG4=1 (SCREEN5 相当, V9968 のみ)

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 674 | SCREEN6 FG4=1 | HMMV 基本 |
| 675 | SCREEN6 FG4=1 | HMMV 右端はみ出し DIY=1 |
| 676 | SCREEN6 FG4=1 | LMMV XOR DIX=1 |
| 677 | SCREEN6 FG4=1 | LMMV TIMP |
| 678 | SCREEN6 FG4=1 | LMMM DIX=1 DIY=1 |
| 679 | SCREEN6 FG4=1 | HMMM 基本 (SX/DX 奇数) |
| 680 | SCREEN6 FG4=1 | YMMM DIX=1 |
| 681 | SCREEN6 FG4=1 | LMCM 右端はみ出し |
| 682 | SCREEN6 FG4=1 | LMMC TIMP DIX=1 |
| 683 | SCREEN6 FG4=1 | HMMC 基本 (DX 奇数) |
| 684 | SCREEN6 FG4=1 | PSET OR |
| 685 | SCREEN6 FG4=1 | POINT X=1 |
| 686 | SCREEN6 FG4=1 | LINE X 主軸 |
| 687 | SCREEN6 FG4=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 688 | SCREEN6 FG4=1 | SRCH 発見 |
| 689 | SCREEN6 FG4=1 | SRCH 未発見 |

## SCREEN7 で FG4=1 (SCREEN5 相当, V9968 のみ)

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 690 | SCREEN7 FG4=1 | HMMV 基本 |
| 691 | SCREEN7 FG4=1 | HMMV 右端はみ出し DIY=1 |
| 692 | SCREEN7 FG4=1 | LMMV XOR DIX=1 |
| 693 | SCREEN7 FG4=1 | LMMV TIMP |
| 694 | SCREEN7 FG4=1 | LMMM DIX=1 DIY=1 |
| 695 | SCREEN7 FG4=1 | HMMM 基本 (SX/DX 奇数) |
| 696 | SCREEN7 FG4=1 | YMMM DIX=1 |
| 697 | SCREEN7 FG4=1 | LMCM 右端はみ出し |
| 698 | SCREEN7 FG4=1 | LMMC TIMP DIX=1 |
| 699 | SCREEN7 FG4=1 | HMMC 基本 (DX 奇数) |
| 700 | SCREEN7 FG4=1 | PSET OR |
| 701 | SCREEN7 FG4=1 | POINT X=1 |
| 702 | SCREEN7 FG4=1 | LINE X 主軸 |
| 703 | SCREEN7 FG4=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 704 | SCREEN7 FG4=1 | SRCH 発見 |
| 705 | SCREEN7 FG4=1 | SRCH 未発見 |

## SCREEN8 で FG4=1 (SCREEN5 相当, V9968 のみ)

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 706 | SCREEN8 FG4=1 | HMMV 基本 |
| 707 | SCREEN8 FG4=1 | HMMV 右端はみ出し DIY=1 |
| 708 | SCREEN8 FG4=1 | LMMV XOR DIX=1 |
| 709 | SCREEN8 FG4=1 | LMMV TIMP |
| 710 | SCREEN8 FG4=1 | LMMM DIX=1 DIY=1 |
| 711 | SCREEN8 FG4=1 | HMMM 基本 (SX/DX 奇数) |
| 712 | SCREEN8 FG4=1 | YMMM DIX=1 |
| 713 | SCREEN8 FG4=1 | LMCM 右端はみ出し |
| 714 | SCREEN8 FG4=1 | LMMC TIMP DIX=1 |
| 715 | SCREEN8 FG4=1 | HMMC 基本 (DX 奇数) |
| 716 | SCREEN8 FG4=1 | PSET OR |
| 717 | SCREEN8 FG4=1 | POINT X=1 |
| 718 | SCREEN8 FG4=1 | LINE X 主軸 |
| 719 | SCREEN8 FG4=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 720 | SCREEN8 FG4=1 | SRCH 発見 |
| 721 | SCREEN8 FG4=1 | SRCH 未発見 |

## SCREEN10 で FG4=1 (SCREEN5 相当, V9968 のみ)

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 722 | SCREEN10 FG4=1 | HMMV 基本 |
| 723 | SCREEN10 FG4=1 | HMMV 右端はみ出し DIY=1 |
| 724 | SCREEN10 FG4=1 | LMMV XOR DIX=1 |
| 725 | SCREEN10 FG4=1 | LMMV TIMP |
| 726 | SCREEN10 FG4=1 | LMMM DIX=1 DIY=1 |
| 727 | SCREEN10 FG4=1 | HMMM 基本 (SX/DX 奇数) |
| 728 | SCREEN10 FG4=1 | YMMM DIX=1 |
| 729 | SCREEN10 FG4=1 | LMCM 右端はみ出し |
| 730 | SCREEN10 FG4=1 | LMMC TIMP DIX=1 |
| 731 | SCREEN10 FG4=1 | HMMC 基本 (DX 奇数) |
| 732 | SCREEN10 FG4=1 | PSET OR |
| 733 | SCREEN10 FG4=1 | POINT X=1 |
| 734 | SCREEN10 FG4=1 | LINE X 主軸 |
| 735 | SCREEN10 FG4=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 736 | SCREEN10 FG4=1 | SRCH 発見 |
| 737 | SCREEN10 FG4=1 | SRCH 未発見 |

## SCREEN11 で FG4=1 (SCREEN5 相当, V9968 のみ)

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 738 | SCREEN11 FG4=1 | HMMV 基本 |
| 739 | SCREEN11 FG4=1 | HMMV 右端はみ出し DIY=1 |
| 740 | SCREEN11 FG4=1 | LMMV XOR DIX=1 |
| 741 | SCREEN11 FG4=1 | LMMV TIMP |
| 742 | SCREEN11 FG4=1 | LMMM DIX=1 DIY=1 |
| 743 | SCREEN11 FG4=1 | HMMM 基本 (SX/DX 奇数) |
| 744 | SCREEN11 FG4=1 | YMMM DIX=1 |
| 745 | SCREEN11 FG4=1 | LMCM 右端はみ出し |
| 746 | SCREEN11 FG4=1 | LMMC TIMP DIX=1 |
| 747 | SCREEN11 FG4=1 | HMMC 基本 (DX 奇数) |
| 748 | SCREEN11 FG4=1 | PSET OR |
| 749 | SCREEN11 FG4=1 | POINT X=1 |
| 750 | SCREEN11 FG4=1 | LINE X 主軸 |
| 751 | SCREEN11 FG4=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 752 | SCREEN11 FG4=1 | SRCH 発見 |
| 753 | SCREEN11 FG4=1 | SRCH 未発見 |

## SCREEN12 で FG4=1 (SCREEN5 相当, V9968 のみ)

### 全コマンド (簡易)

| No. | モード | 内容 |
|---:|---|---|
| 754 | SCREEN12 FG4=1 | HMMV 基本 |
| 755 | SCREEN12 FG4=1 | HMMV 右端はみ出し DIY=1 |
| 756 | SCREEN12 FG4=1 | LMMV XOR DIX=1 |
| 757 | SCREEN12 FG4=1 | LMMV TIMP |
| 758 | SCREEN12 FG4=1 | LMMM DIX=1 DIY=1 |
| 759 | SCREEN12 FG4=1 | HMMM 基本 (SX/DX 奇数) |
| 760 | SCREEN12 FG4=1 | YMMM DIX=1 |
| 761 | SCREEN12 FG4=1 | LMCM 右端はみ出し |
| 762 | SCREEN12 FG4=1 | LMMC TIMP DIX=1 |
| 763 | SCREEN12 FG4=1 | HMMC 基本 (DX 奇数) |
| 764 | SCREEN12 FG4=1 | PSET OR |
| 765 | SCREEN12 FG4=1 | POINT X=1 |
| 766 | SCREEN12 FG4=1 | LINE X 主軸 |
| 767 | SCREEN12 FG4=1 | LINE Y 主軸 DIX=1 DIY=1 |
| 768 | SCREEN12 FG4=1 | SRCH 発見 |
| 769 | SCREEN12 FG4=1 | SRCH 未発見 |
