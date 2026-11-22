# VDPCHK テスト項目一覧

このファイルは `gen_vdpchk.py` が生成します。直接編集しないでください。

- 全 1484 項目。VDPCHK.COM が 1～874、VDPREG.COM が 875～1484 を実行し、失敗した項目の番号を最後に表示します。
- 期待値は openMSX の VDPCmdEngine (実機で確認された動作) とデータブックに準拠した参照モデルで生成しています。
- 各項目は試験範囲を既知のパターンで埋めてから実行し、CPU で VRAM を読み戻して CRC で比較します。範囲はコマンドが触れるライン全体と、その上下 1 ラインです。
- 「V9968 のみ」の節は V9968 を検出できない場合 (V9958 実機など) はスキップし、全数に含めません。
- VRAM バンクの節は全バンクにバンクごとに異なるパターンを書き、対象バンクとバンク番号が 1 ビット違うバンク(ガード) も読み戻して、別バンクの同じアドレスが壊れていないことを確認します。R#29 (スプライト) は 1 フレーム表示させて S#0 の衝突フラグで確認します。LFMM はフォントを SRC バンク、描画先を DST バンクに置き、ガードバンクの同じアドレスには別のフォントを置いて確認します。BG バンク (表示のみ)、コマンド実行中の R#30 変更は自動確認の対象外です。
- 番号の後ろの `T` はタイムアウト (CE または TR が落ちなかった) を表します。

# VDPCHK.COM

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

## VRAM 4MB バンク R#28/R#29/R#30 (V9968 のみ)

### バンクレジスタの書き込み条件

| No. | モード | 内容 |
|---:|---|---|
| 770 | SCREEN5 | R#28 の上位 4 ビットは無視 (F5h = バンク 5) |
| 771 | SCREEN5 | P#4 ロック中は R#28 の書き込みを無視 |
| 772 | SCREEN5 | P#4 ロック中は R#30 の書き込みを無視 (HMMV は DST=1 のまま) |
| 773 | SCREEN5 | R#29 は CPU/コマンドのバンクを変えない |
| 774 | SCREEN5 | R#21 V58=1 で全バンクが 0 に戻り、V58=1 の間は R#28/R#30 を無視 |
| 775 | SCREEN5 | R#30 は下位 4 ビットが SRC、上位 4 ビットが DST |

### CPU (R#28) による全バンクの読み書き

| No. | モード | 内容 |
|---:|---|---|
| 776 | SCREEN5 | 全 16 バンクに異なるパターンを書いて読み戻す (先頭/128KB 境界/末尾) |
| 777 | SCREEN8 | 全 16 バンクに異なるパターンを書いて読み戻す (先頭/128KB 境界/末尾) |
| 778 | SCREEN5 | バンク 1 だけに書き、他の 15 バンクの 0x3FF00 が壊れない |
| 779 | SCREEN5 | バンク 2 だけに書き、他の 15 バンクの 0x37A00 が壊れない |
| 780 | SCREEN5 | バンク 4 だけに書き、他の 15 バンクの 0x2F600 が壊れない |
| 781 | SCREEN5 | バンク 8 だけに書き、他の 15 バンクの 0x27200 が壊れない |
| 782 | SCREEN5 | バンク 14 だけに書き、他の 15 バンクの 0x1EE00 が壊れない |
| 783 | SCREEN5 | バンク 13 だけに書き、他の 15 バンクの 0x16A00 が壊れない |
| 784 | SCREEN5 | バンク 11 だけに書き、他の 15 バンクの 0x0E600 が壊れない |
| 785 | SCREEN5 | バンク 7 だけに書き、他の 15 バンクの 0x06200 が壊れない |
| 786 | SCREEN5 | バンク 0: 0x3FFFF から同じバンクの 0x00000 へ折り返す (バンク 1 は不変) |
| 787 | SCREEN5 | バンク 7: 0x3FFFF から同じバンクの 0x00000 へ折り返す (バンク 8 は不変) |
| 788 | SCREEN5 | バンク 15: 0x3FFFF から同じバンクの 0x00000 へ折り返す (バンク 0 は不変) |
| 789 | SCREEN5 | バンク 3: 0x1FFFF から 0x20000 への連続書き込み |
| 790 | SCREEN8 | バンク 12: 0x1FFFF から 0x20000 への連続書き込み |
| 791 | SCREEN1 | バンク 10: SCREEN1 では 16KB 内で折り返す (A17-A14 とバンクは保持) |

### CPU アクセスの途中で R#28 を変更

| No. | モード | 内容 |
|---:|---|---|
| 792 | SCREEN5 | 読み出し中に R#28 を 3->12: 先読み済みの 1 バイトは旧バンク |
| 793 | SCREEN5 | 書き込み中に R#28 を 5->9: 以降の書き込みは新バンク |
| 794 | SCREEN8 | 読み出し中に R#28 を 3->12: 先読み済みの 1 バイトは旧バンク |
| 795 | SCREEN8 | 書き込み中に R#28 を 5->9: 以降の書き込みは新バンク |

### VDP コマンド (R#30) SCREEN5: 256KB = Y 0-2047

| No. | モード | 内容 |
|---:|---|---|
| 796 | SCREEN5 | HMMV DST=1 |
| 797 | SCREEN5 | HMMV DST=8 |
| 798 | SCREEN5 | HMMV DST=15 |
| 799 | SCREEN5 | HMMV DST=5 Y=1022-1025 (128KB 境界) |
| 800 | SCREEN5 | HMMV DST=10 Y=2046-1 (バンク内で折り返す) |
| 801 | SCREEN5 | HMMV DST=6 DIY=1 Y=1025-1022 |
| 802 | SCREEN5 | LMMV XOR DST=7 Y=1500 |
| 803 | SCREEN5 | HMMM SRC=3 DST=12 (同じ座標) |
| 804 | SCREEN5 | HMMM SRC=DST=5 重なり |
| 805 | SCREEN5 | HMMM SRC=9 Y=1022-1025 -> DST=6 Y=2046-1 |
| 806 | SCREEN5 | HMMM DIY=1 SRC=1 Y=2047-2046 -> DST=2 Y=1-0 |
| 807 | SCREEN5 | LMMM XOR SRC=14 DST=1 |
| 808 | SCREEN5 | LMMM TIMP SRC=0 DST=15 |
| 809 | SCREEN5 | YMMM SRC=11 DST=4 |
| 810 | SCREEN5 | LMCM SRC=13 (DST=2) |
| 811 | SCREEN5 | POINT SRC=6 (DST=9) |
| 812 | SCREEN5 | PSET OR DST=3 (SRC=12 は使わない) |
| 813 | SCREEN5 | LINE DST=14 (SRC=1) |
| 814 | SCREEN5 | LMMC TIMP DST=5 (SRC=10) |
| 815 | SCREEN5 | HMMC DST=12 Y=2047-0 |
| 816 | SCREEN5 | SRCH SRC=9: バンクごとに異なる X に目標色 |
| 817 | SCREEN5 | SRCH EQ=1 SRC=4 |
| 818 | SCREEN5 | HMMV NX=0 NY=0 で DST=6 の 256KB 全体を塗る (バンク 5 末尾/7 先頭/14 は不変) |

### VDP コマンド (R#30) SCREEN8: 256KB = Y 0-1023 (インターリーブ)

| No. | モード | 内容 |
|---:|---|---|
| 819 | SCREEN8 | HMMV DST=1 |
| 820 | SCREEN8 | HMMV DST=8 |
| 821 | SCREEN8 | HMMV DST=15 |
| 822 | SCREEN8 | HMMV DST=5 Y=510-513 (128KB 境界) |
| 823 | SCREEN8 | HMMV DST=10 Y=1022-1 (バンク内で折り返す) |
| 824 | SCREEN8 | LMMV XOR DST=7 |
| 825 | SCREEN8 | HMMM SRC=3 DST=12 (同じ座標) |
| 826 | SCREEN8 | HMMM SRC=9 Y=510-513 -> DST=6 Y=1022-1 |
| 827 | SCREEN8 | LMMM TIMP SRC=14 DST=1 |
| 828 | SCREEN8 | YMMM SRC=11 DST=4 |
| 829 | SCREEN8 | LMCM SRC=13 (DST=2) |
| 830 | SCREEN8 | POINT SRC=6 (DST=9) |
| 831 | SCREEN8 | PSET XOR DST=3 (SRC=12 は使わない) |
| 832 | SCREEN8 | LINE DST=14 (SRC=1) |
| 833 | SCREEN8 | LMMC DST=5 (SRC=10) |
| 834 | SCREEN8 | HMMC DST=12 Y=1023-0 |
| 835 | SCREEN8 | SRCH SRC=9: バンクごとに異なる X に目標色 |

### VDP コマンド (R#30) その他の画面モード

| No. | モード | 内容 |
|---:|---|---|
| 836 | SCREEN6 | LMMV DST=13 Y=1022-1025 |
| 837 | SCREEN7 | HMMV DST=11 Y=510-513 |
| 838 | SCREEN7 | HMMM SRC=2 DST=13 Y=1023-0 |
| 839 | SCREEN8 FG4=1 | HMMV DST=9 Y=1022-1025 (SCREEN5 相当) |
| 840 | SCREEN8 FG4=1 | LMMM SRC=3 Y=2047 -> DST=12 Y=0 |

### CPU と VDP コマンドのバンクを変えて同じアドレスへアクセス

| No. | モード | 内容 |
|---:|---|---|
| 841 | SCREEN5 | CPU がバンク 3 に書いた直後に HMMM が SRC=7 の同アドレスを読む |
| 842 | SCREEN8 | CPU がバンク 3 に書いた直後に HMMM が SRC=7 の同アドレスを読む |
| 843 | SCREEN5 | CPU(12) 書込 -> HMMV(13) -> CPU(12) 書込 -> HMMC(13) -> LMMV(12) を順に同アドレスへ |
| 844 | SCREEN8 | CPU(12) 書込 -> HMMV(13) -> CPU(12) 書込 -> HMMC(13) -> LMMV(12) を順に同アドレスへ |

### VDP コマンド実行中に別バンクを CPU でアクセス

| No. | モード | 内容 |
|---:|---|---|
| 845 | SCREEN5 | HMMV(DST=9) 実行中に CPU がバンク 6 の同アドレスとバンク 9 の別ラインを読み書き |
| 846 | SCREEN5 | HMMM(SRC=2 DST=3) 実行中に CPU が R#28 を 2/4/5 と切り替えて同アドレスを読み書き |
| 847 | SCREEN8 | HMMV(DST=9) 実行中に CPU がバンク 6 の同アドレスとバンク 9 の別ラインを読み書き |
| 848 | SCREEN8 | HMMM(SRC=2 DST=3) 実行中に CPU が R#28 を 2/4/5 と切り替えて同アドレスを読み書き |
| 849 | SCREEN5 | LMMV TIMP(DST=10) 実行中に CPU がバンク 11 へ書き、読み戻す |

### スプライト (R#29 上位 4 ビット): S#0 の衝突フラグで確認

| No. | モード | 内容 |
|---:|---|---|
| 850 | SCREEN5 | R#29=00h: バンク 0 の衝突するスプライト |
| 851 | SCREEN5 | R#29=90h: バンク 9 だけに衝突するスプライト |
| 852 | SCREEN5 | R#29=09h: BG バンク=9 ではスプライトはバンク 0 (衝突なし) |
| 853 | SCREEN5 | R#29=60h: バンク 0 だけ衝突、バンク 6 は無し (衝突なし) |
| 854 | SCREEN5 | R#29=F6h: バンク 15 だけに衝突するスプライト |
| 855 | SCREEN5 | R#29=E0h, R#28=R#30=バンク 15 (衝突あり): スプライトは 14 |
| 856 | SCREEN8 | R#29=00h: バンク 0 の衝突するスプライト |
| 857 | SCREEN8 | R#29=90h: バンク 9 だけに衝突するスプライト |
| 858 | SCREEN8 | R#29=09h: BG バンク=9 ではスプライトはバンク 0 (衝突なし) |
| 859 | SCREEN8 | R#29=60h: バンク 0 だけ衝突、バンク 6 は無し (衝突なし) |

### LFMM (フォントは R#30 SRC バンク、描画は DST バンク)

| No. | モード | 内容 |
|---:|---|---|
| 860 | SCREEN5 | SRC=DST=0 フォント 01000h |
| 861 | SCREEN5 | SRC=3 DST=12 フォント 10000h |
| 862 | SCREEN5 | SRC=12 DST=3 (逆向き) |
| 863 | SCREEN5 | SRC=DST=9 フォント 0F000h -> Y=200 |
| 864 | SCREEN5 | SRC=15 DST=0 |
| 865 | SCREEN5 | SRC=0 DST=15 Y=2040 |
| 866 | SCREEN5 | SRC=6 DST=1 フォント 1FFF8h (128KB 境界をまたぐ) |
| 867 | SCREEN5 | SRC=10 DST=5 フォント 3FFF8h (バンク内で 00000h へ折り返す) |
| 868 | SCREEN5 | TIMP BG=0 SRC=2 DST=13 |
| 869 | SCREEN5 | XOR SRC=11 DST=4 |
| 870 | SCREEN8 | SCREEN8 SRC=7 DST=8 フォント 00123h (インターリーブ) |
| 871 | SCREEN8 | SCREEN8 SRC=13 DST=2 フォント 1FFFCh |
| 872 | SCREEN8 | SCREEN8 SRC=14 DST=1 フォント 3FFF9h (折り返し) |
| 873 | SCREEN7 | SCREEN7 SRC=4 DST=11 フォント 20001h |
| 874 | SCREEN6 | SCREEN6 SRC=12 DST=3 |

# VDPREG.COM (コマンド終了時のレジスタ)

- V9958 の表 4.7 (コマンド終了時のレジスタの状態) を確認します。コマンド R#32～R#46 は読み出せないため、最初のコマンドの後に一部のレジスタ (内容欄の括弧内) と R#46 だけを書いて次のコマンドを実行し、その描画結果、S#7、S#8/S#9 から、保持された値と更新された値 (DY/SY = 終了座標、NY = 残り行数、CLR = 読み出した色) を確認します。
- NY=0 の確認は、DIY=1 で小さい DY から実行し、上端で打ち切られる行数で確認します (NY=0 は 1024 行、256KB モードでは 2048 行)。
- LMMC/HMMC の CLR (最後に CPU が書いた値) と、実行中の STOP は対象外です。

## SCREEN5 のコマンド終了時のレジスタ

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 875 | SCREEN5 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 876 | SCREEN5 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 877 | SCREEN5 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 878 | SCREEN5 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 879 | SCREEN5 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 880 | SCREEN5 | LMMV DIY=1 → LMMV OR (DY/CLR): NY=0 |
| 881 | SCREEN5 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 882 | SCREEN5 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 883 | SCREEN5 | LMMM DIX=1 DIY=1 → LMMM (DY): NY=0, SY=SY0-N |
| 884 | SCREEN5 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 885 | SCREEN5 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 886 | SCREEN5 | HMMM DIY=1 → HMMM (DY): NY=0, SY=SY0-N |
| 887 | SCREEN5 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 888 | SCREEN5 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 889 | SCREEN5 | YMMM 上端で打ち切り → YMMM (DY): SY/NY |
| 890 | SCREEN5 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 891 | SCREEN5 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 892 | SCREEN5 | LMCM 上端で打ち切り → LMCM (SY): NY=NY0-N |
| 893 | SCREEN5 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 894 | SCREEN5 | LMMC 上端で打ち切り → LMMC (DY/CLR): NY=NY0-N |
| 895 | SCREEN5 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 896 | SCREEN5 | HMMC DIX=1 DIY=1 → HMMC (DY/CLR): NY=0 |
| 897 | SCREEN5 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 898 | SCREEN5 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 899 | SCREEN5 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 900 | SCREEN5 | LINE Y 主軸 DIY=1 → LINE (CLR): DY 進む |
| 901 | SCREEN5 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

## SCREEN8 のコマンド終了時のレジスタ

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 902 | SCREEN8 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 903 | SCREEN8 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 904 | SCREEN8 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 905 | SCREEN8 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 906 | SCREEN8 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 907 | SCREEN8 | LMMV DIY=1 → LMMV OR (DY/CLR): NY=0 |
| 908 | SCREEN8 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 909 | SCREEN8 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 910 | SCREEN8 | LMMM DIX=1 DIY=1 → LMMM (DY): NY=0, SY=SY0-N |
| 911 | SCREEN8 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 912 | SCREEN8 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 913 | SCREEN8 | HMMM DIY=1 → HMMM (DY): NY=0, SY=SY0-N |
| 914 | SCREEN8 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 915 | SCREEN8 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 916 | SCREEN8 | YMMM 上端で打ち切り → YMMM (DY): SY/NY |
| 917 | SCREEN8 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 918 | SCREEN8 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 919 | SCREEN8 | LMCM 上端で打ち切り → LMCM (SY): NY=NY0-N |
| 920 | SCREEN8 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 921 | SCREEN8 | LMMC 上端で打ち切り → LMMC (DY/CLR): NY=NY0-N |
| 922 | SCREEN8 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 923 | SCREEN8 | HMMC DIX=1 DIY=1 → HMMC (DY/CLR): NY=0 |
| 924 | SCREEN8 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 925 | SCREEN8 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 926 | SCREEN8 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 927 | SCREEN8 | LINE Y 主軸 DIY=1 → LINE (CLR): DY 進む |
| 928 | SCREEN8 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

## SCREEN6 のコマンド終了時のレジスタ

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 929 | SCREEN6 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 930 | SCREEN6 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 931 | SCREEN6 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 932 | SCREEN6 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 933 | SCREEN6 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 934 | SCREEN6 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 935 | SCREEN6 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 936 | SCREEN6 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 937 | SCREEN6 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 938 | SCREEN6 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 939 | SCREEN6 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 940 | SCREEN6 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 941 | SCREEN6 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 942 | SCREEN6 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 943 | SCREEN6 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 944 | SCREEN6 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 945 | SCREEN6 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 946 | SCREEN6 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 947 | SCREEN6 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

## SCREEN7 のコマンド終了時のレジスタ

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 948 | SCREEN7 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 949 | SCREEN7 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 950 | SCREEN7 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 951 | SCREEN7 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 952 | SCREEN7 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 953 | SCREEN7 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 954 | SCREEN7 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 955 | SCREEN7 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 956 | SCREEN7 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 957 | SCREEN7 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 958 | SCREEN7 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 959 | SCREEN7 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 960 | SCREEN7 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 961 | SCREEN7 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 962 | SCREEN7 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 963 | SCREEN7 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 964 | SCREEN7 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 965 | SCREEN7 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 966 | SCREEN7 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

## SCREEN10 のコマンド終了時のレジスタ

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 967 | SCREEN10 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 968 | SCREEN10 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 969 | SCREEN10 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 970 | SCREEN10 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 971 | SCREEN10 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 972 | SCREEN10 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 973 | SCREEN10 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 974 | SCREEN10 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 975 | SCREEN10 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 976 | SCREEN10 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 977 | SCREEN10 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 978 | SCREEN10 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 979 | SCREEN10 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 980 | SCREEN10 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 981 | SCREEN10 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 982 | SCREEN10 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 983 | SCREEN10 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 984 | SCREEN10 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 985 | SCREEN10 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

## SCREEN12 のコマンド終了時のレジスタ

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 986 | SCREEN12 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 987 | SCREEN12 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 988 | SCREEN12 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 989 | SCREEN12 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 990 | SCREEN12 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 991 | SCREEN12 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 992 | SCREEN12 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 993 | SCREEN12 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 994 | SCREEN12 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 995 | SCREEN12 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 996 | SCREEN12 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 997 | SCREEN12 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 998 | SCREEN12 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 999 | SCREEN12 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1000 | SCREEN12 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1001 | SCREEN12 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1002 | SCREEN12 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1003 | SCREEN12 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1004 | SCREEN12 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

## SCREEN0-4 で R#25 CMD=1 のコマンド終了時のレジスタ

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1005 | SCREEN0(W40) CMD=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1006 | SCREEN0(W40) CMD=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1007 | SCREEN0(W40) CMD=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1008 | SCREEN0(W40) CMD=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1009 | SCREEN0(W40) CMD=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1010 | SCREEN0(W40) CMD=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1011 | SCREEN0(W40) CMD=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1012 | SCREEN0(W40) CMD=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1013 | SCREEN0(W40) CMD=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1014 | SCREEN0(W40) CMD=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1015 | SCREEN0(W40) CMD=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1016 | SCREEN0(W40) CMD=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1017 | SCREEN0(W40) CMD=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1018 | SCREEN0(W40) CMD=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1019 | SCREEN0(W40) CMD=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1020 | SCREEN0(W40) CMD=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1021 | SCREEN0(W40) CMD=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1022 | SCREEN0(W40) CMD=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1023 | SCREEN0(W40) CMD=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1024 | SCREEN0(W80) CMD=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1025 | SCREEN0(W80) CMD=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1026 | SCREEN0(W80) CMD=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1027 | SCREEN0(W80) CMD=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1028 | SCREEN0(W80) CMD=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1029 | SCREEN0(W80) CMD=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1030 | SCREEN0(W80) CMD=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1031 | SCREEN0(W80) CMD=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1032 | SCREEN0(W80) CMD=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1033 | SCREEN0(W80) CMD=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1034 | SCREEN0(W80) CMD=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1035 | SCREEN0(W80) CMD=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1036 | SCREEN0(W80) CMD=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1037 | SCREEN0(W80) CMD=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1038 | SCREEN0(W80) CMD=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1039 | SCREEN0(W80) CMD=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1040 | SCREEN0(W80) CMD=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1041 | SCREEN0(W80) CMD=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1042 | SCREEN0(W80) CMD=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1043 | SCREEN1 CMD=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1044 | SCREEN1 CMD=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1045 | SCREEN1 CMD=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1046 | SCREEN1 CMD=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1047 | SCREEN1 CMD=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1048 | SCREEN1 CMD=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1049 | SCREEN1 CMD=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1050 | SCREEN1 CMD=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1051 | SCREEN1 CMD=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1052 | SCREEN1 CMD=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1053 | SCREEN1 CMD=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1054 | SCREEN1 CMD=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1055 | SCREEN1 CMD=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1056 | SCREEN1 CMD=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1057 | SCREEN1 CMD=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1058 | SCREEN1 CMD=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1059 | SCREEN1 CMD=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1060 | SCREEN1 CMD=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1061 | SCREEN1 CMD=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1062 | SCREEN2 CMD=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1063 | SCREEN2 CMD=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1064 | SCREEN2 CMD=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1065 | SCREEN2 CMD=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1066 | SCREEN2 CMD=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1067 | SCREEN2 CMD=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1068 | SCREEN2 CMD=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1069 | SCREEN2 CMD=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1070 | SCREEN2 CMD=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1071 | SCREEN2 CMD=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1072 | SCREEN2 CMD=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1073 | SCREEN2 CMD=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1074 | SCREEN2 CMD=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1075 | SCREEN2 CMD=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1076 | SCREEN2 CMD=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1077 | SCREEN2 CMD=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1078 | SCREEN2 CMD=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1079 | SCREEN2 CMD=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1080 | SCREEN2 CMD=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1081 | SCREEN3 CMD=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1082 | SCREEN3 CMD=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1083 | SCREEN3 CMD=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1084 | SCREEN3 CMD=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1085 | SCREEN3 CMD=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1086 | SCREEN3 CMD=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1087 | SCREEN3 CMD=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1088 | SCREEN3 CMD=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1089 | SCREEN3 CMD=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1090 | SCREEN3 CMD=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1091 | SCREEN3 CMD=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1092 | SCREEN3 CMD=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1093 | SCREEN3 CMD=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1094 | SCREEN3 CMD=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1095 | SCREEN3 CMD=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1096 | SCREEN3 CMD=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1097 | SCREEN3 CMD=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1098 | SCREEN3 CMD=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1099 | SCREEN3 CMD=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1100 | SCREEN4 CMD=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1101 | SCREEN4 CMD=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1102 | SCREEN4 CMD=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1103 | SCREEN4 CMD=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1104 | SCREEN4 CMD=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1105 | SCREEN4 CMD=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1106 | SCREEN4 CMD=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1107 | SCREEN4 CMD=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1108 | SCREEN4 CMD=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1109 | SCREEN4 CMD=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1110 | SCREEN4 CMD=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1111 | SCREEN4 CMD=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1112 | SCREEN4 CMD=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1113 | SCREEN4 CMD=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1114 | SCREEN4 CMD=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1115 | SCREEN4 CMD=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1116 | SCREEN4 CMD=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1117 | SCREEN4 CMD=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1118 | SCREEN4 CMD=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

## FG4=1 のコマンド終了時のレジスタ (V9968 のみ)

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1119 | SCREEN0(W40) CMD=1 FG4=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1120 | SCREEN0(W40) CMD=1 FG4=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1121 | SCREEN0(W40) CMD=1 FG4=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1122 | SCREEN0(W40) CMD=1 FG4=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1123 | SCREEN0(W40) CMD=1 FG4=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1124 | SCREEN0(W40) CMD=1 FG4=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1125 | SCREEN0(W40) CMD=1 FG4=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1126 | SCREEN0(W40) CMD=1 FG4=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1127 | SCREEN0(W40) CMD=1 FG4=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1128 | SCREEN0(W40) CMD=1 FG4=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1129 | SCREEN0(W40) CMD=1 FG4=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1130 | SCREEN0(W40) CMD=1 FG4=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1131 | SCREEN0(W40) CMD=1 FG4=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1132 | SCREEN0(W40) CMD=1 FG4=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1133 | SCREEN0(W40) CMD=1 FG4=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1134 | SCREEN0(W40) CMD=1 FG4=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1135 | SCREEN0(W40) CMD=1 FG4=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1136 | SCREEN0(W40) CMD=1 FG4=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1137 | SCREEN0(W40) CMD=1 FG4=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1138 | SCREEN0(W80) CMD=1 FG4=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1139 | SCREEN0(W80) CMD=1 FG4=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1140 | SCREEN0(W80) CMD=1 FG4=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1141 | SCREEN0(W80) CMD=1 FG4=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1142 | SCREEN0(W80) CMD=1 FG4=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1143 | SCREEN0(W80) CMD=1 FG4=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1144 | SCREEN0(W80) CMD=1 FG4=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1145 | SCREEN0(W80) CMD=1 FG4=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1146 | SCREEN0(W80) CMD=1 FG4=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1147 | SCREEN0(W80) CMD=1 FG4=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1148 | SCREEN0(W80) CMD=1 FG4=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1149 | SCREEN0(W80) CMD=1 FG4=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1150 | SCREEN0(W80) CMD=1 FG4=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1151 | SCREEN0(W80) CMD=1 FG4=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1152 | SCREEN0(W80) CMD=1 FG4=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1153 | SCREEN0(W80) CMD=1 FG4=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1154 | SCREEN0(W80) CMD=1 FG4=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1155 | SCREEN0(W80) CMD=1 FG4=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1156 | SCREEN0(W80) CMD=1 FG4=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1157 | SCREEN1 CMD=1 FG4=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1158 | SCREEN1 CMD=1 FG4=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1159 | SCREEN1 CMD=1 FG4=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1160 | SCREEN1 CMD=1 FG4=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1161 | SCREEN1 CMD=1 FG4=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1162 | SCREEN1 CMD=1 FG4=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1163 | SCREEN1 CMD=1 FG4=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1164 | SCREEN1 CMD=1 FG4=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1165 | SCREEN1 CMD=1 FG4=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1166 | SCREEN1 CMD=1 FG4=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1167 | SCREEN1 CMD=1 FG4=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1168 | SCREEN1 CMD=1 FG4=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1169 | SCREEN1 CMD=1 FG4=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1170 | SCREEN1 CMD=1 FG4=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1171 | SCREEN1 CMD=1 FG4=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1172 | SCREEN1 CMD=1 FG4=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1173 | SCREEN1 CMD=1 FG4=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1174 | SCREEN1 CMD=1 FG4=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1175 | SCREEN1 CMD=1 FG4=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1176 | SCREEN2 CMD=1 FG4=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1177 | SCREEN2 CMD=1 FG4=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1178 | SCREEN2 CMD=1 FG4=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1179 | SCREEN2 CMD=1 FG4=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1180 | SCREEN2 CMD=1 FG4=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1181 | SCREEN2 CMD=1 FG4=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1182 | SCREEN2 CMD=1 FG4=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1183 | SCREEN2 CMD=1 FG4=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1184 | SCREEN2 CMD=1 FG4=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1185 | SCREEN2 CMD=1 FG4=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1186 | SCREEN2 CMD=1 FG4=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1187 | SCREEN2 CMD=1 FG4=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1188 | SCREEN2 CMD=1 FG4=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1189 | SCREEN2 CMD=1 FG4=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1190 | SCREEN2 CMD=1 FG4=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1191 | SCREEN2 CMD=1 FG4=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1192 | SCREEN2 CMD=1 FG4=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1193 | SCREEN2 CMD=1 FG4=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1194 | SCREEN2 CMD=1 FG4=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1195 | SCREEN3 CMD=1 FG4=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1196 | SCREEN3 CMD=1 FG4=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1197 | SCREEN3 CMD=1 FG4=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1198 | SCREEN3 CMD=1 FG4=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1199 | SCREEN3 CMD=1 FG4=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1200 | SCREEN3 CMD=1 FG4=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1201 | SCREEN3 CMD=1 FG4=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1202 | SCREEN3 CMD=1 FG4=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1203 | SCREEN3 CMD=1 FG4=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1204 | SCREEN3 CMD=1 FG4=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1205 | SCREEN3 CMD=1 FG4=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1206 | SCREEN3 CMD=1 FG4=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1207 | SCREEN3 CMD=1 FG4=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1208 | SCREEN3 CMD=1 FG4=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1209 | SCREEN3 CMD=1 FG4=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1210 | SCREEN3 CMD=1 FG4=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1211 | SCREEN3 CMD=1 FG4=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1212 | SCREEN3 CMD=1 FG4=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1213 | SCREEN3 CMD=1 FG4=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1214 | SCREEN4 CMD=1 FG4=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1215 | SCREEN4 CMD=1 FG4=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1216 | SCREEN4 CMD=1 FG4=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1217 | SCREEN4 CMD=1 FG4=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1218 | SCREEN4 CMD=1 FG4=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1219 | SCREEN4 CMD=1 FG4=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1220 | SCREEN4 CMD=1 FG4=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1221 | SCREEN4 CMD=1 FG4=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1222 | SCREEN4 CMD=1 FG4=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1223 | SCREEN4 CMD=1 FG4=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1224 | SCREEN4 CMD=1 FG4=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1225 | SCREEN4 CMD=1 FG4=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1226 | SCREEN4 CMD=1 FG4=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1227 | SCREEN4 CMD=1 FG4=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1228 | SCREEN4 CMD=1 FG4=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1229 | SCREEN4 CMD=1 FG4=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1230 | SCREEN4 CMD=1 FG4=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1231 | SCREEN4 CMD=1 FG4=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1232 | SCREEN4 CMD=1 FG4=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1233 | SCREEN5 FG4=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1234 | SCREEN5 FG4=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1235 | SCREEN5 FG4=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1236 | SCREEN5 FG4=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1237 | SCREEN5 FG4=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1238 | SCREEN5 FG4=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1239 | SCREEN5 FG4=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1240 | SCREEN5 FG4=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1241 | SCREEN5 FG4=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1242 | SCREEN5 FG4=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1243 | SCREEN5 FG4=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1244 | SCREEN5 FG4=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1245 | SCREEN5 FG4=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1246 | SCREEN5 FG4=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1247 | SCREEN5 FG4=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1248 | SCREEN5 FG4=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1249 | SCREEN5 FG4=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1250 | SCREEN5 FG4=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1251 | SCREEN5 FG4=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1252 | SCREEN6 FG4=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1253 | SCREEN6 FG4=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1254 | SCREEN6 FG4=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1255 | SCREEN6 FG4=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1256 | SCREEN6 FG4=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1257 | SCREEN6 FG4=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1258 | SCREEN6 FG4=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1259 | SCREEN6 FG4=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1260 | SCREEN6 FG4=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1261 | SCREEN6 FG4=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1262 | SCREEN6 FG4=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1263 | SCREEN6 FG4=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1264 | SCREEN6 FG4=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1265 | SCREEN6 FG4=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1266 | SCREEN6 FG4=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1267 | SCREEN6 FG4=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1268 | SCREEN6 FG4=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1269 | SCREEN6 FG4=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1270 | SCREEN6 FG4=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1271 | SCREEN7 FG4=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1272 | SCREEN7 FG4=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1273 | SCREEN7 FG4=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1274 | SCREEN7 FG4=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1275 | SCREEN7 FG4=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1276 | SCREEN7 FG4=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1277 | SCREEN7 FG4=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1278 | SCREEN7 FG4=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1279 | SCREEN7 FG4=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1280 | SCREEN7 FG4=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1281 | SCREEN7 FG4=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1282 | SCREEN7 FG4=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1283 | SCREEN7 FG4=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1284 | SCREEN7 FG4=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1285 | SCREEN7 FG4=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1286 | SCREEN7 FG4=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1287 | SCREEN7 FG4=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1288 | SCREEN7 FG4=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1289 | SCREEN7 FG4=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1290 | SCREEN8 FG4=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1291 | SCREEN8 FG4=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1292 | SCREEN8 FG4=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1293 | SCREEN8 FG4=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1294 | SCREEN8 FG4=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1295 | SCREEN8 FG4=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1296 | SCREEN8 FG4=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1297 | SCREEN8 FG4=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1298 | SCREEN8 FG4=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1299 | SCREEN8 FG4=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1300 | SCREEN8 FG4=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1301 | SCREEN8 FG4=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1302 | SCREEN8 FG4=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1303 | SCREEN8 FG4=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1304 | SCREEN8 FG4=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1305 | SCREEN8 FG4=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1306 | SCREEN8 FG4=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1307 | SCREEN8 FG4=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1308 | SCREEN8 FG4=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1309 | SCREEN10 FG4=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1310 | SCREEN10 FG4=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1311 | SCREEN10 FG4=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1312 | SCREEN10 FG4=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1313 | SCREEN10 FG4=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1314 | SCREEN10 FG4=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1315 | SCREEN10 FG4=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1316 | SCREEN10 FG4=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1317 | SCREEN10 FG4=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1318 | SCREEN10 FG4=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1319 | SCREEN10 FG4=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1320 | SCREEN10 FG4=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1321 | SCREEN10 FG4=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1322 | SCREEN10 FG4=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1323 | SCREEN10 FG4=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1324 | SCREEN10 FG4=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1325 | SCREEN10 FG4=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1326 | SCREEN10 FG4=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1327 | SCREEN10 FG4=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1328 | SCREEN11 FG4=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1329 | SCREEN11 FG4=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1330 | SCREEN11 FG4=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1331 | SCREEN11 FG4=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1332 | SCREEN11 FG4=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1333 | SCREEN11 FG4=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1334 | SCREEN11 FG4=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1335 | SCREEN11 FG4=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1336 | SCREEN11 FG4=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1337 | SCREEN11 FG4=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1338 | SCREEN11 FG4=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1339 | SCREEN11 FG4=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1340 | SCREEN11 FG4=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1341 | SCREEN11 FG4=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1342 | SCREEN11 FG4=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1343 | SCREEN11 FG4=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1344 | SCREEN11 FG4=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1345 | SCREEN11 FG4=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1346 | SCREEN11 FG4=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1347 | SCREEN12 FG4=1 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1348 | SCREEN12 FG4=1 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1349 | SCREEN12 FG4=1 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1350 | SCREEN12 FG4=1 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1351 | SCREEN12 FG4=1 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1352 | SCREEN12 FG4=1 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1353 | SCREEN12 FG4=1 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1354 | SCREEN12 FG4=1 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1355 | SCREEN12 FG4=1 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1356 | SCREEN12 FG4=1 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1357 | SCREEN12 FG4=1 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1358 | SCREEN12 FG4=1 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1359 | SCREEN12 FG4=1 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1360 | SCREEN12 FG4=1 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1361 | SCREEN12 FG4=1 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1362 | SCREEN12 FG4=1 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1363 | SCREEN12 FG4=1 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1364 | SCREEN12 FG4=1 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1365 | SCREEN12 FG4=1 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

## 256KB モード (V58=0) のコマンド終了時のレジスタ (V9968 のみ)

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1366 | SCREEN5 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1367 | SCREEN5 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1368 | SCREEN5 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1369 | SCREEN5 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1370 | SCREEN5 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1371 | SCREEN5 | LMMV DIY=1 → LMMV OR (DY/CLR): NY=0 |
| 1372 | SCREEN5 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1373 | SCREEN5 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1374 | SCREEN5 | LMMM DIX=1 DIY=1 → LMMM (DY): NY=0, SY=SY0-N |
| 1375 | SCREEN5 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1376 | SCREEN5 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1377 | SCREEN5 | HMMM DIY=1 → HMMM (DY): NY=0, SY=SY0-N |
| 1378 | SCREEN5 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1379 | SCREEN5 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1380 | SCREEN5 | YMMM 上端で打ち切り → YMMM (DY): SY/NY |
| 1381 | SCREEN5 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1382 | SCREEN5 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1383 | SCREEN5 | LMCM 上端で打ち切り → LMCM (SY): NY=NY0-N |
| 1384 | SCREEN5 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1385 | SCREEN5 | LMMC 上端で打ち切り → LMMC (DY/CLR): NY=NY0-N |
| 1386 | SCREEN5 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1387 | SCREEN5 | HMMC DIX=1 DIY=1 → HMMC (DY/CLR): NY=0 |
| 1388 | SCREEN5 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1389 | SCREEN5 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1390 | SCREEN5 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1391 | SCREEN5 | LINE Y 主軸 DIY=1 → LINE (CLR): DY 進む |
| 1392 | SCREEN5 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1393 | SCREEN6 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1394 | SCREEN6 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1395 | SCREEN6 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1396 | SCREEN6 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1397 | SCREEN6 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1398 | SCREEN6 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1399 | SCREEN6 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1400 | SCREEN6 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1401 | SCREEN6 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1402 | SCREEN6 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1403 | SCREEN6 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1404 | SCREEN6 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1405 | SCREEN6 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1406 | SCREEN6 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1407 | SCREEN6 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1408 | SCREEN6 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1409 | SCREEN6 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1410 | SCREEN6 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1411 | SCREEN6 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1412 | SCREEN7 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1413 | SCREEN7 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1414 | SCREEN7 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1415 | SCREEN7 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1416 | SCREEN7 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1417 | SCREEN7 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1418 | SCREEN7 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1419 | SCREEN7 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1420 | SCREEN7 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1421 | SCREEN7 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1422 | SCREEN7 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1423 | SCREEN7 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1424 | SCREEN7 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1425 | SCREEN7 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1426 | SCREEN7 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1427 | SCREEN7 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1428 | SCREEN7 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1429 | SCREEN7 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1430 | SCREEN7 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1431 | SCREEN8 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1432 | SCREEN8 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1433 | SCREEN8 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1434 | SCREEN8 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1435 | SCREEN8 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1436 | SCREEN8 | LMMV DIY=1 → LMMV OR (DY/CLR): NY=0 |
| 1437 | SCREEN8 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1438 | SCREEN8 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1439 | SCREEN8 | LMMM DIX=1 DIY=1 → LMMM (DY): NY=0, SY=SY0-N |
| 1440 | SCREEN8 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1441 | SCREEN8 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1442 | SCREEN8 | HMMM DIY=1 → HMMM (DY): NY=0, SY=SY0-N |
| 1443 | SCREEN8 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1444 | SCREEN8 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1445 | SCREEN8 | YMMM 上端で打ち切り → YMMM (DY): SY/NY |
| 1446 | SCREEN8 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1447 | SCREEN8 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1448 | SCREEN8 | LMCM 上端で打ち切り → LMCM (SY): NY=NY0-N |
| 1449 | SCREEN8 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1450 | SCREEN8 | LMMC 上端で打ち切り → LMMC (DY/CLR): NY=NY0-N |
| 1451 | SCREEN8 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1452 | SCREEN8 | HMMC DIX=1 DIY=1 → HMMC (DY/CLR): NY=0 |
| 1453 | SCREEN8 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1454 | SCREEN8 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1455 | SCREEN8 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1456 | SCREEN8 | LINE Y 主軸 DIY=1 → LINE (CLR): DY 進む |
| 1457 | SCREEN8 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### コマンド終了時のレジスタ (一部だけ再設定して次のコマンドを実行)

| No. | モード | 内容 |
|---:|---|---|
| 1458 | SCREEN11 | HMMV → HMMV (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1459 | SCREEN11 | HMMV DIX=1 DIY=1 → HMMV (DY/CLR): NY=0, ARG 保持 |
| 1460 | SCREEN11 | HMMV 上端で打ち切り → HMMV (DY/CLR): NY=NY0-N |
| 1461 | SCREEN11 | HMMV 上端で打ち切り → STOP → HMMV (DY/CLR): 待機中の STOP は NY を変えない |
| 1462 | SCREEN11 | LMMV DIX=1 → LMMV XOR (NY/CLR): DX/NX/ARG 保持, DY=DY0+N |
| 1463 | SCREEN11 | LMMV 上端で打ち切り → LMMV (DY/CLR): NY=NY0-N |
| 1464 | SCREEN11 | LMMM → LMMM XOR (NY): SX/DX/NX 保持, SY/DY=+N |
| 1465 | SCREEN11 | LMMM 上端で打ち切り → LMMM (DY): SY/NY |
| 1466 | SCREEN11 | HMMM → HMMM (NY): SX/DX/NX 保持, SY/DY=+N |
| 1467 | SCREEN11 | HMMM 上端で打ち切り → HMMM (DY): SY/NY |
| 1468 | SCREEN11 | YMMM DIX=1 → YMMM (NY): DX/ARG 保持, SY/DY=+N |
| 1469 | SCREEN11 | LMCM → LMCM (NY): SX/NX 保持, SY=SY0+N |
| 1470 | SCREEN11 | LMCM DIX=1 → PSET (R#46 のみ): CLR=最後に読んだ色 |
| 1471 | SCREEN11 | LMMC → LMMC XOR (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1472 | SCREEN11 | HMMC → HMMC (NY/CLR): DX/NX 保持, DY=DY0+N |
| 1473 | SCREEN11 | PSET → PSET XOR (R#46 のみ): DX/DY/CLR 保持 |
| 1474 | SCREEN11 | POINT → PSET → POINT (R#46 のみ): CLR=読んだ色, SX/SY/DX/DY 保持 |
| 1475 | SCREEN11 | LINE X 主軸 DIX=1 → LINE (CLR): DX/NX/NY/ARG 保持, DY 進む |
| 1476 | SCREEN11 | SRCH → SRCH → PSET (R#46 のみ): SX/SY/CLR/ARG/DX/DY 保持 |

### LFMM 終了時のレジスタ

| No. | モード | 内容 |
|---:|---|---|
| 1477 | SCREEN5 | LFMM → LFMM (R#46 のみ): DX=DX0+8*NX, DY/NY 保持, フォントアドレスが進む |
| 1478 | SCREEN5 | LFMM → HMMV → LFMM (DY/NY): 他のコマンドはフォントアドレスを進めない |

### LFMC 終了時のレジスタ

| No. | モード | 内容 |
|---:|---|---|
| 1479 | SCREEN5 | LFMC → LFMC (CLR/R#46): DX=DX0+NX, DY/NY 保持 |
| 1480 | SCREEN5 | LFMC → HMMV → LFMC (DY/NY/CLR): DX=DX0+NX |

### LFMM 終了時のレジスタ

| No. | モード | 内容 |
|---:|---|---|
| 1481 | SCREEN8 | LFMM → LFMM (R#46 のみ): DX=DX0+8*NX, DY/NY 保持, フォントアドレスが進む |
| 1482 | SCREEN8 | LFMM → HMMV → LFMM (DY/NY): 他のコマンドはフォントアドレスを進めない |

### LFMC 終了時のレジスタ

| No. | モード | 内容 |
|---:|---|---|
| 1483 | SCREEN8 | LFMC → LFMC (CLR/R#46): DX=DX0+NX, DY/NY 保持 |
| 1484 | SCREEN8 | LFMC → HMMV → LFMC (DY/NY/CLR): DX=DX0+NX |
