# Line Drawing From Image (Igor Pro)

**カラー画像から線画を生成**する Igor Pro 用スクリプトです。画像をグレースケール変換し、Sobelフィルターでエッジを抽出、抽出した座標を基に**巡回セールスマン法（TSP）**で線画を描画します。

---

## 📦 主な機能

- RGB画像 → グレースケール変換
- Sobelフィルターでエッジ強度を計算
- 自動しきい値で座標抽出（エッジ強度に基づく）
- 点数を制限してランダム間引き
- Nearest Neighbor法による TSP（巡回セールスマン問題）で線画を生成
- 描画結果を Igor Pro 上で表示

---

## 🔧 使用方法

### 1. 画像をWaveとして読み込む

RGB画像を `imageName` という名前で 3次元 Wave（幅×高さ×RGB）として読み込んでおきます。

### 2. メイン関数を実行

```igorpro
Main("imageName", 10000, 3000)
```
- "imageName": 読み込んだRGB画像Waveの名前（例: "imgRGB"）
- 10000: エッジ抽出時の最大点数
- 3000: 最終的に使う点数の上限（TSP前にランダム間引き）

## 💡関数の概要
| 関数名                                | 説明                     |
| ---------------------------------- | ---------------------- |
| `ConvertImageToGrayscale`          | RGB画像をグレースケールに変換       |
| `SobelEdge`                        | Sobelフィルターで勾配マップを作成    |
| `ExtractCoordsFromGrad`            | 勾配強度に基づいて座標を抽出         |
| `ExtractEdgeCoordsAutoThreshold`   | 点数が最大を超えないように自動しきい値を決定 |
| `NearestNeighborTSP`               | 最近傍貪欲法でTSP経路を計算        |
| `RemoveRandomPointsUntilThreshold` | 点数を指定数までランダムに削減        |
| `Main`                             | 一連の処理をまとめて実行する主関数      |

## ✅補足
- 実行中の進行状況は Print 文でログ出力されます。
- 処理対象の画像が大きい場合、点数制限に注意してください（3万点以上はAbort）。
- 処理結果は Igor のグラフウィンドウで自動的に表示されます。
- 巡回順は最適解とは限りませんが、高速に実行可能です。

## 出力例
[こちら](https://www.irasutoya.com/2019/04/blog-post_90.html)のイラストが下記のように変換されます。

![image](https://github.com/arad166/LineDrawingFromImage/blob/main/image.jpg)
