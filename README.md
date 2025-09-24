# 概要

SeatScape VRは、パーソナルスペース研究をVR空間上で行うことを目的に開発された実験支援ツールです。

## 主要機能

 - 座席とNPCのレイアウト調整
 - 実験参加者1人を対象とした座席選択法による実験の支援
 - メッセージや説明文の画面提示

## 動作環境

SeatScape VRはGodot4.4を使用して開発しています。実行する際はGPUを搭載したPC上での使用を推奨します。動作確認済みのプラットフォームは以下のとおりです。

 - Windows11
 - MetaQuest(PCVR)

## Screen shot

<p align="center">
<img src="https://www.design.kyushu-u.ac.jp/~eigo/image/seatscape-vr/circle_2d.webp" width="70%">
<br>
<img src="https://www.design.kyushu-u.ac.jp/~eigo/image/seatscape-vr/circle_3d.webp" width="70%">
<br>
<img src="https://www.design.kyushu-u.ac.jp/~eigo/image/seatscape-vr/circle_3d_2.webp" width="70%">
<br>
<img src="https://www.design.kyushu-u.ac.jp/~eigo/image/seatscape-vr/circle_3d_3.webp" width="70%">
<br>
<img src="https://www.design.kyushu-u.ac.jp/~eigo/image/seatscape-vr/isle_2d.webp" width="70%">
<br>
<img src="https://www.design.kyushu-u.ac.jp/~eigo/image/seatscape-vr/isle_3d.webp" width="70%">
<br>
<img src="https://www.design.kyushu-u.ac.jp/~eigo/image/seatscape-vr/tables_3d.webp" width="70%">
</p>

## 設定ファイル

部屋や座席の作成はdata/configsフォルダ内のjsonファイルに記述します。

### meshes.json

座席や家具の定義を行うファイルです。

### npcs.json

NPCの定義を行うファイルです。

### rooms.json

部屋の定義を行うファイルです。

